# Ejecuta la prueba de humo sin ventana. Código de salida 0 = correcto.
# Uso:  powershell -File tests\run_smoke.ps1 [-Count 0] [-Rooms 2] [-Godot "ruta\a\godot.exe"]
#   -Count 1  -> 1 objeto por tipo (rápido, por defecto)
#   -Count 0  -> cantidades del juego completo (tarda varios minutos)
#   -Rooms K  -> solo las K primeras salas
#   -From J   -> empieza en la sala J (0 = la primera)
param(
    [int]$Count = 1,
    [int]$Rooms = 99,
    [int]$From = 0,
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
)
$proj = Split-Path -Parent $PSScriptRoot
$log = Join-Path $env:TEMP "tbt_smoke.log"
$out = Join-Path $env:TEMP "tbt_smoke_stdout.log"
Remove-Item $log, $out -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$proj`"", "res://tests/smoke_test.tscn", "--log-file", "`"$log`"", "--", "--test-mode", "--count=$Count", "--rooms=$Rooms", "--from=$From") -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out
Get-Content $log -Encoding UTF8 | Where-Object { $_ -notmatch "^Godot Engine" }
exit $p.ExitCode
