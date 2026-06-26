// lib/screens/driver/deliver_route_screen.dart
// Le livreur se rend chez le client pour livrer le colis

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/flashgo_button.dart';

class DeliverRouteScreen extends StatefulWidget {
  final String orderId;
  const DeliverRouteScreen({super.key, required this.orderId});

  @override
  State<DeliverRouteScreen> createState() => _DeliverRouteScreenState();
}

class _DeliverRouteScreenState extends State<DeliverRouteScreen> {
  LatLng _currentPosition = const LatLng(6.3703, 2.3912);
  bool   _isNearClient    = false;

  @override
  void initState() {
    super.initState();
    _watchPosition();
  }

  void _watchPosition() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((position) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        // Simuler détection proximité client (< 200m)
        // En production : comparer avec client_geom de la commande
        _isNearClient = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // Carte GPS
          FlutterMap(
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom:   15,
            ),
            children: [
              TileLayer(
                urlTemplate:          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'bj.flashgo.app',
              ),
              MarkerLayer(
                markers: [
                  // Position livreur
                  Marker(
                    point:  _currentPosition,
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

          // Bouton retour
          Positioned(
            top:  50,
            left: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding:    const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.black),
                ),
              ),
            ),
          ),

          // Info en haut
          Positioned(
            top:   50,
            left:  70,
            right: 16,
            child: SafeArea(
              child: Container(
                padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color:        const Color(0xFF102A43),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '🏠 Rends-toi chez le client pour livrer le colis',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),

          // Bouton arrivée chez client
          Positioned(
            bottom: 40,
            left:   16,
            right:  16,
            child: SizedBox(
              height: 70,
              child: ElevatedButton(
                onPressed: _isNearClient
                    ? () => context.pushReplacement('/driver/otp/${widget.orderId}')
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isNearClient
                      ? const Color(0xFFBEF264)
                      : Colors.white24,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isNearClient
                      ? 'Arrivé chez le client 🏁'
                      : 'Approche-toi du client...',
                  style: const TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}