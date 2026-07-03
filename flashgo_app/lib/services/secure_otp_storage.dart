// lib/services/secure_otp_storage.dart
// Stockage sécurisé du hash OTP pour validation hors-ligne

import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecureOtpStorage {
  static const String _boxName = 'secure_otp';
  static const int    _maxAttempts = 3;

  // Initialiser Hive (à appeler au démarrage de l'app)
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_boxName);
  }

  // Stocker le hash OTP quand le livreur accepte la course
  static Future<void> storeOtpHash(String orderId, String otpHash) async {
    final box = Hive.box<String>(_boxName);
    await box.put('otp_$orderId', otpHash);
  }

  // Valider l'OTP saisi — fonctionne SANS internet
  static Future<bool> validateOtp(String orderId, String userInput) async {
    final box = Hive.box<String>(_boxName);
    final storedHash = box.get('otp_$orderId');

    if (storedHash == null) return false;

    // Hasher la saisie et comparer
    final inputBytes = utf8.encode(userInput);
    final inputHash  = sha256.convert(inputBytes).toString();

    return inputHash == storedHash;
  }

  // ── Compteur de tentatives persisté (anti brute-force hors-ligne) ──
  //
  // Avant ce correctif, le compteur de tentatives vivait uniquement dans
  // l'état du widget Flutter (_attemptsRemaining) — redémarrer l'app ou
  // simplement naviguer hors de l'écran et y revenir remettait le
  // compteur à 3, permettant un nombre illimité d'essais en pratique.
  // Ici, le compteur est stocké dans Hive (même mécanisme que le hash
  // OTP lui-même), donc il survit à un redémarrage de l'app.

  static Future<int> getAttempts(String orderId) async {
    final box = Hive.box<String>(_boxName);
    final raw = box.get('attempts_$orderId');
    return raw != null ? int.tryParse(raw) ?? 0 : 0;
  }

  static Future<bool> isBlocked(String orderId) async {
    final attempts = await getAttempts(orderId);
    return attempts >= _maxAttempts;
  }

  /// Incrémente le compteur après un échec et retourne le nouvel état.
  static Future<({int attempts, bool isBlocked, int remaining})> recordFailedAttempt(
      String orderId) async {
    final box = Hive.box<String>(_boxName);
    final current = await getAttempts(orderId);
    final newAttempts = current + 1;
    await box.put('attempts_$orderId', newAttempts.toString());
    return (
      attempts:  newAttempts,
      isBlocked: newAttempts >= _maxAttempts,
      remaining: (_maxAttempts - newAttempts).clamp(0, _maxAttempts),
    );
  }

  // Nettoyer après livraison validée
  static Future<void> clearOtp(String orderId) async {
    final box = Hive.box<String>(_boxName);
    await box.delete('otp_$orderId');
    await box.delete('attempts_$orderId');
  }
}