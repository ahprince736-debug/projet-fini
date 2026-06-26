// lib/config/api_config.dart
// URL de base de notre serveur Node.js

class ApiConfig {
  // En développement sur ton PC
  static const String baseUrl = 'http://10.0.2.2:3000';
  // Note : 10.0.2.2 = localhost vu depuis l'émulateur Android
  // Quand tu testes sur un vrai téléphone, remplace par l'IP de ton PC
  // ex: 'http://192.168.1.XX:3000'

  static const String registerVendor  = '$baseUrl/auth/register-vendor';
  static const String registerDriver  = '$baseUrl/auth/register-driver';
  static const String login           = '$baseUrl/auth/login';
  static const String me              = '$baseUrl/auth/me';
  static const String orders          = '$baseUrl/orders';
  static const String ordersNearby    = '$baseUrl/orders/nearby';
  static const String ordersMine      = '$baseUrl/orders/mine';
  static const String locationsDriver = '$baseUrl/locations/driver';
  static const String wallet          = '$baseUrl/wallet';
  static const String walletWithdraw  = '$baseUrl/wallet/withdraw';
}