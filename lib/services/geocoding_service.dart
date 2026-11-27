import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Reverse-geocoding service — converts (lat, lng) → readable address using
/// OpenStreetMap's free Nominatim API.
///
/// Usage:
///   final address = await GeocodingService.reverse(35.1398, 129.0985);
///   // → "309 Suyeong-ro, Nam-gu, Busan, Republic of Korea"
///
/// Nominatim usage policy:
///   - Max 1 request per second
///   - Must provide a valid User-Agent
///   - For production apps with high volume, use a commercial geocoding
///     service (Google Places, Mapbox, HERE).
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  static const _nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';

  /// Convert (lat, lng) → readable address.
  ///
  /// Returns null on failure. Returns a formatted address string like
  /// "309 Suyeong-ro, Nam-gu, Busan, Republic of Korea" on success.
  Future<String?> reverse(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(
        '$_nominatimUrl?lat=$latitude&lon=$longitude&format=json&accept-language=en&zoom=18',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent':
                  'smartFind/1.0.0 (Kyungsung University lost-and-found app)',
              'Accept-Language': 'en',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      if (address == null) {
        // Fallback to display_name if address object is missing.
        return data['display_name'] as String?;
      }

      // Build a readable address line: "<house_number> <road>, <suburb>,
      // <city>, <country>".
      final parts = <String>[];
      final houseNumber = address['house_number'] as String?;
      final road = address['road'] as String?;
      if (houseNumber != null && road != null) {
        parts.add('$houseNumber $road');
      } else if (road != null) {
        parts.add(road);
      } else if (address['building'] != null) {
        parts.add(address['building'] as String);
      }

      final suburb =
          address['suburb'] as String? ?? address['neighbourhood'] as String?;
      final cityDistrict = address['city_district'] as String?;
      final borough = address['borough'] as String?;
      final city =
          address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String?;
      final county = address['county'] as String?;
      final state = address['state'] as String?;
      final country = address['country'] as String?;
      final postcode = address['postcode'] as String?;

      // Add locality-level info.
      if (suburb != null) parts.add(suburb);
      if (cityDistrict != null && cityDistrict != suburb) {
        parts.add(cityDistrict);
      } else if (borough != null && borough != suburb) {
        parts.add(borough);
      }
      if (city != null) parts.add(city);
      if (county != null && county != city) parts.add(county);
      if (state != null) parts.add(state);
      if (postcode != null) parts.add(postcode);
      if (country != null) parts.add(country);

      if (parts.isEmpty) {
        return data['display_name'] as String?;
      }
      return parts.join(', ');
    } catch (e) {
      debugPrint('[geocoding] Reverse geocoding failed: $e');
      return null;
    }
  }

  /// Convenience: returns a short location label (e.g. "Nam-gu, Busan") for
  /// display in lists/cards where the full address is too long.
  Future<String?> reverseShort(double latitude, double longitude) async {
    final full = await reverse(latitude, longitude);
    if (full == null) return null;
    // Take the last 2-3 comma-separated parts (usually city, state, country).
    final parts = full.split(', ');
    if (parts.length <= 2) return full;
    return parts.sublist(parts.length - 3).join(', ');
  }
}
