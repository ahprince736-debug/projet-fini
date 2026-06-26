// lib/screens/driver/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../widgets/flashgo_button.dart';
import '../../widgets/flashgo_textfield.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _waCtrl   = TextEditingController();
  final _passCtrl = TextEditingController();
  bool   _isLoading    = false;
  String? _errorMessage;

  @override
  void dispose() {
    _waCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_waCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Remplis tous les champs');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'whatsapp': _waCtrl.text.trim(),
          'password': _passCtrl.text,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await LocalStorage.saveToken(data['token']);
        await LocalStorage.saveRole(data['profile']['role']);
        await LocalStorage.saveUserId(data['profile']['id']);
        if (!mounted) return;
        if (data['profile']['role'] == 'driver') {
          context.go('/driver/dashboard');
        } else {
          setState(() => _errorMessage = 'Ce compte n\'est pas un compte livreur.');
        }
      } else if (response.statusCode == 403) {
        if (!mounted) return;
        context.go('/driver/waiting');
      } else {
        setState(() => _errorMessage = data['message'] ?? data['error']);
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_flashgo.png',
                width:  90,
                height: 90,
              ),
              const SizedBox(height: 24),
              const Text(
                'Connexion Livreur',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prêt à prendre la route ?',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),
              FlashGoTextField(
                label:        'Numéro WhatsApp',
                hint:         '+22960000000',
                controller:   _waCtrl,
                keyboardType: TextInputType.phone,
              ),
              FlashGoTextField(
                label:      'Mot de passe',
                hint:       '••••••••',
                controller: _passCtrl,
                obscure:    true,
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
                label:     'Prendre la route 🏍',
                color:     const Color(0xFFBEF264),
                onPressed: _login,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => context.go('/driver/register'),
                child: const Text(
                  'Pas encore inscrit ? Soumettre mon dossier',
                  style: TextStyle(
                    color:           Color(0xFF22D3EE),
                    fontSize:        13,
                    decoration:      TextDecoration.underline,
                    decorationColor: Color(0xFF22D3EE),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.go('/vendor/login'),
                child: const Text(
                  'Je suis vendeur →',
                  style: TextStyle(color: Colors.white24, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}