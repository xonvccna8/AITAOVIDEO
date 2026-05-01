// Main file sử dụng Local Database (Không cần Firebase)
// Chạy với: flutter run -t lib/main_local.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:chemivision/services/local_database_service.dart';
import 'package:chemivision/screens/auth_wrapper_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Local Database và demo data
  print('🗄️ Initializing Local Database...');
  await LocalDatabaseService.instance.initializeDemoData();
  print('✅ Local Database ready!');

  // Handle uncaught errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      print('🚨 Flutter Error: ${details.exception}');
    }
  };

  // Handle platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      print('🚨 Platform Error: $error');
      print('Stack trace: $stack');
    }
    return true;
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOÁN HỌC 4.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF388E3C)),
        useMaterial3: true,
      ),
      home: const AuthWrapperLocal(),
    );
  }
}
