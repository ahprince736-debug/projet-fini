// lib/screens/shared/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/local_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 2));

    final token = await LocalStorage.getToken();
    final role  = await LocalStorage.getRole();

    if (!mounted) return;

    if (token == null) {
      context.go('/vendor/login');
    } else if (role == 'vendor') {
      context.go('/vendor/dashboard');
    } else if (role == 'driver') {
      context.go('/driver/dashboard');
    } else {
      context.go('/vendor/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo FlashGo
            Image.asset(
              'assets/images/logo_flashgo.png',
              width:  120,
              height: 120,
            ),
            const SizedBox(height: 24),
            const Text(
              '⚡ FLASHGO',
              style: TextStyle(
                color:         Colors.white,
                fontSize:      32,
                fontWeight:    FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Livraison express au Bénin',
              style: TextStyle(
                color:    Colors.white54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Color(0xFF22D3EE),
            ),
          ],
        ),
      ),
    );
  }
}