// lib/widgets/speed_streak.dart
//
// Élément signature de l'identité FlashGo : trois chevrons fins en
// diagonale, évoquant la vitesse / l'éclair du nom de marque. À utiliser
// avec parcimonie — un seul endroit fort par écran (splash, en-tête d'un
// CTA principal), jamais en décoration répétée partout.

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SpeedStreak extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const SpeedStreak({
    super.key,
    this.width  = 64,
    this.height = 40,
    this.color  = AppColors.cta,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  width,
      height: height,
      child: CustomPaint(
        painter: _StreakPainter(color: color),
      ),
    );
  }
}

class _StreakPainter extends CustomPainter {
  final Color color;
  const _StreakPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = size.height * 0.16
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke;

    // Trois traits diagonaux de longueur croissante, opacité décroissante
    // vers l'arrière — donne une impression de mouvement vers la droite.
    final lengths    = [0.55, 0.75, 1.0];
    final opacities  = [0.35, 0.65, 1.0];

    for (var i = 0; i < 3; i++) {
      paint.color = color.withOpacity(opacities[i]);
      final yOffset = size.height * (0.2 + i * 0.3);
      final xEnd    = size.width * lengths[i];
      canvas.drawLine(
        Offset(0, yOffset + size.height * 0.15),
        Offset(xEnd, yOffset - size.height * 0.15),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StreakPainter oldDelegate) =>
      oldDelegate.color != color;
}
