import 'package:chemivision/models/user_model.dart';
import 'package:chemivision/services/local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final LocalDatabaseService _db = LocalDatabaseService.instance;
  static UserModel? _globalCurrentUser;
  UserModel? _cachedUser;

  // Get current user
  UserModel? get currentUser => _cachedUser ?? _globalCurrentUser;

  // Stream of auth changes
  Stream<UserModel?> get authStateChanges async* {
    yield await getCurrentUser();
  }

  // Sign up
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? className,
  }) async {
    try {
      final userModel = await _db.registerUser(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        className: className,
      );

      _cachedUser = userModel;
      _globalCurrentUser = userModel;

      // Save role to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', role.name);

      return userModel;
    } catch (e) {
      throw Exception('Lỗi đăng ký: ${e.toString()}');
    }
  }

  // Sign in
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await _db.loginUser(email: email, password: password);

      _cachedUser = userModel;
      _globalCurrentUser = userModel;

      // Save role to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userRole', userModel.role.name);

      return userModel;
    } catch (e) {
      throw Exception('Lỗi đăng nhập: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _db.logoutUser();
      _cachedUser = null;
      _globalCurrentUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userRole');
    } catch (e) {
      throw Exception('Lỗi đăng xuất: ${e.toString()}');
    }
  }

  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      final current = await getCurrentUser();
      if (current != null && current.uid == uid) {
        _cachedUser = current;
        _globalCurrentUser = current;
        return current;
      }
      return await _db.getUserById(uid);
    } catch (e) {
      throw Exception('Lỗi lấy thông tin người dùng: ${e.toString()}');
    }
  }

  // Update user class (for students)
  Future<void> updateUserClass(String uid, String className) async {
    try {
      await _db.updateUserClass(uid, className);

      if (_cachedUser != null && _cachedUser!.uid == uid) {
        _cachedUser = _cachedUser!.copyWith(className: className);
        _globalCurrentUser = _cachedUser;
      }
    } catch (e) {
      throw Exception('Lỗi cập nhật lớp: ${e.toString()}');
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final user = await _db.getCurrentUser();
    _cachedUser = user;
    _globalCurrentUser = user;
    return user;
  }

  Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final user = await signIn(email: email, password: password);
    if (user == null) {
      throw Exception('Không thể đăng nhập');
    }
    return user;
  }

  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? className,
  }) async {
    final user = await signUp(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
      className: className,
    );
    if (user == null) {
      throw Exception('Không thể đăng ký tài khoản');
    }
    return user;
  }

  // Get saved role from local storage
  Future<UserRole?> getSavedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleString = prefs.getString('userRole');
      if (roleString == null) return null;

      return UserRole.values.firstWhere(
        (e) => e.name == roleString,
        orElse: () => UserRole.student,
      );
    } catch (e) {
      return null;
    }
  }
}
