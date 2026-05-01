// Local Database Service - Thay thế Firebase tạm thời
// Sử dụng SharedPreferences để lưu trữ dữ liệu nội bộ

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chemivision/models/user_model.dart';
import 'package:chemivision/models/class_model.dart';

class LocalDatabaseService {
  static const String _keyUsers = 'local_db_users';
  static const String _keyClasses = 'local_db_classes';
  static const String _keyCurrentUser = 'local_db_current_user';
  static const String _keyIsLoggedIn = 'local_db_is_logged_in';

  static LocalDatabaseService? _instance;
  static LocalDatabaseService get instance {
    _instance ??= LocalDatabaseService._();
    return _instance!;
  }

  LocalDatabaseService._();

  // ==================== USER MANAGEMENT ====================

  /// Lấy tất cả users từ local database
  Future<Map<String, Map<String, dynamic>>> _getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_keyUsers);
    if (usersJson == null || usersJson.isEmpty) {
      return {};
    }
    final Map<String, dynamic> decoded = jsonDecode(usersJson);
    return decoded.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
    );
  }

  /// Lưu tất cả users vào local database
  Future<void> _saveAllUsers(Map<String, Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsers, jsonEncode(users));
  }

  /// Đăng ký user mới
  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? className,
  }) async {
    final users = await _getAllUsers();
    final emailKey = email.toLowerCase();

    // Kiểm tra email đã tồn tại chưa
    if (users.containsKey(emailKey)) {
      throw Exception('Email đã được sử dụng. Vui lòng chọn email khác.');
    }

    // Tạo user mới
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final userData = {
      'id': userId,
      'email': email,
      'password': password, // Trong production nên hash password
      'fullName': fullName,
      'role': role.toString().split('.').last,
      'className': className,
      'createdAt': now.toIso8601String(),
      'loginCount': 0,
      'lastLoginAt': null,
    };

    users[emailKey] = userData;
    await _saveAllUsers(users);

    // Nếu là học sinh và có className, cập nhật số lượng học sinh trong lớp
    if (role == UserRole.student && className != null && className.isNotEmpty) {
      await _incrementClassStudentCount(className);
    }

    final user = UserModel(
      uid: userId,
      email: email,
      fullName: fullName,
      role: role,
      className: className,
      createdAt: now,
    );

    // Tự động đăng nhập sau khi đăng ký
    await _setCurrentUser(user);

    return user;
  }

  /// Đăng nhập
  Future<UserModel> loginUser({
    required String email,
    required String password,
  }) async {
    final users = await _getAllUsers();
    final emailKey = email.toLowerCase();

    if (!users.containsKey(emailKey)) {
      throw Exception('Tài khoản không tồn tại. Vui lòng đăng ký.');
    }

    final userData = users[emailKey]!;
    if (userData['password'] != password) {
      throw Exception('Mật khẩu không đúng. Vui lòng thử lại.');
    }

    // Tăng số lần đăng nhập và cập nhật thời gian
    final now = DateTime.now();
    userData['loginCount'] = (userData['loginCount'] ?? 0) + 1;
    userData['lastLoginAt'] = now.toIso8601String();

    // Lưu lại vào database
    users[emailKey] = userData;
    await _saveAllUsers(users);

    final user = UserModel(
      uid: userData['id'],
      email: userData['email'],
      fullName: userData['fullName'],
      role: UserRole.values.firstWhere(
        (r) => r.toString().split('.').last == userData['role'],
        orElse: () => UserRole.student,
      ),
      className: userData['className'],
      createdAt: DateTime.parse(userData['createdAt']),
      loginCount: userData['loginCount'] ?? 0,
      lastLoginAt:
          userData['lastLoginAt'] != null
              ? DateTime.parse(userData['lastLoginAt'])
              : null,
    );

    await _setCurrentUser(user);
    return user;
  }

  /// Đăng xuất
  Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  /// Lấy user hiện tại
  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!isLoggedIn) return null;

    final userJson = prefs.getString(_keyCurrentUser);
    if (userJson == null || userJson.isEmpty) return null;

    try {
      final userData = jsonDecode(userJson);
      return UserModel(
        uid: userData['id'],
        email: userData['email'],
        fullName: userData['fullName'],
        role: UserRole.values.firstWhere(
          (r) => r.toString().split('.').last == userData['role'],
          orElse: () => UserRole.student,
        ),
        className: userData['className'],
        createdAt: DateTime.parse(userData['createdAt']),
        loginCount: userData['loginCount'] ?? 0,
        lastLoginAt:
            userData['lastLoginAt'] != null
                ? DateTime.parse(userData['lastLoginAt'])
                : null,
      );
    } catch (e) {
      return null;
    }
  }

  /// Tìm user theo ID
  Future<UserModel?> getUserById(String uid) async {
    final users = await _getAllUsers();
    for (final userData in users.values) {
      if (userData['id'] == uid) {
        return UserModel(
          uid: userData['id'],
          email: userData['email'],
          fullName: userData['fullName'],
          role: UserRole.values.firstWhere(
            (r) => r.toString().split('.').last == userData['role'],
            orElse: () => UserRole.student,
          ),
          className: userData['className'],
          createdAt: DateTime.parse(userData['createdAt']),
          loginCount: userData['loginCount'] ?? 0,
          lastLoginAt:
              userData['lastLoginAt'] != null
                  ? DateTime.parse(userData['lastLoginAt'])
                  : null,
        );
      }
    }
    return null;
  }

  /// Cập nhật lớp cho user theo ID
  Future<void> updateUserClass(String uid, String className) async {
    final users = await _getAllUsers();
    final classes = await _getAllClasses();

    String? matchedUserKey;
    for (final entry in users.entries) {
      if (entry.value['id'] == uid) {
        matchedUserKey = entry.key;
        break;
      }
    }

    if (matchedUserKey == null) {
      return;
    }

    users[matchedUserKey]!['className'] = className;
    await _saveAllUsers(users);

    _rebuildStudentCounts(classes, users);
    await _saveAllClasses(classes);

    final current = await getCurrentUser();
    if (current != null && current.uid == uid) {
      await _setCurrentUser(current.copyWith(className: className));
    }
  }

  /// Lưu user hiện tại
  Future<void> _setCurrentUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = {
      'id': user.uid,
      'email': user.email,
      'fullName': user.fullName,
      'role': user.role.toString().split('.').last,
      'className': user.className,
      'createdAt': user.createdAt.toIso8601String(),
      'loginCount': user.loginCount,
      'lastLoginAt': user.lastLoginAt?.toIso8601String(),
    };
    await prefs.setString(_keyCurrentUser, jsonEncode(userData));
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  // ==================== CLASS MANAGEMENT ====================

  /// Lấy tất cả classes từ local database
  Future<Map<String, Map<String, dynamic>>> _getAllClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final classesJson = prefs.getString(_keyClasses);
    if (classesJson == null || classesJson.isEmpty) {
      return {};
    }
    final Map<String, dynamic> decoded = jsonDecode(classesJson);
    return decoded.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
    );
  }

  /// Lưu tất cả classes vào local database
  Future<void> _saveAllClasses(
    Map<String, Map<String, dynamic>> classes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClasses, jsonEncode(classes));
  }

  /// Tạo class mới
  Future<ClassModel> createClass({
    required String className,
    required String teacherId,
    required String teacherName,
  }) async {
    final classes = await _getAllClasses();

    // Kiểm tra class đã tồn tại chưa
    final classKey = className.toLowerCase().replaceAll(' ', '_');
    if (classes.containsKey(classKey)) {
      throw Exception('Lớp "$className" đã tồn tại. Vui lòng chọn tên khác.');
    }

    final classId = 'class_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final classData = {
      'id': classId,
      'className': className,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'studentCount': 0,
      'createdAt': now.toIso8601String(),
    };

    classes[classKey] = classData;
    await _saveAllClasses(classes);

    return ClassModel(
      id: classId,
      className: className,
      teacherId: teacherId,
      teacherName: teacherName,
      createdAt: now,
      studentIds: [],
    );
  }

  /// Lấy danh sách classes của giáo viên
  Future<List<ClassModel>> getClassesByTeacher(String teacherId) async {
    final classes = await _getAllClasses();
    final teacherClasses = <ClassModel>[];

    for (final classData in classes.values) {
      if (classData['teacherId'] == teacherId) {
        teacherClasses.add(
          ClassModel(
            id: classData['id'],
            className: classData['className'],
            teacherId: classData['teacherId'],
            teacherName: classData['teacherName'],
            createdAt: DateTime.parse(classData['createdAt']),
            studentIds: [],
          ),
        );
      }
    }

    // Sắp xếp theo thời gian tạo mới nhất
    teacherClasses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return teacherClasses;
  }

  /// Lấy TẤT CẢ các lớp (cho giáo viên xem tất cả lớp trong hệ thống)
  Future<List<ClassModel>> getAllClasses() async {
    final classes = await _getAllClasses();
    final allClasses = <ClassModel>[];

    for (final classData in classes.values) {
      allClasses.add(
        ClassModel(
          id: classData['id'],
          className: classData['className'],
          teacherId: classData['teacherId'],
          teacherName: classData['teacherName'],
          createdAt: DateTime.parse(classData['createdAt']),
          studentIds: [],
        ),
      );
    }

    // Sắp xếp theo thời gian tạo mới nhất
    allClasses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allClasses;
  }

  /// Lấy lớp theo ID
  Future<ClassModel?> getClassById(String classId) async {
    final classes = await _getAllClasses();

    for (final classData in classes.values) {
      if (classData['id'] == classId) {
        return ClassModel(
          id: classData['id'],
          className: classData['className'],
          teacherId: classData['teacherId'],
          teacherName: classData['teacherName'],
          createdAt: DateTime.parse(classData['createdAt']),
          studentIds: [],
        );
      }
    }

    return null;
  }

  /// Lấy danh sách học sinh trong lớp
  Future<List<UserModel>> getStudentsByClass(String className) async {
    final users = await _getAllUsers();
    final students = <UserModel>[];

    for (final userData in users.values) {
      if (userData['role'] == 'student' &&
          userData['className']?.toLowerCase() == className.toLowerCase()) {
        students.add(
          UserModel(
            uid: userData['id'],
            email: userData['email'],
            fullName: userData['fullName'],
            role: UserRole.student,
            className: userData['className'],
            createdAt: DateTime.parse(userData['createdAt']),
            loginCount: userData['loginCount'] ?? 0,
            lastLoginAt:
                userData['lastLoginAt'] != null
                    ? DateTime.parse(userData['lastLoginAt'])
                    : null,
          ),
        );
      }
    }

    // Sắp xếp theo tên
    students.sort((a, b) => a.fullName.compareTo(b.fullName));
    return students;
  }

  /// Tăng số lượng học sinh trong lớp (tự động tạo lớp nếu chưa tồn tại)
  Future<void> _incrementClassStudentCount(String className) async {
    final classes = await _getAllClasses();
    final classKey = className.toLowerCase().replaceAll(' ', '_');

    if (classes.containsKey(classKey)) {
      // Lớp đã tồn tại, tăng số lượng học sinh
      classes[classKey]!['studentCount'] =
          (classes[classKey]!['studentCount'] ?? 0) + 1;
    } else {
      // Lớp chưa tồn tại, tự động tạo lớp mới
      final classId = 'class_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();

      classes[classKey] = {
        'id': classId,
        'className': className,
        'teacherId': 'system', // Lớp tự động tạo bởi hệ thống
        'teacherName': 'Hệ thống',
        'studentCount': 1,
        'createdAt': now.toIso8601String(),
      };
    }

    await _saveAllClasses(classes);
  }

  void _rebuildStudentCounts(
    Map<String, Map<String, dynamic>> classes,
    Map<String, Map<String, dynamic>> users,
  ) {
    for (final classData in classes.values) {
      classData['studentCount'] = 0;
    }

    for (final userData in users.values) {
      final role = (userData['role'] ?? '').toString();
      final className = userData['className']?.toString();
      if (role != 'student' || className == null || className.isEmpty) {
        continue;
      }

      for (final classData in classes.values) {
        final storedClassName = (classData['className'] ?? '').toString();
        if (storedClassName.toLowerCase() == className.toLowerCase()) {
          classData['studentCount'] = (classData['studentCount'] ?? 0) + 1;
          break;
        }
      }
    }
  }

  /// Thêm học sinh vào lớp theo classId + studentId
  Future<void> addStudentToClassById(String classId, String studentId) async {
    final classModel = await getClassById(classId);
    if (classModel == null) {
      throw Exception('Không tìm thấy lớp học');
    }

    final users = await _getAllUsers();
    final classes = await _getAllClasses();

    bool updated = false;
    for (final entry in users.entries) {
      if (entry.value['id'] == studentId) {
        entry.value['className'] = classModel.className;
        updated = true;
        break;
      }
    }

    if (!updated) {
      throw Exception('Không tìm thấy học sinh');
    }

    _rebuildStudentCounts(classes, users);
    await _saveAllUsers(users);
    await _saveAllClasses(classes);
  }

  /// Xóa học sinh khỏi lớp theo classId + studentId
  Future<void> removeStudentFromClassById(
    String classId,
    String studentId,
  ) async {
    final classModel = await getClassById(classId);
    if (classModel == null) {
      throw Exception('Không tìm thấy lớp học');
    }

    final users = await _getAllUsers();
    final classes = await _getAllClasses();

    for (final entry in users.entries) {
      final currentClass = entry.value['className']?.toString() ?? '';
      if (entry.value['id'] == studentId &&
          currentClass.toLowerCase() == classModel.className.toLowerCase()) {
        entry.value['className'] = null;
        break;
      }
    }

    _rebuildStudentCounts(classes, users);
    await _saveAllUsers(users);
    await _saveAllClasses(classes);
  }

  /// Xóa class
  Future<void> deleteClass(String classId) async {
    final classes = await _getAllClasses();

    // Tìm và xóa class theo id
    String? keyToRemove;
    for (final entry in classes.entries) {
      if (entry.value['id'] == classId) {
        keyToRemove = entry.key;
        break;
      }
    }

    if (keyToRemove != null) {
      classes.remove(keyToRemove);
      await _saveAllClasses(classes);
    }
  }

  // ==================== DEMO DATA ====================

  /// Khởi tạo dữ liệu demo
  Future<void> initializeDemoData() async {
    final users = await _getAllUsers();

    // Chỉ khởi tạo nếu chưa có dữ liệu
    if (users.isEmpty) {
      // Tạo tài khoản giáo viên demo
      await registerUser(
        email: 'teacher@MathVision.com',
        password: 'teacher123',
        fullName: 'Giáo viên Demo',
        role: UserRole.teacher,
      );

      // Tạo tài khoản học sinh demo
      await registerUser(
        email: 'student@MathVision.com',
        password: 'student123',
        fullName: 'Học sinh Demo',
        role: UserRole.student,
        className: '6A1',
      );

      // Đăng xuất sau khi tạo demo data
      await logoutUser();

      print('✅ Demo data initialized successfully');
    }
  }

  /// Xóa tất cả dữ liệu (cho testing)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsers);
    await prefs.remove(_keyClasses);
    await prefs.remove(_keyCurrentUser);
    await prefs.remove(_keyIsLoggedIn);
  }
}
