// lib/screens/driver/register_kyc_screen.dart
// Inscription du livreur + upload des pièces KYC

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

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _waCtrl       = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confCtrl     = TextEditingController();
  final _plaqueCtrl   = TextEditingController();

  XFile? _profilePhoto;
  XFile? _cniPhoto;
  bool   _isLoading    = false;
  String? _errorMessage;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _waCtrl.dispose();
    _passCtrl.dispose();
    _confCtrl.dispose();
    _plaqueCtrl.dispose();
    super.dispose();
  }

  // Choisir une photo depuis caméra ou galerie
  Future<void> _pickPhoto(bool isProfile) async {
    final source = await showModalBottomSheet<ImageSource>(
      context:         context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choisir la source', style: AppTypography.displaySmall),
            const SizedBox(height: 20),
            ListTile(
              leading:  const Icon(Icons.camera_alt, color: AppColors.accent),
              title:    Text('Caméra', style: AppTypography.bodyLarge),
              onTap:    () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:  const Icon(Icons.photo_library, color: AppColors.cta),
              title:    Text('Galerie', style: AppTypography.bodyLarge),
              onTap:    () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final photo = await _picker.pickImage(source: source, imageQuality: 80);
    if (photo != null) {
      setState(() {
        if (isProfile) _profilePhoto = photo;
        else           _cniPhoto     = photo;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_profilePhoto == null || _cniPhoto == null) {
      setState(() => _errorMessage = 'Les deux photos sont obligatoires');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // 1. Créer le compte via notre API Node.js
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
        setState(() => _errorMessage = data['error'] ?? 'Erreur lors de l\'inscription');
        return;
      }

      // 2. Uploader les photos KYC dans Supabase Storage
      final supabase = Supabase.instance.client;
      final userId   = data['profile']['id'];

      await supabase.storage.from('kyc_documents').upload(
        '$userId/profile.jpg',
        File(_profilePhoto!.path),
        fileOptions: const FileOptions(upsert: true),
      );

      await supabase.storage.from('kyc_documents').upload(
        '$userId/cni.jpg',
        File(_cniPhoto!.path),
        fileOptions: const FileOptions(upsert: true),
      );

      if (!mounted) return;
      context.go('/driver/waiting');

    } catch (e) {
      setState(() => _errorMessage = 'Erreur : ${e.toString()}');
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
        title: Text('Inscription Livreur', style: AppTypography.displaySmall),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              FlashGoTextField(
                label:     'Nom complet',
                hint:      'ex: Marcel Okonkwo',
                controller: _nameCtrl,
                validator: (v) => v!.isEmpty ? 'Champ obligatoire' : null,
              ),

              FlashGoTextField(
                label:     'Numéro de plaque moto',
                hint:      'ex: 229-MOTO-12',
                controller: _plaqueCtrl,
                validator: (v) => v!.isEmpty ? 'Champ obligatoire' : null,
              ),

              FlashGoTextField(
                label:        'Numéro WhatsApp',
                hint:         '+22960000000',
                controller:   _waCtrl,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v!.isEmpty) return 'Champ obligatoire';
                  if (!RegExp(r'^\+\d{10,15}$').hasMatch(v)) {
                    return 'Format invalide. Ex: +22960000000';
                  }
                  return null;
                },
              ),

              FlashGoTextField(
                label:     'Mot de passe',
                hint:      'Min. 8 caractères',
                controller: _passCtrl,
                obscure:   true,
                validator: (v) {
                  if (v!.length < 8) return 'Minimum 8 caractères';
                  return null;
                },
              ),

              FlashGoTextField(
                label:     'Confirmer le mot de passe',
                hint:      'Répète le mot de passe',
                controller: _confCtrl,
                obscure:   true,
                validator: (v) {
                  if (v != _passCtrl.text) return 'Les mots de passe ne correspondent pas';
                  return null;
                },
              ),

              // Section KYC
              Text('Documents obligatoires', style: AppTypography.displaySmall),
              const SizedBox(height: 4),
              Text(
                'Ces documents sont stockés de façon sécurisée et privée.',
                style: AppTypography.label.copyWith(color: AppColors.textDisabled),
              ),
              const SizedBox(height: 16),

              // Zone photo profil
              _KycUploadZone(
                label:    'Photo de profil (selfie)',
                icon:     Icons.person,
                photo:    _profilePhoto,
                onTap:    () => _pickPhoto(true),
              ),
              const SizedBox(height: 12),

              // Zone CNI
              _KycUploadZone(
                label:    'Pièce d\'identité (CNI ou Passeport)',
                icon:     Icons.credit_card,
                photo:    _cniPhoto,
                onTap:    () => _pickPhoto(false),
              ),
              const SizedBox(height: 24),

              // Message erreur
              if (_errorMessage != null) ...[
                Container(
                  padding:    const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: AppColors.danger),
                  ),
                  child: Text(_errorMessage!,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.danger)),
                ),
                const SizedBox(height: 16),
              ],

              FlashGoButton(
                label:     'Soumettre mon dossier',
                color:     AppColors.warning,
                onPressed: _register,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),

              Center(
                child: GestureDetector(
                  onTap: () => context.go('/driver/login'),
                  child: Text(
                    'Déjà inscrit ? Se connecter',
                    style: AppTypography.bodyMedium.copyWith(
                      color:      AppColors.accent,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget zone upload KYC ─────────────────────────────────
class _KycUploadZone extends StatelessWidget {
  final String label;
  final IconData icon;
  final XFile?  photo;
  final VoidCallback onTap;

  const _KycUploadZone({
    required this.label,
    required this.icon,
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color:        AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photo != null
                ? AppColors.success
                : Colors.white24,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: photo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(photo!.path), fit: BoxFit.cover),
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Icon(Icons.check_circle, color: AppColors.success, size: 40),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white38, size: 32),
                  const SizedBox(height: 8),
                  Text(label,
                    style: AppTypography.label.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 4),
                  Text('Caméra ou Galerie',
                    style: AppTypography.label.copyWith(color: AppColors.textFaint, fontSize: 11)),
                ],
              ),
      ),
    );
  }
}