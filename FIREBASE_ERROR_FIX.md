# 🔥 Fix Firebase/Cloud Firestore Errors

## ❌ Lỗi Thường Gặp

### Lỗi: "cloud_firestore plugin doesn't have a main class"
```
The plugin `cloud_firestore` doesn't have a main class defined in
io.flutter.plugins.firebase.firestore or mainClass entry in the plugin's
pubspec.yaml.
```

## ✅ Giải Pháp

### Giải Pháp 1: Chạy Script Fix Tự Động (Khuyến nghị)

```powershell
# Chạy script fix tất cả
.\fix_all_errors.ps1
```

Script này sẽ:
1. Clean Flutter và Gradle
2. Clear cache
3. Reinstall dependencies với version ổn định
4. Verify installation

### Giải Pháp 2: Fix Manual

#### Bước 1: Clean Everything
```powershell
flutter clean
cd android
.\gradlew clean
cd ..
```

#### Bước 2: Clear Cache
```powershell
# Clear Gradle cache
Remove-Item -Path "$env:USERPROFILE\.gradle\caches\transforms-*" -Recurse -Force
Remove-Item -Path "$env:USERPROFILE\.gradle\caches\modules-*" -Recurse -Force

# Clear Pub cache for Firebase plugins
Remove-Item -Path "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\cloud_firestore-*" -Recurse -Force
Remove-Item -Path "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\firebase_core-*" -Recurse -Force
Remove-Item -Path "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\firebase_auth-*" -Recurse -Force
```

#### Bước 3: Downgrade Firebase Versions
Mở `pubspec.yaml` và thay đổi:

```yaml
# Từ:
firebase_core: ^3.6.0
firebase_auth: ^5.3.1
cloud_firestore: ^5.4.4

# Thành:
firebase_core: ^3.3.0
firebase_auth: ^5.1.4
cloud_firestore: ^5.2.1
```

#### Bước 4: Reinstall
```powershell
flutter pub get
```

#### Bước 5: Rebuild
```powershell
flutter run
```

### Giải Pháp 3: Sử dụng Demo Mode (Không cần Firebase)

Nếu bạn chỉ muốn test app mà không cần Firebase thật:

#### Bước 1: Sử dụng Mock Service
App đã có sẵn Mock Authentication Service. Chỉ cần chạy:

```powershell
flutter run
```

App sẽ tự động detect nếu Firebase không available và chuyển sang Mock mode.

#### Bước 2: Test với Demo Accounts
```
Teacher Account:
- Email: teacher@histovision.com
- Password: teacher123

Student Account:
- Email: student@histovision.com
- Password: student123
```

## 🔍 Kiểm Tra Lỗi

### Check 1: Verify Dependencies
```powershell
flutter pub get
flutter pub outdated
```

### Check 2: Verify Firebase Config
```powershell
# Check if google-services.json exists
Test-Path android/app/google-services.json

# Check package name
Get-Content android/app/google-services.json | Select-String "package_name"
Get-Content android/app/build.gradle.kts | Select-String "applicationId"
```

Package names phải khớp: `com.example.histovision`

### Check 3: Verify Plugin Installation
```powershell
# Check pubspec.lock
Get-Content pubspec.lock | Select-String "firebase"
```

Phải thấy:
- firebase_core
- firebase_auth
- cloud_firestore

## 🚀 Các Phương Án Chạy App

### Phương Án A: Firebase Production (Khuyến nghị cho production)
1. Tạo Firebase project thật
2. Download google-services.json thật
3. Enable Authentication & Firestore
4. Chạy: `flutterfire configure`
5. Chạy: `flutter run`

### Phương Án B: Firebase Demo (Cho development)
1. Sử dụng google-services.json demo có sẵn
2. Chạy: `.\fix_all_errors.ps1`
3. Chạy: `flutter run`
4. App sẽ tự động fallback sang Mock mode nếu Firebase fail

### Phương Án C: Mock Mode (Cho testing nhanh)
1. Không cần Firebase
2. Chạy: `flutter run`
3. Sử dụng demo accounts
4. Tất cả tính năng vẫn hoạt động (trừ sync cloud)

## 📊 So Sánh Các Phương Án

| Feature | Firebase Production | Firebase Demo | Mock Mode |
|---------|-------------------|---------------|-----------|
| Authentication | ✅ Real | ⚠️ May fail | ✅ Local |
| Cloud Sync | ✅ Yes | ❌ No | ❌ No |
| Offline | ✅ Yes | ❌ No | ✅ Yes |
| Setup Time | 30 min | 5 min | 0 min |
| Cost | Free tier | Free | Free |
| Best For | Production | Development | Quick Test |

## 🐛 Troubleshooting

### Lỗi: "Failed to resolve: firebase-firestore"
```powershell
# Clear Gradle cache
cd android
.\gradlew clean --refresh-dependencies
cd ..
flutter clean
flutter pub get
```

### Lỗi: "Namespace not specified"
```powershell
# Run fix script
.\fix_firestore_plugin.ps1
```

### Lỗi: "Duplicate class found"
```powershell
# Clear all caches
.\fix_all_errors.ps1
```

### Lỗi: "Firebase not initialized"
Kiểm tra `lib/main.dart`:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## 💡 Tips

1. **Luôn chạy `flutter clean` trước khi fix**
2. **Clear cache nếu lỗi persist**
3. **Sử dụng Mock mode cho testing nhanh**
4. **Setup Firebase thật cho production**
5. **Check Flutter doctor**: `flutter doctor -v`

## 📞 Vẫn Gặp Lỗi?

### Bước 1: Collect Information
```powershell
flutter doctor -v > flutter_doctor.txt
flutter pub get > pub_get.txt
```

### Bước 2: Check Logs
```powershell
flutter run --verbose > run_log.txt
```

### Bước 3: Try Clean Install
```powershell
# Uninstall app
adb uninstall com.example.histovision

# Clean everything
flutter clean
Remove-Item -Path "build" -Recurse -Force
Remove-Item -Path "android/build" -Recurse -Force
Remove-Item -Path "android/.gradle" -Recurse -Force

# Reinstall
flutter pub get
flutter run
```

## ✅ Kết Luận

Có 3 cách để chạy app:
1. **Firebase Production** - Tốt nhất cho production
2. **Firebase Demo** - Tốt cho development
3. **Mock Mode** - Nhanh nhất cho testing

Chọn phương án phù hợp với nhu cầu của bạn!

---

**Made with ❤️ by Kiro AI Assistant**
