# Pule los sonidos de art/audio/raw/ con Audacity 3.x (mod-script-pipe) y deja el resultado
# en art/audio/sfx/. El juego usa automáticamente lo que haya en sfx/.
#
#   powershell -File tools\audacity_polish.ps1 [-Only place_1,pick_2] [-Revert]
#
# Requisitos: Audacity 3.x abierto con mod-script-pipe activado. No toques Audacity mientras corre.
# Cadenas (conservadoras; se ajustan en $Chains):
#   tick   golpes y roces: baja un poco los graves + un toque de sala pequeña
#   chime  campanas: quita graves + sala media con cola
#   bird   pájaros: sin graves ni agudos duros + reverb de exterior (sensación de distancia)
# wind (bucle) no se procesa: un filtro rompería la unión del bucle.
# -Revert borra los WAV de sfx/ generados por este script y vuelve a la síntesis.
param(
    [string[]]$Only = @(),
    [switch]$Revert
)

$proj = Split-Path -Parent $PSScriptRoot
$raw = Join-Path $proj "art\audio\raw"
$sfx = Join-Path $proj "art\audio\sfx"
$tmp = Join-Path $env:TEMP "tbt_audacity"
New-Item -ItemType Directory -Force $tmp | Out-Null

if ($Revert) {
    foreach ($f in Get-ChildItem $raw -Filter *.wav) {
        $target = Join-Path $sfx $f.Name
        foreach ($p in @($target, "$target.import")) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p } }
    }
    "Revertido: sfx/ sin ficheros pulidos."
    return
}

. (Join-Path $PSScriptRoot "audacity_pipe.ps1")

# --- Cadenas de efectos --------------------------------------------------------------------
$room = 'Reverb: RoomSize={0} Delay={1} Reverberance={2} HfDamping={3} ToneLow=100 ToneHigh={4} WetGain={5} DryGain=0 StereoWidth=0 WetOnly=0'
$Chains = @{
    tick  = @{
        pad = 0.2
        cmds = @(
            'BassAndTreble: Bass=-6 Treble=0 Gain=0',
            ($room -f 18, 5, 15, 65, 60, -17),
            'SelectAll:', 'FadeOut:'
        )
    }
    chime = @{
        pad = 0.6
        cmds = @(
            'BassAndTreble: Bass=-9 Treble=0 Gain=0',
            ($room -f 40, 12, 35, 40, 100, -12),
            'SelectAll:', 'FadeOut:'
        )
    }
    bird  = @{
        pad = 0.6
        cmds = @(
            'BassAndTreble: Bass=-18 Treble=-3 Gain=0',
            ($room -f 70, 30, 45, 55, 80, -9),
            'SelectAll:', 'FadeOut:'
        )
    }
}

function Get-Chain([string]$name) {
    $base = $name -replace '_\d+$', ''
    switch -Regex ($base) {
        '^(place|collection|room_complete)$' { return 'chime' }
        '^bird$' { return 'bird' }
        '^wind$' { return $null }
        default { return 'tick' }
    }
}

# --- Lectura/escritura de WAV PCM 16 bit --------------------------------------------------
function Read-Wav([string]$path) {
    $b = [System.IO.File]::ReadAllBytes($path)
    $pos = 12
    $fmt = $null
    while ($pos + 8 -le $b.Length) {
        $id = [System.Text.Encoding]::ASCII.GetString($b, $pos, 4)
        $len = [BitConverter]::ToInt32($b, $pos + 4)
        if ($id -eq "fmt ") {
            $fmt = @{ channels = [BitConverter]::ToInt16($b, $pos + 10); rate = [BitConverter]::ToInt32($b, $pos + 12); bits = [BitConverter]::ToInt16($b, $pos + 22) }
        } elseif ($id -eq "data") {
            $n = [int]($len / 2)
            $peak = 0
            for ($i = 0; $i -lt $n; $i++) {
                $s = [Math]::Abs([int][BitConverter]::ToInt16($b, $pos + 8 + 2 * $i))
                if ($s -gt $peak) { $peak = $s }
            }
            return @{ fmt = $fmt; peak = $peak / 32768.0; frames = [int]($n / $fmt.channels); bytes = $b; dataPos = $pos + 8; dataLen = $len }
        }
        $pos += 8 + $len + ($len % 2)
    }
    throw "WAV sin bloque data: $path"
}

