param(
    [int]$Port = 5173,
    [switch]$OpenBrowser
)

& "$PSScriptRoot\scripts\start_web_with_env.ps1" -Port $Port -OpenBrowser:$OpenBrowser
exit $LASTEXITCODE
