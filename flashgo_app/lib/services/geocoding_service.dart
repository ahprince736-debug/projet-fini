// lib/services/geocoding_service.dart
//
// Géocodage d'adresses textuelles → coordonnées GPS via Nominatim (OpenStreetMap).
//
// Pourquoi Nominatim plutôt que Google Maps ?
//  - Gratuit, sans clé API, sans carte bancaire
//  - Couverture correcte au Bénin (Cotonou, Abomey-Calavi, Porto-Novo,
//    Parakou, quartiers principaux)
//  - Suffisant pour une app de livraison locale en phase de lancement
//
// Limitations à connaître :
//  - Rate-limit : 1 requête/seconde (politique Nominatim)
//    → géré ici par un délai minimum entre deux appels
//  - Adresses très informelles ("derrière la pharmacie du marché") :
//    pas trouvées → l'UI invite l'utilisateur à préciser
//  - Si le volume de commandes dépasse ~50/min : migrer vers l'API
//    Google Maps Geocoding ($5/1000 req après crédit gratuit mensuel)
//
// CGU Nominatim : https://operations.osmfoundation.org/policies/nominatim/
// → Attribution obligatoire dans l'UI (mention "© OpenStreetMap")

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final double lat;
  final double lng;
  final String displayName; // Adresse formatée retournée par Nominatim

  const GeocodingResult({
    required this.lat,
    required this.lng,
    required this.displayName,
  });
}

class GeocodingService {
  GeocodingService._(); // Classe statique, jamais instanciée

  // ── Cache en mémoire ────────────────────────────────────
  // Évite de rappeler Nominatim si l'utilisateur saisit plusieurs fois
  // la même adresse dans la session courante.
  static final Map<String, GeocodingResult> _cache = {};

  // ── Rate-limit ──────────────────────────────────────────
  // Nominatim exige au moins 1 seconde entre deux requêtes.
  static DateTime? _lastCall;
  static const _minInterval = Duration(milliseconds: 1100); // marge de sécurité

  /// Convertit une adresse textuelle en coordonnées GPS.
  ///
  /// Paramètres :
  ///  - [address] : adresse saisie par l'utilisateur
  ///  - [countryCode] : code pays ISO 3166-1 pour restreindre la recherche
  ///    (défaut : 'bj' → Bénin uniquement)
  ///  - [cityBias] : ville préfixée à la requête pour améliorer la précision
  ///    sur les adresses courtes (défaut : 'Cotonou')
  ///
  /// Retourne null si l'adresse n'est pas trouvée (pas d'exception).
  static Future<GeocodingResult?> geocode(
    String address, {
    String countryCode = 'bj',
    String cityBias    = 'Cotonou',
  }) async {
    final query = address.trim();
    if (query.isEmpty) return null;

    // Clé de cache : combinaison query + pays
    final cacheKey = '$countryCode|$query';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    // Rate-limit : attendre si le dernier appel est trop récent
    if (_lastCall != null) {
      final elapsed = DateTime.now().difference(_lastCall!);
      if (elapsed < _minInterval) {
        await Future.delayed(_minInterval - elapsed);
      }
    }
    _lastCall = DateTime.now();

    try {
      // Préfixer la ville pour améliorer les résultats sur des adresses
      // courtes ou informelles ("Rue 1200" → "Cotonou Rue 1200")
      final searchQuery = query.toLowerCase().contains(cityBias.toLowerCase())
          ? query
          : '$cityBias, $query';

      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q':            searchQuery,
        'format':       'json',
        'limit':        '1',
        'countrycodes': countryCode,
        'addressdetails': '0',
      });

      final response = await http.get(uri, headers: {
        // Header obligatoire selon CGU Nominatim : identifier l'app
        // avec une adresse de contact valide.
        'User-Agent': 'FlashGo-Delivery-App/1.0 (contact@flashgo.bj)',
        'Accept-Language': 'fr',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final List<dynamic> results = jsonDecode(response.body);
      if (results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final lat   = double.tryParse(first['lat'] as String? ?? '');
      final lng   = double.tryParse(first['lon'] as String? ?? '');

      if (lat == null || lng == null) return null;

      final result = GeocodingResult(
        lat:         lat,
        lng:         lng,
        displayName: first['display_name'] as String? ?? query,
      );

      // Mettre en cache
      _cache[cacheKey] = result;
      return result;

    } on TimeoutException {
      return null; // Timeout → l'UI invite à réessayer
    } catch (_) {
      return null;
    }
  }

  /// Vide le cache (à appeler si l'utilisateur change de ville/contexte).
  static void clearCache() => _cache.clear();
}
