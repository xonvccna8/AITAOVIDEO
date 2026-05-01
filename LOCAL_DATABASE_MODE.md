# 🗄️ Chế Độ Local Database

## 📖 Giới Thiệu

App hiện đang chạy với **Local Database** (SharedPreferences) thay vì Firebase. Điều này giúp:
- ✅ Không cần cấu hình Firebase
- ✅ Chạy ngay lập tức
- ✅ Không cần internet
- ✅ Dữ liệu lưu trên thiết bị

## 🚀 Cách Chạy

```powershell
# Chỉ cần chạy
flutter run
```

**Xong!** App sẽ tự động sử dụng Local Database.

## 📝 Tài Khoản Demo

### Giáo viên:
- **Email:** teacher@histovision.com
- **Password:** teacher123

### Học sinh:
- **Email:** student@histovision.com
- **Password:** student123
- **Lớp:** 10A1

## 🎯 Tính Năng

### ✅ Đã Hoạt Động:
1. **Đăng ký/Đăng nhập** - Lưu trên thiết bị
2. **Phân quyền** - Học sinh/Giáo viên
3. **Quản lý lớp** - Tạo, xem, xóa lớp
4. **Danh sách học sinh** - Xem học sinh trong lớp
5. **Tất cả chức năng học tập** - Video, Quiz, Q&A, etc.

### 📱 Dữ Liệu Lưu Trữ:
- Users (email, password, role, class)
- Classes (name, teacher, students)
- Login state (auto-login)

## 📁 Cấu Trúc Files

### Files Mới (Local Database):
```
lib/
├── services/
│   └── local_database_service.dart  # Service chính
├── screens/
│   ├── auth_wrapper_local.dart      # Auth wrapper
│   ├── auth/
│   │   ├── login_screen_local.dart  # Login
│   │   └── register_screen_local.dart # Register
│   └── teacher/
│       ├── teacher_home_screen_local.dart
│       ├── classes_screen_local.dart
│       └── class_detail_screen_local.dart
└── main.dart                         # Entry point (đã cập nhật)
```

### Files Firebase (Giữ Nguyên):
```
lib/
├── firebase_options.dart            # Firebase config
├── services/
│   ├── auth_service.dart            # Firebase auth
│   └── class_service.dart           # Firestore
├── screens/
│   ├── auth_wrapper.dart            # Firebase wrapper
│   ├── auth/
│   │   ├── login_screen.dart        # Firebase login
│   │   └── register_screen.dart     # Firebase register
│   └── teacher/
│       ├── teacher_home_screen.dart
│       ├── classes_screen.dart
│       └── class_detail_screen.dart
```

## 🔄 Chuyển Đổi Giữa Firebase và Local

### Bật Firebase (khi cần):

1. Mở `pubspec.yaml`:
```yaml
# Bỏ comment các dòng này:
firebase_core: ^3.3.0
firebase_auth: ^5.1.4
cloud_firestore: ^5.2.1
```

2. Mở `lib/main.dart`:
```dart
// Bỏ comment Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:chemivision/firebase_options.dart';
import 'package:chemivision/screens/auth_wrapper.dart';

// Comment Local imports
// import 'package:chemivision/services/local_database_service.dart';
// import 'package:chemivision/screens/auth_wrapper_local.dart';

// Trong main():
// Bỏ comment Firebase init
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

// Comment Local init
// await LocalDatabaseService.instance.initializeDemoData();

// Trong MyApp:
home: const AuthWrapper(), // Firebase
// home: const AuthWrapperLocal(), // Local
```

3. Chạy:
```powershell
flutter pub get
flutter run
```

### Bật Local Database (hiện tại):
Ngược lại với các bước trên.

## 🗃️ Database Schema

### Users Table:
```json
{
  "email_key": {
    "id": "user_timestamp",
    "email": "user@example.com",
    "password": "password123",
    "fullName": "Nguyễn Văn A",
    "role": "student|teacher",
    "className": "10A1",
    "createdAt": "2025-12-16T10:00:00Z"
  }
}
```

### Classes Table:
```json
{
  "class_key": {
    "id": "class_timestamp",
    "className": "Lớp 10A1",
    "teacherId": "user_id",
    "teacherName": "Giáo viên X",
    "studentCount": 25,
    "createdAt": "2025-12-16T10:00:00Z"
  }
}
```

## ⚠️ Lưu Ý

### Giới Hạn Local Database:
1. **Không sync cloud** - Dữ liệu chỉ trên 1 thiết bị
2. **Mất khi xóa app** - Cài lại app sẽ mất dữ liệu
3. **Không real-time** - Không tự động cập nhật

### Khi Nào Dùng Firebase:
1. **Production** - Cần sync nhiều thiết bị
2. **Real-time** - Cần cập nhật tức thì
3. **Backup** - Cần lưu trữ cloud
4. **Analytics** - Cần theo dõi người dùng

## 🧪 Test

### Test Đăng Ký:
1. Mở app
2. Chọn "Đăng ký"
3. Chọn role (Học sinh/Giáo viên)
4. Nhập thông tin
5. Đăng ký thành công

### Test Đăng Nhập:
1. Mở app
2. Nhập email/password demo
3. Đăng nhập thành công

### Test Quản Lý Lớp (Giáo viên):
1. Đăng nhập với tài khoản giáo viên
2. Vào "Lớp học"
3. Tạo lớp mới
4. Xem danh sách học sinh

### Test Học Sinh:
1. Đăng ký với role học sinh
2. Nhập mã lớp (VD: 10A1)
3. Đăng ký thành công
4. Vào giao diện học tập

## 📞 Troubleshooting

### Lỗi: "Tài khoản không tồn tại"
- Kiểm tra email đã đăng ký chưa
- Sử dụng demo accounts

### Lỗi: "Email đã được sử dụng"
- Email đã đăng ký trước đó
- Dùng email khác hoặc đăng nhập

### Muốn reset dữ liệu:
```dart
// Trong code hoặc debug console:
await LocalDatabaseService.instance.clearAllData();
await LocalDatabaseService.instance.initializeDemoData();
```

Hoặc xóa app và cài lại.

## 🎉 Kết Luận

Local Database mode hoạt động hoàn hảo cho:
- ✅ Development
- ✅ Testing
- ✅ Demo
- ✅ Offline usage

Khi cần production, chỉ cần bật lại Firebase!

---

**Made with ❤️ by Kiro AI Assistant**

