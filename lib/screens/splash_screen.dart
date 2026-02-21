import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/themes.dart';
import '../config/router.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      // Wait for splash animation
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Wait for auth state to be ready with timeout
      final user = await _authService.authStateChanges.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );

      if (!mounted) return;

      if (user != null) {
        try {
          final userInfo = await _authService.getCurrentUserInfo();
          final role = userInfo['role'];
          if (!mounted) return;
          context.go(AppRouter.getDashboardRoute(role));
        } catch (e) {
          debugPrint('Error getting user info: $e');
          if (!mounted) return;
          context.go(AppRouter.getDashboardRoute(null));
        }
      } else {
        context.go('/sign-in');
      }
    } catch (e) {
      debugPrint('Splash screen error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        // Still try to navigate after error
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/sign-in');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.business_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'VyaparBook',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vyapar ka Digital Hisaab',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 48),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              )
            else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
