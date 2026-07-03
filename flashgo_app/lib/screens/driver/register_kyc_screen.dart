// lib/screens/driver/register_kyc_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../widgets/flashgo_button.dart';
import '../../widgets/flashgo_textfield.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/speed_streak.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});
  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _waCtrl     = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _confCtrl   = TextEditingController();
  final _plaqueCtrl = TextEditingController();

  XFile? _profilePhoto;
  XFile? _cniPhoto;
  bool   _isLoading    = false;
  String? _errorMessage;
  int    _step         = 1;   // 1=infos, 2=documents, 3=résumé
  final  _picker       = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose(); _waCtrl.dispose();
    _passCtrl.dispose(); _confCtrl.dispose();
    _plaqueCtrl.dispose(); super.dispose();
  }

  Future<void> _pickPhoto(bool isProfile) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Source de la photo', style: AppTypography.displaySmall.copyWith(fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.camera_alt, color: AppColors.accent),
            title: Text('Caméra', style: AppTypography.bodyLarge),
            onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library, color: AppColors.cta),
            title: Text('Galerie', style: AppTypography.bodyLarge),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final photo = await _picker.pickImage(source: source, imageQuality: 80);
    if (photo != null) setState(() => isProfile ? _profilePhoto = photo : _cniPhoto = photo);
  }

  Future<void> _register() async {
    if (_profilePhoto == null || _cniPhoto == null) {
      setState(() => _errorMessage = 'Les deux documents sont obligatoires.'); return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerDriver),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': '${_nameCtrl.text.trim()} | Plaque: ${_plaqueCtrl.text.trim()}',
          'whatsapp':  _waCtrl.text.trim(),
          'password':  _passCtrl.text,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode != 201) {
        setState(() => _errorMessage = data['error'] ?? 'Erreur lors de l\'inscription'); return;
      }
      final userId = data['profile']['id'];
      final supabase = Supabase.instance.client;
      await supabase.storage.from('kyc_documents').upload(
        '$userId/profile.jpg', File(_profilePhoto!.path),
        fileOptions: const FileOptions(upsert: true),
      );
      await supabase.storage.from('kyc_documents').upload(
        '$userId/cni.jpg', File(_cniPhoto!.path),
        fileOptions: const FileOptions(upsert: true),
      );
      if (!mounted) return;
      context.go('/driver/waiting');
    } catch (e) {
      setState(() => _errorMessage = 'Erreur technique. Réessaie plus tard.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [

        // ── En-tête ────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.headerDriver, AppColors.background],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => _step > 1
                        ? setState(() { _step--; _errorMessage = null; })
                        : context.pop(),
                    child: const Icon(Icons.arrow_back, color: Colors.white70, size: 22),
                  ),
                  const Spacer(),
                  SpeedStreak(width: 48, height: 28, color: AppColors.accent),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Container(
                    padding:    const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:  AppColors.accent.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.motorcycle, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Deviens livreur\nFlashGo', style: AppTypography.displayLarge),
                ]),
                const SizedBox(height: 6),
                Text('Étape $_step sur 3 — ${_step == 1 ? 'Tes informations' : _step == 2 ? 'Tes documents KYC' : 'Confirmer'}',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled)),
                const SizedBox(height: 16),
                _StepIndicator(currentStep: _step, totalSteps: 3),
              ]),
            ),
          ),
        ),

        // ── Corps ──────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Étape 1 : Infos ────────────────────
                if (_step == 1) ...[
                  FlashGoTextField(
                    label: 'Nom complet', hint: 'ex: Marcel Okonkwo',
                    controller: _nameCtrl,
                    prefix: const Icon(Icons.person, color: AppColors.accent, size: 18),
                    validator: (v) => v!.trim().isEmpty ? 'Champ obligatoire' : null,
                  ),
                  FlashGoTextField(
                    label: 'Plaque d\'immatriculation', hint: 'ex: 229-MOTO-12',
                    controller: _plaqueCtrl,
                    prefix: const Icon(Icons.two_wheeler, color: AppColors.accent, size: 18),
                    validator: (v) => v!.trim().isEmpty ? 'Champ obligatoire' : null,
                  ),
                  FlashGoTextField(
                    label: 'Numéro WhatsApp', hint: '+22960000000',
                    controller: _waCtrl, keyboardType: TextInputType.phone,
                    prefix: const Icon(Icons.phone_android, color: AppColors.accent, size: 18),
                    validator: (v) {
                      if (v!.isEmpty) return 'Champ obligatoire';
                      if (!RegExp(r'^\+\d{10,15}$').hasMatch(v)) return 'Format : +22960000000';
                      return null;
                    },
                  ),
                  FlashGoTextField(
                    label: 'Mot de passe', hint: 'Min. 8 caractères',
                    controller: _passCtrl, obscure: true,
                    prefix: const Icon(Icons.lock_outline, color: AppColors.accent, size: 18),
                    validator: (v) => v!.length < 8 ? 'Minimum 8 caractères' : null,
                  ),
                  FlashGoTextField(
                    label: 'Confirmer le mot de passe', hint: 'Répète le mot de passe',
                    controller: _confCtrl, obscure: true,
                    prefix: const Icon(Icons.lock, color: AppColors.accent, size: 18),
                    validator: (v) => v != _passCtrl.text
                        ? 'Les mots de passe ne correspondent pas' : null,
                  ),
                  const SizedBox(height: 16),
                  FlashGoButton(
                    label: 'Continuer vers les documents →',
                    color: AppColors.accent,
                    icon:  Icons.arrow_forward,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() { _step = 2; _errorMessage = null; });
                      }
                    },
                  ),
                ],

                // ── Étape 2 : Documents KYC ────────────
                if (_step == 2) ...[
                  // Bandeau avertissement validation
                  Container(
                    padding:    const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        AppColors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Validation manuelle requise',
                            style: AppTypography.label.copyWith(
                              color: AppColors.warning, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'L\'équipe FlashGo vérifie ton dossier sous 24–48h. '
                            'Tu recevras une confirmation sur WhatsApp.',
                            style: AppTypography.label.copyWith(
                              color: AppColors.warning.withOpacity(0.8), fontSize: 11)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Text('Documents obligatoires', style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Stockés de façon chiffrée et privée.',
                    style: AppTypography.label.copyWith(color: AppColors.textDisabled, fontSize: 11)),
                  const SizedBox(height: 14),
                  _KycUploadZone(
                    label: 'Photo de profil', subtitle: 'Selfie visage bien visible',
                    icon: Icons.person, photo: _profilePhoto, onTap: () => _pickPhoto(true),
                  ),
                  const SizedBox(height: 12),
                  _KycUploadZone(
                    label: 'Pièce d\'identité', subtitle: 'CNI ou Passeport (recto)',
                    icon: Icons.credit_card, photo: _cniPhoto, onTap: () => _pickPhoto(false),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
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
                  ],
                  const SizedBox(height: 20),
                  FlashGoButton(
                    label:     'Soumettre mon dossier',
                    color:     AppColors.accent,
                    icon:      Icons.send,
                    onPressed: _register,
                    isLoading: _isLoading,
                  ),
                ],

                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () => context.go('/driver/login'),
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
    children: List.generate(totalSteps * 2 - 1, (i) {
      if (i.isOdd) return const SizedBox(width: 6);
      final step      = i ~/ 2 + 1;
      final isActive  = step == currentStep;
      final isDone    = step < currentStep;
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height:   3,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.accent
                : isActive ? AppColors.accent.withOpacity(0.5) : Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }),
  );
}

class _KycUploadZone extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final XFile?   photo;
  final VoidCallback onTap;
  const _KycUploadZone({required this.label, required this.subtitle,
    required this.icon, required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = photo != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width:  double.infinity, height: 130,
        decoration: BoxDecoration(
          color:        hasPhoto ? AppColors.success.withOpacity(0.05) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasPhoto ? AppColors.success : Colors.white24,
            width: hasPhoto ? 1.5 : 1,
          ),
        ),
        child: hasPhoto
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(fit: StackFit.expand, children: [
                  Image.file(File(photo!.path), fit: BoxFit.cover),
                  Container(
                    color: Colors.black54,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 36),
                      const SizedBox(height: 6),
                      Text(label, style: AppTypography.label.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('Appuie pour changer', style: AppTypography.label.copyWith(color: Colors.white54, fontSize: 10)),
                    ]),
                  ),
                ]),
              )
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: Colors.white24, size: 32),
                const SizedBox(height: 8),
                Text(label, style: AppTypography.label.copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTypography.label.copyWith(color: AppColors.textFaint, fontSize: 11)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Text('Caméra ou Galerie',
                    style: AppTypography.label.copyWith(color: AppColors.accent, fontSize: 10)),
                ),
              ]),
      ),
    );
  }
}
