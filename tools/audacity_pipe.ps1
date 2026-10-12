# Cliente mínimo de mod-script-pipe de Audacity 3.x (PowerShell 5.1, sin dependencias).
# Uso:  . .\tools\audacity_pipe.ps1 ; Connect-Audacity ; Send-Audacity 'Help: Command="Reverb"'
# Requisitos: Audacity 3.x abierto con el módulo mod-script-pipe activado
# (Editar > Preferencias > Módulos > mod-script-pipe = Activado).

$script:AudacityTo = $null
$script:AudacityFrom = $null
$script:AudacityWriter = $null
$script:AudacityReader = $null

function Connect-Audacity {
    param([int]$TimeoutMs = 15000)
    $script:AudacityTo = New-Object System.IO.Pipes.NamedPipeClientStream(".", "ToSrvPipe", [System.IO.Pipes.PipeDirection]::Out)
    $script:AudacityFrom = New-Object System.IO.Pipes.NamedPipeClientStream(".", "FromSrvPipe", [System.IO.Pipes.PipeDirection]::In)
    $script:AudacityTo.Connect($TimeoutMs)
    $script:AudacityFrom.Connect($TimeoutMs)
    $enc = New-Object System.Text.ASCIIEncoding
    $script:AudacityWriter = New-Object System.IO.StreamWriter($script:AudacityTo, $enc)
    $script:AudacityWriter.AutoFlush = $true
    $script:AudacityReader = New-Object System.IO.StreamReader($script:AudacityFrom, $enc)
}

function Disconnect-Audacity {
    foreach ($s in @($script:AudacityTo, $script:AudacityFrom)) { if ($s) { $s.Dispose() } }
}

# Envía un comando y devuelve las líneas de respuesta (la última es "BatchCommand finished: OK|Failed!").
function Send-Audacity {
    param([Parameter(Mandatory)][string]$Command)
    $script:AudacityWriter.Write($Command + "`r`n`0")
    $lines = New-Object System.Collections.Generic.List[string]
    while ($true) {
        $line = $script:AudacityReader.ReadLine()
        if ($null -eq $line) { break }
        if ($line -eq "") {
            if ($lines.Count -gt 0) { break } else { continue }
        }
        $lines.Add($line)
    }
    return ,$lines.ToArray()
}
