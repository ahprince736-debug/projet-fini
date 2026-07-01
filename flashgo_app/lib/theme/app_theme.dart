// lib/theme/app_theme.dart
//
// ThemeData centralisé de FlashGo — appelé une seule fois depuis main.dart.
// Avant ce fichier, le ThemeData était défini inline dans main.dart et
// quasiment inutilisé : chaque widget redéfinissait ses propres couleurs
// au lieu de lire le thème ambiant (Theme.of(context)).
//
// Objectif : centraliser ici les choix structurels (couleurs de base,
// typographie, formes), pour que toute évolution de marque se fasse
// à un seul endroit.

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandSeed,
        brightness: Brightness.dark,
        primary: AppColors.cta,
        secondary: AppColors.accent,
        error: AppColors.danger,
        surface: AppColors.surface,
      ),
    );

    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTypography.displaySmall,
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge:  AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall:  AppTypography.displaySmall,
        headlineMedium: AppTypography.displayMedium,
        headlineSmall:  AppTypography.displaySmall,
        bodyLarge:  AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        labelLarge: AppTypography.label,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cta,
          foregroundColor: Colors.black,
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
      ),
    );
  }
}
