// lib/providers/location_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../utils/geo_parser.dart';

// Stream Riverpod — écoute la position d'un livreur en temps réel
final driverLocationProvider =
    StreamProvider.family<LatLng?, String>((ref, driverId) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('driver_locations')
      .stream(primaryKey: ['driver_id'])
      .eq('driver_id', driverId)
      .map((data) {
        if (data.isEmpty) return null;
        // Décodage du champ `geom` (type geography PostGIS),
        // renvoyé par Supabase Realtime au format EWKB hexadécimal.
        return parseGeographyPoint(data.first['geom']);
      });
});