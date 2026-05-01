// Teacher Home Screen sử dụng Local Database
import 'package:flutter/material.dart';
import 'package:chemivision/services/local_database_service.dart';
import 'package:chemivision/screens/teacher/classes_screen_local.dart';
import 'package:chemivision/screens/landing_home.dart';
import 'package:chemivision/screens/auth/login_screen_local.dart';
import 'package:chemivision/models/user_model.dart';

class TeacherHomeScreenLocal extends StatefulWidget {
  const TeacherHomeScreenLocal({super.key});

  @override
  State<TeacherHomeScreenLocal> createState() => _TeacherHomeScreenLocalState();
}

class _TeacherHomeScreenLocalState extends State<TeacherHomeScreenLocal> {
  final _dbService = LocalDatabaseService.instance;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _dbService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<int> _getTotalStudents() async {
    final classes = await _dbService.getAllClasses();
    int total = 0;

    for (var classModel in classes) {
      final students = await _dbService.getStudentsByClass(
        classModel.className,
      );
      total += students.length;
    }

    return total;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Đăng xuất'),
            content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Đăng xuất',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _dbService.logoutUser();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreenLocal()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1B5E20), // Purple 900
              const Color(0xFF2E7D32), // Purple 700
              const Color(0xFF43A047), // Purple 500
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2E7D32), // Purple 700
                      const Color(0xFF43A047), // Purple 500
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xin chào, ${_currentUser?.fullName ?? 'Giáo viên'}!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Trang quản lý giáo viên',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          onPressed: _logout,
                          tooltip: 'Đăng xuất',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // Section title
                      Center(
                        child: Text(
                          'QUẢN LÝ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.95),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Menu items
                      Row(
                        children: [
                          Expanded(
                            child: _buildMenuCard(
                              icon: Icons.class_,
                              label: 'Lớp học',
                              description: 'Quản lý lớp và học sinh',
                              color: const Color(0xFF388E3C),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ClassesScreenLocal(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMenuCard(
                              icon: Icons.apps,
                              label: 'Chức năng',
                              description: 'Các công cụ học tập',
                              color: const Color(0xFF66BB6A), // Purple 400
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LandingHomeScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Quick stats
                      Center(
                        child: Text(
                          'THỐNG KÊ NHANH',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.95),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Stats cards
                      FutureBuilder(
                        future: _dbService.getAllClasses(),
                        builder: (context, snapshot) {
                          final classCount = snapshot.data?.length ?? 0;

                          return Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.class_,
                                  value: classCount.toString(),
                                  label: 'Lớp học',
                                  color: const Color(0xFF388E3C),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FutureBuilder(
                                  future: _getTotalStudents(),
                                  builder: (context, studentSnapshot) {
                                    final studentCount =
                                        studentSnapshot.data ?? 0;
                                    return _buildStatCard(
                                      icon: Icons.people,
                                      value: studentCount.toString(),
                                      label: 'Học sinh',
                                      color: const Color(
                                        0xFF9333EA,
                                      ), // Purple 600
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 40),

                      // Info card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Hướng dẫn sử dụng',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '1. Vào "Lớp học" để tạo và quản lý lớp\n'
                              '2. Chia sẻ mã lớp cho học sinh đăng ký\n'
                              '3. Vào "Chức năng" để sử dụng các công cụ học tập',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
