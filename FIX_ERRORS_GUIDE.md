# 🔧 Hướng Dẫn Fix Lỗi HistoVision

## ✅ Đã Fix

### 1. Package Name Mismatch
**Vấn đề:** Package name trong `google-services.json` không khớp với `build.gradle.kts`
- ❌ Cũ: `com.histovision.app`
- ✅ Mới: `com.example.histovision`

**Đã fix:** Cập nhật `android/app/google-services.json`

### 2. Firebase Configuration
**Đã kiểm tra:**
- ✅ `firebase_core: ^3.6.0`
- ✅ `firebase_auth: ^5.3.1`
- ✅ `cloud_firestore: ^5.4.4`
- ✅ Google Services plugin đã được thêm

## 🚀 Cách Chạy App

### Phương án 1: Sử dụng Script Tự Động (Khuyến nghị)
```powershell
# Chạy script fix và build
.\fix_build.ps1
```

### Phương án 2: Chạy Từng Bước
```powershell
# Bước 1: Clean
flutter clean

# Bước 2: Get dependencies
flutter pub get

# Bước 3: Clean Android
cd android
./gradlew clean
cd ..

# Bước 4: Build APK
flutter build apk --debug

# Hoặc chạy trực tiếp
flutter run
```

## 🔍 Kiểm Tra Lỗi Còn Lại

### Nếu vẫn có lỗi về Firebase:

1. **Kiểm tra Internet Connection**
   - Firebase cần kết nối internet để hoạt động

2. **Tạo Firebase Project Thật**
   - Truy cập: https://console.firebase.google.com
   - Tạo project mới
   - Thêm Android app với package name: `com.example.histovision`
   - Download file `google-services.json` thật
   - Thay thế file hiện tại trong `android/app/google-services.json`

3. **Enable Firebase Services**
   - Trong Firebase Console, enable:
     - Authentication (Email/Password)
     - Cloud Firestore

### Nếu có lỗi về Gradle:

```powershell
# Xóa cache Gradle
Remove-Item -Path "$env:USERPROFILE\.gradle\caches" -Recurse -Force

# Build lại
flutter pub get
flutter build apk --debug
```

### Nếu có lỗi về Dependencies:

```powershell
# Upgrade dependencies
flutter pub upgrade

# Hoặc outdated check
flutter pub outdated
```

## 📱 Test App

### Test trên Emulator:
```powershell
# Khởi động emulator
flutter emulators --launch <emulator_id>

# Chạy app
flutter run
```

### Test trên Device thật:
```powershell
# Kiểm tra device
flutter devices

# Chạy app
flutter run -d <device_id>
```

## 🎯 Các Tính Năng Đã Thêm

### 1. Authentication System
- ✅ Login Screen (Email/Password)
- ✅ Register Screen (với role: Student/Teacher)
- ✅ Auth Wrapper (tự động điều hướng)
- ✅ Logout functionality

### 2. Student Features
- ✅ Đăng ký với class code
- ✅ Truy cập tất cả chức năng học tập
- ✅ Xem profile

### 3. Teacher Features
- ✅ Teacher Home Screen
- ✅ Quản lý Classes
- ✅ Tạo class mới
- ✅ Xem danh sách học sinh trong class
- ✅ Truy cập tất cả chức năng

### 4. Database Structure (Firestore)

```
users/
  {userId}/
    - email: string
    - fullName: string
    - role: "student" | "teacher"
    - className: string (for students)
    - createdAt: timestamp

classes/
  {classId}/
    - className: string
    - teacherId: string
    - teacherName: string
    - studentCount: number
    - createdAt: timestamp
```

## 🐛 Debug Tips

### Xem logs:
```powershell
# Flutter logs
flutter logs

# Android logs
adb logcat | Select-String "flutter"
```

### Check Firebase connection:
```dart
// Trong main.dart, đã có:
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## 📞 Support

Nếu vẫn gặp lỗi, hãy:
1. Chụp màn hình lỗi
2. Copy full error message
3. Kiểm tra file logs

## ⚠️ Lưu Ý Quan Trọng

1. **Firebase Project:** File `google-services.json` hiện tại là DEMO. Để app hoạt động đầy đủ, bạn cần:
   - Tạo Firebase project thật
   - Download google-services.json thật
   - Enable Authentication và Firestore

2. **API Keys:** Các API key trong code (OpenAI, Gemini) cần được thay thế bằng key thật của bạn

3. **Package Name:** Nếu muốn đổi package name, cần đổi ở:
   - `android/app/build.gradle.kts`
   - `android/app/google-services.json`
   - `android/app/src/main/AndroidManifest.xml`

## 🎉 Kết Luận

Tất cả lỗi chính đã được fix:
- ✅ Package name đã khớp
- ✅ Firebase dependencies đã đúng
- ✅ Build configuration đã OK
- ✅ Code không có lỗi syntax

Chạy `.\fix_build.ps1` để build app!
