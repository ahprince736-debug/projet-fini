// lib/services/local_storage.dart
// Stockage local persistant (données gardées même après fermeture de l'app)
//
// Sécurité : le token JWT et l'ID utilisateur sont stockés via
// flutter_secure_storage (Keychain sur iOS, Keystore sur Android),
// jamais en clair via SharedPreferences. Avant ce correctif, le token
// de session était lisible en texte brut sur l'appareil — un risque
// réel en cas de device root/jailbreaké ou d'accès physique.
//
// Les données non sensibles (nom de boutique, rôle, device_id) restent
// dans SharedPreferences : pas besoin de chiffrement matériel pour elles.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalStorage {
  static const String _shopNameKey = 'shop_name';
  static const String _tokenKey    = 'token';
  static const String _userIdKey   = 'user_id';
  static const String _roleKey     = 'role';
  static const String _deviceIdKey = 'device_id';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Nom de la boutique (non sensible) ──────────────────
  static Future<void> saveShopName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shopNameKey, name);
  }

  static Future<String?> getShopName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shopNameKey);
  }

  // ── Token JWT (sensible → stockage sécurisé) ───────────
  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  // ── User ID (sensible → stockage sécurisé) ─────────────
  static Future<void> saveUserId(String id) async {
    await _secureStorage.write(key: _userIdKey, value: id);
  }

  static Future<String?> getUserId() async {
    return _secureStorage.read(key: _userIdKey);
  }

  // ── Rôle (vendor / driver) — non sensible ──────────────
  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  // ── Device ID — non sensible ───────────────────────────
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
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userIdKey);
  }
}
