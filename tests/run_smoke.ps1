# Ejecuta la prueba de humo sin ventana. Código de salida 0 = correcto.
# Uso:  powershell -File tests\run_smoke.ps1 [-Godot "ruta\a\godot.exe"]
param(
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
)
$proj = Split-Path -Parent $PSScriptRoot
$log = Join-Path $env:TEMP "tbt_smoke.log"
$out = Join-Path $env:TEMP "tbt_smoke_stdout.log"
Remove-Item $log, $out -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$proj`"", "res://tests/smoke_test.tscn", "--log-file", "`"$log`"") -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out
Get-Content $log -Encoding UTF8 | Where-Object { $_ -notmatch "^Godot Engine" }
exit $p.ExitCode
