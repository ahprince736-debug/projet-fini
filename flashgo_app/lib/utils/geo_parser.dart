// lib/utils/geo_parser.dart
// Décode le format EWKB (hexadécimal) renvoyé par Supabase Realtime
// pour les colonnes de type `geography`/`geometry` (PostGIS).
//
// Supabase Realtime ne convertit pas automatiquement ces colonnes en JSON
// lisible : il renvoie le binaire EWKB encodé en hexadécimal, par ex :
// "0101000020E6100000<8 octets longitude><8 octets latitude>"
//
// Format standard pour un POINT avec SRID 4326 (le défaut PostGIS) :
//   - 1 octet  : ordre des octets (01 = little-endian)
//   - 4 octets : type de géométrie + flag SRID (01000020 = Point + SRID)
//   - 4 octets : SRID (E6100000 = 4326 en little-endian)
//   - 8 octets : longitude (double, little-endian)
//   - 8 octets : latitude  (double, little-endian)
//
// Total : 9 octets d'en-tête (18 caractères hex) + 16 octets de coordonnées
// (32 caractères hex) = 50 caractères hex minimum.

import 'dart:typed_data';
import 'package:latlong2/latlong.dart';

const int _headerHexLength = 18; // 9 octets d'en-tête
const int _coordHexLength  = 32; // 16 octets (2 doubles)

/// Tente de décoder un point géographique depuis une valeur EWKB hexadécimale.
/// Retourne null si la valeur est absente, vide, ou dans un format inattendu
/// (plutôt que de planter — un flux temps réel ne doit jamais crasher l'UI).
LatLng? parseGeographyPoint(dynamic rawValue) {
  if (rawValue == null) return null;
  if (rawValue is! String) return null;

  final hex = rawValue.trim();
  if (hex.length < _headerHexLength + _coordHexLength) return null;

  try {
    final coordsHex = hex.substring(_headerHexLength);
    final lonHex = coordsHex.substring(0, 16);
    final latHex = coordsHex.substring(16, 32);

    final lon = _hexToDoubleLittleEndian(lonHex);
    final lat = _hexToDoubleLittleEndian(latHex);

    // Garde-fou : coordonnées GPS plausibles uniquement
    if (lat.isNaN || lon.isNaN) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;

    return LatLng(lat, lon);
  } catch (_) {
    // Format inattendu (ex: SRID différent, géométrie non-Point) —
    // on échoue silencieusement plutôt que de casser l'écran de suivi.
    return null;
  }
}

double _hexToDoubleLittleEndian(String hex8Bytes) {
  final bytes = Uint8List(8);
  for (int i = 0; i < 8; i++) {
    final byteHex = hex8Bytes.substring(i * 2, i * 2 + 2);
    bytes[i] = int.parse(byteHex, radix: 16);
  }
  return bytes.buffer.asByteData().getFloat64(0, Endian.little);
}
