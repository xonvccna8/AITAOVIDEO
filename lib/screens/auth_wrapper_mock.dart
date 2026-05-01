// Auth Wrapper for Mock Mode (No Firebase)
import 'package:flutter/material.dart';
import 'package:chemivision/models/user_model.dart';
import 'package:chemivision/services/mock_auth_service.dart';
import 'package:chemivision/screens/auth/login_screen_mock.dart';
import 'package:chemivision/screens/landing_home.dart';
import 'package:chemivision/screens/teacher/teacher_home_screen.dart';

class AuthWrapperMock extends StatefulWidget {
  const AuthWrapperMock({super.key});

  @override
  State<AuthWrapperMock> createState() => _AuthWrapperMockState();
}

class _AuthWrapperMockState extends State<AuthWrapperMock> {
  final MockAuthService _authService = MockAuthService();
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    MockAuthService.initializeDemoAccounts();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading Mock Mode...'),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return const LoginScreenMock();
    }

    // Route based on role
    if (_currentUser!.role == UserRole.teacher) {
      return const TeacherHomeScreen();
    } else {
      return const LandingHomeScreen();
    }
  }
}


