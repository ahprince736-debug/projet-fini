// lib/screens/vendor/handover_screen.dart
// Écran de remise physique du colis au livreur

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../widgets/flashgo_button.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class HandoverScreen extends StatefulWidget {
  final String orderId;
  const HandoverScreen({super.key, required this.orderId});

  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double>   _pulseAnim;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Animation de pulsation sur la bordure lime
    _animController = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handover() async {
    setState(() => _isLoading = true);

    final token = await LocalStorage.getToken();

    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.orders}/${widget.orderId}/dispatch'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('✅ Colis en transit ! SMS envoyé au client.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/vendor/dashboard');
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text(data['error'] ?? 'Erreur'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Impossible de joindre le serveur.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // Animation pulsation
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Container(
                  width:  180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cta.withOpacity(_pulseAnim.value),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:       AppColors.cta.withOpacity(_pulseAnim.value * 0.3),
                        blurRadius:  30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: AppColors.cta,
                    size:  80,
                  ),
                );
              },
            ),
            const SizedBox(height: 40),

            // Alerte
            Text(
              'Le livreur est arrivé !',
              style: AppTypography.displayLarge.copyWith(color: AppColors.cta, fontSize: 26),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Text(
              'Veuillez lui remettre le colis physiquement avant de confirmer.',
              style: AppTypography.bodyLarge.copyWith(color: Colors.white70, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: AppColors.warning.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ne confirmez qu\'après avoir vu le livreur tenir le colis.',
                      style: AppTypography.label.copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Bouton confirmation
            FlashGoButton(
              label:     'Remettre le colis ⚡',
              height:    64,
              onPressed: _handover,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),

            // Bouton annuler
            TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Annuler',
                style: AppTypography.label.copyWith(color: AppColors.textDisabled),
              ),
            ),
          ],
        ),
      ),
    );
  }
}