// lib/screens/vendor/dashboard_screen.dart
// Tableau de bord principal du vendeur

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../widgets/flashgo_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/quota_widget.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  String  _shopName      = '';
  bool    _isSubscribed  = false;
  int     _quotaUsed     = 0;
  List    _orders        = [];
  bool    _isLoading     = true;
  String  _filter        = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final shopName = await LocalStorage.getShopName();
    final token    = await LocalStorage.getToken();

    setState(() => _shopName = shopName ?? 'Ma Boutique');

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.ordersMine),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
      );

      print('Orders response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _orders = data['orders'] ?? []);
      } else if (response.statusCode == 401) {
        // Token expiré — retour au login
        await LocalStorage.clearAll();
        if (mounted) context.go('/vendor/login');
      }
    } catch (e) {
      print('Error loading orders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Filtrer les commandes selon l'onglet sélectionné
  List get _filteredOrders {
    if (_filter == 'all') return _orders;
    return _orders.where((o) => o['status'] == _filter).toList();
  }

  Future<void> _logout() async {
    await LocalStorage.clearAll();
    if (!mounted) return;
    context.go('/vendor/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A43),
        elevation:       0,
        title: Text(
          _shopName,
          style: const TextStyle(
            color:      Colors.white,
            fontSize:   16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Badge abonnement
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color:        _isSubscribed
                  ? const Color(0xFF22C55E).withOpacity(0.2)
                  : const Color(0xFFF59E0B).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isSubscribed
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFF59E0B),
              ),
            ),
            child: Text(
              _isSubscribed ? 'Premium ⭐' : 'Gratuit',
              style: TextStyle(
                color: _isSubscribed
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFF59E0B),
                fontSize:   11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon:     const Icon(Icons.logout, color: Colors.white54),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color:     const Color(0xFF22D3EE),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Widget quota
              QuotaWidget(used: _quotaUsed, total: 3),
              const SizedBox(height: 20),

              // Bouton créer un colis
              FlashGoButton(
                label:     'Créer un Colis ➕',
                height:    64,
                onPressed: () => context.push('/vendor/new-order'),
              ),
              const SizedBox(height: 24),

              // Titre historique
              const Text(
                'Mes livraisons',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Filtres
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(label: 'Tous',       value: 'all',        selected: _filter, onTap: (v) => setState(() => _filter = v)),
                    _FilterChip(label: 'En attente', value: 'pending',    selected: _filter, onTap: (v) => setState(() => _filter = v)),
                    _FilterChip(label: 'En transit', value: 'in_transit', selected: _filter, onTap: (v) => setState(() => _filter = v)),
                    _FilterChip(label: 'Livrés',     value: 'delivered',  selected: _filter, onTap: (v) => setState(() => _filter = v)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Liste commandes
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
              else if (_filteredOrders.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.inbox, color: Colors.white24, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _filter == 'all'
                            ? 'Aucune livraison pour l\'instant.\nCrée ton premier colis !'
                            : 'Aucune livraison dans cette catégorie.',
                        style: const TextStyle(color: Colors.white38, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap:  true,
                  physics:     const NeverScrollableScrollPhysics(),
                  itemCount:   _filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = _filteredOrders[index];
                    return _OrderCard(
                      order: order,
                      onTap: () {
                        // Navigation vers radar si en transit
                        if (order['status'] == 'in_transit' ||
                            order['status'] == 'accepted') {
                          context.push('/vendor/radar/${order['id']}');
                        }
                      },
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

// ── Widget filtre ──────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF006D77)
              : const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF22D3EE)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      isSelected ? const Color(0xFF22D3EE) : Colors.white54,
            fontSize:   13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Widget carte commande ──────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Map order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        const Color(0xFF102A43),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Colis #${order['id'].toString().substring(0, 8)}',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize:   14,
                  ),
                ),
                StatusBadge(status: order['status'] ?? 'pending'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order['client_address'] ?? 'Adresse inconnue',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order['prix_fcfa'] ?? 0} FCFA',
                  style: const TextStyle(
                    color:      Color(0xFFBEF264),
                    fontWeight: FontWeight.bold,
                    fontSize:   15,
                  ),
                ),
                if (order['status'] == 'accepted' || order['status'] == 'in_transit')
                  const Row(
                    children: [
                      Icon(Icons.navigation, color: Color(0xFF22D3EE), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Voir sur carte →',
                        style: TextStyle(color: Color(0xFF22D3EE), fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}