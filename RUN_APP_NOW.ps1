param(
    [string]$DeviceId = ""
)

# ===================================
# RUN HISTOVISION APP - ONE CLICK
# Always runs from ASCII workspace to avoid Unicode path issues.
# ===================================
$asciiWorkspace = & "$PSScriptRoot\scripts\get_ascii_workspace.ps1"
Push-Location $asciiWorkspace
try {
    Write-Host ""
    Write-Host "HISTOVISION - ANDROID ONE CLICK RUN" -ForegroundColor Cyan
    Write-Host "ASCII workspace: $asciiWorkspace" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "[1/2] Installing dependencies..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to get dependencies" -ForegroundColor Red
        exit 1
    }
    Write-Host "Dependencies ready" -ForegroundColor Green
    Write-Host ""

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
            Write-Host "Could not parse device list automatically. Falling back to default device selection." -ForegroundColor Yellow
        }
    }

    Write-Host "[2/2] Running app..." -ForegroundColor Yellow
    Write-Host ""
    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        Write-Host "No specific device found. Running default flutter device selection." -ForegroundColor Yellow
        flutter run
    } else {
        Write-Host "Using device: $DeviceId" -ForegroundColor Green
        flutter run --device-id $DeviceId
    }
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
