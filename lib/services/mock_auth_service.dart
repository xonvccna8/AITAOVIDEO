// Mock Authentication Service for Demo Mode
// Use this if Firebase is not configured

import 'package:shared_preferences/shared_preferences.dart';
import 'package:chemivision/models/user_model.dart';

class MockAuthService {
  static const String _keyUserId = 'mock_user_id';
  static const String _keyUserEmail = 'mock_user_email';
  static const String _keyUserName = 'mock_user_name';
  static const String _keyUserRole = 'mock_user_role';
  static const String _keyUserClass = 'mock_user_class';
  static const String _keyIsLoggedIn = 'mock_is_logged_in';

  // Mock user database (in-memory)
  static final Map<String, Map<String, dynamic>> _mockUsers = {};

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

    if (!isLoggedIn) return null;

    final userId = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyUserEmail);
    final fullName = prefs.getString(_keyUserName);
    final role = prefs.getString(_keyUserRole);
    final className = prefs.getString(_keyUserClass);

    if (userId == null || email == null) return null;

    return UserModel(
      uid: userId,
      email: email,
      fullName: fullName ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.toString() == 'UserRole.$role',
        orElse: () => UserRole.student,
      ),
      className: className,
      createdAt: DateTime.now(),
    );
  }

  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    // Check if user exists in mock database
    final userKey = email.toLowerCase();
    if (!_mockUsers.containsKey(userKey)) {
      throw Exception('Tài khoản không tồn tại. Vui lòng đăng ký.');
    }

    final userData = _mockUsers[userKey]!;
    if (userData['password'] != password) {
      throw Exception('Mật khẩu không đúng.');
    }

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserId, userData['id']);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserName, userData['fullName']);
    await prefs.setString(_keyUserRole, userData['role']);
    if (userData['className'] != null) {
      await prefs.setString(_keyUserClass, userData['className']);
    }

    return UserModel(
      uid: userData['id'],
      email: email,
      fullName: userData['fullName'],
      role: UserRole.values.firstWhere(
        (r) => r.toString() == 'UserRole.${userData['role']}',
      ),
      className: userData['className'],
      createdAt: DateTime.parse(userData['createdAt']),
    );
  }

  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? className,
  }) async {
    // Check if user already exists
    final userKey = email.toLowerCase();
    if (_mockUsers.containsKey(userKey)) {
      throw Exception('Email đã được sử dụng.');
    }

    // Create new user
    final userId = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    _mockUsers[userKey] = {
      'id': userId,
      'password': password,
      'fullName': fullName,
      'role': role.toString().split('.').last,
      'className': className,
      'createdAt': now.toIso8601String(),
    };

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserName, fullName);
    await prefs.setString(_keyUserRole, role.toString().split('.').last);
    if (className != null) {
      await prefs.setString(_keyUserClass, className);
    }

    return UserModel(
      uid: userId,
      email: email,
      fullName: fullName,
      role: role,
      className: className,
      createdAt: now,
    );
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Initialize with demo accounts
  static void initializeDemoAccounts() {
    _mockUsers['teacher@mathvision.com'] = {
      'id': 'demo_teacher_1',
      'password': 'teacher123',
      'fullName': 'Giáo viên Demo',
      'role': 'teacher',
      'className': null,
      'createdAt': DateTime.now().toIso8601String(),
    };

    _mockUsers['student@mathvision.com'] = {
      'id': 'demo_student_1',
      'password': 'student123',
      'fullName': 'Học sinh Demo',
      'role': 'student',
      'className': '10A1',
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
