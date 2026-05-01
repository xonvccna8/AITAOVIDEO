# Script Clean v?? Ch???y App - Local Database Mode
$asciiWorkspace = & "$PSScriptRoot\scripts\get_ascii_workspace.ps1"
Push-Location $asciiWorkspace
try {
    Write-Host "=== CLEAN & RUN - Local Database Mode ===" -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Clean Flutter
    Write-Host "[1/5] Cleaning Flutter..." -ForegroundColor Yellow
    flutter clean
    Write-Host "Flutter cleaned" -ForegroundColor Green
    Write-Host ""

    # Step 2: Delete pubspec.lock
    Write-Host "[2/5] Deleting pubspec.lock..." -ForegroundColor Yellow
    if (Test-Path "pubspec.lock") {
        Remove-Item "pubspec.lock" -Force
        Write-Host "pubspec.lock deleted" -ForegroundColor Green
    } else {
        Write-Host "pubspec.lock not found" -ForegroundColor Yellow
    }
    Write-Host ""

    # Step 3: Delete .dart_tool
    Write-Host "[3/5] Deleting .dart_tool..." -ForegroundColor Yellow
    if (Test-Path ".dart_tool") {
        Remove-Item ".dart_tool" -Recurse -Force
        Write-Host ".dart_tool deleted" -ForegroundColor Green
    } else {
        Write-Host ".dart_tool not found" -ForegroundColor Yellow
    }
    Write-Host ""

    # Step 4: Get dependencies
    Write-Host "[4/5] Getting dependencies..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to get dependencies" -ForegroundColor Red
        Write-Host ""
        Write-Host "Trying flutter pub upgrade..." -ForegroundColor Yellow
        flutter pub upgrade
        if ($LASTEXITCODE -ne 0) {
            exit 1
        }
    }
    Write-Host "Dependencies installed" -ForegroundColor Green
    Write-Host ""

    # Step 5: Run app
    Write-Host "[5/5] Running app..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Demo Accounts:" -ForegroundColor Cyan
    Write-Host "   Teacher: teacher@histovision.com / teacher123" -ForegroundColor White
    Write-Host "   Student: student@histovision.com / student123" -ForegroundColor White
    Write-Host ""
    Write-Host "Using LOCAL DATABASE (No Firebase)" -ForegroundColor Green
    Write-Host ""

    flutter run
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
