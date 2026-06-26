// lib/services/secure_otp_storage.dart
// Stockage sécurisé du hash OTP pour validation hors-ligne

import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecureOtpStorage {
  static const String _boxName = 'secure_otp';

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

  // Nettoyer après livraison validée
  static Future<void> clearOtp(String orderId) async {
    final box = Hive.box<String>(_boxName);
    await box.delete('otp_$orderId');
  }
}