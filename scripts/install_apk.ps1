param(
    [string]$DeviceId = "",
    [switch]$BuildIfMissing,
    [switch]$LaunchApp = $true,
    [switch]$ReinstallClean
)

# Script tự động cài đặt APK vào thiết bị Android
# Sử dụng: .\scripts\install_apk.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Auto Install APK to Android Device" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Tìm ADB
$adbPath = $null
$possiblePaths = @(
    "C:\Users\xonvc\AppData\Local\Android\Sdk\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "C:\Users\xonvc\AppData\Local\Android\sdk\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe",
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $adbPath = $path
        Write-Host "Found ADB at: $adbPath" -ForegroundColor Green
        break
    }
}

if (-not $adbPath) {
    Write-Host "ERROR: ADB not found. Please install Android SDK or set ANDROID_HOME." -ForegroundColor Red
    exit 1
}

# Kiểm tra thiết bị
Write-Host ""
Write-Host "Checking connected devices..." -ForegroundColor Yellow
$devicesOutput = & $adbPath devices 2>&1
$devices = @()

foreach ($line in $devicesOutput) {
    if ($line -match "^\s*([^\s]+)\s+device\s*$") {
        $devices += $matches[1]
    }
}

if ($devices.Count -eq 0) {
    Write-Host "ERROR: No Android device connected." -ForegroundColor Red
    Write-Host "Please connect your device via USB and enable USB debugging." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Current devices:" -ForegroundColor Yellow
    & $adbPath devices
    exit 1
}

Write-Host "Found $($devices.Count) device(s):" -ForegroundColor Green
foreach ($device in $devices) {
    Write-Host "  - $device" -ForegroundColor Cyan
}

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    $DeviceId = $devices[0]
}

if ($devices -notcontains $DeviceId) {
    Write-Host "ERROR: Requested device '$DeviceId' is not connected." -ForegroundColor Red
    exit 1
}

# Tìm APK
$apkPaths = @(
    "android\app\build\outputs\apk\debug\app-debug.apk",
    "build\app\outputs\flutter-apk\app-debug.apk",
    "app-debug.apk"
)

$apkPath = $null
foreach ($path in $apkPaths) {
    if (Test-Path $path) {
        $apkPath = (Resolve-Path $path).Path
        Write-Host ""
        Write-Host "Found APK at: $apkPath" -ForegroundColor Green
        $apkInfo = Get-Item $apkPath
        Write-Host "Size: $([math]::Round($apkInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
        break
    }
}

if (-not $apkPath -and $BuildIfMissing) {
    Write-Host ""
    Write-Host "APK not found. Building debug APK automatically..." -ForegroundColor Yellow
    flutter build apk --debug
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to build APK automatically." -ForegroundColor Red
        exit 1
    }

    foreach ($path in $apkPaths) {
        if (Test-Path $path) {
            $apkPath = (Resolve-Path $path).Path
            Write-Host "Built APK at: $apkPath" -ForegroundColor Green
            break
        }
    }
}

if (-not $apkPath) {
    Write-Host ""
    Write-Host "ERROR: APK not found. Please build the app first:" -ForegroundColor Red
    Write-Host "  flutter build apk --debug" -ForegroundColor Yellow
    exit 1
}

# Cài đặt APK
Write-Host ""
Write-Host "Installing APK to device: $DeviceId..." -ForegroundColor Yellow

$packageName = "com.example.histovision"
$targetDevice = $DeviceId
Write-Host "Target device: $targetDevice" -ForegroundColor Cyan

if ($ReinstallClean) {
    Write-Host "Performing clean reinstall..." -ForegroundColor Yellow
    & $adbPath -s $targetDevice uninstall $packageName 2>&1 | Out-Null
}

# Cài đặt APK mới
Write-Host "Installing new APK..." -ForegroundColor Yellow
Write-Host ""

$installOutput = & $adbPath -s $targetDevice install -r "$apkPath" 2>&1
$installOutputString = $installOutput -join "`n"

$installSuccess = $false
if ($LASTEXITCODE -eq 0) {
    $installSuccess = $true
} elseif ($installOutputString -match "Success") {
    $installSuccess = $true
} elseif ($installOutputString -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
    Write-Host "Existing app signature is incompatible. Removing old app and retrying..." -ForegroundColor Yellow
    & $adbPath -s $targetDevice uninstall $packageName 2>&1 | Out-Null
    $installOutput = & $adbPath -s $targetDevice install "$apkPath" 2>&1
    $installOutputString = $installOutput -join "`n"
    if ($LASTEXITCODE -eq 0 -or $installOutputString -match "Success") {
        $installSuccess = $true
    }
}

if ($installSuccess) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  APK installed successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Device: $targetDevice" -ForegroundColor Cyan
    Write-Host "Package: $packageName" -ForegroundColor Cyan
    Write-Host ""
    if ($LaunchApp) {
        Write-Host "Launching app automatically..." -ForegroundColor Yellow
        & $adbPath -s $targetDevice shell am force-stop $packageName 2>&1 | Out-Null
        & $adbPath -s $targetDevice shell monkey -p $packageName -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
        Write-Host "App launched!" -ForegroundColor Green
    } else {
        Write-Host "Launching app..." -ForegroundColor Yellow
        Write-Host "You can now launch the app on your device." -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "ERROR: Failed to install APK" -ForegroundColor Red
    Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Installation output:" -ForegroundColor Yellow
    $installOutput | ForEach-Object { Write-Host $_ }
    Write-Host ""
    
    # Phân tích lỗi và đưa ra gợi ý
    if ($installOutputString -match "INSTALL_FAILED_USER_RESTRICTED" -or $installOutputString -match "Install canceled by user") {
        Write-Host "Troubleshooting:" -ForegroundColor Cyan
        Write-Host "  1. Check your device screen and accept the installation prompt" -ForegroundColor White
        Write-Host "  2. Go to Settings > Developer Options > Enable 'Install via USB'" -ForegroundColor White
        Write-Host "  3. Go to Settings > Security > Enable 'Unknown sources' or 'Install unknown apps'" -ForegroundColor White
        Write-Host "  4. Try running the script again" -ForegroundColor White
    } elseif ($installOutputString -match "INSTALL_FAILED_INSUFFICIENT_STORAGE") {
        Write-Host "Troubleshooting:" -ForegroundColor Cyan
        Write-Host "  Your device doesn't have enough storage space." -ForegroundColor White
        Write-Host "  Please free up some space and try again." -ForegroundColor White
    } elseif ($installOutputString -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
        Write-Host "Troubleshooting:" -ForegroundColor Cyan
        Write-Host "  Existing app uses a different signing key." -ForegroundColor White
        Write-Host "  Run again with -ReinstallClean if the automatic retry still fails." -ForegroundColor White
    } else {
        Write-Host "Troubleshooting:" -ForegroundColor Cyan
        Write-Host "  Please check the error message above and:" -ForegroundColor White
        Write-Host "  1. Ensure USB debugging is enabled" -ForegroundColor White
        Write-Host "  2. Check device connection" -ForegroundColor White
        Write-Host "  3. Try uninstalling the app manually first" -ForegroundColor White
    }
    
    exit 1
}

