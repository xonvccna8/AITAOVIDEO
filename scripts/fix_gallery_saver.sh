#!/bin/bash
# Script để tự động sửa lỗi gallery_saver plugin sau flutter pub get
# Dùng cho Linux/Mac

echo "Fixing gallery_saver plugin issues..."

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
GALLERY_SAVER_PATH="$PUB_CACHE/hosted/pub.dev/gallery_saver-2.3.2/android/build.gradle"

if [ ! -f "$GALLERY_SAVER_PATH" ]; then
    echo "gallery_saver plugin not found at: $GALLERY_SAVER_PATH"
    echo "Please run 'flutter pub get' first"
    exit 1
fi

# Backup file
cp "$GALLERY_SAVER_PATH" "$GALLERY_SAVER_PATH.bak"

# Kiểm tra và thêm namespace nếu chưa có
if ! grep -q "namespace" "$GALLERY_SAVER_PATH"; then
    sed -i '/android {/a\    namespace '\''carnegietechnologies.gallery_saver'\''' "$GALLERY_SAVER_PATH"
    echo "Added namespace to gallery_saver"
fi

# Kiểm tra và thêm compileOptions nếu chưa có
if ! grep -q "compileOptions" "$GALLERY_SAVER_PATH"; then
    sed -i '/namespace/a\    compileOptions {\n        sourceCompatibility JavaVersion.VERSION_11\n        targetCompatibility JavaVersion.VERSION_11\n    }' "$GALLERY_SAVER_PATH"
    echo "Added compileOptions to gallery_saver"
fi

# Kiểm tra và thêm kotlinOptions nếu chưa có
if ! grep -q "kotlinOptions" "$GALLERY_SAVER_PATH"; then
    sed -i '/compileOptions {/,/}/a\    kotlinOptions {\n        jvmTarget = '\''11'\''\n    }' "$GALLERY_SAVER_PATH"
    echo "Added kotlinOptions to gallery_saver"
fi

echo "gallery_saver plugin fixed successfully!"
echo "You can now build your app."

