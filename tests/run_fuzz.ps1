# Prueba de "mono": acciones aleatorias con comprobación de invariantes (ver fuzz_test.gd).
# Uso:  powershell -File tests\run_fuzz.ps1 [-Steps 600] [-Seed 12345] [-Count 2]
param(
    [int]$Steps = 600,
    [int]$Seed = 12345,
    [int]$Count = 2,
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
)
$proj = Split-Path -Parent $PSScriptRoot
$log = Join-Path $env:TEMP "tbt_fuzz.log"
Remove-Item $log -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$proj`"", "res://tests/fuzz_test.tscn", "--log-file", "`"$log`"", "--", "--test-mode", "--steps=$Steps", "--seed=$Seed", "--count=$Count") -NoNewWindow -Wait -PassThru
Get-Content $log -Encoding UTF8 | Where-Object { $_ -match "^==|VIOLACI|Acciones|RESULTADO|ERROR|SCRIPT|WARNING" } | Select-Object -First 60
exit $p.ExitCode
