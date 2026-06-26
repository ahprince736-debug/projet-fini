// lib/screens/web/tracking_screen.dart
// Page web de suivi — accessible via lien SMS sans installation

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  const TrackingScreen({super.key, required this.orderId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Map?    _order;
  LatLng? _driverPosition;
  bool    _isLoading = true;
  StreamSubscription? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.orders}/${widget.orderId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _order     = data['order'];
          _isLoading = false;
        });

        if (_order?['driver_id'] != null) {
          _startTracking(_order!['driver_id']);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _startTracking(String driverId) {
    final supabase = Supabase.instance.client;
    _realtimeSub = supabase
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            setState(() => _driverPosition = const LatLng(6.375, 2.395));
          }
        });
  }

  Future<void> _callDriver() async {
    final phone = _order?['client_phone'] ?? '';
    final url   = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _whatsappDriver() async {
    final phone = _order?['client_phone'] ?? '';
    final url   = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A43),
        elevation:       0,
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Color(0xFFBEF264), size: 20),
            const SizedBox(width: 6),
            Text(
              'FlashGo — Colis #${widget.orderId.substring(0, 8)}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
          : Column(
              children: [

                // Carte 50% de l'écran
                Expanded(
                  flex: 5,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _driverPosition ?? const LatLng(6.3703, 2.3912),
                      initialZoom:   14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'bj.flashgo.app',
                      ),
                      if (_driverPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point:  _driverPosition!,
                              width:  50,
                              height: 50,
                              child:  Container(
                                decoration: BoxDecoration(
                                  color:  const Color(0xFFBEF264),
                                  shape:  BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.motorcycle,
                                  color: Colors.black, size: 26),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Infos et OTP
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [

                        // Infos livreur
                        Container(
                          padding:    const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:        const Color(0xFF102A43),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              CircleAvatar(
                                radius:          24,
                                backgroundColor: Color(0xFF1E2D3D),
                                child: Icon(Icons.person, color: Colors.white54),
                              ),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Livreur FlashGo',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text('En route vers vous',
                                    style: TextStyle(color: Color(0xFF22D3EE), fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Zone OTP
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color:        const Color(0xFF0F1A0A),
                            borderRadius: BorderRadius.circular(16),
                            border:       Border.all(
                              color: const Color(0xFFBEF264),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text('🔐 Votre code de sécurité',
                                style: TextStyle(
                                  color:      Color(0xFFBEF264),
                                  fontSize:   14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _order?['otp_display'] ?? '• • • • •',
                                style: const TextStyle(
                                  color:         Colors.white,
                                  fontSize:      42,
                                  fontWeight:    FontWeight.bold,
                                  letterSpacing: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Donnez ce code UNIQUEMENT quand\nvous tiendrez le colis dans vos mains.',
                                style: TextStyle(
                                  color:    Colors.white54,
                                  fontSize: 12,
                                  height:   1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Boutons contact
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _callDriver,
                                icon:      const Icon(Icons.phone),
                                label:     const Text('Appeler'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E2D3D),
                                  foregroundColor: Colors.white,
                                  padding:         const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _whatsappDriver,
                                icon:      const Icon(Icons.message),
                                label:     const Text('WhatsApp'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  padding:         const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
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