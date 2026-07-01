// lib/services/location_service.dart
// Gère l'envoi de la position GPS du livreur toutes les 100m

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import '../config/api_config.dart';

class LocationService {
  static double? _lastLat;
  static double? _lastLng;
  static const double _minDistance = 100; // mètres minimum entre deux envois

  // Référence au stream — indispensable pour pouvoir l'annuler dans stopTracking().
  // Avant ce correctif, le stream continuait à tourner même après déconnexion
  // du livreur, drainant la batterie et générant des appels API inutiles
  // (fuite mémoire + fuite réseau).
  static StreamSubscription<Position>? _positionSub;

  static Future<void> startTracking(String driverId) async {
    // Annuler un éventuel tracking précédent avant d'en démarrer un nouveau
    await _positionSub?.cancel();
    _positionSub = null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((Position position) async {
      // Filtre distance : n'envoie que si déplacement > 100m
      if (_lastLat != null && _lastLng != null) {
        final distance = Geolocator.distanceBetween(
          _lastLat!, _lastLng!,
          position.latitude, position.longitude,
        );
        if (distance < _minDistance) return;
      }

      // Note : driver_id retiré du body — le backend l'extrait maintenant
      // directement du token JWT (correction IDOR appliquée en Phase A).
      try {
        await ApiService.put(ApiConfig.locationsDriver, {
          'lat': position.latitude,
          'lng': position.longitude,
        });
        _lastLat = position.latitude;
        _lastLng = position.longitude;
      } catch (_) {
        // Silencieux si pas de connexion — l'OfflineSyncService prend le relais
      }
    });
  }

  static Future<void> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _lastLat     = null;
    _lastLng     = null;
  }
}