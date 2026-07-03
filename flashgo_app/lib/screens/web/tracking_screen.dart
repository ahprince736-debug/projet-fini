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
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

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
  bool    _hasError  = false;
  Timer?  _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() { _isLoading = true; _hasError = false; });
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
      } else {
        setState(() { _isLoading = false; _hasError = true; });
      }
    } catch (e) {
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _startTracking(String driverId) {
    final supabase = Supabase.instance.client;
    // Le visiteur de cette page n'est PAS connecté (lien public envoyé par SMS),
    // donc le flux temps réel direct sur driver_locations serait bloqué par RLS.
    // On interroge à la place une fonction RPC publique et restreinte qui ne
    // renvoie la position que si la commande est active — sans exposer la
    // table driver_locations dans son ensemble.
    _pollingTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      try {
        final result = await supabase
            .rpc('get_tracking_location', params: {'p_order_id': widget.orderId});
        if (result is List && result.isNotEmpty && mounted) {
          final row = result.first;
          final lat = (row['lat'] as num?)?.toDouble();
          final lng = (row['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            setState(() => _driverPosition = LatLng(lat, lng));
          }
        }
      } catch (_) {
        // Échec silencieux d'un cycle de polling : on retente au prochain tick.
      }
    });
  }

  Future<void> _callDriver() async {
    final phone = _order?['driver_whatsapp'] ?? '';
    if (phone.isEmpty) { _showNoPhoneMessage(); return; }
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _whatsappDriver() async {
    final phone = _order?['driver_whatsapp'] ?? '';
    if (phone.isEmpty) { _showNoPhoneMessage(); return; }
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showNoPhoneMessage() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Numéro de contact indisponible pour cette commande.'),
      backgroundColor: AppColors.warning,
    ));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation:       0,
        title: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.cta, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'FlashGo — Colis #${widget.orderId.substring(0, 8)}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _hasError
              ? _TrackingErrorState(onRetry: _loadOrder)
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
                                  color:  AppColors.cta,
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
                            color:        AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              CircleAvatar(
                                radius:          24,
                                backgroundColor: AppColors.surfaceVariant,
                                child: Icon(Icons.person, color: Colors.white54),
                              ),
                              SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Livreur FlashGo',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text('En route vers vous',
                                    style: TextStyle(color: AppColors.accent, fontSize: 12)),
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
                            color:        AppColors.trackingGreenBg,
                            borderRadius: BorderRadius.circular(16),
                            border:       Border.all(
                              color: AppColors.cta,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text('🔐 Votre code de sécurité',
                                style: TextStyle(
                                  color:      AppColors.cta,
                                  fontSize:   14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _order?['otp_display'] ?? '• • • • •',
                                style: AppTypography.codeDisplay.copyWith(
                                  fontSize:      42,
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
                                  backgroundColor: AppColors.surfaceVariant,
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
                                  backgroundColor: AppColors.whatsapp,
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
class _TrackingErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _TrackingErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, color: Colors.white24, size: 72),
          const SizedBox(height: 20),
          const Text(
            'Commande introuvable',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ce lien de suivi n\'est plus valide, ou la commande '
            'n\'existe pas. Vérifie le lien reçu par SMS.',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh, color: AppColors.accent),
            label: const Text('Réessayer', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    ),
  );
}
