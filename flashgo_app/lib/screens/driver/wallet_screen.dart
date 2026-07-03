// lib/screens/driver/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../widgets/flashgo_button.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int    _balance       = 0;
  List   _transactions  = [];
  bool   _isLoading     = true;
  bool   _isWithdrawing = false;
  String _network       = 'mtn';
  final  _momoCtrl      = TextEditingController();

  @override
  void initState() { super.initState(); _loadWallet(); }

  @override
  void dispose() { _momoCtrl.dispose(); super.dispose(); }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    final token = await LocalStorage.getToken();
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.wallet),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _balance      = data['balance']      ?? 0;
          _transactions = data['transactions'] ?? [];
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestWithdrawal() async {
    if (_momoCtrl.text.isEmpty) {
      _snack('Entre ton numéro MoMo', AppColors.warning); return;
    }
    if (_balance < 500) {
      _snack('Solde minimum pour retirer : 500 FCFA', AppColors.danger); return;
    }
    setState(() => _isWithdrawing = true);
    final token = await LocalStorage.getToken();
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.walletWithdraw),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'amount': _balance, 'momo_number': _momoCtrl.text.trim(), 'network': _network}),
      );
      if (response.statusCode == 200) {
        _momoCtrl.clear();
        _snack('✅ Demande enregistrée — virement à 19h00.', AppColors.success);
        _loadWallet();
      } else {
        final data = jsonDecode(response.body);
        _snack(data['message'] ?? 'Erreur', AppColors.danger);
      }
    } catch (_) {
      _snack('Impossible de joindre le serveur.', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : CustomScrollView(
              slivers: [

                // ── App Bar avec solde proéminent ────────
                SliverAppBar(
                  backgroundColor:    AppColors.surface,
                  expandedHeight:     220,
                  pinned:             true,
                  leading: IconButton(
                    icon:      const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding:    const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:  AppColors.success.withOpacity(0.15),
                                    shape:  BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.account_balance_wallet,
                                    color: AppColors.success, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text('Mon Portefeuille',
                                  style: AppTypography.displaySmall.copyWith(fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text('Solde disponible',
                              style: AppTypography.label.copyWith(color: AppColors.textDisabled)),
                            const SizedBox(height: 6),
                            Text(
                              '$_balance FCFA',
                              style: AppTypography.codeDisplay.copyWith(
                                color:         AppColors.success,
                                fontSize:      44,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color:        (_balance >= 500 ? AppColors.success : AppColors.warning).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _balance >= 500 ? AppColors.success : AppColors.warning,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _balance >= 500 ? 'Retrait disponible' : 'Min. 500 FCFA pour retirer',
                                style: AppTypography.label.copyWith(
                                  color:    _balance >= 500 ? AppColors.success : AppColors.warning,
                                  fontSize: 11, fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Corps ────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── Section retrait ────────────────
                      Text('Demander un retrait',
                        style: AppTypography.displaySmall.copyWith(fontSize: 16)),
                      const SizedBox(height: 14),

                      // Choix réseau
                      Row(children: [
                        _NetworkChip(label: 'MTN MoMo',    value: 'mtn',    selected: _network, color: AppColors.cta,     onTap: (v) => setState(() => _network = v)),
                        const SizedBox(width: 8),
                        _NetworkChip(label: 'Moov Money',  value: 'moov',   selected: _network, color: AppColors.info,    onTap: (v) => setState(() => _network = v)),
                        const SizedBox(width: 8),
                        _NetworkChip(label: 'Celtis Cash', value: 'celtis', selected: _network, color: AppColors.success, onTap: (v) => setState(() => _network = v)),
                      ]),
                      const SizedBox(height: 14),

                      // Champ numéro MoMo
                      Container(
                        decoration: BoxDecoration(
                          color:        AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller:   _momoCtrl,
                          keyboardType: TextInputType.phone,
                          style: AppTypography.bodyLarge,
                          decoration: InputDecoration(
                            hintText:  'Numéro MoMo (ex: +22960000000)',
                            hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
                            filled:        true,
                            fillColor:     Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:   BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.phone_android, color: AppColors.accent, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Note regroupement
                      Row(children: [
                        const Icon(Icons.schedule, color: AppColors.textFaint, size: 13),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Virements groupés à 19h00 — zéro frais de transfert.',
                            style: AppTypography.label.copyWith(color: AppColors.textDisabled, fontSize: 11),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      FlashGoButton(
                        label:     'Virement MoMo du soir 📲',
                        icon:      Icons.send,
                        onPressed: _requestWithdrawal,
                        isLoading: _isWithdrawing,
                      ),
                      const SizedBox(height: 32),

                      // ── Historique ─────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Historique', style: AppTypography.displaySmall.copyWith(fontSize: 16)),
                          if (_transactions.isNotEmpty)
                            Text('${_transactions.length} transactions',
                              style: AppTypography.label.copyWith(color: AppColors.textDisabled, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_transactions.isEmpty)
                        _EmptyTransactions()
                      else
                        ...(_transactions.asMap().entries.map((e) =>
                          _TransactionTile(tx: e.value, isLast: e.key == _transactions.length - 1))),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding:    const EdgeInsets.symmetric(vertical: 40),
    decoration: BoxDecoration(
      color:        AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: [
      const Icon(Icons.receipt_long_outlined, color: Colors.white12, size: 48),
      const SizedBox(height: 12),
      Text('Aucune transaction pour l\'instant.',
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
        textAlign: TextAlign.center),
    ]),
  );
}

class _TransactionTile extends StatelessWidget {
  final Map  tx;
  final bool isLast;
  const _TransactionTile({required this.tx, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isEarning = tx['type'] == 'earning';
    final color     = isEarning ? AppColors.success : AppColors.danger;
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 2),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top:    isLast ? Radius.zero : Radius.zero,
          bottom: isLast ? const Radius.circular(14) : Radius.zero,
        ),
        border: Border(bottom: BorderSide(color: Colors.white05)),
      ),
      child: Row(children: [
        Container(
          padding:    const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(isEarning ? Icons.arrow_downward : Icons.arrow_upward,
            color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEarning ? 'Gain course' : 'Retrait MoMo',
              style: AppTypography.bodyLarge.copyWith(fontSize: 14)),
            Text(tx['created_at']?.toString().substring(0, 10) ?? '',
              style: AppTypography.label.copyWith(color: AppColors.textDisabled, fontSize: 11)),
          ],
        )),
        Text(
          '${isEarning ? '+' : '-'}${tx['amount']} F',
          style: AppTypography.codeInline.copyWith(color: color, fontSize: 16),
        ),
      ]),
    );
  }
}

class _NetworkChip extends StatelessWidget {
  final String label, value, selected;
  final Color  color;
  final Function(String) onTap;
  const _NetworkChip({required this.label, required this.value, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:        isSelected ? color.withOpacity(0.15) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
          ),
          child: Text(label,
            style: AppTypography.label.copyWith(
              color: isSelected ? color : AppColors.textDisabled,
              fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
