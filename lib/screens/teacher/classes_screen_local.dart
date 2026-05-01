// Classes Screen sử dụng Local Database
import 'package:flutter/material.dart';
import 'package:chemivision/models/class_model.dart';
import 'package:chemivision/models/user_model.dart';
import 'package:chemivision/services/local_database_service.dart';
import 'package:chemivision/screens/teacher/class_detail_screen_local.dart';

class ClassesScreenLocal extends StatefulWidget {
  const ClassesScreenLocal({super.key});

  @override
  State<ClassesScreenLocal> createState() => _ClassesScreenLocalState();
}

class _ClassesScreenLocalState extends State<ClassesScreenLocal> {
  final _dbService = LocalDatabaseService.instance;
  List<ClassModel> _classes = [];
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final user = await _dbService.getCurrentUser();
    if (user != null) {
      // Lấy TẤT CẢ các lớp trong hệ thống để giáo viên có thể quản lý
      final classes = await _dbService.getAllClasses();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _classes = classes;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createClass() async {
    final classNameController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo lớp mới'),
        content: TextField(
          controller: classNameController,
          decoration: InputDecoration(
            labelText: 'Tên lớp',
            hintText: 'VD: 6A1, 7B2, 8A3, 9C1...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (classNameController.text.trim().isNotEmpty) {
                Navigator.pop(context, classNameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C), // Purple 600
            ),
            child: const Text('Tạo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && _currentUser != null) {
      try {
        await _dbService.createClass(
          className: result,
          teacherId: _currentUser!.id,
          teacherName: _currentUser!.fullName,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tạo lớp "$result" thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteClass(ClassModel classModel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lớp'),
        content: Text('Bạn có chắc chắn muốn xóa lớp "${classModel.className}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.deleteClass(classModel.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa lớp "${classModel.className}"'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadData();
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2E7D32), // Purple 700
                      const Color(0xFF43A047), // Purple 500
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Quản lý Lớp học',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.white),
                      onPressed: _createClass,
                      tooltip: 'Tạo lớp mới',
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _classes.isEmpty
                        ? _buildEmptyState()
                        : _buildClassList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createClass,
        backgroundColor: const Color(0xFF388E3C), // Purple 600
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tạo lớp mới',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
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
              Icons.class_outlined,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chưa có lớp học nào',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn nút "Tạo lớp mới" để bắt đầu',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final classModel = _classes[index];
        return _buildClassCard(classModel);
      },
    );
  }

  Widget _buildClassCard(ClassModel classModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClassDetailScreenLocal(classModel: classModel),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF388E3C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.class_,
                  color: Color(0xFF388E3C),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classModel.className,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<List<UserModel>>(
                      future: _dbService.getStudentsByClass(classModel.className),
                      builder: (context, snapshot) {
                        final studentCount = snapshot.data?.length ?? 0;
                        return Text(
                          '$studentCount học sinh',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mã lớp: ${classModel.className}',
                      style: TextStyle(
                        color: const Color(0xFF43A047), // Purple 500
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClassDetailScreenLocal(classModel: classModel),
                        ),
                      ).then((_) => _loadData());
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, 
                               color: Colors.red.shade400, size: 20),
                    onPressed: () => _deleteClass(classModel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


