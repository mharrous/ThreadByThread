# Ejecuta la prueba de humo sin ventana. Código de salida 0 = correcto.
# Uso:  powershell -File tests\run_smoke.ps1 [-ItemsPerColor 15] [-Godot "ruta\a\godot.exe"]
#   -ItemsPerColor 1  -> 10 objetos (rápido, por defecto)
#   -ItemsPerColor 15 -> 150 objetos (tarda unos minutos)
param(
    [int]$ItemsPerColor = 1,
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
)
$proj = Split-Path -Parent $PSScriptRoot
$log = Join-Path $env:TEMP "tbt_smoke.log"
$out = Join-Path $env:TEMP "tbt_smoke_stdout.log"
Remove-Item $log, $out -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$proj`"", "res://tests/smoke_test.tscn", "--log-file", "`"$log`"", "--", "--test-mode", "--items-per-color=$ItemsPerColor") -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out
Get-Content $log -Encoding UTF8 | Where-Object { $_ -notmatch "^Godot Engine" }
exit $p.ExitCode
