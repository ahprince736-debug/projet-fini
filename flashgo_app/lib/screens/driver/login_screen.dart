// lib/screens/driver/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../widgets/flashgo_button.dart';
import '../../widgets/flashgo_textfield.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/speed_streak.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});
  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _waCtrl   = TextEditingController();
  final _passCtrl = TextEditingController();
  bool    _isLoading    = false;
  String? _errorMessage;

  @override
  void dispose() { _waCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_waCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Remplis tous les champs'); return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body:    jsonEncode({'whatsapp': _waCtrl.text.trim(), 'password': _passCtrl.text}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await LocalStorage.saveToken(data['token']);
        await LocalStorage.saveRole(data['profile']['role']);
        await LocalStorage.saveUserId(data['profile']['id']);
        if (!mounted) return;
        data['profile']['role'] == 'driver'
            ? context.go('/driver/dashboard')
            : setState(() => _errorMessage = 'Ce compte n\'est pas un compte livreur.');
      } else if (response.statusCode == 403) {
        if (!mounted) return;
        context.go('/driver/waiting');
      } else {
        setState(() => _errorMessage = data['message'] ?? data['error']);
      }
    } catch (_) {
      setState(() => _errorMessage = 'Impossible de joindre le serveur.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── En-tête Livreur ─────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
                colors: [AppColors.headerDriver, AppColors.background],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding:    const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:  AppColors.brandSeed.withOpacity(0.15),
                            shape:  BoxShape.circle,
                            border: Border.all(color: AppColors.brandSeed.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.motorcycle, color: AppColors.accent, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text('Livreur', style: AppTypography.displaySmall.copyWith(color: AppColors.accent)),
                        const Spacer(),
                        SpeedStreak(width: 48, height: 28, color: AppColors.accent),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text('Prêt à prendre\nla route ?', style: AppTypography.displayLarge),
                    const SizedBox(height: 6),
                    Text('Connecte-toi pour voir les courses disponibles',
                      style: AppTypography.bodyMedium),
                  ],
                ),
              ),
            ),
          ),

          // ── Formulaire ──────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FlashGoTextField(
                    label:        'Numéro WhatsApp',
                    hint:         '+22960000000',
                    controller:   _waCtrl,
                    keyboardType: TextInputType.phone,
                    prefix:       const Icon(Icons.phone_android, color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(height: 4),
                  FlashGoTextField(
                    label:      'Mot de passe',
                    hint:       '••••••••',
                    controller: _passCtrl,
                    obscure:    true,
                    prefix:     const Icon(Icons.lock_outline, color: AppColors.accent, size: 18),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding:    const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:        AppColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(color: AppColors.danger.withOpacity(0.5)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!,
                          style: AppTypography.label.copyWith(color: AppColors.danger))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FlashGoButton(
                    label:     'Prendre la route',
                    icon:      Icons.motorcycle,
                    color:     AppColors.accent,
                    onPressed: _login,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/driver/register'),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: 'Pas encore inscrit ? ',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled)),
                        TextSpan(text: 'Soumettre mon dossier',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.accent, fontWeight: FontWeight.w600)),
                      ])),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/vendor/login'),
                      child: Text('Je suis vendeur →',
                        style: AppTypography.label.copyWith(color: AppColors.textFaint)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
