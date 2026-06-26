// lib/services/location_service.dart
// Gère l'envoi de la position GPS du livreur toutes les 100m

import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import '../config/api_config.dart';

class LocationService {
  static double? _lastLat;
  static double? _lastLng;
  static const double _minDistance = 100; // mètres minimum avant envoi

  static Future<void> startTracking(String driverId) async {
    // Vérifier les permissions GPS
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Écouter les changements de position
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((Position position) async {
      // Vérifier si on s'est déplacé de plus de 100m
      if (_lastLat != null && _lastLng != null) {
        final distance = Geolocator.distanceBetween(
          _lastLat!, _lastLng!,
          position.latitude, position.longitude,
        );
        if (distance < _minDistance) return;
      }

      // Envoyer la position à l'API
      try {
        await ApiService.put(ApiConfig.locationsDriver, {
          'driver_id': driverId,
          'lat':       position.latitude,
          'lng':       position.longitude,
        });

        _lastLat = position.latitude;
        _lastLng = position.longitude;
      } catch (e) {
        // Silencieux si pas de connexion
      }
    });
  }

  static void stopTracking() {
    _lastLat = null;
    _lastLng = null;
  }
}