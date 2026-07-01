// lib/config/api_config.dart
//
// URL de base de l'API FlashGo — gérée par --dart-define à la compilation.
//
// Pourquoi --dart-define plutôt que coder l'URL en dur ?
//   - Une URL codée en dur force à modifier le code source pour chaque
//     environnement (émulateur, device réel, staging, production) —
//     c'est une source d'erreurs humaines et de commits accidentels.
//   - --dart-define injecte la valeur à la compilation sans toucher au
//     code source, et sans jamais l'exposer dans le repo Git.
//
// ── Comment lancer l'app selon l'environnement ──────────────────────
//
// 1. Émulateur Android (localhost via alias Android)
//    flutter run --dart-define=API_URL=http://10.0.2.2:3000
//
// 2. Vrai téléphone Android sur le même Wi-Fi
//    flutter run --dart-define=API_URL=http://192.168.1.XX:3000
//    (remplacer XX par l'IP locale de ton PC — visible dans ifconfig/ipconfig)
//
// 3. Production (serveur déployé)
//    flutter run --dart-define=API_URL=https://api.flashgo.bj
//    ou dans le build release :
//    flutter build apk --dart-define=API_URL=https://api.flashgo.bj
//
// ── Valeur par défaut ────────────────────────────────────────────────
// Si --dart-define est absent (ex : ouverture directe depuis l'IDE sans
// config de lancement), on tombe sur l'émulateur Android par défaut.
// C'est acceptable en dev ; jamais en production.

class ApiConfig {
  ApiConfig._(); // Classe statique — jamais instanciée

  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000', // émulateur Android par défaut
  );

  // ── Auth ────────────────────────────────────────────────
  static const String registerVendor = '$baseUrl/auth/register-vendor';
  static const String registerDriver = '$baseUrl/auth/register-driver';
  static const String login          = '$baseUrl/auth/login';
  static const String me             = '$baseUrl/auth/me';

  // ── Commandes ────────────────────────────────────────────
  static const String orders        = '$baseUrl/orders';
  static const String ordersNearby  = '$baseUrl/orders/nearby';
  static const String ordersMine    = '$baseUrl/orders/mine';

  // ── Localisation ─────────────────────────────────────────
  static const String locationsDriver = '$baseUrl/locations/driver';

  // ── Portefeuille ─────────────────────────────────────────
  static const String wallet         = '$baseUrl/wallet';
  static const String walletWithdraw = '$baseUrl/wallet/withdraw';
}
