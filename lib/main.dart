import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'config/themes.dart';
import 'config/router.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  // Catch all errors in zone
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    try {
      const firebaseOptions = FirebaseOptions(
        apiKey: 'AIzaSyBYkCWUQu8EumATv-Nq9Hu-UHwz0gvmdM8',
        appId: '1:347587111588:web:2d453790b81937e5699431',
        messagingSenderId: '347587111588',
        projectId: 'ibase-29eaf',
        databaseURL: 'https://ibase-29eaf-default-rtdb.firebaseio.com',
        storageBucket: 'ibase-29eaf.appspot.com',
        iosBundleId: 'com.example.msmeDemo',
      );
      await Firebase.initializeApp(options: firebaseOptions);
      debugPrint("Firebase initialized successfully");

      // Initialize auth persistence (only for web)
      if (kIsWeb) {
        await AuthService.initializePersistence();
      }
    } catch (e, stack) {
      debugPrint("Firebase initialization failed: $e");
      debugPrint("Stack: $stack");
    }

    // Catch Flutter framework errors
    FlutterError.onError = (details) {
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack: ${details.stack}');
    };

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Unhandled Error: $error');
    debugPrint('Stack: $stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VyaparBook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
