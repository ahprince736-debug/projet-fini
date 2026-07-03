// lib/screens/shared/paywall_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/flashgo_button.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:      const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Titre ────────────────────────────────────
            Center(
              child: Column(children: [
                Container(
                  padding:    const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:  AppColors.danger.withOpacity(0.1),
                    shape:  BoxShape.circle,
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.bolt, color: AppColors.danger, size: 32),
                ),
                const SizedBox(height: 16),
                Text('Limite atteinte', style: AppTypography.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Tu as utilisé tes 3 actions gratuites du jour.\nChoisis comment continuer.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
            const SizedBox(height: 32),

            // ── Option Premium ───────────────────────────
            _PlanCard(
              tag:        '⭐ Recommandé',
              tagColor:   AppColors.cta,
              title:      'Abonnement Premium',
              price:      '5 000 FCFA / mois',
              subtitle:   'ou 50 000 FCFA / an — économisez 10 000 F',
              borderColor: AppColors.cta,
              bgColor:    AppColors.paywallGreenBg,
              perks: const [
                'Actions illimitées chaque jour',
                'Priorité sur les nouvelles courses',
                'Support WhatsApp dédié',
              ],
              child: FlashGoButton(
                label:     'S\'abonner via Mobile Money',
                icon:      Icons.phone_android,
                onPressed: () { /* TODO: KKiaPay */ },
              ),
            ),
            const SizedBox(height: 16),

            // ── Option Pay-per-use ───────────────────────
            _PlanCard(
              tag:        '⚡ Flexible',
              tagColor:   AppColors.accent,
              title:      'Paiement à l\'usage',
              price:      '100 FCFA / action',
              subtitle:   'Recharge minimum : 500 FCFA',
              borderColor: AppColors.accent,
              bgColor:    AppColors.paywallDark,
              perks: const [
                'Sans engagement',
                'Valable jusqu\'à épuisement',
                'Rechargeable à tout moment',
              ],
              child: FlashGoButton(
                label:     'Recharger mon compte',
                color:     AppColors.accent,
                icon:      Icons.add_circle_outline,
                onPressed: () { /* TODO: recharge */ },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String      tag, title, price, subtitle;
  final Color       tagColor, borderColor, bgColor;
  final List<String> perks;
  final Widget      child;
  const _PlanCard({
    required this.tag, required this.title, required this.price,
    required this.subtitle, required this.tagColor, required this.borderColor,
    required this.bgColor, required this.perks, required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding:    const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color:        bgColor,
      borderRadius: BorderRadius.circular(18),
      border:       Border.all(color: borderColor.withOpacity(0.4), width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:        tagColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(tag, style: AppTypography.label.copyWith(color: tagColor, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(height: 12),
        Text(title, style: AppTypography.displaySmall),
        const SizedBox(height: 6),
        Text(price, style: AppTypography.codeInline.copyWith(color: tagColor, fontSize: 20)),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTypography.label.copyWith(color: AppColors.textDisabled)),
        const SizedBox(height: 16),
        ...perks.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(Icons.check_circle, color: tagColor, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(p, style: AppTypography.label.copyWith(color: AppColors.textSecondary))),
          ]),
        )),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}
