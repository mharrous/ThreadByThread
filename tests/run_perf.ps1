# Mide FPS con todos los objetos a 1080p sin VSync (abre una ventana ~20 s). -Low: sin "Iluminación avanzada".
# Uso:  powershell -File tests\run_perf.ps1
param(
    [switch]$Low,
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64.exe"
)
$proj = Split-Path -Parent $PSScriptRoot
$log = Join-Path $env:TEMP "tbt_perf.log"
Remove-Item $log -ErrorAction SilentlyContinue
$gargs = @("--path", "`"$proj`"", "--windowed", "--resolution", "1920x1080", "--disable-vsync", "res://tests/perf_test.tscn", "--log-file", "`"$log`"", "--", "--test-mode", "--no-autopause", "--no-vsync")
if ($Low) { $gargs += "--low" }
$p = Start-Process -FilePath $Godot -ArgumentList $gargs -Wait -PassThru
Get-Content $log -Encoding UTF8 | Where-Object { $_ -match "==|fps=|ERROR|SCRIPT" }
exit $p.ExitCode
