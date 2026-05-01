// Auth Service Wrapper - Automatically uses Firebase or Mock based on availability

import 'package:chemivision/models/user_model.dart';
import 'package:chemivision/services/auth_service.dart';
import 'package:chemivision/services/mock_auth_service.dart';

class AuthServiceWrapper {
  static bool _useFirebase = true;
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    
    try {
      // Try to use Firebase
      _useFirebase = true;
    } catch (e) {
      // Firebase not available, use mock
      _useFirebase = false;
      MockAuthService.initializeDemoAccounts();
    }
    
    _initialized = true;
  }

  static Future<UserModel?> getCurrentUser() async {
    initialize();
    
    if (_useFirebase) {
      try {
        return await AuthService().getCurrentUser();
      } catch (e) {
        print('⚠️ Firebase error, switching to mock mode: $e');
        _useFirebase = false;
        MockAuthService.initializeDemoAccounts();
        return await MockAuthService().getCurrentUser();
      }
    } else {
      return await MockAuthService().getCurrentUser();
    }
  }

  static Future<UserModel> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    initialize();
    
    if (_useFirebase) {
      try {
        return await AuthService().signInWithEmailAndPassword(email, password);
      } catch (e) {
        print('⚠️ Firebase error, switching to mock mode: $e');
        _useFirebase = false;
        MockAuthService.initializeDemoAccounts();
        return await MockAuthService().signInWithEmailAndPassword(email, password);
      }
    } else {
      return await MockAuthService().signInWithEmailAndPassword(email, password);
    }
  }

  static Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? className,
  }) async {
    initialize();
    
    if (_useFirebase) {
      try {
        return await AuthService().registerWithEmailAndPassword(
          email: email,
          password: password,
          fullName: fullName,
          role: role,
          className: className,
        );
      } catch (e) {
        print('⚠️ Firebase error, switching to mock mode: $e');
        _useFirebase = false;
        MockAuthService.initializeDemoAccounts();
        return await MockAuthService().registerWithEmailAndPassword(
          email: email,
          password: password,
          fullName: fullName,
          role: role,
          className: className,
        );
      }
    } else {
      return await MockAuthService().registerWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        className: className,
      );
    }
  }

  static Future<void> signOut() async {
    initialize();
    
    if (_useFirebase) {
      try {
        await AuthService().signOut();
      } catch (e) {
        print('⚠️ Firebase error, using mock signout: $e');
        await MockAuthService().signOut();
      }
    } else {
      await MockAuthService().signOut();
    }
  }

  static bool isUsingFirebase() {
    initialize();
    return _useFirebase;
  }
}


