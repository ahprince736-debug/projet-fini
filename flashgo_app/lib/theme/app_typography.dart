// lib/theme/app_typography.dart
//
// Système typographique de FlashGo — 3 rôles distincts, pas la même police
// partout (ce qui rendrait l'app interchangeable avec n'importe quelle autre) :
//
//  - Sora       → titres, montants importants, identité de marque
//  - Inter      → corps de texte, labels, boutons (lisibilité avant tout)
//  - Space Mono → chiffres "précis" : code OTP, numéro de commande, prix —
//                 la police à chasse fixe donne une vraie sensation de
//                 rigueur logistique à ces éléments, et les distingue
//                 visuellement du reste de l'interface.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle get displayLarge => GoogleFonts.sora(
        fontSize:   28,
        fontWeight: FontWeight.w700,
        color:      AppColors.textPrimary,
        height:     1.2,
      );

  static TextStyle get displayMedium => GoogleFonts.sora(
        fontSize:   22,
        fontWeight: FontWeight.w700,
        color:      AppColors.textPrimary,
        height:     1.25,
      );

  static TextStyle get displaySmall => GoogleFonts.sora(
        fontSize:   18,
        fontWeight: FontWeight.w600,
        color:      AppColors.textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        color:    AppColors.textPrimary,
        height:   1.4,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        color:    AppColors.textSecondary,
        height:   1.4,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize:   13,
        fontWeight: FontWeight.w500,
        color:      AppColors.textSecondary,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize:   15,
        fontWeight: FontWeight.w600,
      );

  /// Pour les codes OTP, numéros de commande, montants — chasse fixe,
  /// espacement des lettres pour une lecture rapide chiffre par chiffre.
  static TextStyle get codeDisplay => GoogleFonts.spaceMono(
        fontSize:      36,
        fontWeight:    FontWeight.w700,
        color:         AppColors.textPrimary,
        letterSpacing: 8,
      );

  /// Variante plus petite du style "code" — montants, n° de commande inline.
  static TextStyle get codeInline => GoogleFonts.spaceMono(
        fontSize:      15,
        fontWeight:    FontWeight.w600,
        color:         AppColors.textPrimary,
      );
}
