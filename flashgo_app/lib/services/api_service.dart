// lib/services/api_service.dart
// Service qui gère toutes les requêtes HTTP vers notre API Node.js

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_storage.dart';

class ApiService {
  /// Callback global déclenché quand le serveur renvoie 401 (token expiré
  /// ou invalide). Branché depuis main.dart, car ce service statique n'a
  /// pas de BuildContext pour naviguer lui-même.
  ///
  /// Avant ce correctif : un 401 remontait juste comme une ApiException
  /// générique, gérée (ou pas) au cas par cas dans chaque écran — l'usager
  /// pouvait rester bloqué sur un écran qui échoue en boucle, sans jamais
  /// être renvoyé vers le login.
  static Future<void> Function(String? role)? onSessionExpired;

  static bool _isHandlingExpiry = false;

  static void _handleSessionExpiry() {
    if (_isHandlingExpiry) return; // évite les déclenchements multiples
    _isHandlingExpiry = true;
    LocalStorage.getRole().then((role) async {
      await LocalStorage.clearAll();
      await onSessionExpired?.call(role);
      _isHandlingExpiry = false;
    });
  }

  // ── GET ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> get(String url) async {
    final token = await LocalStorage.getToken();

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  // ── POST ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final token = await LocalStorage.getToken();

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  // ── PATCH ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> patch(
    String url,
    Map<String, dynamic> body,
  ) async {
    final token = await LocalStorage.getToken();

    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  // ── PUT ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> put(
    String url,
    Map<String, dynamic> body,
  ) async {
    final token = await LocalStorage.getToken();

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  // ── Gestion des réponses ───────────────────────────────
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401) {
      _handleSessionExpiry();
    }

    // Erreur : on lance une exception avec le message du serveur
    throw ApiException(
      statusCode: response.statusCode,
      message:    data['message'] ?? data['error'] ?? 'Erreur inconnue',
      redirect:   data['redirect'],
    );
  }
}

// Classe pour les erreurs API
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? redirect;

  ApiException({
    required this.statusCode,
    required this.message,
    this.redirect,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}