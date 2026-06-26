// lib/screens/driver/wallet_screen.dart
// Portefeuille du livreur — gains et retraits MoMo

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/local_storage.dart';
import '../../widgets/flashgo_button.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int    _balance      = 0;
  List   _transactions = [];
  bool   _isLoading    = true;
  String _network      = 'mtn';
  final  _momoCtrl     = TextEditingController();
  bool   _isWithdrawing = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    _momoCtrl.dispose();
    super.dispose();
  }

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
    } catch (e) {
      // Silencieux
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestWithdrawal() async {
    if (_momoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Entre ton numéro MoMo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_balance < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Solde minimum : 500 FCFA'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isWithdrawing = true);
    final token = await LocalStorage.getToken();

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.walletWithdraw),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount':      _balance,
          'momo_number': _momoCtrl.text.trim(),
          'network':     _network,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('✅ Demande enregistrée. Virement à 19h00.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        _momoCtrl.clear();
        _loadWallet();
      } else {
        final data = jsonDecode(response.body);
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
    } finally {
      setState(() => _isWithdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Mon Portefeuille',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Solde principal
                  Container(
                    width:   double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF006D77), Color(0xFF102A43)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text('Solde disponible',
                          style: TextStyle(color: Colors.white54, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          '$_balance FCFA',
                          style: const TextStyle(
                            color:      Color(0xFF22C55E),
                            fontSize:   42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section retrait
                  const Text('Demander un retrait MoMo',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sélection réseau
                  Row(
                    children: [
                      _NetworkChip(label: 'MTN MoMo',    value: 'mtn',   selected: _network, color: const Color(0xFFFFC107), onTap: (v) => setState(() => _network = v)),
                      const SizedBox(width: 8),
                      _NetworkChip(label: 'Moov Money',  value: 'moov',  selected: _network, color: const Color(0xFF1565C0), onTap: (v) => setState(() => _network = v)),
                      const SizedBox(width: 8),
                      _NetworkChip(label: 'Celtis Cash', value: 'celtis',selected: _network, color: const Color(0xFF2E7D32), onTap: (v) => setState(() => _network = v)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Numéro MoMo
                  TextField(
                    controller:   _momoCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText:      'Numéro MoMo (ex: +22960000000)',
                      hintStyle:     const TextStyle(color: Colors.white38),
                      filled:        true,
                      fillColor:     const Color(0xFF1E2D3D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fonds virés à 19h00 en un seul bloc pour annuler les frais.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  FlashGoButton(
                    label:     'Demander le virement MoMo du soir 📲',
                    onPressed: _requestWithdrawal,
                    isLoading: _isWithdrawing,
                  ),
                  const SizedBox(height: 32),

                  // Historique transactions
                  const Text('Historique',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_transactions.isEmpty)
                    const Center(
                      child: Text('Aucune transaction pour l\'instant.',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap:  true,
                      physics:     const NeverScrollableScrollPhysics(),
                      itemCount:   _transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        final isEarning = tx['type'] == 'earning';
                        return Container(
                          margin:  const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:        const Color(0xFF102A43),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isEarning ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isEarning
                                    ? const Color(0xFF22C55E)
                                    : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isEarning ? 'Gain course' : 'Retrait MoMo',
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                              Text(
                                '${isEarning ? '+' : '-'}${tx['amount']} FCFA',
                                style: TextStyle(
                                  color:      isEarning
                                      ? const Color(0xFF22C55E)
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize:   14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

// ── Widget sélection réseau ────────────────────────────────
class _NetworkChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Color  color;
  final Function(String) onTap;

  const _NetworkChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:        isSelected ? color.withOpacity(0.2) : const Color(0xFF1E2D3D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:      isSelected ? color : Colors.white38,
              fontSize:   11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}