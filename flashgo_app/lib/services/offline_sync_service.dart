// lib/services/offline_sync_service.dart
//
// Gère les validations OTP effectuées hors-ligne (zone blanche) qui n'ont
// pas encore été confirmées au serveur.
//
// Avant ce correctif : une validation réussie en mode hors-ligne marquait
// la livraison comme terminée uniquement en local (Hive). Le serveur, lui,
// ignorait tout — la commande restait bloquée à son ancien statut pour
// toujours, et le paiement (déclenché côté serveur après validation) n'était
// jamais crédité au livreur. Ce service met en file d'attente chaque
// validation hors-ligne, puis tente de la rejouer dès qu'une connexion
// redevient disponible (au démarrage de l'app, et à l'arrivée sur le
// dashboard livreur).

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'local_storage.dart';

class OfflineSyncService {
  static const String _queueKey = 'pending_otp_validations';

  /// Ajoute une validation OTP réussie hors-ligne à la file d'attente,
  /// pour qu'elle soit confirmée au serveur dès que possible.
  static Future<void> queueValidation(String orderId, String otpInput) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? [];
    raw.add(jsonEncode({'order_id': orderId, 'otp_input': otpInput}));
    await prefs.setStringList(_queueKey, raw);
  }

  /// Tente de rejouer toutes les validations en attente auprès du serveur.
  /// Échec silencieux entrée par entrée : celles qui réussissent (200) ou
  /// qui sont définitivement invalides côté serveur (400 — ex. commande déjà
  /// close autrement) sont retirées. Celles qui échouent par manque de
  /// réseau restent en file pour le prochain essai.
  static Future<void> trySyncPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? [];
    if (raw.isEmpty) return;

    final token = await LocalStorage.getToken();
    final remaining = <String>[];

    for (final entry in raw) {
      try {
        final item = jsonDecode(entry) as Map<String, dynamic>;
        final response = await http.patch(
          Uri.parse('${ApiConfig.orders}/${item['order_id']}/validate-otp'),
          headers: {
            'Content-Type':  'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'otp_input': item['otp_input']}),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode != 200 && response.statusCode != 400) {
          remaining.add(entry);
        }
      } catch (_) {
        remaining.add(entry); // toujours hors-ligne : on réessaiera plus tard
      }
    }

    await prefs.setStringList(_queueKey, remaining);
  }

  /// Nombre de validations en attente de confirmation serveur.
  static Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_queueKey) ?? []).length;
  }
}
