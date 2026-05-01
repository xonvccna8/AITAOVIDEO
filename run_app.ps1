# Script ch???y app HistoVision
$asciiWorkspace = & "$PSScriptRoot\scripts\get_ascii_workspace.ps1"
Push-Location $asciiWorkspace
try {
    Write-Host "=== HistoVision - Local Database Mode ===" -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Get dependencies
    Write-Host "[1/2] Getting dependencies..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to get dependencies" -ForegroundColor Red
        exit 1
    }
    Write-Host "Dependencies ready" -ForegroundColor Green
    Write-Host ""

    # Step 2: Run app
    Write-Host "[2/2] Running app..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Demo Accounts:" -ForegroundColor Cyan
    Write-Host "   Teacher: teacher@histovision.com / teacher123" -ForegroundColor White
    Write-Host "   Student: student@histovision.com / student123" -ForegroundColor White
    Write-Host ""

    flutter run
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
