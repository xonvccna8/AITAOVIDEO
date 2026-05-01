# Run HistoVision WITHOUT Firebase (Mock Mode Only)
$asciiWorkspace = & "$PSScriptRoot\scripts\get_ascii_workspace.ps1"
Push-Location $asciiWorkspace
try {
    Write-Host "=== Running HistoVision in Mock Mode ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "This will run the app WITHOUT Firebase." -ForegroundColor Yellow
    Write-Host "All features will work using Mock Authentication." -ForegroundColor Yellow
    Write-Host ""

    # Step 1: Remove Firebase dependencies temporarily
    Write-Host "[1/3] Preparing Mock Mode..." -ForegroundColor Yellow

    $pubspecPath = "pubspec.yaml"
    $pubspecBackup = "pubspec.yaml.backup"

    # Backup original pubspec.yaml
    if (Test-Path $pubspecPath) {
        Copy-Item $pubspecPath $pubspecBackup -Force
        Write-Host "Backed up pubspec.yaml" -ForegroundColor Green
    }

    # Create pubspec without Firebase
    $content = Get-Content $pubspecPath -Raw
    $contentNoFirebase = $content -replace "(?m)^\s*#\s*Firebase.*$", ""
    $contentNoFirebase = $contentNoFirebase -replace "(?m)^\s*firebase_core:.*$", "  # firebase_core: ^3.3.0  # Disabled for Mock mode"
    $contentNoFirebase = $contentNoFirebase -replace "(?m)^\s*firebase_auth:.*$", "  # firebase_auth: ^5.1.4  # Disabled for Mock mode"
    $contentNoFirebase = $contentNoFirebase -replace "(?m)^\s*cloud_firestore:.*$", "  # cloud_firestore: ^5.2.1  # Disabled for Mock mode"

    Set-Content -Path $pubspecPath -Value $contentNoFirebase
    Write-Host "Disabled Firebase dependencies" -ForegroundColor Green
    Write-Host ""

    # Step 2: Get dependencies
    Write-Host "[2/3] Installing dependencies..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) { exit 1 }
    Write-Host "Dependencies installed" -ForegroundColor Green
    Write-Host ""

    # Step 3: Run app
    Write-Host "[3/3] Running app in Mock Mode..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Demo Accounts:" -ForegroundColor Cyan
    Write-Host "  Teacher: teacher@histovision.com / teacher123" -ForegroundColor White
    Write-Host "  Student: student@histovision.com / student123" -ForegroundColor White
    Write-Host ""

    flutter run
    $exitCode = $LASTEXITCODE

    # Restore original pubspec.yaml
    if (Test-Path $pubspecBackup) {
        Copy-Item $pubspecBackup $pubspecPath -Force
        Remove-Item $pubspecBackup -Force
        Write-Host ""
        Write-Host "Restored original pubspec.yaml" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "=== Done! ===" -ForegroundColor Green
    exit $exitCode
} finally {
    Pop-Location
}
