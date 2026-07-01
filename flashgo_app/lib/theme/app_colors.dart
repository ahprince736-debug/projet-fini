// lib/theme/app_colors.dart
// Source unique de vérité pour toutes les couleurs de l'app FlashGo.
//
// Direction visuelle : palette ancrée dans l'identité béninoise plutôt que
// dans le cliché "fond presque noir + un seul accent néon" (vert/cyan vif)
// que beaucoup d'apps tech adoptent par défaut. Ici, double accent
// ambre (soleil, gilets des Zem) + jade profond (vert du drapeau béninois).
//
// Règle d'usage : plus aucun nouveau Color(0xFF...) ne doit apparaître
// dans un widget — toujours référencer AppColors.xxx à la place.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // classe statique, jamais instanciée

  // ── Fonds ───────────────────────────────────────────────
  static const Color background      = Color(0xFF0B1320); // encre profonde
  static const Color surface         = Color(0xFF131D2E); // cartes / sections
  static const Color surfaceVariant  = Color(0xFF1C2A40); // champs de saisie / sous-cartes

  // ── Couleurs de marque ──────────────────────────────────
  static const Color brandSeed       = Color(0xFF0F9D8C); // jade, seed du ThemeData
  static const Color accent          = Color(0xFF2DD4C4); // jade clair — liens, info "live"
  static const Color cta             = Color(0xFFFFB627); // ambre — boutons d'action (CTA)

  // ── États sémantiques ───────────────────────────────────
  static const Color success         = Color(0xFF2DD4A0);
  static const Color danger          = Color(0xFFE63946);
  static const Color warning         = Color(0xFFFFB627);
  static const Color info            = Color(0xFF3B9EE3);
  static const Color inTransit       = Color(0xFF9B6FD6); // violet — statut "en transit"

  // ── Intégrations tierces ────────────────────────────────
  static const Color whatsapp        = Color(0xFF25D366);

  // ── Variantes spécifiques (écran Paywall) ───────────────
  static const Color paywallDark     = Color(0xFF0E1828);
  static const Color paywallGreenBg  = Color(0xFF132A1C);
  static const Color trackingGreenBg = Color(0xFF0E1F16);

  // ── Fonds de gradient des en-têtes branded ────────────
  // Utilisés comme point de départ d'un dégradé vers AppColors.background
  // dans les app bars de login et de dashboard.
  static const Color headerVendor    = Color(0xFF0F1E35); // navy profond → login vendeur
  static const Color headerDriver    = Color(0xFF0A1F17); // vert nuit → login livreur

  // ── Variantes spécifiques (écran Wallet) ────────────────
  static const Color walletAmber     = Color(0xFFFFB627);
  static const Color walletGreen     = Color(0xFF1F8A5F);
  static const Color walletBlue      = Color(0xFF1D6FA5);

  // ── Neutres ──────────────────────────────────────────────
  static const Color slate           = Color(0xFF334155);

  // ── Texte sur fond sombre (alias lisibles de Colors.white*) ──
  static const Color textPrimary     = Colors.white;
  static const Color textSecondary   = Colors.white70;
  static const Color textTertiary    = Colors.white54;
  static const Color textDisabled    = Colors.white38;
  static const Color textFaint       = Colors.white24;
}

