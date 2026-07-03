// lib/screens/driver/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../services/location_service.dart';
import '../../widgets/quota_widget.dart';
import '../../widgets/status_badge.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

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

  // Debounce : évite les appels API en rafale quand l'utilisateur
  // tire le RefreshIndicator plusieurs fois de suite rapidement.
  Timer?    _debounceTimer;
  DateTime? _lastFetch;
  static const _minFetchInterval = Duration(seconds: 8);

  @override
  void initState() { super.initState(); _loadDriver(); }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDriver() async {
    final userId = await LocalStorage.getUserId();
    final token  = await LocalStorage.getToken();
    if (!mounted) return;
    setState(() => _driverId = userId ?? '');

    // Cache profil : lire d'abord le nom stocké localement pour un
    // affichage immédiat (zéro latence perçue), puis mettre à jour
    // en arrière-plan si le réseau répond.
    final cachedName = await LocalStorage.getShopName(); // réutilise le slot "nom"
    if (!mounted) return;
    if (cachedName != null) setState(() => _driverName = cachedName);

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.me),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final name = data['profile']['full_name'] ?? 'Livreur';
        setState(() => _driverName = name);
        // Mettre à jour le cache local
        await LocalStorage.saveShopName(name);
      }
    } catch (_) {}

    if (!mounted) return;
    await _fetchNearbyOrders();
  }

  Future<void> _fetchNearbyOrders() async {
    // Debounce : si un fetch a eu lieu il y a moins de 8s, on ignore
    // silencieusement l'appel (évite la rafale d'appels API quand
    // l'utilisateur tire le RefreshIndicator plusieurs fois d'affilée).
    final now = DateTime.now();
    if (_lastFetch != null && now.difference(_lastFetch!) < _minFetchInterval) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _lastFetch = now;

    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final token = await LocalStorage.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.ordersNearby}?lat=${position.latitude}&lng=${position.longitude}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _orders = data['orders'] ?? []);
      }
    } catch (_) {
      if (mounted) setState(() => _orders = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _isOnline = value);
    if (value) {
      LocationService.startTracking(_driverId);
      _showSnack('GPS activé — tu es visible des vendeurs', AppColors.success);
    } else {
      LocationService.stopTracking();
      _showSnack('Tu es hors ligne', AppColors.slate);
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    final token    = await LocalStorage.getToken();
    final deviceId = await LocalStorage.getDeviceId() ?? 'device_$_driverId';
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.orders}/$orderId/accept'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'device_id': deviceId}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (!mounted) return;
        _showSnack('Course acceptée ! Rends-toi à la boutique.', AppColors.success);
        context.push('/driver/collect/$orderId');
      } else if (response.statusCode == 402) {
        context.push('/paywall');
      } else {
        _showSnack(data['message'] ?? 'Erreur', AppColors.danger);
      }
    } catch (_) {
      _showSnack('Impossible de joindre le serveur.', AppColors.danger);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
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
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _fetchNearbyOrders,
        color:     AppColors.accent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            // ── App Bar avec statut en-ligne ────────────
            SliverAppBar(
              backgroundColor:    AppColors.surface,
              pinned:             true,
              expandedHeight:     130,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                      colors: [AppColors.headerDriver, AppColors.surface],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          // Indicateur statut
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width:  46, height: 46,
                            decoration: BoxDecoration(
                              color:  (_isOnline ? AppColors.success : AppColors.slate).withOpacity(0.15),
                              shape:  BoxShape.circle,
                              border: Border.all(
                                color: _isOnline ? AppColors.success : AppColors.slate,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.motorcycle,
                              color: _isOnline ? AppColors.success : AppColors.textDisabled,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment:  MainAxisAlignment.center,
                              children: [
                                Text(_driverName, style: AppTypography.displaySmall.copyWith(fontSize: 16)),
                                const SizedBox(height: 2),
                                Row(children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 7, height: 7,
                                    decoration: BoxDecoration(
                                      color: _isOnline ? AppColors.success : AppColors.textDisabled,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _isOnline ? 'En ligne — GPS actif' : 'Hors ligne',
                                    style: AppTypography.label.copyWith(
                                      color:    _isOnline ? AppColors.success : AppColors.textDisabled,
                                      fontSize: 11,
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                          Switch(
                            value:          _isOnline,
                            onChanged:      _toggleOnline,
                            activeColor:    AppColors.success,
                            inactiveThumbColor: Colors.white38,
                          ),
                          IconButton(
                            icon:      const Icon(Icons.logout, color: AppColors.textDisabled, size: 20),
                            onPressed: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Corps ────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  QuotaWidget(used: _quotaUsed, total: 3),
                  const SizedBox(height: 12),

                  // Raccourci portefeuille
                  GestureDetector(
                    onTap: () => context.push('/driver/wallet'),
                    child: Container(
                      padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color:        AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border:       Border.all(color: AppColors.success.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        Container(
                          padding:    const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:  AppColors.success.withOpacity(0.1),
                            shape:  BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: AppColors.success, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mon portefeuille', style: AppTypography.bodyLarge.copyWith(fontSize: 14)),
                              Text('Gains et retraits MoMo',
                                style: AppTypography.label.copyWith(color: AppColors.textDisabled, fontSize: 11)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: AppColors.textDisabled, size: 13),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Titre courses
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Courses disponibles', style: AppTypography.displaySmall),
                      if (!_isLoading)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:        AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_orders.length} dans 5 km',
                            style: AppTypography.label.copyWith(color: AppColors.accent, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: AppColors.accent),
                      ),
                    )
                  else if (_orders.isEmpty)
                    _EmptyOrders(onRefresh: _fetchNearbyOrders)
                  else
                    ...(_orders.map((order) => _AvailableOrderCard(
                      order:    order,
                      onAccept: () => _acceptOrder(order['id']),
                    ))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyOrders({required this.onRefresh});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(children: [
      const Icon(Icons.motorcycle, color: Colors.white10, size: 80),
      const SizedBox(height: 16),
      Text(
        'Aucune course dans ta zone\npour l\'instant.',
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      TextButton.icon(
        onPressed: onRefresh,
        icon:  const Icon(Icons.refresh, color: AppColors.accent, size: 16),
        label: Text('Actualiser', style: AppTypography.label.copyWith(color: AppColors.accent)),
      ),
    ]),
  );
}

class _AvailableOrderCard extends StatelessWidget {
  final Map order;
  final VoidCallback onAccept;
  const _AvailableOrderCard({required this.order, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final distKm = ((order['distance_m'] ?? 0) / 1000).toStringAsFixed(1);
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.accent.withOpacity(0.15)),
      ),
      child: Column(children: [
        // Header — prix + distance
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color:        AppColors.surfaceVariant.withOpacity(0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            StatusBadge(status: order['status'] ?? 'pending'),
            const Spacer(),
            Text(
              '${order['prix_fcfa'] ?? 0} FCFA',
              style: AppTypography.codeInline.copyWith(color: AppColors.cta, fontSize: 20),
            ),
          ]),
        ),
        // Corps
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.location_on, color: AppColors.accent, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order['client_address'] ?? 'Adresse inconnue',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(children: [
                const Icon(Icons.route, color: AppColors.textDisabled, size: 13),
                const SizedBox(width: 4),
                Text('$distKm km',
                  style: AppTypography.label.copyWith(color: AppColors.textDisabled)),
              ]),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width:  double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Accepter cette course ➔',
                  style: AppTypography.button.copyWith(fontSize: 14, color: Colors.black)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
