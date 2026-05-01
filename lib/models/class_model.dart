class ClassModel {
  final String id;
  final String className;
  final String teacherId;
  final String teacherName;
  final DateTime createdAt;
  final List<String> studentIds;

  // Getter để tính số lượng học sinh
  int get studentCount => studentIds.length;

  ClassModel({
    required this.id,
    required this.className,
    required this.teacherId,
    required this.teacherName,
    required this.createdAt,
    this.studentIds = const [],
  });

  factory ClassModel.fromMap(Map<String, dynamic> map, String id) {
    return ClassModel(
      id: id,
      className: map['className'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      studentIds: List<String>.from(map['studentIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'className': className,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'createdAt': createdAt.toIso8601String(),
      'studentIds': studentIds,
    };
  }
}
