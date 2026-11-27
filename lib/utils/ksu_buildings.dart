import 'package:flutter/material.dart';

/// A Kyungsung University campus building with its lat/lng.
///
/// Positions are APPROXIMATE (typically within ~100 m): the relative layout was
/// read off the illustrated campus map at
/// https://kscms.ks.ac.kr/eng/CMS/CampusMgr/list.do?mCode=MN043 and the whole
/// set was then placed on the real campus (Google Maps place pin for
/// "Kyungsung University": 35.1397716, 129.0984966).
///
/// Surveyed positions override these numbers without touching Dart code:
/// run `node tool/fetch-osm-buildings.mjs`, then
/// `node tool/apply-osm-buildings.mjs`; the result is stored in
/// `assets/data/building_positions.json` and loaded by [BuildingPositions].
class KsuBuilding {
  const KsuBuilding({
    required this.number,
    required this.name,
    required double latitude,
    required double longitude,
    required this.category,
    this.description = '',
  }) : _latitude = latitude,
       _longitude = longitude;

  /// Building number from the official campus map. Some buildings share a
  /// number with different sub-names (e.g. Bldg. No.27 = Library + Gymnasium +
  /// Parking Lot + Natural Sciences Annex).
  final int number;

  /// Display name (English, from the official site).
  final String name;

  final double _latitude;
  final double _longitude;

  /// Latitude (WGS84) - a surveyed override if one is installed.
  double get latitude => BuildingPositions.of(this)?.$1 ?? _latitude;

  /// Longitude (WGS84) - a surveyed override if one is installed.
  double get longitude => BuildingPositions.of(this)?.$2 ?? _longitude;

  /// The coordinates compiled into the app (before any override).
  double get builtInLatitude => _latitude;
  double get builtInLongitude => _longitude;

  /// What the building is for, in one or two plain sentences.
  final String description;

  /// Functional category - used for icon/colour theming on the map.
  final String category;

  /// Category enum for switch.
  KsuBuildingCategory get categoryEnum =>
      KsuBuildingCategoryX.fromValue(category);

  /// "No. 12" - the number as printed on the campus map.
  String get numberLabel => 'No. $number';

  /// First non-empty word of [name], used as the marker label when space is tight.
  String get shortName {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? '?' : parts.first;
  }
}

/// Building position overrides (see [KsuBuilding]), in two layers:
///
/// 1. **Surveyed** - `assets/data/building_positions.json`, bundled with the
///    app ([apply]).
/// 2. **Admin** - corrections made in the in-app admin panel and stored in
///    Firestore at `config/buildings` ([applyAdmin]). These win over layer 1.
///
/// [revision] ticks whenever either layer changes, so map screens can redraw.
class BuildingPositions {
  BuildingPositions._();

  static final Map<String, (double, double)> _surveyed = {};
  static final Map<String, (double, double)> _admin = {};

  /// Bumped on every change; listen to it to redraw markers.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// The override for [b], or null when the built-in value applies.
  static (double, double)? of(KsuBuilding b) =>
      _admin[b.name] ?? _surveyed[b.name];

  /// True when an admin has moved [b] away from its default position.
  static bool isAdminSet(KsuBuilding b) => _admin.containsKey(b.name);

  /// The admin-set positions only (what is stored in Firestore).
  static Map<String, (double, double)> get adminPositions =>
      Map.unmodifiable(_admin);

  static int get count => {..._surveyed.keys, ..._admin.keys}.length;

  /// Replace the surveyed layer. Entries with out-of-range numbers are ignored.
  /// Input shape: `{"positions": {"Building name": [lat, lng]}}`.
  static void apply(Map<String, dynamic> json) {
    _parseInto(_surveyed, json['positions']);
    revision.value++;
  }

  /// Replace the admin layer (same input shape as [apply]).
  static void applyAdmin(Map<String, dynamic>? json) {
    _parseInto(_admin, json?['positions']);
    revision.value++;
  }

