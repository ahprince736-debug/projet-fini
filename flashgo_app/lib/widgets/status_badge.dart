// lib/widgets/status_badge.dart
// Badge coloré qui affiche le statut d'une commande

import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'pending':    return const Color(0xFFF59E0B); // Jaune
      case 'accepted':   return const Color(0xFF3B82F6); // Bleu
      case 'arrived':    return const Color(0xFF8B5CF6); // Violet
      case 'in_transit': return const Color(0xFF22D3EE); // Cyan
      case 'delivered':  return const Color(0xFF22C55E); // Vert
      case 'cancelled':  return const Color(0xFFEF4444); // Rouge
      default:           return Colors.grey;
    }
  }

  String get _label {
    switch (status) {
      case 'pending':    return 'En attente';
      case 'accepted':   return 'Accepté';
      case 'arrived':    return 'Livreur arrivé';
      case 'in_transit': return 'En transit';
      case 'delivered':  return 'Livré';
      case 'cancelled':  return 'Annulé';
      default:           return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: _color, width: 1),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color:      _color,
          fontSize:   12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}