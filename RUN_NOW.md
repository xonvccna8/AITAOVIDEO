# 🚀 CHẠY APP NGAY - LOCAL DATABASE MODE

## ⚡ CÁCH CHẠY NHANH NHẤT

```powershell
.\clean_and_run.ps1
```

**Xong!** Script sẽ tự động:
1. Clean Flutter
2. Xóa pubspec.lock
3. Xóa .dart_tool
4. Get dependencies
5. Chạy app

## 📱 Demo Accounts

| Role | Email | Password |
|------|-------|----------|
| **Giáo viên** | teacher@histovision.com | teacher123 |
| **Học sinh** | student@histovision.com | student123 |

## ✅ Đã Fix

### 1. Tắt Firebase Hoàn Toàn ✅
- ✅ Comment Firebase trong `pubspec.yaml`
- ✅ Comment Firebase trong `lib/main.dart`
- ✅ Tắt Google Services plugin trong `android/app/build.gradle.kts`
- ✅ Tắt Google Services classpath trong `android/build.gradle.kts`

### 2. Sử Dụng Local Database ✅
- ✅ `LocalDatabaseService` - Quản lý users & classes
- ✅ `SharedPreferences` - Lưu trữ dữ liệu
- ✅ Demo accounts tự động tạo
- ✅ Tất cả tính năng hoạt động

### 3. Files Đã Cập Nhật ✅
```
android/
├── build.gradle.kts          # Tắt Google Services classpath
└── app/
    └── build.gradle.kts      # Tắt Google Services plugin

lib/
├── main.dart                 # Sử dụng Local Database
└── services/
    └── local_database_service.dart

pubspec.yaml                  # Comment Firebase dependencies
```

## 🎯 Tính Năng Hoạt Động

- ✅ Đăng ký/Đăng nhập (Local)
- ✅ Phân quyền Học sinh/Giáo viên
- ✅ Quản lý lớp học
- ✅ Xem danh sách học sinh
- ✅ Tất cả chức năng học tập
- ✅ Auto-login
- ✅ Logout

## 🔧 Nếu Vẫn Gặp Lỗi

### Lỗi: "cloud_firestore" hoặc "firebase_*"

**Giải pháp:**
```powershell
# Chạy script clean
.\clean_and_run.ps1
```

### Lỗi: "google-services.json"

**Giải pháp:**
File này đã được tắt trong build.gradle.kts. Nếu vẫn lỗi:
```powershell
# Rename file
Rename-Item "android/app/google-services.json" "google-services.json.bak"

# Sau đó chạy
.\clean_and_run.ps1
```

### Lỗi: Dependencies conflict

**Giải pháp:**
```powershell
# Xóa cache
flutter clean
Remove-Item pubspec.lock -Force
Remove-Item .dart_tool -Recurse -Force

# Get lại
flutter pub get
flutter run
```

## 📊 So Sánh

| Feature | Firebase Mode | Local Database Mode |
|---------|---------------|---------------------|
| Setup Time | 30 min | 0 min |
| Internet | Required | Not required |
| Cloud Sync | Yes | No |
| Offline | Yes | Yes |
| Data Storage | Cloud | Device |
| Best For | Production | Development/Testing |

## 🔄 Bật Lại Firebase (Khi Cần)

### Bước 1: Bỏ comment trong `pubspec.yaml`
```yaml
firebase_core: ^3.3.0
firebase_auth: ^5.1.4
cloud_firestore: ^5.2.1
```

### Bước 2: Bỏ comment trong `android/build.gradle.kts`
```kotlin
classpath("com.google.gms:google-services:4.4.0")
```

### Bước 3: Bỏ comment trong `android/app/build.gradle.kts`
```kotlin
id("com.google.gms.google-services")
```

### Bước 4: Bỏ comment trong `lib/main.dart`
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:chemivision/firebase_options.dart';
import 'package:chemivision/screens/auth_wrapper.dart';

// Trong main():
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

// Trong MyApp:
home: const AuthWrapper(),
```

### Bước 5: Chạy
```powershell
flutter pub get
flutter run
```

## 📞 Support

Nếu vẫn gặp vấn đề:
1. Chạy `.\clean_and_run.ps1`
2. Xem logs: `flutter logs`
3. Check `flutter doctor`

## 🎉 Kết Luận

**APP ĐÃ SẴN SÀNG CHẠY VỚI LOCAL DATABASE!**

Không cần Firebase, không cần internet, chạy ngay lập tức!

```powershell
.\clean_and_run.ps1
```

---

**Made with ❤️ by Kiro AI Assistant**

