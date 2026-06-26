// lib/widgets/flashgo_button.dart
// Bouton réutilisable style FlashGo

import 'package:flutter/material.dart';

class FlashGoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool isLoading;
  final double height;

  const FlashGoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color     = const Color(0xFFBEF264), // Lime électrique
    this.isLoading = false,
    this.height    = 56,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width:  24,
                height: 24,
                child:  CircularProgressIndicator(
                  color:       Colors.black,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}