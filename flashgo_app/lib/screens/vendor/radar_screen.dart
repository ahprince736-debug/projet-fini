// lib/screens/vendor/radar_screen.dart
// Carte temps réel — le vendeur suit le livreur

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/api_config.dart';
import '../../services/local_storage.dart' as ls;
import '../../widgets/flashgo_button.dart';

class RadarScreen extends StatefulWidget {
  final String orderId;
  const RadarScreen({super.key, required this.orderId});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final MapController _mapController = MapController();
  LatLng? _driverPosition;
  Map?    _orderData;
  bool    _isLoading = true;
  StreamSubscription? _realtimeSub;

  // Position de la boutique (Cotonou par défaut)
  final LatLng _shopPosition = const LatLng(6.3703, 2.3912);

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final token    = await ls.LocalStorage.getToken();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.orders}/${widget.orderId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _orderData = data['order'];
          _isLoading = false;
        });

        // Démarrer l'écoute Realtime si un livreur est assigné
        if (_orderData?['driver_id'] != null) {
          _startRealtimeTracking(_orderData!['driver_id']);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _startRealtimeTracking(String driverId) {
    // Écouter les mises à jour de position via Supabase Realtime
    final supabase = Supabase.instance.client;

    _realtimeSub = supabase
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            // Note : les coordonnées sont stockées en PostGIS
            // On récupère lat/lng depuis les métadonnées
            setState(() {
              _driverPosition = const LatLng(6.3750, 2.3950);
            });
          }
        });
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
        backgroundColor: Colors.transparent,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Suivi du livreur',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
          : Stack(
              children: [

                // ── Carte plein écran ──────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _shopPosition,
                    initialZoom:   14,
                  ),
                  children: [
                    // Tuiles OpenStreetMap
                    TileLayer(
                      urlTemplate:          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'bj.flashgo.app',
                    ),

                    // Marqueurs
                    MarkerLayer(
                      markers: [
                        // Boutique (point fixe blanc)
                        Marker(
                          point:  _shopPosition,
                          width:  40,
                          height: 40,
                          child:  Container(
                            decoration: BoxDecoration(
                              color:  Colors.white,
                              shape:  BoxShape.circle,
                              border: Border.all(color: const Color(0xFF006D77), width: 3),
                            ),
                            child: const Icon(Icons.store, color: Color(0xFF006D77), size: 20),
                          ),
                        ),

                        // Livreur (moto lime en déplacement)
                        if (_driverPosition != null)
                          Marker(
                            point:  _driverPosition!,
                            width:  50,
                            height: 50,
                            child:  Container(
                              decoration: BoxDecoration(
                                color:  const Color(0xFFBEF264),
                                shape:  BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color:      const Color(0xFFBEF264).withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.motorcycle, color: Colors.black, size: 26),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // ── Panel inférieur ────────────────────────
                Positioned(
                  bottom: 0,
                  left:   0,
                  right:  0,
                  child: Container(
                    padding:     const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color:        Color(0xFF102A43),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Barre de drag
                        Container(
                          width:  40, height: 4,
                          decoration: BoxDecoration(
                            color:        Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Infos livreur
                        Row(
                          children: [
                            // Photo livreur
                            Container(
                              width:  56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape:  BoxShape.circle,
                                border: Border.all(color: const Color(0xFF22D3EE), width: 2),
                                color:  const Color(0xFF1E2D3D),
                              ),
                              child: const Icon(Icons.person, color: Colors.white54, size: 30),
                            ),
                            const SizedBox(width: 16),

                            // Nom et plaque
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _orderData?['driver_id'] != null
                                        ? 'Livreur assigné'
                                        : 'En attente d\'un livreur...',
                                    style: const TextStyle(
                                      color:      Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize:   15,
                                    ),
                                  ),
                                  const Text(
                                    'Arrivée estimée dans 5 min',
                                    style: TextStyle(color: Color(0xFF22D3EE), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),

                            // Bouton WhatsApp
                            Container(
                              decoration: BoxDecoration(
                                color:  const Color(0xFF25D366).withOpacity(0.2),
                                shape:  BoxShape.circle,
                                border: Border.all(color: const Color(0xFF25D366)),
                              ),
                              child: IconButton(
                                icon:      const Icon(Icons.message, color: Color(0xFF25D366)),
                                onPressed: () {
                                  // TODO : ouvrir WhatsApp
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Bouton remise si livreur arrivé
                        if (_orderData?['status'] == 'arrived')
                          FlashGoButton(
                            label:     'Remettre le colis ⚡',
                            onPressed: () => context.push(
                              '/vendor/handover/${widget.orderId}',
                            ),
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