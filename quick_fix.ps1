# Quick Fix Script for HistoVision
Write-Host "=== Quick Fix HistoVision ===" -ForegroundColor Cyan

# Step 1: Flutter pub get
Write-Host "`n[1/2] Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Step 2: Check for errors
Write-Host "`n[2/2] Checking for errors..." -ForegroundColor Yellow
flutter analyze

Write-Host "`n✅ Done! Now you can run:" -ForegroundColor Green
Write-Host "  flutter run" -ForegroundColor White
Write-Host "  or" -ForegroundColor White
Write-Host "  flutter build apk" -ForegroundColor White
