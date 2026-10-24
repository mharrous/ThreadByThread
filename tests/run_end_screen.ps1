# Pantalla final con clics reales: "Seguir explorando" y "Menú principal". Código de salida 0 = correcto.
# Uso:  powershell -File tests\run_end_screen.ps1
param(
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
)
$proj = Split-Path -Parent $PSScriptRoot
$log = Join-Path $env:TEMP "tbt_end_screen.log"
Remove-Item $log -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$proj`"", "res://tests/end_screen_test.tscn", "--log-file", "`"$log`"", "--", "--test-mode", "--show-title") -NoNewWindow -Wait -PassThru
Get-Content $log -Encoding UTF8 | Where-Object { $_ -notmatch "^Godot Engine" }
exit $p.ExitCode
