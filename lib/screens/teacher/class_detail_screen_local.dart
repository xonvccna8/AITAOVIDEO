// Class Detail Screen sử dụng Local Database
import 'package:flutter/material.dart';
import 'package:chemivision/models/class_model.dart';
import 'package:chemivision/models/user_model.dart';
import 'package:chemivision/services/local_database_service.dart';

class ClassDetailScreenLocal extends StatefulWidget {
  final ClassModel classModel;

  const ClassDetailScreenLocal({super.key, required this.classModel});

  @override
  State<ClassDetailScreenLocal> createState() => _ClassDetailScreenLocalState();
}

class _ClassDetailScreenLocalState extends State<ClassDetailScreenLocal> {
  final _dbService = LocalDatabaseService.instance;
  List<UserModel> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    
    final students = await _dbService.getStudentsByClass(widget.classModel.className);
    
    if (mounted) {
      setState(() {
        _students = students;
        _isLoading = false;
      });
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2E7D32), // Purple 700
                      const Color(0xFF43A047), // Purple 500
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            widget.classModel.className,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _loadStudents,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Class info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoItem(
                            icon: Icons.people,
                            value: _students.length.toString(),
                            label: 'Học sinh',
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildInfoItem(
                            icon: Icons.qr_code,
                            value: widget.classModel.className,
                            label: 'Mã lớp',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Student list
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _students.isEmpty
                        ? _buildEmptyState()
                        : _buildStudentList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chưa có học sinh nào',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Chia sẻ mã lớp "${widget.classModel.className}" cho học sinh để họ đăng ký vào lớp',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          // Copy class code button
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Mã lớp: ${widget.classModel.className}'),
                  action: SnackBarAction(
                    label: 'OK',
                    onPressed: () {},
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: Text('Mã lớp: ${widget.classModel.className}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF388E3C), // Purple 600
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    return Column(
      children: [
        // List header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(
                'Danh sách học sinh (${_students.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Student list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _students.length,
            itemBuilder: (context, index) {
              final student = _students[index];
              return _buildStudentCard(student, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(UserModel student, int index) {
    // Format thời gian truy cập cuối
    String lastLoginText = 'Chưa truy cập';
    if (student.lastLoginAt != null) {
      final now = DateTime.now();
      final difference = now.difference(student.lastLoginAt!);
      
      if (difference.inMinutes < 1) {
        lastLoginText = 'Vừa xong';
      } else if (difference.inMinutes < 60) {
        lastLoginText = '${difference.inMinutes} phút trước';
      } else if (difference.inHours < 24) {
        lastLoginText = '${difference.inHours} giờ trước';
      } else if (difference.inDays < 7) {
        lastLoginText = '${difference.inDays} ngày trước';
      } else {
        lastLoginText = '${(difference.inDays / 7).floor()} tuần trước';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF43A047).withOpacity(0.1),
          child: Text(
            index.toString(),
            style: const TextStyle(
              color: Color(0xFF388E3C), // Purple 600
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          student.email,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF43A047).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.login,
                size: 14,
                color: Color(0xFF388E3C),
              ),
              const SizedBox(width: 4),
              Text(
                '${student.loginCount}',
                style: const TextStyle(
                  color: Color(0xFF388E3C),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.login,
                  label: 'Số lần truy cập',
                  value: '${student.loginCount} lần',
                  color: const Color(0xFF43A047),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.access_time,
                  label: 'Truy cập cuối',
                  value: lastLoginText,
                  color: const Color(0xFF9333EA),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  label: 'Ngày đăng ký',
                  value: '${student.createdAt.day}/${student.createdAt.month}/${student.createdAt.year}',
                  color: const Color(0xFF66BB6A),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


