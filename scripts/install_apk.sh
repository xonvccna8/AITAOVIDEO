#!/bin/bash
# Script tự động cài đặt APK vào thiết bị Android (Linux/Mac)
# Sử dụng: ./scripts/install_apk.sh

echo "========================================"
echo "  Auto Install APK to Android Device"
echo "========================================"
echo ""

# Tìm ADB
ADB_PATH=""
if [ -n "$ANDROID_HOME" ]; then
    ADB_PATH="$ANDROID_HOME/platform-tools/adb"
elif [ -n "$ANDROID_SDK_ROOT" ]; then
    ADB_PATH="$ANDROID_SDK_ROOT/platform-tools/adb"
else
    ADB_PATH=$(which adb)
fi

if [ -z "$ADB_PATH" ] || [ ! -f "$ADB_PATH" ]; then
    echo "ERROR: ADB not found. Please install Android SDK or set ANDROID_HOME."
    exit 1
fi

echo "Found ADB at: $ADB_PATH"

# Kiểm tra thiết bị
echo ""
echo "Checking connected devices..."
DEVICES=$($ADB_PATH devices | grep -w "device" | awk '{print $1}')

if [ -z "$DEVICES" ]; then
    echo "ERROR: No Android device connected."
    echo "Please connect your device via USB and enable USB debugging."
    echo ""
    echo "Current devices:"
    $ADB_PATH devices
    exit 1
fi

DEVICE_COUNT=$(echo "$DEVICES" | wc -l)
echo "Found $DEVICE_COUNT device(s):"
echo "$DEVICES" | while read device; do
    echo "  - $device"
done

# Tìm APK
APK_PATH=""
for path in "android/app/build/outputs/apk/debug/app-debug.apk" \
            "build/app/outputs/flutter-apk/app-debug.apk" \
            "app-debug.apk"; do
    if [ -f "$path" ]; then
        APK_PATH=$(realpath "$path")
        echo ""
        echo "Found APK at: $APK_PATH"
        APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
        echo "Size: $APK_SIZE"
        break
    fi
done

if [ -z "$APK_PATH" ]; then
    echo ""
    echo "ERROR: APK not found. Please build the app first:"
    echo "  flutter build apk --debug"
    exit 1
fi

# Cài đặt APK
FIRST_DEVICE=$(echo "$DEVICES" | head -n 1)
echo ""
echo "Installing APK to device: $FIRST_DEVICE..."

# Gỡ cài đặt app cũ nếu có
PACKAGE_NAME="com.example.histovision"
echo "Checking if app is already installed..."
if $ADB_PATH -s "$FIRST_DEVICE" shell pm list packages | grep -q "$PACKAGE_NAME"; then
    echo "App is already installed. Uninstalling old version..."
    $ADB_PATH -s "$FIRST_DEVICE" uninstall "$PACKAGE_NAME" > /dev/null 2>&1
    sleep 2
fi

# Cài đặt APK mới
echo "Installing new APK..."
if $ADB_PATH -s "$FIRST_DEVICE" install -r "$APK_PATH"; then
    echo ""
    echo "========================================"
    echo "  APK installed successfully!"
    echo "========================================"
    echo ""
    echo "Device: $FIRST_DEVICE"
    echo "Package: $PACKAGE_NAME"
    echo ""
    echo "You can now launch the app on your device."
    
    read -p "Do you want to launch the app now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Launching app..."
        $ADB_PATH -s "$FIRST_DEVICE" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1
        echo "App launched!"
    fi
else
    echo ""
    echo "ERROR: Failed to install APK"
    exit 1
fi

