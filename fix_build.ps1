# Script to fix build issues
$asciiWorkspace = & "$PSScriptRoot\scripts\get_ascii_workspace.ps1"
Push-Location $asciiWorkspace
try {
    Write-Host "=== Fixing HistoVision Build Issues ===" -ForegroundColor Green

    Write-Host "`n[1/6] Cleaning Flutter build..." -ForegroundColor Yellow
    flutter clean
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host "`n[2/6] Getting Flutter dependencies..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host "`n[3/6] Cleaning Android build..." -ForegroundColor Yellow
    Push-Location (Join-Path $asciiWorkspace 'android')
    try {
        .\gradlew.bat clean
        if ($LASTEXITCODE -ne 0) { exit 1 }
    } finally {
        Pop-Location
    }

    Write-Host "`n[4/6] Clearing Gradle cache..." -ForegroundColor Yellow
    if (Test-Path "$env:USERPROFILE\.gradle\caches") {
        Remove-Item -Path "$env:USERPROFILE\.gradle\caches\transforms-*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:USERPROFILE\.gradle\caches\modules-*" -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "`n[5/6] Building APK..." -ForegroundColor Yellow
    flutter build apk --debug
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host "`n[6/6] Build complete!" -ForegroundColor Green
    Write-Host "`nIf there are still errors, please check:" -ForegroundColor Cyan
    Write-Host "1. Firebase configuration (google-services.json)" -ForegroundColor White
    Write-Host "2. Internet connection" -ForegroundColor White
    Write-Host "3. Android SDK installation" -ForegroundColor White
} finally {
    Pop-Location
}