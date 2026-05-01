# 🎓 HistoVision - Ứng Dụng Học Lịch Sử Việt Nam Bằng AI

[![Flutter](https://img.shields.io/badge/Flutter-3.7+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Latest-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📖 Giới Thiệu

HistoVision là ứng dụng học lịch sử Việt Nam hiện đại, sử dụng AI để tạo video, hình ảnh và nội dung tương tác. Ứng dụng hỗ trợ phân quyền Học sinh và Giáo viên, giúp quản lý lớp học và theo dõi quá trình học tập.

## ✨ Tính Năng Chính

### 🎯 Cho Học Sinh
- ✅ Tái hiện lịch sử từ văn bản (AI Video 5s & 15s)
- ✅ Tái hiện lịch sử từ hình ảnh
- ✅ Phòng triển lãm lịch sử
- ✅ Hỏi đáp kiến thức lịch sử (Việt/English)
- ✅ Tự động tạo đề thi
- ✅ Tái hiện video nâng cao
- ✅ Trò chơi lịch sử (Quiz game)
- ✅ Tạo infographic lịch sử
- ✅ Đăng ký với mã lớp học

### 👨‍🏫 Cho Giáo Viên
- ✅ Tất cả tính năng của học sinh
- ✅ Quản lý lớp học
- ✅ Tạo lớp mới với mã code
- ✅ Xem danh sách học sinh
- ✅ Theo dõi số lượng học sinh

### 🔐 Authentication
- ✅ Đăng ký/Đăng nhập với Email
- ✅ Phân quyền: Student/Teacher
- ✅ Firebase Authentication
- ✅ Auto-login với saved credentials

## 🚀 Cài Đặt & Chạy

### Yêu Cầu
- Flutter SDK 3.7+
- Android Studio / VS Code
- Firebase account (optional cho demo)

### Bước 1: Clone Project
```bash
git clone https://github.com/yourusername/histovision.git
cd histovision
```

### Bước 2: Cài Dependencies
```bash
flutter pub get
```

### Bước 3: Chạy App
```bash
# Trên emulator/device
flutter run

# Build APK
flutter build apk --debug
```

### Quick Fix (Nếu Có Lỗi)
```powershell
# Windows
.\quick_fix.ps1

# Hoặc manual
flutter clean
flutter pub get
flutter run
```

## 📁 Cấu Trúc Project

```
lib/
├── models/              # Data models
│   ├── user_model.dart
│   └── class_model.dart
├── services/            # Business logic
│   ├── auth_service.dart
│   ├── class_service.dart
│   ├── gemini_service.dart
│   └── openai_service.dart
├── screens/             # UI screens
│   ├── auth/           # Login & Register
│   ├── teacher/        # Teacher features
│   ├── landing_home.dart
│   └── ...
├── firebase_options.dart
└── main.dart
```

## 🔥 Firebase Setup

### Demo Mode (Hiện Tại)
App đang chạy với Firebase demo config. Để sử dụng đầy đủ:

### Production Setup
1. Tạo Firebase project: https://console.firebase.google.com
2. Thêm Android app với package: `com.example.histovision`
3. Download `google-services.json` → `android/app/`
4. Enable Authentication (Email/Password)
5. Enable Cloud Firestore
6. Chạy: `flutterfire configure`

Chi tiết: Xem [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md)

## 🗄️ Database Structure

### Firestore Collections

#### `users`
```json
{
  "userId": {
    "email": "student@example.com",
    "fullName": "Nguyễn Văn A",
    "role": "student",
    "className": "10A1",
    "createdAt": "timestamp"
  }
}
```

#### `classes`
```json
{
  "classId": {
    "className": "Lớp 10A1",
    "teacherId": "teacher_id",
    "teacherName": "Giáo viên X",
    "studentCount": 25,
    "createdAt": "timestamp"
  }
}
```

## 🛠️ Tech Stack

- **Framework:** Flutter 3.7+
- **Language:** Dart
- **Backend:** Firebase (Auth + Firestore)
- **AI Services:**
  - OpenAI GPT (Video prompts)
  - Google Gemini (Q&A, Infographic)
  - AIVideoAuto (Video generation)
- **State Management:** StatefulWidget
- **UI:** Material Design 3

## 📚 Documentation

- [SETUP_COMPLETE.md](SETUP_COMPLETE.md) - Hướng dẫn setup đầy đủ
- [FIX_ERRORS_GUIDE.md](FIX_ERRORS_GUIDE.md) - Hướng dẫn fix lỗi
- [WHAT_WAS_FIXED.md](WHAT_WAS_FIXED.md) - Lịch sử fix lỗi
- [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md) - Setup Firebase
- [CHANGELOG_NEW_FEATURES.md](CHANGELOG_NEW_FEATURES.md) - Tính năng mới

## 🐛 Troubleshooting

### Lỗi Build
```bash
flutter clean
flutter pub get
flutter run
```

### Lỗi Firebase
- Kiểm tra `google-services.json`
- Đảm bảo package name khớp
- Enable Authentication & Firestore

### Lỗi Dependencies
```bash
flutter pub upgrade
flutter pub outdated
```

Chi tiết: [FIX_ERRORS_GUIDE.md](FIX_ERRORS_GUIDE.md)

## 🧪 Testing

### Test Accounts (Demo)
**Giáo viên:**
- Email: teacher@histovision.com
- Password: teacher123

**Học sinh:**
- Email: student@histovision.com
- Password: student123
- Class: 10A1

## 🔐 Security

- ⚠️ API keys trong code là DEMO
- ⚠️ Thay thế bằng keys thật trước khi deploy
- ⚠️ Cấu hình Firestore rules cho production
- ⚠️ Enable email verification

## 📝 License

MIT License - Xem [LICENSE](LICENSE) để biết thêm chi tiết

## 👥 Contributors

- **Developer:** Your Name
- **AI Assistant:** Kiro

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

- Email: support@histovision.com
- Issues: [GitHub Issues](https://github.com/yourusername/histovision/issues)

## 🎉 Acknowledgments

- Flutter Team
- Firebase Team
- OpenAI & Google Gemini
- Vietnamese History Community

---

**Made with ❤️ for Vietnamese Education**

🇻🇳 Học lịch sử Việt Nam một cách hiện đại và thú vị!
