// lib/widgets/quota_widget.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class QuotaWidget extends StatelessWidget {
  final int used;
  final int total;
  const QuotaWidget({super.key, required this.used, required this.total});

  @override
  Widget build(BuildContext context) {
    final remaining = total - used;
    final ratio     = (total > 0) ? used / total : 0.0;
    final color     = remaining > 1
        ? AppColors.success
        : remaining == 1 ? AppColors.warning : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: color, size: 16),
              const SizedBox(width: 6),
              Text('Actions gratuites du jour', style: AppTypography.label),
              const Spacer(),
              Text(
                '$remaining restante${remaining > 1 ? 's' : ''}',
                style: AppTypography.label.copyWith(
                  color:      color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            ratio,
              backgroundColor:  Colors.white12,
              valueColor:       AlwaysStoppedAnimation<Color>(color),
              minHeight:        6,
            ),
          ),
          if (remaining == 0) ...[
            const SizedBox(height: 8),
            Text(
              'Quota épuisé — passe en Premium ou recharge 500 FCFA.',
              style: AppTypography.label.copyWith(
                color:    AppColors.danger,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
