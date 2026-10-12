# Genera capturas del juego en captures\ (abre una ventana unos segundos).
# Uso:  powershell -File tests\run_shots.ps1 [-Godot "ruta\a\godot.exe"]
param(
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
)
$proj = Split-Path -Parent $PSScriptRoot
$out = Join-Path $proj "captures"
New-Item -ItemType Directory -Force $out | Out-Null
Remove-Item "$out\*.png" -ErrorAction SilentlyContinue
$log = Join-Path $env:TEMP "tbt_shots.log"
Remove-Item $log -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $Godot -ArgumentList @("--path", "`"$proj`"", "--windowed", "--resolution", "1600x900", "res://tests/screenshot_runner.tscn", "--log-file", "`"$log`"", "--", "--out=`"$out`"", "--no-autopause", "--test-mode") -Wait -PassThru
Get-Content $log -Encoding UTF8 | Where-Object { $_ -match "ERROR|WARN|SCRIPT" }
Get-ChildItem $out | Select-Object Name
exit $p.ExitCode
