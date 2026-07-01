// lib/screens/shared/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/local_storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/speed_streak.dart';

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
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Motif signature derrière le logo — un seul endroit fort,
            // évoque la vitesse/l'éclair du nom FlashGo.
            const SpeedStreak(width: 90, height: 56),
            const SizedBox(height: 8),

            // Logo FlashGo
            Image.asset(
              'assets/images/logo_flashgo.png',
              width:  120,
              height: 120,
            ),
            const SizedBox(height: 24),
            Text(
              '⚡ FLASHGO',
              style: AppTypography.displayLarge.copyWith(
                fontSize:      32,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Livraison express au Bénin',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}