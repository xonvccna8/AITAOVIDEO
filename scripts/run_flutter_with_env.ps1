param(
    [string]$Target = "lib/main_local.dart",
    [string]$DeviceId = "",
    [switch]$DryRun
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
    Write-Host "TOAN HOC 4.0 - Flutter auto run" -ForegroundColor Cyan
    Write-Host "Target: $Target" -ForegroundColor DarkGray
    Write-Host "Workspace: $workspace" -ForegroundColor DarkGray
    Write-Host "Using env: $($local.Path)" -ForegroundColor DarkGray
    Write-Host ""

    if ($DryRun) {
        Write-Host "Dart defines loaded:" -ForegroundColor Yellow
        foreach ($arg in $dartDefineArgs) {
            $name = ($arg -replace '^--dart-define=', '').Split("=")[0]
            Write-Host "  $name" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "Command preview:" -ForegroundColor Yellow
        $maskedDartDefineArgs = @()
        foreach ($arg in $dartDefineArgs) {
            $name = ($arg -replace '^--dart-define=', '').Split("=")[0]
            $maskedDartDefineArgs += "--dart-define=$name=***"
        }
        $previewArgs = @("run", "-t", $Target) + $maskedDartDefineArgs
        if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
            $previewArgs += @("--device-id", $DeviceId)
        }
        Write-Host ("flutter " + ($previewArgs -join " ")) -ForegroundColor White
        exit 0
    }

    Write-Host "[1/2] Getting Flutter dependencies..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        try {
            $devicesJson = flutter devices --machine | ConvertFrom-Json
            $androidDevice = $devicesJson |
                Where-Object { $_.platformType -eq "android" } |
                Select-Object -First 1
            if ($androidDevice -and $androidDevice.id) {
                $DeviceId = $androidDevice.id
            }
        } catch {
            Write-Host "Could not auto-detect Android device. Flutter will choose the default target." -ForegroundColor Yellow
        }
    }

    Write-Host "[2/2] Running Flutter with API keys from .env.local..." -ForegroundColor Yellow
    $runArgs = @("run", "-t", $Target) + $dartDefineArgs
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        Write-Host "Using device: $DeviceId" -ForegroundColor Green
        $runArgs += @("--device-id", $DeviceId)
    }

    & flutter @runArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