function Write-PaddedWav($wav, [double]$padSeconds, [string]$outPath) {
    $padBytes = [int]($padSeconds * $wav.fmt.rate) * $wav.fmt.channels * 2
    $dataLen = $wav.dataLen + $padBytes
    $ms = New-Object System.IO.MemoryStream
    $w = New-Object System.IO.BinaryWriter($ms)
    $w.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF")); $w.Write([int](36 + $dataLen))
    $w.Write([System.Text.Encoding]::ASCII.GetBytes("WAVEfmt ")); $w.Write([int]16)
    $w.Write([int16]1); $w.Write([int16]$wav.fmt.channels); $w.Write([int]$wav.fmt.rate)
    $w.Write([int]($wav.fmt.rate * $wav.fmt.channels * 2)); $w.Write([int16]($wav.fmt.channels * 2)); $w.Write([int16]16)
    $w.Write([System.Text.Encoding]::ASCII.GetBytes("data")); $w.Write([int]$dataLen)
    $w.Write($wav.bytes, $wav.dataPos, $wav.dataLen)
    $w.Write((New-Object byte[] $padBytes))
    $w.Flush()
    [System.IO.File]::WriteAllBytes($outPath, $ms.ToArray())
}

function Assert-Ok($reply, [string]$what) {
    $last = $reply[$reply.Length - 1]
    if ($last -notmatch "OK") { throw "Audacity falló en '$what': $($reply -join ' | ')" }
}

# Arranca Audacity si no está abierto y espera a que exista el pipe.
if (-not ([System.IO.Directory]::GetFiles("\\.\pipe\") | Where-Object { $_ -match "ToSrvPipe" })) {
    $aud = "C:\Program Files\Audacity\Audacity.exe"
    if (-not (Test-Path $aud)) { throw "No encuentro Audacity 3.x en $aud" }
    Start-Process -FilePath $aud
    $waited = 0
    while (-not ([System.IO.Directory]::GetFiles("\\.\pipe\") | Where-Object { $_ -match "ToSrvPipe" }) -and $waited -lt 40) { Start-Sleep -Seconds 1; $waited++ }
    Start-Sleep -Seconds 2
}
# --- Proceso -------------------------------------------------------------------------------
Connect-Audacity
[void](Send-Audacity 'SelectAll:'); [void](Send-Audacity 'RemoveTracks:')
$files = Get-ChildItem $raw -Filter *.wav | Sort-Object Name
if ($Only.Count -gt 0) { $files = $files | Where-Object { $Only -contains $_.BaseName } }
$done = 0
foreach ($f in $files) {
    $chainName = Get-Chain $f.BaseName
    if (-not $chainName) { "saltado  $($f.Name)  (bucle)"; continue }
    $chain = $Chains[$chainName]
    $wav = Read-Wav $f.FullName
    $padded = Join-Path $tmp $f.Name
    Write-PaddedWav $wav $chain.pad $padded
    $peakDb = [Math]::Min(-1.0, 20.0 * [Math]::Log10([Math]::Max($wav.peak, 0.001)))

    Assert-Ok (Send-Audacity ('Import2: Filename="{0}"' -f ($padded -replace '\\', '/'))) "Import2 $($f.Name)"
    Assert-Ok (Send-Audacity 'SelectAll:') "SelectAll"
    foreach ($c in $chain.cmds) { Assert-Ok (Send-Audacity $c) $c }
    Assert-Ok (Send-Audacity ('Normalize: PeakLevel={0} ApplyVolume=1 RemoveDcOffset=1 StereoIndependent=0' -f [Math]::Round($peakDb, 2).ToString([System.Globalization.CultureInfo]::InvariantCulture))) "Normalize"
    $out = Join-Path $sfx $f.Name
    Assert-Ok (Send-Audacity ('Export2: Filename="{0}" NumChannels=1' -f ($out -replace '\\', '/'))) "Export2 $($f.Name)"
    Assert-Ok (Send-Audacity 'SelectAll:') "SelectAll"
    Assert-Ok (Send-Audacity 'RemoveTracks:') "RemoveTracks"

    $res = Read-Wav $out
    "{0,-22} cadena={1,-5} pico {2:N2} -> {3:N2}  duración {4:N2}s -> {5:N2}s  ({6} Hz, {7} bit, {8} canal)" -f $f.Name, $chainName, $wav.peak, $res.peak, ($wav.frames / $wav.fmt.rate), ($res.frames / $res.fmt.rate), $res.fmt.rate, $res.fmt.bits, $res.fmt.channels
    $done++
}
Disconnect-Audacity
"Pulidos: $done. Abre Godot (o --import) para que los importe."
