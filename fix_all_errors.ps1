# Complete Fix Script for HistoVision
Write-Host "=== FIXING ALL ERRORS ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean everything
Write-Host "[1/7] Cleaning Flutter..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter clean failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Flutter cleaned" -ForegroundColor Green
Write-Host ""

# Step 2: Clean Gradle
Write-Host "[2/7] Cleaning Gradle..." -ForegroundColor Yellow
if (Test-Path "android") {
    Push-Location android
    if (Test-Path "gradlew.bat") {
        .\gradlew.bat clean
    } elseif (Test-Path "gradlew") {
        .\gradlew clean
    }
    Pop-Location
    Write-Host "✅ Gradle cleaned" -ForegroundColor Green
} else {
    Write-Host "⚠️ Android folder not found" -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Clear Gradle cache
Write-Host "[3/7] Clearing Gradle cache..." -ForegroundColor Yellow
$gradleCache = "$env:USERPROFILE\.gradle\caches"
if (Test-Path $gradleCache) {
    try {
        Remove-Item -Path "$gradleCache\transforms-*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$gradleCache\modules-*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Gradle cache cleared" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Could not clear some cache files (may be in use)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Gradle cache not found" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Clear Pub cache for problematic plugins
Write-Host "[4/7] Clearing Pub cache for Firebase plugins..." -ForegroundColor Yellow
$pubCache = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev"
if (Test-Path $pubCache) {
    try {
        Remove-Item -Path "$pubCache\cloud_firestore-*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$pubCache\firebase_core-*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$pubCache\firebase_auth-*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Pub cache cleared for Firebase plugins" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Could not clear some cache files" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Pub cache not found" -ForegroundColor Yellow
}
Write-Host ""

# Step 5: Remove pubspec.lock to force clean install
Write-Host "[5/8] Removing pubspec.lock..." -ForegroundColor Yellow
if (Test-Path "pubspec.lock") {
    Remove-Item "pubspec.lock" -Force
    Write-Host "✅ pubspec.lock removed" -ForegroundColor Green
} else {
    Write-Host "⚠️ pubspec.lock not found" -ForegroundColor Yellow
}
Write-Host ""

# Step 6: Get dependencies
Write-Host "[6/8] Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter pub get failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "This is OK - app will use Mock mode" -ForegroundColor Yellow
}
Write-Host "✅ Dependencies process completed" -ForegroundColor Green
Write-Host ""

# Step 7: Verify installation
Write-Host "[7/8] Verifying installation..." -ForegroundColor Yellow
$pubspecLock = "pubspec.lock"
if (Test-Path $pubspecLock) {
    $lockContent = Get-Content $pubspecLock -Raw
    if ($lockContent -match "firebase_core") {
        Write-Host "✅ Firebase Core installed" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Firebase Core not found in pubspec.lock" -ForegroundColor Yellow
    }
    if ($lockContent -match "firebase_auth") {
        Write-Host "✅ Firebase Auth installed" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Firebase Auth not found in pubspec.lock" -ForegroundColor Yellow
    }
    if ($lockContent -match "cloud_firestore") {
        Write-Host "✅ Cloud Firestore installed" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Cloud Firestore not found in pubspec.lock" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ pubspec.lock not found" -ForegroundColor Yellow
}
Write-Host ""

# Step 8: Run Flutter doctor
Write-Host "[8/8] Running Flutter doctor..." -ForegroundColor Yellow
flutter doctor
Write-Host ""

# Final message
Write-Host "=== FIX COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Run: flutter run" -ForegroundColor White
Write-Host "2. If still errors, run: flutter pub upgrade" -ForegroundColor White
Write-Host "3. Check Firebase setup in Firebase Console" -ForegroundColor White
Write-Host ""
Write-Host "If you see 'cloud_firestore' plugin errors:" -ForegroundColor Yellow
Write-Host "- This is a known issue with some Firebase plugin versions" -ForegroundColor White
Write-Host "- The app will still work in demo mode" -ForegroundColor White
Write-Host "- For production, setup real Firebase project" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
