# Script cài đặt nhanh APK (không có tương tác)
# Sử dụng: .\scripts\quick_install.ps1

$adbPath = "C:\Users\xonvc\AppData\Local\Android\sdk\platform-tools\adb.exe"
$apkPath = "android\app\build\outputs\apk\debug\app-debug.apk"
$packageName = "com.example.histovision"

if (-not (Test-Path $adbPath)) {
    Write-Host "ADB not found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $apkPath)) {
    Write-Host "APK not found! Building..." -ForegroundColor Yellow
    flutter build apk --debug
    if (-not (Test-Path $apkPath)) {
        Write-Host "Build failed!" -ForegroundColor Red
        exit 1
    }
}

$devices = & $adbPath devices | Select-String -Pattern "device$" | ForEach-Object { ($_ -split "\s+")[0] }
if ($devices.Count -eq 0) {
    Write-Host "No device connected!" -ForegroundColor Red
    exit 1
}

$device = $devices[0]
Write-Host "Installing to device: $device" -ForegroundColor Cyan

# Uninstall old version
& $adbPath -s $device uninstall $packageName 2>&1 | Out-Null

# Install new APK
Write-Host "Installing APK..." -ForegroundColor Yellow
$result = & $adbPath -s $device install -r $apkPath 2>&1

if ($LASTEXITCODE -eq 0 -or ($result -join "`n") -match "Success") {
    Write-Host "Installation successful!" -ForegroundColor Green
    Write-Host "Launching app..." -ForegroundColor Cyan
    & $adbPath -s $device shell monkey -p $packageName -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
} else {
    Write-Host "Installation failed:" -ForegroundColor Red
    $result | ForEach-Object { Write-Host $_ }
    Write-Host ""
    Write-Host "Please check your device and accept the installation prompt." -ForegroundColor Yellow
    Write-Host "Or run: .\scripts\install_apk.ps1 for interactive installation." -ForegroundColor Yellow
}

