// lib/screens/vendor/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../widgets/flashgo_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/quota_widget.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});
  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  String  _shopName     = '';
  bool    _isSubscribed = false;
  int     _quotaUsed    = 0;
  List    _orders       = [];
  bool    _isLoading    = true;
  bool    _isLoadingMore = false;
  bool    _hasMore      = true;
  int     _currentPage  = 1;
  String  _filter       = 'all';
  static const _pageSize = 20;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData({bool reset = true}) async {
    if (reset) {
      setState(() { _isLoading = true; _currentPage = 1; _orders = []; _hasMore = true; });
    } else {
      if (!_hasMore || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    final shopName = await LocalStorage.getShopName();
    final token    = await LocalStorage.getToken();
    if (reset) setState(() => _shopName = shopName ?? 'Ma Boutique');

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.ordersMine}?page=$_currentPage&limit=$_pageSize'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newOrders = data['orders'] ?? [];
        setState(() {
          if (reset) {
            _orders = newOrders;
          } else {
            _orders = [..._orders, ...newOrders];
          }
          _hasMore = data['has_more'] ?? false;
          _currentPage++;
        });
      } else if (response.statusCode == 401) {
        await LocalStorage.clearAll();
        if (mounted) context.go('/vendor/login');
      }
    } catch (_) {
      // Silencieux — RefreshIndicator permet de réessayer
    } finally {
      setState(() { _isLoading = false; _isLoadingMore = false; });
    }
  }

  List get _filteredOrders {
    if (_filter == 'all') return _orders;
    return _orders.where((o) => o['status'] == _filter).toList();
  }

  int get _deliveredCount  => _orders.where((o) => o['status'] == 'delivered').length;
  int get _activeCount     => _orders.where((o) =>
      ['accepted','arrived','in_transit'].contains(o['status'])).length;

  Future<void> _logout() async {
    await LocalStorage.clearAll();
    if (!mounted) return;
    context.go('/vendor/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color:     AppColors.accent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            // ── App Bar sticky avec gradient ────────────
            SliverAppBar(
              backgroundColor:    AppColors.surface,
              elevation:          0,
              pinned:             true,
              expandedHeight:     160,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                      colors: [AppColors.headerVendor, AppColors.surface],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_shopName,
                                      style: AppTypography.displaySmall,
                                      overflow: TextOverflow.ellipsis),
                                    Text('Tableau de bord vendeur',
                                      style: AppTypography.label.copyWith(color: AppColors.textDisabled)),
                                  ],
                                ),
                              ),
                              // Badge plan
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color:        (_isSubscribed ? AppColors.success : AppColors.cta).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border:       Border.all(
                                    color: _isSubscribed ? AppColors.success : AppColors.cta,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _isSubscribed ? '⭐ Premium' : '⚡ Gratuit',
                                  style: AppTypography.label.copyWith(
                                    color:      _isSubscribed ? AppColors.success : AppColors.cta,
                                    fontWeight: FontWeight.bold,
                                    fontSize:   11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon:      const Icon(Icons.logout, color: AppColors.textDisabled, size: 20),
                                onPressed: _logout,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Mini stats
                          Row(children: [
                            _StatPill(label: 'Total',      value: '${_orders.length}',     color: AppColors.textSecondary),
                            const SizedBox(width: 10),
                            _StatPill(label: 'En cours',   value: '$_activeCount',          color: AppColors.accent),
                            const SizedBox(width: 10),
                            _StatPill(label: 'Livrés',     value: '$_deliveredCount',       color: AppColors.success),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _FilterBar(
                  selected: _filter,
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
            ),

            // ── Corps ────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  QuotaWidget(used: _quotaUsed, total: 3),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: AppColors.accent),
                      ),
                    )
                  else if (_filteredOrders.isEmpty)
                    _EmptyState(filter: _filter)
                  else ...[
                    ...(_filteredOrders.map((order) => _OrderCard(
                      order: order,
                      onTap: () {
                        if (['in_transit','accepted'].contains(order['status'])) {
                          context.push('/vendor/radar/${order['id']}');
                        }
                      },
                    ))),
                    // Bouton "charger plus" si pagination disponible
                    if (_hasMore && _filter == 'all')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: _isLoadingMore
                              ? const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)
                              : TextButton.icon(
                                  onPressed: () => _loadData(reset: false),
                                  icon:  const Icon(Icons.expand_more, color: AppColors.accent, size: 18),
                                  label: Text('Charger plus',
                                    style: AppTypography.label.copyWith(color: AppColors.accent)),
                                ),
                        ),
                      ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),

      // ── FAB créer un colis ───────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed:       () => context.push('/vendor/new-order'),
        backgroundColor: AppColors.cta,
        foregroundColor: Colors.black,
        icon:            const Icon(Icons.add),
        label:           Text('Nouveau colis', style: AppTypography.button.copyWith(color: Colors.black)),
      ),
    );
  }
}

// ── Widgets internes ───────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _StatPill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(children: [
      Text('$value ', style: AppTypography.label.copyWith(color: color, fontWeight: FontWeight.bold)),
      Text(label,    style: AppTypography.label.copyWith(color: color.withOpacity(0.7), fontSize: 11)),
    ]),
  );
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final Function(String) onChanged;
  const _FilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'Tous'), ('pending', 'Attente'), ('in_transit', 'Transit'), ('delivered', 'Livrés'),
    ];
    return Container(
      color:  AppColors.surface,
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: filters.map((f) {
          final isSelected = f.$1 == selected;
          return GestureDetector(
            onTap: () => onChanged(f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color:        isSelected ? AppColors.brandSeed.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(
                  color: isSelected ? AppColors.accent : Colors.white12,
                ),
              ),
              child: Center(
                child: Text(f.$2, style: AppTypography.label.copyWith(
                  color:      isSelected ? AppColors.accent : AppColors.textTertiary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(children: [
      Icon(
        filter == 'all' ? Icons.inventory_2_outlined : Icons.filter_list,
        color: Colors.white12, size: 72,
      ),
      const SizedBox(height: 16),
      Text(
        filter == 'all'
            ? 'Aucune livraison pour l\'instant.\nTouche le bouton + pour commencer.'
            : 'Aucune livraison dans cette catégorie.',
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
        textAlign: TextAlign.center,
      ),
    ]),
  );
}

class _OrderCard extends StatelessWidget {
  final Map order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = ['accepted','arrived','in_transit'].contains(order['status']);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(
            color: isActive ? AppColors.accent.withOpacity(0.25) : Colors.white10,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          // Header carte
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Colis #${order['id'].toString().substring(0, 8).toUpperCase()}',
                    style: AppTypography.codeInline.copyWith(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                StatusBadge(status: order['status'] ?? 'pending'),
              ],
            ),
          ),
          // Séparateur
          const Divider(height: 1, color: Colors.white10),
          // Corps
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(children: [
              const Icon(Icons.location_on, color: AppColors.accent, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order['client_address'] ?? 'Adresse inconnue',
                  style: AppTypography.bodyMedium.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${order['prix_fcfa'] ?? 0} F',
                style: AppTypography.codeInline.copyWith(color: AppColors.cta, fontSize: 14),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:  AppColors.accent.withOpacity(0.1),
                    shape:  BoxShape.circle,
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.navigation, color: AppColors.accent, size: 13),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
