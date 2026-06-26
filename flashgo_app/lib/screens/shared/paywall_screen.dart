// lib/screens/shared/paywall_screen.dart
// Écran affiché quand le quota gratuit est dépassé

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/flashgo_button.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Bannière alerte
            Container(
              width:  double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: Colors.red),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Limite gratuite atteinte !',
                      style: TextStyle(
                        color:      Colors.red,
                        fontSize:   16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tu as utilisé tes 3 actions gratuites du jour sur cet appareil.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Option A — Abonnement
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:        const Color(0xFF1C2B0A),
                borderRadius: BorderRadius.circular(16),
                border:       Border.all(color: const Color(0xFFBEF264), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⭐ Abonnement Premium',
                    style: TextStyle(color: Color(0xFFBEF264), fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('5 000 FCFA / mois',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('ou 50 000 FCFA / an',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 16),
                  FlashGoButton(
                    label:     'S\'abonner via Mobile Money',
                    onPressed: () {
                      // TODO : intégrer KKiaPay
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Option B — Pay per use
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:        const Color(0xFF0E1E2B),
                borderRadius: BorderRadius.circular(16),
                border:       Border.all(color: const Color(0xFF22D3EE), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚡ Pay-per-use',
                    style: TextStyle(color: Color(0xFF22D3EE), fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('100 FCFA / action',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Recharge minimum : 500 FCFA',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 16),
                  FlashGoButton(
                    label:  'Recharger mon compte',
                    color:  const Color(0xFF22D3EE),
                    onPressed: () {
                      // TODO : intégrer recharge
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}