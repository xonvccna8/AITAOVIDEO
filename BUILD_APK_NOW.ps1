param(
    [ValidateSet("debug", "release", "profile")]
    [string]$Mode = "debug"
)

& "$PSScriptRoot\scripts\build_apk_with_env.ps1" -Mode $Mode
exit $LASTEXITCODE
