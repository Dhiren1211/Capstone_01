import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smartfind/utils/constants.dart';
import 'package:smartfind/utils/ksu_buildings.dart';

/// Guards against the original bug: the whole campus data set was ~4 km away
/// from the real campus, so GPS positions and map pins never agreed.
void main() {
  // Google Maps place pin for "Kyungsung University" (Suyeong-ro 309, Busan).
  const campusLat = 35.1397716;
  const campusLng = 129.0984966;

  double metersFromCampus(double lat, double lng) {
    final dLat = (lat - campusLat) * 110574;
    final dLng =
        (lng - campusLng) * 111320 * math.cos(campusLat * math.pi / 180);
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  test('map centre is on the real campus', () {
    final d = metersFromCampus(
      AppConstants.defaultMapCenterLat,
      AppConstants.defaultMapCenterLng,
    );
    expect(d, lessThan(300));
  });

  test('every building is within 600 m of the campus pin', () {
    for (final b in ksuBuildings) {
      expect(
        metersFromCampus(b.latitude, b.longitude),
        lessThan(600),
        reason: '${b.name} is too far from the campus',
      );
    }
  });

  test('every building is inside the campus and camera bounds', () {
    for (final b in ksuBuildings) {
      expect(
        b.latitude >= AppConstants.ksuCampusSouth &&
            b.latitude <= AppConstants.ksuCampusNorth,
        isTrue,
        reason: '${b.name}: latitude outside the campus box',
      );
      expect(
        b.longitude >= AppConstants.ksuCampusWest &&
            b.longitude <= AppConstants.ksuCampusEast,
        isTrue,
        reason: '${b.name}: longitude outside the campus box',
      );
    }
    expect(
      AppConstants.ksuCameraNorth,
      greaterThan(AppConstants.ksuCampusNorth),
    );
    expect(AppConstants.ksuCameraSouth, lessThan(AppConstants.ksuCampusSouth));
    expect(AppConstants.ksuCameraEast, greaterThan(AppConstants.ksuCampusEast));
    expect(AppConstants.ksuCameraWest, lessThan(AppConstants.ksuCampusWest));
  });

  test('every picker location has a building with coordinates', () {
    final names = ksuBuildings.map((b) => b.name).toSet();
    for (final n in AppConstants.defaultLocations) {
      expect(names, contains(n));
    }
  });
}
