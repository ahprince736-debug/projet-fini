// lib/screens/vendor/radar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/api_config.dart';
import '../../theme/app_typography.dart';
import '../../services/local_storage.dart' as ls;
import '../../utils/geo_parser.dart';
import '../../widgets/flashgo_button.dart';
import '../../theme/app_colors.dart';

class RadarScreen extends StatefulWidget {
  final String orderId;
  const RadarScreen({super.key, required this.orderId});
  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng?  _driverPosition;
  Map?     _orderData;
  bool     _isLoading = true;
  String?  _errorMessage;
  StreamSubscription? _realtimeSub;

  // Pulsation du marqueur livreur quand en mouvement
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  final LatLng _shopPosition = const LatLng(6.3703, 2.3912);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadOrder();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    final token = await ls.LocalStorage.getToken();
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.orders}/${widget.orderId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { _orderData = data['order']; _isLoading = false; });
        if (_orderData?['driver_id'] != null) {
          _startRealtimeTracking(_orderData!['driver_id']);
        }
      } else {
        setState(() { _errorMessage = 'Commande introuvable.'; _isLoading = false; });
      }
    } catch (_) {
      setState(() { _errorMessage = 'Impossible de charger la commande.'; _isLoading = false; });
    }
  }

  void _startRealtimeTracking(String driverId) {
    _realtimeSub = Supabase.instance.client
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final position = parseGeographyPoint(data.first['geom']);
            if (position != null) {
              setState(() => _driverPosition = position);
              // Recentrer la carte sur le livreur
              _mapController.move(position, 15);
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _errorMessage != null
              ? _ErrorState(message: _errorMessage!, onRetry: _loadOrder)
              : Stack(children: [

                  // ── Carte plein écran ──────────────────
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _driverPosition ?? _shopPosition,
                      initialZoom:   15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'bj.flashgo.app',
                      ),
                      MarkerLayer(markers: [
                        // Boutique
                        Marker(
                          point: _shopPosition, width: 44, height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color:  Colors.white,
                              shape:  BoxShape.circle,
                              border: Border.all(color: AppColors.brandSeed, width: 2.5),
                              boxShadow: [BoxShadow(color: AppColors.brandSeed.withOpacity(0.3), blurRadius: 8)],
                            ),
                            child: const Icon(Icons.store, color: AppColors.brandSeed, size: 20),
                          ),
                        ),
                        // Livreur (animé)
                        if (_driverPosition != null)
                          Marker(
                            point: _driverPosition!, width: 54, height: 54,
                            child: AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (_, __) => Container(
                                decoration: BoxDecoration(
                                  color:  AppColors.cta,
                                  shape:  BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [BoxShadow(
                                    color:      AppColors.cta.withOpacity(_pulseAnim.value * 0.5),
                                    blurRadius: 16, spreadRadius: 4,
                                  )],
                                ),
                                child: const Icon(Icons.motorcycle, color: Colors.black, size: 26),
                              ),
                            ),
                          ),
                      ]),
                    ],
                  ),

                  // ── Bouton retour + badge statut ────────
                  Positioned(
                    top: 50, left: 16, right: 16,
                    child: SafeArea(
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            padding:    const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:        Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow:    [const BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color:        AppColors.surface.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow:    [const BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: Row(children: [
                              // Indicateur live
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: _driverPosition != null ? AppColors.success : AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _driverPosition != null ? 'Livreur en direct' : 'En attente du livreur...',
                                style: AppTypography.label.copyWith(
                                  color: _driverPosition != null ? AppColors.success : AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ]),
                          ),
                        ),
                        // Bouton centrer sur livreur
                        if (_driverPosition != null) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _mapController.move(_driverPosition!, 15),
                            child: Container(
                              padding:    const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:        AppColors.cta,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow:    [BoxShadow(color: AppColors.cta.withOpacity(0.4), blurRadius: 8)],
                              ),
                              child: const Icon(Icons.gps_fixed, color: Colors.black, size: 20),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),

                  // ── Panel inférieur ────────────────────
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding:    const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      decoration: const BoxDecoration(
                        color:        AppColors.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Handle
                          Container(width: 40, height: 4,
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 16),

                          // Infos livreur
                          Row(children: [
                            Container(
                              width:  52, height: 52,
                              decoration: BoxDecoration(
                                shape:  BoxShape.circle,
                                border: Border.all(
                                  color: _driverPosition != null ? AppColors.accent : Colors.white24,
                                  width: 2,
                                ),
                                color: AppColors.surfaceVariant,
                              ),
                              child: Icon(Icons.person,
                                color: _driverPosition != null ? AppColors.accent : Colors.white38,
                                size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _orderData?['driver_id'] != null
                                        ? 'Livreur assigné'
                                        : 'En attente d\'un livreur...',
                                    style: AppTypography.bodyLarge.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _driverPosition != null
                                        ? 'Position mise à jour en direct'
                                        : 'Il acceptera ta commande bientôt',
                                    style: AppTypography.label.copyWith(
                                      color: _driverPosition != null ? AppColors.accent : AppColors.textDisabled,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // WhatsApp
                            if (_orderData?['driver_id'] != null)
                              GestureDetector(
                                onTap: () {}, // TODO: ouvrir WhatsApp
                                child: Container(
                                  padding:    const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:  AppColors.whatsapp.withOpacity(0.15),
                                    shape:  BoxShape.circle,
                                    border: Border.all(color: AppColors.whatsapp.withOpacity(0.5)),
                                  ),
                                  child: const Icon(Icons.message, color: AppColors.whatsapp, size: 20),
                                ),
                              ),
                          ]),

                          // Bouton remise si livreur arrivé
                          if (_orderData?['status'] == 'arrived') ...[
                            const SizedBox(height: 16),
                            FlashGoButton(
                              label:     'Le livreur est là — Remettre le colis ⚡',
                              icon:      Icons.handshake,
                              onPressed: () => context.push('/vendor/handover/${widget.orderId}'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.signal_wifi_off, color: Colors.white24, size: 64),
      const SizedBox(height: 16),
      Text(message, style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
        textAlign: TextAlign.center),
      const SizedBox(height: 20),
      TextButton.icon(
        onPressed: onRetry,
        icon:  const Icon(Icons.refresh, color: AppColors.accent),
        label: Text('Réessayer', style: AppTypography.label.copyWith(color: AppColors.accent)),
      ),
    ]),
  );
}
