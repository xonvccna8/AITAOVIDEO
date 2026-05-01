import 'package:chemivision/models/class_model.dart';
import 'package:chemivision/models/user_model.dart';
import 'package:chemivision/services/local_database_service.dart';

class ClassService {
  final LocalDatabaseService _db = LocalDatabaseService.instance;

  // Create a new class
  Future<ClassModel> createClass({
    required String className,
    required String teacherId,
    required String teacherName,
  }) async {
    try {
      return await _db.createClass(
        className: className,
        teacherId: teacherId,
        teacherName: teacherName,
      );
    } catch (e) {
      throw Exception('Lỗi tạo lớp: ${e.toString()}');
    }
  }

  // Get all classes for a teacher
  Stream<List<ClassModel>> getTeacherClasses(String teacherId) {
    return Stream.fromFuture(_db.getClassesByTeacher(teacherId));
  }

  // Get all available classes (for students to join)
  Stream<List<ClassModel>> getAllClasses() {
    return Stream.fromFuture(_db.getAllClasses());
  }

  // Get students in a class
  Future<List<UserModel>> getStudentsInClass(String classId) async {
    try {
      final classData = await _db.getClassById(classId);
      if (classData == null) {
        return [];
      }
      return await _db.getStudentsByClass(classData.className);
    } catch (e) {
      throw Exception('Lỗi lấy danh sách học sinh: ${e.toString()}');
    }
  }

  // Add student to class
  Future<void> addStudentToClass(String classId, String studentId) async {
    try {
      await _db.addStudentToClassById(classId, studentId);
    } catch (e) {
      throw Exception('Lỗi thêm học sinh vào lớp: ${e.toString()}');
    }
  }

  // Remove student from class
  Future<void> removeStudentFromClass(String classId, String studentId) async {
    try {
      await _db.removeStudentFromClassById(classId, studentId);
    } catch (e) {
      throw Exception('Lỗi xóa học sinh khỏi lớp: ${e.toString()}');
    }
  }

  // Delete class
  Future<void> deleteClass(String classId) async {
    try {
      await _db.deleteClass(classId);
    } catch (e) {
      throw Exception('Lỗi xóa lớp: ${e.toString()}');
    }
  }

  // Get class by ID
  Future<ClassModel?> getClassById(String classId) async {
    try {
      return await _db.getClassById(classId);
    } catch (e) {
      throw Exception('Lỗi lấy thông tin lớp: ${e.toString()}');
    }
  }
}
