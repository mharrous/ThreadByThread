# Capturas de la vista de la ventana (calle vacía y cada tipo de suceso) en captures_street\.
# Uso:  powershell -File tests\run_street_shots.ps1 [-Godot "ruta\a\godot.exe"]
param(
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
)
$proj = Split-Path -Parent $PSScriptRoot
$out = Join-Path $proj "captures_street"
New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $out -Filter *.png | Remove-Item -Force
$log = Join-Path $env:TEMP "tbt_street.log"
Remove-Item $log -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $Godot -ArgumentList @("--path", "`"$proj`"", "--windowed", "--resolution", "1600x900", "res://tests/screenshot_runner.tscn", "--log-file", "`"$log`"", "--", "--out=`"$out`"", "--no-autopause", "--test-mode", "--street") -Wait -PassThru
Get-Content $log -Encoding UTF8 | Where-Object { $_ -match "ERROR|WARN|SCRIPT|rendimiento|Parse" } | Select-Object -First 30
Get-ChildItem $out | Select-Object Name
exit $p.ExitCode