  static void _parseInto(Map<String, (double, double)> target, Object? raw) {
    target.clear();
    if (raw is! Map) return;
    raw.forEach((key, value) {
      if (key is! String || value is! List || value.length < 2) return;
      final lat = value[0];
      final lng = value[1];
      if (lat is! num || lng is! num) return;
      if (!isValid(lat.toDouble(), lng.toDouble())) return;
      target[key] = (lat.toDouble(), lng.toDouble());
    });
  }

  static bool isValid(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  static void clear() {
    _surveyed.clear();
    _admin.clear();
    revision.value++;
  }
}

enum KsuBuildingCategory {
  academic,
  library,
  student,
  dormitory,
  athletic,
  arts,
  service,
  entrance,
}

extension KsuBuildingCategoryX on KsuBuildingCategory {
  String get value {
    switch (this) {
      case KsuBuildingCategory.academic:
        return 'academic';
      case KsuBuildingCategory.library:
        return 'library';
      case KsuBuildingCategory.student:
        return 'student';
      case KsuBuildingCategory.dormitory:
        return 'dormitory';
      case KsuBuildingCategory.athletic:
        return 'athletic';
      case KsuBuildingCategory.arts:
        return 'arts';
      case KsuBuildingCategory.service:
        return 'service';
      case KsuBuildingCategory.entrance:
        return 'entrance';
    }
  }

  String get label {
    switch (this) {
      case KsuBuildingCategory.academic:
        return 'Academic';
      case KsuBuildingCategory.library:
        return 'Library';
      case KsuBuildingCategory.student:
        return 'Student Union';
      case KsuBuildingCategory.dormitory:
        return 'Dormitory';
      case KsuBuildingCategory.athletic:
        return 'Athletic';
      case KsuBuildingCategory.arts:
        return 'Arts';
      case KsuBuildingCategory.service:
        return 'Service';
      case KsuBuildingCategory.entrance:
        return 'Entrance';
    }
  }

  Color get color {
    switch (this) {
      case KsuBuildingCategory.academic:
        return const Color(0xFF2B3F66);
      case KsuBuildingCategory.library:
        return const Color(0xFF9A6A2E);
      case KsuBuildingCategory.student:
        return const Color(0xFF2F7D5B);
      case KsuBuildingCategory.dormitory:
        return const Color(0xFF58606F);
      case KsuBuildingCategory.athletic:
        return const Color(0xFFB3402F);
      case KsuBuildingCategory.arts:
        return const Color(0xFF7A4E5B);
      case KsuBuildingCategory.service:
        return const Color(0xFF858B97);
      case KsuBuildingCategory.entrance:
        return const Color(0xFF111C33);
    }
  }

  IconData get icon {
    switch (this) {
      case KsuBuildingCategory.academic:
        return Icons.school_rounded;
      case KsuBuildingCategory.library:
        return Icons.local_library_rounded;
      case KsuBuildingCategory.student:
        return Icons.groups_rounded;
      case KsuBuildingCategory.dormitory:
        return Icons.apartment_rounded;
      case KsuBuildingCategory.athletic:
        return Icons.sports_basketball_rounded;
      case KsuBuildingCategory.arts:
        return Icons.theater_comedy_rounded;
      case KsuBuildingCategory.service:
        return Icons.local_parking_rounded;
      case KsuBuildingCategory.entrance:
        return Icons.door_front_door_rounded;
    }
  }

