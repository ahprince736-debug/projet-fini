// lib/services/local_storage.dart
// Stockage local persistant (données gardées même après fermeture de l'app)

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _shopNameKey = 'shop_name';
  static const String _tokenKey    = 'token';
  static const String _userIdKey   = 'user_id';
  static const String _roleKey     = 'role';
  static const String _deviceIdKey = 'device_id';

  // ── Nom de la boutique ─────────────────────────────────
  static Future<void> saveShopName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shopNameKey, name);
  }

  static Future<String?> getShopName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shopNameKey);
  }

  // ── Token JWT ──────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // ── User ID ────────────────────────────────────────────
  static Future<void> saveUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, id);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // ── Rôle (vendor / driver) ─────────────────────────────
  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  // ── Device ID ──────────────────────────────────────────
  static Future<void> saveDeviceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIdKey, id);
  }

  static Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIdKey);
  }

  // ── Tout effacer (déconnexion) ─────────────────────────
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}