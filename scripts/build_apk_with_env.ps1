param(
    [string]$Target = "lib/main_local.dart",
    [ValidateSet("debug", "release", "profile")]
    [string]$Mode = "debug"
)

. "$PSScriptRoot\env_helpers.ps1"

$local = Assert-LocalEnv
$dartDefineArgs = Get-DartDefineArgs -EnvValues $local.Values
$workspace = $local.Root
$asciiWorkspaceScript = Join-Path $PSScriptRoot "get_ascii_workspace.ps1"
if (Test-Path -LiteralPath $asciiWorkspaceScript) {
    try {
        $workspace = & $asciiWorkspaceScript
    } catch {
        Write-Host "Could not create ASCII workspace. Falling back to project path." -ForegroundColor Yellow
    }
}

Push-Location $workspace
try {
    Write-Host ""
    Write-Host "TOAN HOC 4.0 - Flutter APK build" -ForegroundColor Cyan
    Write-Host "Target: $Target" -ForegroundColor DarkGray
    Write-Host "Mode: $Mode" -ForegroundColor DarkGray
    Write-Host "Workspace: $workspace" -ForegroundColor DarkGray
    Write-Host "Using env: $($local.Path)" -ForegroundColor DarkGray
    Write-Host ""

    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $buildArgs = @("build", "apk", "-t", $Target, "--$Mode") + $dartDefineArgs
    & flutter @buildArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
