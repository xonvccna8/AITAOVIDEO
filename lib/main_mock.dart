// Main file for Mock Mode (No Firebase Required)
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:chemivision/screens/auth_wrapper_mock.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NO Firebase initialization - using Mock mode only
  print('🎮 Running in MOCK MODE - No Firebase required');

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
      title: 'TOÁN HỌC 4.0 (Mock Mode)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF388E3C)),
        useMaterial3: true,
      ),
      home: const AuthWrapperMock(),
    );
  }
}
