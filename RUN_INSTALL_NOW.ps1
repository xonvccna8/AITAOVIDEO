param(
    [string]$DeviceId = ""
)

$asciiWorkspace = & "$PSScriptRoot\scripts\get_ascii_workspace.ps1"
Push-Location $asciiWorkspace
try {
    Write-Host "" 
    Write-Host "HISTOVISION - BUILD, INSTALL AND LAUNCH" -ForegroundColor Cyan
    Write-Host "ASCII workspace: $asciiWorkspace" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "[1/3] Installing dependencies..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to get dependencies" -ForegroundColor Red
        exit 1
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
            Write-Host "Could not detect Android device from flutter devices. Using first ADB device." -ForegroundColor Yellow
        }
    }

    Write-Host "[2/3] Building debug APK..." -ForegroundColor Yellow
    flutter build apk --debug
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "[3/3] Installing and launching on phone..." -ForegroundColor Yellow
    & "$asciiWorkspace\scripts\install_apk.ps1" -DeviceId $DeviceId -BuildIfMissing -LaunchApp
    exit $LASTEXITCODE
} finally {
    Pop-Location
}