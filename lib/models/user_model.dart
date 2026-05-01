class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final String? className; // Chỉ dành cho học sinh
  final DateTime createdAt;
  final int loginCount; // Số lần đăng nhập
  final DateTime? lastLoginAt; // Thời gian đăng nhập cuối

  // Getter để tương thích với code cũ
  String get id => uid;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.className,
    required this.createdAt,
    this.loginCount = 0,
    this.lastLoginAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${map['role']}',
        orElse: () => UserRole.student,
      ),
      className: map['className'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      loginCount: map['loginCount'] ?? 0,
      lastLoginAt: map['lastLoginAt'] != null ? DateTime.parse(map['lastLoginAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role.name,
      'className': className,
      'createdAt': createdAt.toIso8601String(),
      'loginCount': loginCount,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    UserRole? role,
    String? className,
    DateTime? createdAt,
    int? loginCount,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      className: className ?? this.className,
      createdAt: createdAt ?? this.createdAt,
      loginCount: loginCount ?? this.loginCount,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}

enum UserRole {
  student,  // Học sinh
  teacher,  // Giáo viên
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Học sinh';
      case UserRole.teacher:
        return 'Giáo viên';
    }
  }
}