  static KsuBuildingCategory fromValue(String value) {
    switch (value) {
      case 'library':
        return KsuBuildingCategory.library;
      case 'student':
        return KsuBuildingCategory.student;
      case 'dormitory':
        return KsuBuildingCategory.dormitory;
      case 'athletic':
        return KsuBuildingCategory.athletic;
      case 'arts':
        return KsuBuildingCategory.arts;
      case 'service':
        return KsuBuildingCategory.service;
      case 'entrance':
        return KsuBuildingCategory.entrance;
      case 'academic':
      default:
        return KsuBuildingCategory.academic;
    }
  }
}

/// All 30 Kyungsung University campus buildings + entrances + athletic
/// facilities, with their computed lat/lng.
///
/// Source: https://kscms.ks.ac.kr/eng/CMS/CampusMgr/list.do?mCode=MN043
const List<KsuBuilding> ksuBuildings = [
  KsuBuilding(
    number: 1,
    name: 'Hansung Building',
    latitude: 35.138881,
    longitude: 129.096791,
    category: 'academic',
    description: 'Teaching building with lecture rooms and faculty offices.',
  ),
  KsuBuilding(
    number: 2,
    name: 'Natural Sciences Building',
    latitude: 35.139427,
    longitude: 129.098617,
    category: 'academic',
    description: 'Teaching and laboratory building for the natural sciences.',
  ),
  KsuBuilding(
    number: 3,
    name: 'Arts Building',
    latitude: 35.138871,
    longitude: 129.096048,
    category: 'arts',
    description: 'Studios, practice rooms and teaching space for the arts programmes.',
  ),
  KsuBuilding(
    number: 3,
    name: 'Concert Hall',
    latitude: 35.138411,
    longitude: 129.096037,
    category: 'arts',
    description: 'Performance hall used for concerts and campus events.',
  ),
  KsuBuilding(
    number: 4,
    name: 'Commerce Building',
    latitude: 35.140069,
    longitude: 129.095647,
    category: 'academic',
    description: 'Teaching building for the business and commerce programmes.',
  ),
  KsuBuilding(
    number: 5,
    name: 'Social Sciences Building',
    latitude: 35.140727,
    longitude: 129.097660,
    category: 'academic',
    description: 'Teaching building for the social science programmes.',
  ),
  KsuBuilding(
    number: 6,
    name: 'Humanities Building',
    latitude: 35.141195,
    longitude: 129.100509,
    category: 'academic',
    description: 'Teaching building for the humanities programmes.',
  ),
  KsuBuilding(
    number: 7,
    name: 'Engineering Building I',
    latitude: 35.142071,
    longitude: 129.100751,
    category: 'academic',
    description: 'Teaching and laboratory building for the engineering programmes.',
  ),
  KsuBuilding(
    number: 8,
    name: 'Engineering Building II',
    latitude: 35.142279,
    longitude: 129.100195,
    category: 'academic',
    description: 'Teaching and laboratory building for the engineering programmes.',
  ),
  KsuBuilding(
    number: 9,
    name: 'Pharmacy & Sciences Building',
    latitude: 35.141979,
    longitude: 129.100399,
    category: 'academic',
    description: 'Teaching and laboratory building for the pharmacy and science programmes.',
  ),
  KsuBuilding(
    number: 10,
    name: 'Industry-University Cooperation Building',
    latitude: 35.140479,
    longitude: 129.095845,
    category: 'academic',
    description: 'Offices and meeting rooms for industry-university cooperation and research projects.',
  ),
  KsuBuilding(
    number: 11,
    name: 'Nightingale Building',
    latitude: 35.140684,
    longitude: 129.095988,
    category: 'academic',
    description: 'Teaching building for the nursing programmes.',
  ),
  KsuBuilding(
    number: 12,
    name: 'Multimedia Building',
    latitude: 35.140085,
    longitude: 129.097588,
    category: 'academic',
    description: 'Teaching and studio space for the media programmes.',
  ),
  KsuBuilding(
    number: 22,
    name: 'Culture Building',
    latitude: 35.139626,
    longitude: 129.097413,
    category: 'academic',
    description: 'Multi-purpose building for cultural activities and student groups.',
  ),
  KsuBuilding(
    number: 23,
    name: 'Student Union Building I',
    latitude: 35.137710,
    longitude: 129.098496,
    category: 'student',
    description: 'Student centre with dining, shops and student services.',
  ),
  KsuBuilding(
    number: 24,
    name: 'Student Union Building II',
    latitude: 35.137479,
    longitude: 129.097643,
    category: 'student',
    description: 'Student centre with dining, shops and student services.',
  ),
  KsuBuilding(
    number: 25,
    name: 'ROTC Building',
    latitude: 35.139523,
    longitude: 129.099134,
    category: 'academic',
    description: 'Building used by the ROTC programme.',
  ),
  KsuBuilding(
    number: 26,
    name: 'Multimedia Information Building',
    latitude: 35.139071,
    longitude: 129.097588,
    category: 'academic',
    description: 'Information and computing services building.',
  ),
  KsuBuilding(
    number: 27,
    name: 'Central Library Building',
    latitude: 35.138248,
    longitude: 129.099623,
    category: 'library',
    description: 'The university library, with reading rooms and study areas. Laptops, phones and notebooks are the items most often left behind in places like this.',
  ),
  KsuBuilding(
    number: 27,
    name: 'Natural Sciences Building Annex',
    latitude: 35.137788,
    longitude: 129.100047,
    category: 'academic',
    description: 'Annex of the Natural Sciences Building.',
  ),
  KsuBuilding(
    number: 28,
    name: 'Nuri International Dormitory I',
    latitude: 35.140979,
    longitude: 129.096285,
    category: 'dormitory',
    description: 'Residence hall for students, including international students.',
  ),
  KsuBuilding(
    number: 29,
    name: 'Nuri International Dormitory II',
    latitude: 35.140996,
    longitude: 129.096747,
    category: 'dormitory',
    description: 'Residence hall for students, including international students.',
  ),
  KsuBuilding(
    number: 30,
    name: 'THE GENESIS',
    latitude: 35.140303,
    longitude: 129.099596,
    category: 'academic',
    description: 'Academic building.',
  ),
  KsuBuilding(
    number: 27,
    name: 'Gymnasium',
    latitude: 35.138612,
    longitude: 129.100074,
    category: 'athletic',
    description: 'Indoor sports hall. Water bottles, clothing and earphones are the items most often left behind in sports facilities.',
  ),
  KsuBuilding(
    number: 27,
    name: 'Parking Lot',
    latitude: 35.138967,
    longitude: 129.100003,
    category: 'service',
    description: 'Vehicle parking area.',
  ),
  KsuBuilding(
    number: 28,
    name: 'Tennis Court',
    latitude: 35.142279,
    longitude: 129.101114,
    category: 'athletic',
    description: 'Outdoor tennis courts.',
  ),
  KsuBuilding(
    number: 29,
    name: 'Grand Stadium',
    latitude: 35.141629,
    longitude: 129.100008,
    category: 'athletic',
    description: 'Main outdoor sports ground.',
  ),
  KsuBuilding(
    number: 30,
    name: 'Entrance',
    latitude: 35.136956,
    longitude: 129.100718,
    category: 'service',
    description: 'Campus entrance.',
  ),
  KsuBuilding(
    number: 31,
    name: 'Front Gate',
    latitude: 35.136999,
    longitude: 129.097011,
    category: 'entrance',
    description: 'Main entrance of the campus.',
  ),
  KsuBuilding(
    number: 32,
    name: 'East Gate',
    latitude: 35.140814,
    longitude: 129.101328,
    category: 'entrance',
    description: 'East entrance of the campus.',
  ),
];

/// Look up a Kyungsung building by case-insensitive name match.
/// Returns null if not found.
KsuBuilding? findKsuBuildingByName(String name) {
  final q = name.trim().toLowerCase();
  if (q.isEmpty) return null;
  for (final b in ksuBuildings) {
    if (b.name.toLowerCase() == q) return b;
  }
  // Fuzzy fallback: building whose name starts with the query or vice versa.
  for (final b in ksuBuildings) {
    if (b.name.toLowerCase().startsWith(q) ||
        q.startsWith(b.name.toLowerCase())) {
      return b;
    }
  }
  return null;
}

/// Filter Kyungsung buildings by category (used by the map's category filter chips).
List<KsuBuilding> ksuBuildingsByCategory(KsuBuildingCategory category) {
  return ksuBuildings.where((b) => b.categoryEnum == category).toList();
}

/// Search Kyungsung buildings by free-text query: name, number ("27", "no 27",
/// "bldg 27") or category label.
List<KsuBuilding> searchKsuBuildings(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return ksuBuildings;
  final digits = RegExp(r'\d+').firstMatch(q)?.group(0);
  return ksuBuildings.where((b) {
    if (b.name.toLowerCase().contains(q)) return true;
    if (b.categoryEnum.label.toLowerCase().contains(q)) return true;
    if (digits != null && q.replaceAll(RegExp(r'[^a-z0-9]'), '').endsWith(digits)) {
      return b.number.toString() == digits;
    }
    return false;
  }).toList();
}
