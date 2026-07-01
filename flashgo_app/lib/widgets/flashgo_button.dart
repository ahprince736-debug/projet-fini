// lib/widgets/flashgo_button.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class FlashGoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool isLoading;
  final double height;
  final IconData? icon;

  const FlashGoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color     = AppColors.cta,
    this.isLoading = false,
    this.height    = 56,
    this.icon,
  });

  bool get _isPrimary => color == AppColors.cta;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: _isPrimary ? Colors.black : Colors.white,
          elevation:       _isPrimary ? 4 : 0,
          shadowColor:     _isPrimary ? AppColors.cta.withOpacity(0.4) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(
            (_isPrimary ? Colors.black : Colors.white).withOpacity(0.08),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width:  22,
                height: 22,
                child:  CircularProgressIndicator(
                  color:       _isPrimary ? Colors.black : Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize:      MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: AppTypography.button.copyWith(
                    color: _isPrimary ? Colors.black : Colors.white,
                  )),
                ],
              ),
      ),
    );
  }
}
