// lib/screens/driver/collect_route_screen.dart
// Le livreur se rend à la boutique pour récupérer le colis

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';

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
  void initState() {
    super.initState();
    _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      // Garder position par défaut
    }
  }

  Future<void> _arrivedAtShop() async {
    setState(() => _isLoading = true);

    final token = await LocalStorage.getToken();

    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.orders}/${widget.orderId}/arrived'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('✅ Notification envoyée au vendeur !'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        // Attendre que le vendeur remette le colis
        // puis naviguer vers la livraison
        context.pushReplacement('/driver/deliver/${widget.orderId}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Impossible de joindre le serveur.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
                  '📍 Rends-toi à la boutique pour récupérer le colis',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),

          // Bouton arrivée — grand et rouge en bas
          Positioned(
            bottom: 40,
            left:   16,
            right:  16,
            child: SizedBox(
              height: 70,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _arrivedAtShop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Je suis arrivé au point de collecte',
                        style: TextStyle(
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