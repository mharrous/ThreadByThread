# Graba el tráiler con el Movie Maker de Godot (vídeo y sonido del juego) y lo pasa a mp4 con ffmpeg.
# La ventana del proyecto es de 1600×900: mientras graba, un override.cfg temporal la pone a 1920×1080 sin
# bordes (Godot lo lee al arrancar y luego se borra). Tarda unos 3 minutos por idioma; no hay que tocar nada.
# Uso:  powershell -File tools\trailer\grabar_trailer.ps1 [-Lang es,en] [-Godot "ruta\a\godot.exe"]
# Salida: build\trailer\thread_by_thread_trailer_<idioma>.mp4  (1920×1080, 30 fps, H.264 + AAC)
param(
    [string[]]$Lang = @("es", "en"),
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
)
$proj = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out = Join-Path $proj "build\trailer"
New-Item -ItemType Directory -Force $out | Out-Null
$override = Join-Path $proj "override.cfg"
Set-Content -Path $override -Encoding ascii -Value @(
    "[display]", "window/size/window_width_override=1920", "window/size/window_height_override=1080",
    "window/size/borderless=true", "window/size/position=Vector2i(0, 0)")
foreach ($l in $Lang) {
    $avi = Join-Path $out "trailer_$l.avi"
    $mp4 = Join-Path $out "thread_by_thread_trailer_$l.mp4"
    Remove-Item $avi, $mp4 -ErrorAction SilentlyContinue
    Write-Host "Grabando ($l)..."
    $p = Start-Process -FilePath $Godot -ArgumentList @("--path", "`"$proj`"", "--resolution", "1920x1080",
        "--write-movie", "`"$avi`"", "--fixed-fps", "30", "res://tools/trailer/trailer.tscn",
        "--", "--test-mode", "--no-autopause", "--lang=$l") -Wait -PassThru
    if (-not (Test-Path $avi)) { Remove-Item $override; Write-Error "No se ha grabado $avi"; exit 1 }
    # Calidad alta, compatible con redes y Steam: H.264 yuv420p, sonido AAC 192 kb/s, limitador (sin picos
    # que saturen) y fundido de entrada.
    & ffmpeg -y -loglevel error -i $avi -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart `
        -c:a aac -b:a 192k -af "alimiter=limit=0.9:level=disabled,afade=t=in:d=0.6" $mp4
    if ($LASTEXITCODE -ne 0) { Write-Error "ffmpeg falló con $avi"; exit 1 }
    Remove-Item $avi
    Write-Host "Listo: $mp4"
}
Remove-Item $override
