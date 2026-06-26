// lib/widgets/quota_widget.dart
// Affiche le quota gratuit restant du jour

import 'package:flutter/material.dart';

class QuotaWidget extends StatelessWidget {
  final int used;
  final int total;

  const QuotaWidget({
    super.key,
    required this.used,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = total - used;
    final color = remaining > 0
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:        const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            'Gratuités du jour : ',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            '$remaining / $total',
            style: TextStyle(
              color:      color,
              fontSize:   14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (remaining == 0) ...[
            const SizedBox(width: 8),
            const Text(
              '— Recharge requise',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ]
        ],
      ),
    );
  }
}