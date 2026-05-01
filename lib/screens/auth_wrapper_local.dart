// Auth Wrapper sử dụng Local Database
import 'package:flutter/material.dart';
import 'package:chemivision/models/user_model.dart';
import 'package:chemivision/services/local_database_service.dart';
import 'package:chemivision/screens/auth/login_screen_local.dart';
import 'package:chemivision/screens/landing_home.dart';
import 'package:chemivision/screens/teacher/teacher_home_screen_local.dart';

class AuthWrapperLocal extends StatefulWidget {
  const AuthWrapperLocal({super.key});

  @override
  State<AuthWrapperLocal> createState() => _AuthWrapperLocalState();
}

class _AuthWrapperLocalState extends State<AuthWrapperLocal> {
  final LocalDatabaseService _dbService = LocalDatabaseService.instance;
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    try {
      final user = await _dbService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2E7D32),
                const Color(0xFF4CAF50),
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'Đang tải...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return const LoginScreenLocal();
    }

    // Điều hướng theo role
    if (_currentUser!.role == UserRole.teacher) {
      return const TeacherHomeScreenLocal();
    } else {
      return const LandingHomeScreen();
    }
  }
}


