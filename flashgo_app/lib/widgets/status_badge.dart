// lib/widgets/status_badge.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'pending':    return AppColors.warning;
      case 'accepted':   return AppColors.info;
      case 'arrived':    return AppColors.inTransit;
      case 'in_transit': return AppColors.accent;
      case 'delivered':  return AppColors.success;
      case 'cancelled':  return AppColors.danger;
      default:           return Colors.grey;
    }
  }

  String get _label {
    switch (status) {
      case 'pending':    return 'En attente';
      case 'accepted':   return 'Accepté';
      case 'arrived':    return 'Livreur arrivé';
      case 'in_transit': return 'En transit';
      case 'delivered':  return 'Livré ✓';
      case 'cancelled':  return 'Annulé';
      default:           return status;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'pending':    return Icons.schedule;
      case 'accepted':   return Icons.check_circle_outline;
      case 'arrived':    return Icons.store;
      case 'in_transit': return Icons.motorcycle;
      case 'delivered':  return Icons.done_all;
      case 'cancelled':  return Icons.cancel_outlined;
      default:           return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: _color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: 11),
          const SizedBox(width: 5),
          Text(
            _label,
            style: AppTypography.label.copyWith(
              color:      _color,
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
