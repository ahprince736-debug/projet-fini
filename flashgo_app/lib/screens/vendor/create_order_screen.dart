// lib/screens/vendor/create_order_screen.dart
// Formulaire de création d'un colis

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../widgets/flashgo_button.dart';
import '../../widgets/flashgo_textfield.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _addressCtrl    = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _shopLatCtrl    = TextEditingController();
  final _shopLngCtrl    = TextEditingController();
  final _clientLatCtrl  = TextEditingController();
  final _clientLngCtrl  = TextEditingController();

  String  _cargoType    = 'other';
  bool    _isLoading    = false;
  String? _errorMessage;
  Map?    _priceResult;

  final List<Map> _cargoTypes = [
    {'value': 'liquid',   'label': '🥤 Liquide',   'color': Color(0xFF22D3EE)},
    {'value': 'food',     'label': '🍔 Nourriture', 'color': Color(0xFFBEF264)},
    {'value': 'fragile',  'label': '🔮 Cassable',   'color': Color(0xFFF59E0B)},
    {'value': 'other',    'label': '📦 Autre',      'color': Colors.white38},
  ];

  @override
  void dispose() {
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _shopLatCtrl.dispose();
    _shopLngCtrl.dispose();
    _clientLatCtrl.dispose();
    _clientLngCtrl.dispose();
    super.dispose();
  }

  Future<void> _calculatePrice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; _errorMessage = null; _priceResult = null; });

    try {
      final token    = await LocalStorage.getToken();
      final userId   = await LocalStorage.getUserId();
      final deviceId = await LocalStorage.getDeviceId() ?? 'device_${userId}';

      final response = await http.post(
        Uri.parse(ApiConfig.orders),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'shop_lat':       6.3703,
          'shop_lng':       2.3912,
          'client_address': _addressCtrl.text.trim(),
          'client_lat':     6.3600,
          'client_lng':     2.3800,
          'client_phone':   _phoneCtrl.text.trim(),
          'cargo_type':     _cargoType,
          'device_id':      deviceId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        setState(() => _priceResult = data);
        // Afficher confirmation
        _showConfirmation(data);
      } else if (response.statusCode == 402) {
        context.push('/paywall');
      } else {
        setState(() => _errorMessage = data['message'] ?? data['error']);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Impossible de joindre le serveur.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showConfirmation(Map data) {
    showModalBottomSheet(
      context:      context,
      backgroundColor: const Color(0xFF102A43),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('✅ Colis créé avec succès !',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  Text('${data['prix_fcfa']} FCFA',
                    style: const TextStyle(color: Color(0xFFBEF264), fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Prix de la course', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
                Column(children: [
                  Text('${data['distance_km']} km',
                    style: const TextStyle(color: Color(0xFF22D3EE), fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Distance estimée', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ],
            ),
            const SizedBox(height: 24),
            FlashGoButton(
              label:     'Voir mes livraisons →',
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/vendor/dashboard');
              },
            ),
          ],
        ),
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
        title: const Text('Nouveau Colis',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Adresse client
              FlashGoTextField(
                label:      'Adresse du client',
                hint:       'ex: Rue 1200, Cotonou',
                controller: _addressCtrl,
                validator:  (v) => v!.isEmpty ? 'Champ obligatoire' : null,
              ),

              // Téléphone client
              FlashGoTextField(
                label:        'Téléphone du client',
                hint:         '+22960000000',
                controller:   _phoneCtrl,
                keyboardType: TextInputType.phone,
                validator:    (v) => v!.isEmpty ? 'Champ obligatoire' : null,
              ),

              // Coordonnées boutique
              const Text('Position de ta boutique (GPS)',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FlashGoTextField(
                      label:        'Latitude boutique',
                      hint:         '6.3703',
                      controller:   _shopLatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator:    (v) => v!.isEmpty ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FlashGoTextField(
                      label:        'Longitude boutique',
                      hint:         '2.3912',
                      controller:   _shopLngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator:    (v) => v!.isEmpty ? 'Requis' : null,
                    ),
                  ),
                ],
              ),

              // Coordonnées client
              const Text('Position du client (GPS)',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FlashGoTextField(
                      label:        'Latitude client',
                      hint:         '6.3800',
                      controller:   _clientLatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator:    (v) => v!.isEmpty ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FlashGoTextField(
                      label:        'Longitude client',
                      hint:         '2.4000',
                      controller:   _clientLngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator:    (v) => v!.isEmpty ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Type de colis
              const Text('Type de marchandise',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _cargoTypes.map((type) {
                  final isSelected = _cargoType == type['value'];
                  return GestureDetector(
                    onTap: () => setState(() => _cargoType = type['value'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (type['color'] as Color).withOpacity(0.2)
                            : const Color(0xFF1E2D3D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? type['color'] as Color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        type['label'] as String,
                        style: TextStyle(
                          color: isSelected ? type['color'] as Color : Colors.white54,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Message erreur
              if (_errorMessage != null) ...[
                Container(
                  padding:    const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: Colors.red),
                  ),
                  child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // Bouton calculer
              FlashGoButton(
                label:     'Calculer le prix de la course ➔',
                onPressed: _calculatePrice,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}