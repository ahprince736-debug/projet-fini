// lib/screens/driver/waiting_screen.dart
// Écran d'attente de validation KYC

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverWaitingScreen extends StatefulWidget {
  const DriverWaitingScreen({super.key});

  @override
  State<DriverWaitingScreen> createState() => _DriverWaitingScreenState();
}

class _DriverWaitingScreenState extends State<DriverWaitingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _rotateAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _contactAdmin() async {
    // Remplace par ton numéro WhatsApp admin
    const adminNumber = '+22900000000';
    final url = Uri.parse('https://wa.me/$adminNumber?text=Bonjour, je viens de soumettre mon dossier livreur FlashGo et j\'aimerais savoir l\'état de ma validation.');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Icône animée
              RotationTransition(
                turns: _rotateAnim,
                child: Container(
                  width:  100,
                  height: 100,
                  decoration: BoxDecoration(
                    color:  const Color(0xFF1E2D3D),
                    shape:  BoxShape.circle,
                    border: Border.all(color: const Color(0xFF22D3EE), width: 2),
                  ),
                  child: const Icon(
                    Icons.hourglass_top,
                    color: Color(0xFF22D3EE),
                    size:  50,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              const Text(
                'Dossier en cours\nde vérification',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   26,
                  fontWeight: FontWeight.bold,
                  height:     1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              const Text(
                'L\'équipe FlashGo Bénin examine vos pièces d\'identité.\nDurée estimée : 24 à 48 heures.',
                style: TextStyle(
                  color:    Colors.white54,
                  fontSize: 14,
                  height:   1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        const Color(0xFF1E2D3D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Color(0xFF22D3EE), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vos pièces d\'identité sont stockées de façon sécurisée et privée.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Bouton WhatsApp support
              SizedBox(
                width:  double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _contactAdmin,
                  icon:  const Icon(Icons.message, color: Colors.white),
                  label: const Text(
                    'Contacter le support admin',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => context.go('/driver/login'),
                child: const Text(
                  'Retour à la connexion',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}