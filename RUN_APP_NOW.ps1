param(
    [string]$DeviceId = "",
    [switch]$DryRun
)

& "$PSScriptRoot\scripts\run_flutter_with_env.ps1" -DeviceId $DeviceId -DryRun:$DryRun
exit $LASTEXITCODE
