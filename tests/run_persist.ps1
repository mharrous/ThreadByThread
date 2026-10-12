# Guardado y carga entre procesos: una ejecución guarda y otra, desde cero, comprueba que se restauró.
# Uso:  powershell -File tests\run_persist.ps1
param(
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
)
$proj = Split-Path -Parent $PSScriptRoot
$code = 0
foreach ($phase in @("write", "read")) {
    $log = Join-Path $env:TEMP "tbt_persist_$phase.log"
    Remove-Item $log -ErrorAction SilentlyContinue
    # La segunda ejecución debe conservar el guardado de la primera (en pruebas se borra al arrancar).
    $extra = if ($phase -eq "read") { @("--keep-save") } else { @() }
    $p = Start-Process -FilePath $Godot -ArgumentList (@("--headless", "--path", "`"$proj`"", "res://tests/persist_test.tscn", "--log-file", "`"$log`"", "--", "--test-mode", "--phase=$phase") + $extra) -NoNewWindow -Wait -PassThru
    Get-Content $log -Encoding UTF8 | Where-Object { $_ -match "^==|OK|FALLO|RESULTADO|ERROR|SCRIPT" }
    if ($p.ExitCode -ne 0) { $code = $p.ExitCode }
}
exit $code
