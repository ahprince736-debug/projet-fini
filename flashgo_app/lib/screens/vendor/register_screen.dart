// lib/screens/vendor/register_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../widgets/flashgo_button.dart';
import '../../widgets/flashgo_textfield.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/speed_streak.dart';

class VendorRegisterScreen extends StatefulWidget {
  const VendorRegisterScreen({super.key});
  @override
  State<VendorRegisterScreen> createState() => _VendorRegisterScreenState();
}

class _VendorRegisterScreenState extends State<VendorRegisterScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _shopController = TextEditingController();
  final _nameController = TextEditingController();
  final _waController   = TextEditingController();
  final _passController = TextEditingController();
  final _confController = TextEditingController();
  bool    _isLoading    = false;
  String? _errorMessage;
  // Indicateur d'étape visuel (1 = infos, 2 = sécurité)
  int     _step         = 1;

  @override
  void dispose() {
    _shopController.dispose(); _nameController.dispose();
    _waController.dispose();   _passController.dispose();
    _confController.dispose(); super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerVendor),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'shop_name': _shopController.text.trim(),
          'full_name': _nameController.text.trim(),
          'whatsapp':  _waController.text.trim(),
          'password':  _passController.text,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 Boutique créée ! Connecte-toi.'), backgroundColor: AppColors.success));
        context.go('/vendor/login');
      } else {
        setState(() => _errorMessage = data['error'] ?? 'Erreur inconnue');
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
      body: Column(children: [

        // ── En-tête branded ───────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.headerVendor, AppColors.background],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back, color: Colors.white70, size: 22),
                  ),
                  const Spacer(),
                  SpeedStreak(width: 48, height: 28, color: AppColors.cta),
                ]),
                const SizedBox(height: 20),
                Text('Ouvre ta boutique\nsur FlashGo', style: AppTypography.displayLarge),
                const SizedBox(height: 6),
                Text('Livraisons express dans tout Cotonou',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled)),
                const SizedBox(height: 20),
                // Indicateur d'étapes
                _StepIndicator(currentStep: _step, totalSteps: 2),
              ]),
            ),
          ),
        ),

        // ── Formulaire ─────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Étape 1 — Infos boutique
                if (_step == 1) ...[
                  Text('Ta boutique', style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  FlashGoTextField(
                    label: 'Nom de la boutique', hint: 'ex: Boutique Cotonou Chic',
                    controller: _shopController,
                    prefix: const Icon(Icons.store, color: AppColors.accent, size: 18),
                    validator: (v) => v!.trim().isEmpty ? 'Champ obligatoire' : null,
                  ),
                  FlashGoTextField(
                    label: 'Ton nom complet', hint: 'ex: Ablavi Mensah',
                    controller: _nameController,
                    prefix: const Icon(Icons.person, color: AppColors.accent, size: 18),
                    validator: (v) => v!.trim().isEmpty ? 'Champ obligatoire' : null,
                  ),
                  FlashGoTextField(
                    label: 'Numéro WhatsApp', hint: '+22960000000',
                    controller: _waController, keyboardType: TextInputType.phone,
                    prefix: const Icon(Icons.phone_android, color: AppColors.accent, size: 18),
                    validator: (v) {
                      if (v!.isEmpty) return 'Champ obligatoire';
                      if (!RegExp(r'^\+\d{10,15}$').hasMatch(v)) return 'Format : +22960000000';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  FlashGoButton(
                    label: 'Continuer →',
                    icon:  Icons.arrow_forward,
                    onPressed: () {
                      // Valider uniquement les 3 premiers champs avant de passer à l'étape 2
                      if (_shopController.text.trim().isEmpty ||
                          _nameController.text.trim().isEmpty ||
                          _waController.text.trim().isEmpty) {
                        setState(() => _errorMessage = 'Remplis tous les champs');
                        return;
                      }
                      setState(() { _step = 2; _errorMessage = null; });
                    },
                  ),
                ],

                // Étape 2 — Sécurité
                if (_step == 2) ...[
                  GestureDetector(
                    onTap: () => setState(() { _step = 1; _errorMessage = null; }),
                    child: Row(children: [
                      const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 14),
                      Text('Retour', style: AppTypography.label.copyWith(color: AppColors.accent)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text('Sécurité du compte', style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  FlashGoTextField(
                    label: 'Mot de passe', hint: 'Min. 8 caractères — 1 majuscule, 1 chiffre',
                    controller: _passController, obscure: true,
                    prefix: const Icon(Icons.lock_outline, color: AppColors.accent, size: 18),
                    validator: (v) {
                      if (v!.length < 8) return 'Minimum 8 caractères';
                      if (!v.contains(RegExp(r'[A-Z]'))) return 'Au moins 1 majuscule';
                      if (!v.contains(RegExp(r'[0-9]'))) return 'Au moins 1 chiffre';
                      return null;
                    },
                  ),
                  FlashGoTextField(
                    label: 'Confirmer le mot de passe', hint: 'Répète le mot de passe',
                    controller: _confController, obscure: true,
                    prefix: const Icon(Icons.lock, color: AppColors.accent, size: 18),
                    validator: (v) => v != _passController.text
                        ? 'Les mots de passe ne correspondent pas' : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding:    const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:        AppColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(color: AppColors.danger.withOpacity(0.5)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 15),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!,
                          style: AppTypography.label.copyWith(color: AppColors.danger))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  FlashGoButton(
                    label:     'Créer ma boutique ⚡',
                    icon:      Icons.flash_on,
                    onPressed: _register,
                    isLoading: _isLoading,
                  ),
                ],

                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () => context.go('/vendor/login'),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Déjà inscrit ? ',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled)),
                      TextSpan(text: 'Se connecter',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.accent, fontWeight: FontWeight.w600)),
                    ])),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep, totalSteps;
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(totalSteps, (i) {
      final isActive   = i + 1 == currentStep;
      final isComplete = i + 1 < currentStep;
      return Expanded(
        child: Container(
          margin:  EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
          height:  3,
          decoration: BoxDecoration(
            color:        isComplete ? AppColors.cta : isActive ? AppColors.cta.withOpacity(0.6) : Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }),
  );
}
