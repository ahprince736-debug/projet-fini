// lib/screens/driver/dashboard_screen.dart
// Tableau de bord du livreur — liste des courses disponibles

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../services/location_service.dart';
import '../../widgets/quota_widget.dart';
import '../../widgets/status_badge.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  List   _orders     = [];
  bool   _isLoading  = true;
  bool   _isOnline   = false;
  int    _quotaUsed  = 0;
  String _driverName = '';
  String _driverId   = '';

  @override
  void initState() {
    super.initState();
    _loadDriver();
  }

  Future<void> _loadDriver() async {
    final userId = await LocalStorage.getUserId();
    final token  = await LocalStorage.getToken();

    setState(() => _driverId = userId ?? '');

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.me),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _driverName = data['profile']['full_name'] ?? 'Livreur');
      }
    } catch (e) {
      // Silencieux
    }

    await _fetchNearbyOrders();
  }

  Future<void> _fetchNearbyOrders() async {
    setState(() => _isLoading = true);

    try {
      // Récupérer la position actuelle
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final token = await LocalStorage.getToken();

      final response = await http.get(
        Uri.parse('${ApiConfig.ordersNearby}?lat=${position.latitude}&lng=${position.longitude}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _orders = data['orders'] ?? []);
      }
    } catch (e) {
      // Si pas de GPS, charger quand même
      setState(() => _orders = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _isOnline = value);

    if (value) {
      // Démarrer le tracking GPS
      LocationService.startTracking(_driverId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('🟢 Tu es en ligne — GPS activé'),
          backgroundColor: Color(0xFF22C55E),
          duration:        Duration(seconds: 2),
        ),
      );
    } else {
      LocationService.stopTracking();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('⚫ Tu es hors ligne'),
          backgroundColor: Color(0xFF334155),
          duration:        Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    final token    = await LocalStorage.getToken();
    final deviceId = await LocalStorage.getDeviceId() ?? 'device_$_driverId';

    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.orders}/$orderId/accept'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'device_id': deviceId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Stocker le hash OTP localement
        if (data['otp_hash'] != null) {
          // SecureOtpStorage gère le stockage sécurisé
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('✅ Course acceptée ! Rends-toi à la boutique.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );

        context.push('/driver/collect/$orderId');
      } else if (response.statusCode == 402) {
        context.push('/paywall');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text(data['message'] ?? 'Erreur'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Impossible de joindre le serveur.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    LocationService.stopTracking();
    await LocalStorage.clearAll();
    if (!mounted) return;
    context.go('/driver/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A43),
        elevation:       0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _driverName,
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _isOnline ? '🟢 En ligne' : '⚫ Hors ligne',
              style: TextStyle(
                color:    _isOnline ? const Color(0xFF22C55E) : Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          // Toggle en ligne / hors ligne
          Switch(
            value:           _isOnline,
            onChanged:       _toggleOnline,
            activeColor:     const Color(0xFF22C55E),
            inactiveThumbColor: Colors.white38,
          ),
          IconButton(
            icon:      const Icon(Icons.logout, color: Colors.white54),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNearbyOrders,
        color:     const Color(0xFF22D3EE),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Quota widget
              QuotaWidget(used: _quotaUsed, total: 3),
              const SizedBox(height: 16),

              // Bouton wallet
              GestureDetector(
                onTap: () => context.push('/driver/wallet'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        const Color(0xFF102A43),
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                        color: Color(0xFF22C55E), size: 24),
                      SizedBox(width: 12),
                      Text('Voir mon portefeuille',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                      Spacer(),
                      Icon(Icons.arrow_forward_ios,
                        color: Colors.white38, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Titre courses disponibles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Courses disponibles',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_orders.length} dans 5km',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Liste des courses
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
                  ),
                )
              else if (_orders.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.motorcycle, color: Colors.white12, size: 80),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune course disponible\ndans ta zone pour l\'instant.',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _fetchNearbyOrders,
                        child: const Text(
                          'Actualiser',
                          style: TextStyle(color: Color(0xFF22D3EE)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap:  true,
                  physics:     const NeverScrollableScrollPhysics(),
                  itemCount:   _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return _OrderAvailableCard(
                      order:    order,
                      onAccept: () => _acceptOrder(order['id']),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carte course disponible ────────────────────────────────
class _OrderAvailableCard extends StatelessWidget {
  final Map order;
  final VoidCallback onAccept;

  const _OrderAvailableCard({required this.order, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFF102A43),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(status: order['status'] ?? 'pending'),
              Text(
                '${order['prix_fcfa'] ?? 0} FCFA',
                style: const TextStyle(
                  color:      Color(0xFFBEF264),
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF22D3EE), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order['client_address'] ?? 'Adresse inconnue',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(Icons.route, color: Colors.white38, size: 16),
              const SizedBox(width: 6),
              Text(
                '${((order['distance_m'] ?? 0) / 1000).toStringAsFixed(1)} km',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bouton accepter
          SizedBox(
            width:  double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Accepter cette course ➔',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}