// lib/screens/driver/collect_route_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class CollectRouteScreen extends StatefulWidget {
  final String orderId;
  const CollectRouteScreen({super.key, required this.orderId});
  @override
  State<CollectRouteScreen> createState() => _CollectRouteScreenState();
}

class _CollectRouteScreenState extends State<CollectRouteScreen> {
  LatLng _currentPosition = const LatLng(6.3703, 2.3912);
  bool   _isLoading       = false;

  @override
  void initState() { super.initState(); _getCurrentPosition(); }

  Future<void> _getCurrentPosition() async {
    try {
      final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() => _currentPosition = LatLng(p.latitude, p.longitude));
    } catch (_) {}
  }

  Future<void> _arrivedAtShop() async {
    setState(() => _isLoading = true);
    final token = await LocalStorage.getToken();
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.orders}/${widget.orderId}/arrived'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Notification envoyée au vendeur !'),
          backgroundColor: AppColors.success,
        ));
        context.pushReplacement('/driver/deliver/${widget.orderId}');
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible de joindre le serveur.'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(initialCenter: _currentPosition, initialZoom: 15),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'bj.flashgo.app'),
            MarkerLayer(markers: [
              Marker(
                point: _currentPosition, width: 52, height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    color:  AppColors.cta, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: AppColors.cta.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
                  ),
                  child: const Icon(Icons.motorcycle, color: Colors.black, size: 26),
                ),
              ),
            ]),
          ],
        ),

        // Bouton retour
        Positioned(
          top: 50, left: 16,
          child: SafeArea(
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding:    const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
              ),
            ),
          ),
        ),

        // Bandeau info
        Positioned(
          top: 50, left: 72, right: 16,
          child: SafeArea(
            child: Container(
              padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:        AppColors.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow:    [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Row(children: [
                const Icon(Icons.store, color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Rends-toi à la boutique',
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white))),
              ]),
            ),
          ),
        ),

        // Bouton arrivée
        Positioned(
          bottom: 32, left: 16, right: 16,
          child: Container(
            decoration: BoxDecoration(
              color:        AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow:    [BoxShadow(color: Colors.black45, blurRadius: 16, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Collecte du colis', style: AppTypography.displaySmall.copyWith(fontSize: 15)),
                Text('Confirme ton arrivée à la boutique', style: AppTypography.label.copyWith(color: AppColors.textDisabled)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _arrivedAtShop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text('Je suis arrivé au point de collecte',
                            style: AppTypography.button.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
