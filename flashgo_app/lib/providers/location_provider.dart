// lib/providers/location_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

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
        // Note : coordonnées à adapter selon le format PostGIS retourné
        return const LatLng(6.3703, 2.3912);
      });
});