// lib/screens/driver/otp_validation_screen.dart
// Validation OTP de la livraison — fonctionne hors-ligne

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../services/secure_otp_storage.dart';
import '../../widgets/flashgo_button.dart';

class OtpValidationScreen extends StatefulWidget {
  final String orderId;
  const OtpValidationScreen({super.key, required this.orderId});

  @override
  State<OtpValidationScreen> createState() => _OtpValidationScreenState();
}

class _OtpValidationScreenState extends State<OtpValidationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(5, (_) => FocusNode());

  int    _attemptsRemaining = 3;
  bool   _isBlocked         = false;
  bool   _isLoading         = false;
  bool   _isOffline         = false;

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes)  { f.dispose(); }
    super.dispose();
  }

  String get _otpInput =>
      _controllers.map((c) => c.text).join();

  Future<void> _validate() async {
    if (_otpInput.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Entre les 5 chiffres du code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isBlocked) return;

    setState(() => _isLoading = true);

    try {
      // Essayer d'abord en ligne
      final token    = await LocalStorage.getToken();
      final driverId = await LocalStorage.getUserId();

      final response = await http.patch(
        Uri.parse('${ApiConfig.orders}/${widget.orderId}/validate-otp'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'otp_input': _otpInput,
          'driver_id': driverId,
        }),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _onSuccess();
      } else if (response.statusCode == 400) {
        setState(() {
          _attemptsRemaining = data['remaining'] ?? _attemptsRemaining - 1;
          _isBlocked         = _attemptsRemaining <= 0;
        });
        _onError();
      } else if (response.statusCode == 429) {
        setState(() => _isBlocked = true);
      }

    } catch (e) {
      // Hors ligne — validation locale avec Hive
      setState(() => _isOffline = true);
      final isValid = await SecureOtpStorage.validateOtp(
        widget.orderId, _otpInput,
      );

      if (isValid) {
        _onSuccess();
      } else {
        setState(() {
          _attemptsRemaining--;
          _isBlocked = _attemptsRemaining <= 0;
        });
        _onError();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSuccess() {
    SecureOtpStorage.clearOtp(widget.orderId);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF102A43),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 70),
            const SizedBox(height: 16),
            const Text('Livraison validée !',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Ton paiement a été crédité dans ton portefeuille.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FlashGoButton(
              label:     'Voir mes gains →',
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/driver/wallet');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onError() {
    for (final c in _controllers) { c.clear(); }
    _focusNodes[0].requestFocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBlocked
              ? '🚫 Trop de tentatives. Contacte le support.'
              : '❌ Code incorrect. $_attemptsRemaining tentative(s) restante(s).',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Validation OTP',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // Icône cadenas
            Icon(
              _isBlocked ? Icons.lock : Icons.lock_open,
              color: _isBlocked
                  ? Colors.red
                  : const Color(0xFFBEF264),
              size: 80,
            ),
            const SizedBox(height: 24),

            const Text(
              'Entre le code donné\npar le client',
              style: TextStyle(
                color:      Colors.white,
                fontSize:   22,
                fontWeight: FontWeight.bold,
                height:     1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            const Text(
              'Le client doit te donner ce code\nuniquement quand il tient le colis.',
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 5 cases OTP
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                return SizedBox(
                  width:  52,
                  height: 64,
                  child: TextFormField(
                    controller:   _controllers[index],
                    focusNode:    _focusNodes[index],
                    enabled:      !_isBlocked,
                    keyboardType: TextInputType.number,
                    maxLength:    1,
                    textAlign:    TextAlign.center,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled:      true,
                      fillColor:   const Color(0xFF1E2D3D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   const BorderSide(
                          color: Color(0xFFBEF264), width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 4) {
                        _focusNodes[index + 1].requestFocus();
                      }
                      if (value.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Indicateur tentatives
            if (!_isBlocked)
              Text(
                'Tentatives restantes : $_attemptsRemaining / 3',
                style: TextStyle(
                  color:      _attemptsRemaining <= 1
                      ? Colors.red
                      : Colors.white54,
                  fontSize:   13,
                  fontWeight: FontWeight.w500,
                ),
              ),

            if (_isBlocked)
              const Text(
                '🚫 BLOQUÉ — Contacte le support FlashGo',
                style: TextStyle(
                  color:      Colors.red,
                  fontSize:   13,
                  fontWeight: FontWeight.bold,
                ),
              ),

            // Indicateur hors-ligne
            if (_isOffline) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:        Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: Colors.orange),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.orange, size: 14),
                    SizedBox(width: 6),
                    Text('Validation locale cryptée active (Zone Blanche)',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Bouton valider
            if (!_isBlocked)
              FlashGoButton(
                label:     'Vérifier le code & Finaliser',
                onPressed: _validate,
                isLoading: _isLoading,
              ),
          ],
        ),
      ),
    );
  }
}