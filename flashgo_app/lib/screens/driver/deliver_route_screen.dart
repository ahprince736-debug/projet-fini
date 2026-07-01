// lib/screens/driver/deliver_route_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class DeliverRouteScreen extends StatefulWidget {
  final String orderId;
  const DeliverRouteScreen({super.key, required this.orderId});
  @override
  State<DeliverRouteScreen> createState() => _DeliverRouteScreenState();
}

class _DeliverRouteScreenState extends State<DeliverRouteScreen>
    with SingleTickerProviderStateMixin {
  LatLng _currentPosition = const LatLng(6.3703, 2.3912);
  bool   _isNearClient    = false;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _watchPosition();
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  void _watchPosition() {
    Geolocator.getPositionStream(locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high, distanceFilter: 20,
    )).listen((position) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isNearClient = true; // En production : comparer avec client_geom
      });
    });
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
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    decoration: BoxDecoration(
                      color:  AppColors.cta, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(
                        color: AppColors.cta.withOpacity(_pulseAnim.value * 0.5),
                        blurRadius: 16, spreadRadius: 3,
                      )],
                    ),
                    child: const Icon(Icons.motorcycle, color: Colors.black, size: 26),
                  ),
                ),
              ),
            ]),
          ],
        ),

        Positioned(top: 50, left: 16,
          child: SafeArea(child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding:    const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)]),
              child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
            ),
          )),
        ),

        Positioned(top: 50, left: 72, right: 16,
          child: SafeArea(child: Container(
            padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:        AppColors.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow:    [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Row(children: [
              const Icon(Icons.home, color: AppColors.cta, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Rends-toi chez le client',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white))),
            ]),
          )),
        ),

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
                Row(children: [
                  Text('Livraison chez le client', style: AppTypography.displaySmall.copyWith(fontSize: 15)),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        (_isNearClient ? AppColors.success : AppColors.warning).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(color: _isNearClient ? AppColors.success : AppColors.warning),
                    ),
                    child: Text(
                      _isNearClient ? 'Arrivé' : 'En route',
                      style: AppTypography.label.copyWith(
                        color:      _isNearClient ? AppColors.success : AppColors.warning,
                        fontSize:   11, fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ]),
                Text('Confirme quand tu es devant le client', style: AppTypography.label.copyWith(color: AppColors.textDisabled)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: _isNearClient ? () => context.pushReplacement('/driver/otp/${widget.orderId}') : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isNearClient ? AppColors.cta : AppColors.surfaceVariant,
                      foregroundColor: _isNearClient ? Colors.black : AppColors.textDisabled,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _isNearClient ? 'Arrivé chez le client 🏁' : 'Approche-toi du client...',
                      style: AppTypography.button.copyWith(
                        color: _isNearClient ? Colors.black : AppColors.textDisabled,
                      ),
                    ),
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
