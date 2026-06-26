// lib/screens/vendor/register_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../widgets/flashgo_button.dart';
import '../../widgets/flashgo_textfield.dart';

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
  bool _isLoading       = false;
  String? _errorMessage;

  @override
  void dispose() {
    _shopController.dispose();
    _nameController.dispose();
    _waController.dispose();
    _passController.dispose();
    _confController.dispose();
    super.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('Compte créé ! Connecte-toi maintenant.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        context.go('/vendor/login');
      } else {
        setState(() => _errorMessage = data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Impossible de joindre le serveur.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Center(
                  child: Image.asset(
                    'assets/images/logo_flashgo.png',
                    width:  80,
                    height: 80,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Créez votre\nespace vendeur',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   28,
                    fontWeight: FontWeight.bold,
                    height:     1.2,
                  ),
                ),
                const SizedBox(height: 32),
                FlashGoTextField(
                  label:      'Nom de la boutique',
                  hint:       'ex: Boutique Cotonou Chic',
                  controller: _shopController,
                  validator:  (v) => v!.isEmpty ? 'Champ obligatoire' : null,
                ),
                FlashGoTextField(
                  label:      'Nom complet du gérant',
                  hint:       'ex: Ablavi Mensah',
                  controller: _nameController,
                  validator:  (v) => v!.isEmpty ? 'Champ obligatoire' : null,
                ),
                FlashGoTextField(
                  label:        'Numéro WhatsApp',
                  hint:         '+22960000000',
                  controller:   _waController,
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
                  controller: _passController,
                  obscure:   true,
                  validator: (v) {
                    if (v!.length < 8) return 'Minimum 8 caractères';
                    if (!v.contains(RegExp(r'[A-Z]'))) return 'Au moins 1 majuscule';
                    if (!v.contains(RegExp(r'[0-9]'))) return 'Au moins 1 chiffre';
                    return null;
                  },
                ),
                FlashGoTextField(
                  label:     'Confirmer le mot de passe',
                  hint:      'Répète le mot de passe',
                  controller: _confController,
                  obscure:   true,
                  validator: (v) {
                    if (v != _passController.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  Container(
                    padding:    const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(color: Colors.red),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FlashGoButton(
                  label:     'Créer ma boutique ⚡',
                  onPressed: _register,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => context.go('/vendor/login'),
                    child: const Text(
                      'Déjà inscrit ? Se connecter',
                      style: TextStyle(
                        color:           Color(0xFF22D3EE),
                        fontSize:        14,
                        decoration:      TextDecoration.underline,
                        decorationColor: Color(0xFF22D3EE),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}