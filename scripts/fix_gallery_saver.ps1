# Script để tự động sửa lỗi gallery_saver plugin sau flutter pub get
# LƯU Ý: Sử dụng scripts/fix_plugins.ps1 để fix tất cả plugins cùng lúc
# Chạy script này sau mỗi lần chạy: flutter pub get

Write-Host "Fixing gallery_saver plugin issues..." -ForegroundColor Yellow
Write-Host "NOTE: Consider using scripts/fix_plugins.ps1 for comprehensive fixes" -ForegroundColor Yellow

$pubCache = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev"
$gallerySaverPath = "$pubCache\gallery_saver-2.3.2\android\build.gradle"

if (-not (Test-Path $gallerySaverPath)) {
    Write-Host "gallery_saver plugin not found at: $gallerySaverPath" -ForegroundColor Red
    Write-Host "Please run 'flutter pub get' first" -ForegroundColor Yellow
    exit 1
}

# Đọc nội dung file
$content = Get-Content $gallerySaverPath -Raw

# Kiểm tra và thêm namespace nếu chưa có
if ($content -notmatch "namespace\s+'") {
    $content = $content -replace "(android\s+\{[^}]*)(compileSdkVersion)", "`$1    namespace 'carnegietechnologies.gallery_saver'`n    `$2"
    Write-Host "Added namespace to gallery_saver" -ForegroundColor Green
}

# Kiểm tra và thêm compileOptions nếu chưa có
if ($content -notmatch "compileOptions\s+\{") {
    $content = $content -replace "(android\s+\{[^}]*)(sourceSets)", "`$1    compileOptions {`n        sourceCompatibility JavaVersion.VERSION_11`n        targetCompatibility JavaVersion.VERSION_11`n    }`n`n    `$2"
    Write-Host "Added compileOptions to gallery_saver" -ForegroundColor Green
}

# Kiểm tra và thêm kotlinOptions nếu chưa có
if ($content -notmatch "kotlinOptions\s+\{") {
    $content = $content -replace "(compileOptions[^}]*\})", "`$1`n`n    kotlinOptions {`n        jvmTarget = '11'`n    }"
    Write-Host "Added kotlinOptions to gallery_saver" -ForegroundColor Green
}

# Ghi lại file
Set-Content -Path $gallerySaverPath -Value $content -NoNewline

Write-Host "gallery_saver plugin fixed successfully!" -ForegroundColor Green
Write-Host "You can now build your app." -ForegroundColor Cyan

