// lib/screens/vendor/login_screen.dart
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

class VendorLoginScreen extends StatefulWidget {
  const VendorLoginScreen({super.key});
  @override
  State<VendorLoginScreen> createState() => _VendorLoginScreenState();
}

class _VendorLoginScreenState extends State<VendorLoginScreen> {
  final _waCtrl   = TextEditingController();
  final _passCtrl = TextEditingController();
  bool    _isLoading    = false;
  String? _errorMessage;
  String? _shopName;

  @override
  void initState() { super.initState(); _loadShopName(); }

  Future<void> _loadShopName() async {
    final name = await LocalStorage.getShopName();
    setState(() => _shopName = name);
  }

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
        if (data['profile']['shop_name'] != null) {
          await LocalStorage.saveShopName(data['profile']['shop_name']);
        }
        if (!mounted) return;
        data['profile']['role'] == 'vendor'
            ? context.go('/vendor/dashboard')
            : setState(() => _errorMessage = 'Ce compte n\'est pas un compte vendeur.');
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
  void dispose() { _waCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── En-tête branded ─────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
                colors: [AppColors.headerVendor, AppColors.background],
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
                        Image.asset('assets/images/logo_flashgo.png', width: 40, height: 40),
                        const SizedBox(width: 10),
                        Text('FlashGo', style: AppTypography.displaySmall.copyWith(color: AppColors.cta)),
                        const Spacer(),
                        const SpeedStreak(width: 48, height: 28),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _shopName != null ? 'Ravi de vous revoir,\n$_shopName !' : 'Bon retour\nsur FlashGo !',
                      style: AppTypography.displayLarge,
                    ),
                    const SizedBox(height: 6),
                    Text('Gérez vos livraisons express au Bénin', style: AppTypography.bodyMedium),
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
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text('Mot de passe oublié ?',
                        style: AppTypography.label.copyWith(color: AppColors.textDisabled)),
                    ),
                  ),
                  if (_errorMessage != null) ...[
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
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  FlashGoButton(
                    label:     'Se connecter',
                    icon:      Icons.arrow_forward,
                    onPressed: _login,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/vendor/register'),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: 'Pas de compte ? ',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled)),
                        TextSpan(text: 'Créer ma boutique',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          )),
                      ])),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(child: Divider(color: Colors.white10)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('ou', style: AppTypography.label.copyWith(color: AppColors.textFaint)),
                    ),
                    const Expanded(child: Divider(color: Colors.white10)),
                  ]),
                  const SizedBox(height: 16),
                  FlashGoButton(
                    label:     'Espace Livreur →',
                    color:     AppColors.surfaceVariant,
                    onPressed: () => context.go('/driver/login'),
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
