// lib/screens/vendor/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../widgets/flashgo_button.dart';
import '../../widgets/flashgo_textfield.dart';

class VendorLoginScreen extends StatefulWidget {
  const VendorLoginScreen({super.key});

  @override
  State<VendorLoginScreen> createState() => _VendorLoginScreenState();
}

class _VendorLoginScreenState extends State<VendorLoginScreen> {
  final _waCtrl   = TextEditingController();
  final _passCtrl = TextEditingController();
  bool   _isLoading    = false;
  String? _errorMessage;
  String? _shopName;

  @override
  void initState() {
    super.initState();
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    final name = await LocalStorage.getShopName();
    setState(() => _shopName = name);
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
        if (data['profile']['shop_name'] != null) {
          await LocalStorage.saveShopName(data['profile']['shop_name']);
        }
        if (!mounted) return;
        if (data['profile']['role'] == 'vendor') {
          context.go('/vendor/dashboard');
        } else {
          setState(() => _errorMessage = 'Ce compte n\'est pas un compte vendeur.');
        }
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
  void dispose() {
    _waCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Center(
                child: Image.asset(
                  'assets/images/logo_flashgo.png',
                  width:  80,
                  height: 80,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _shopName != null
                    ? 'Ravi de vous revoir,\n$_shopName !'
                    : 'Ravi de vous revoir !',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   26,
                  fontWeight: FontWeight.bold,
                  height:     1.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connecte-toi pour gérer tes livraisons',
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
                label:     'Se connecter',
                color:     const Color(0xFF22D3EE),
                onPressed: _login,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/vendor/register'),
                  child: const Text(
                    'Pas encore de compte ? S\'inscrire',
                    style: TextStyle(
                      color:           Color(0xFF22D3EE),
                      fontSize:        14,
                      decoration:      TextDecoration.underline,
                      decorationColor: Color(0xFF22D3EE),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Row(children: [
                Expanded(child: Divider(color: Colors.white12)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ou', style: TextStyle(color: Colors.white38)),
                ),
                Expanded(child: Divider(color: Colors.white12)),
              ]),
              const SizedBox(height: 20),
              FlashGoButton(
                label:     'Je suis livreur →',
                color:     const Color(0xFF1E2D3D),
                onPressed: () => context.go('/driver/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}