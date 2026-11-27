import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Routing service — fetches real road-following routes between two
/// coordinates using the free OSRM (Open Source Routing Machine) public
/// API.
///
/// The OSRM public server at `router.project-osrm.org` is rate-limited and
/// intended for testing/development. For production, you should host your
/// own OSRM instance or use a commercial routing API (Mapbox Directions,
/// Google Directions, HERE Routing).
///
/// URL format:
///   `https://router.project-osrm.org/route/v1/PROFILE/LNG1,LAT1;LNG2,LAT2?overview=full&geometries=geojson&steps=true`
///
/// Profile: 'foot' for walking, 'driving' for cars, 'cycling' for bikes.
///
/// Returns the route as a list of [LatLng] points (the polyline geometry)
/// plus the total distance (meters) and duration (seconds).
class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  static const _osrmBase = 'https://router.project-osrm.org/route/v1';

  /// Get a walking route from [origin] to [destination].
  ///
  /// Returns null if the request fails. Caller should fall back to a
  /// straight dashed line in that case.
  Future<RouteResult?> getWalkingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return _getRoute(origin: origin, destination: destination, profile: 'foot');
  }

  /// Get a driving route from [origin] to [destination].
  Future<RouteResult?> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    return _getRoute(
      origin: origin,
      destination: destination,
      profile: 'driving',
    );
  }

  Future<RouteResult?> _getRoute({
    required LatLng origin,
    required LatLng destination,
    required String profile,
  }) async {
    try {
      final url =
          '$_osrmBase/$profile/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson&steps=true';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final distance = (route['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (route['duration'] as num?)?.toDouble() ?? 0.0;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      if (geometry == null) return null;

      final coords = geometry['coordinates'] as List?;
      if (coords == null || coords.isEmpty) return null;

      // OSRM returns coordinates as [lng, lat] pairs — convert to LatLng.
      final points = <LatLng>[];
      for (final c in coords) {
        final pair = c as List;
        if (pair.length >= 2) {
          points.add(
            LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
          );
        }
      }

      // Extract step-by-step instructions (optional).
      final legs = route['legs'] as List?;
      final steps = <RouteStep>[];
      if (legs != null) {
        for (final leg in legs) {
          final legSteps = (leg as Map<String, dynamic>)['steps'] as List?;
          if (legSteps == null) continue;
          for (final s in legSteps) {
            final step = s as Map<String, dynamic>;
            final maneuver = step['maneuver'] as Map<String, dynamic>?;
            final stepName = step['name'] as String? ?? '';
            final stepDistance = (step['distance'] as num?)?.toDouble() ?? 0.0;
            final stepDuration = (step['duration'] as num?)?.toDouble() ?? 0.0;
            final type = maneuver?['type'] as String? ?? '';
            final modifier = maneuver?['modifier'] as String? ?? '';
            steps.add(
              RouteStep(
                instruction: _humanStepInstruction(type, modifier, stepName),
                distance: stepDistance,
                duration: stepDuration,
              ),
            );
          }
        }
      }

      return RouteResult(
        points: points,
        distance: distance,
        duration: duration,
        steps: steps,
      );
    } catch (e) {
      debugPrint('[routing] OSRM routing failed: $e');
      return null;
    }
  }

  /// Convert OSRM's maneuver type+modifier + road name into a human-readable
  /// instruction like "Turn right onto Suyeong-ro" or "Continue straight".
  String _humanStepInstruction(String type, String modifier, String name) {
    final direction = _modifierToText(modifier);
    final action = _typeToText(type);
    if (name.isEmpty) {
      return '$action$direction'.trim();
    }
    return '$action$direction onto $name'.trim();
  }

  String _typeToText(String type) {
    switch (type) {
      case 'turn':
        return 'Turn';
      case 'new name':
        return 'Continue';
      case 'depart':
        return 'Start';
      case 'arrive':
        return 'Arrive';
      case 'merge':
        return 'Merge';
      case 'on ramp':
        return 'Take the ramp';
      case 'off ramp':
        return 'Take the exit';
      case 'fork':
        return 'At the fork,';
      case 'end of road':
        return 'At the end of the road,';
      case 'continue':
        return 'Continue';
      case 'roundabout':
        return 'Enter the roundabout';
      case 'rotary':
        return 'Enter the rotary';
      case 'roundabout turn':
        return 'In the roundabout,';
      case 'notification':
        return '';
      case 'exit roundabout':
        return 'Exit the roundabout';
      case 'exit rotary':
        return 'Exit the rotary';
      default:
        return 'Go';
    }
  }

  String _modifierToText(String modifier) {
    switch (modifier) {
      case 'uturn':
        return ' to make a U-turn';
      case 'sharp right':
        return ' sharp right';
      case 'right':
        return ' right';
      case 'slight right':
        return ' slight right';
      case 'straight':
        return ' straight';
      case 'slight left':
        return ' slight left';
      case 'left':
        return ' left';
      case 'sharp left':
        return ' sharp left';
      default:
        return '';
    }
  }
}

/// Result of an OSRM routing request.
class RouteResult {
  RouteResult({
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
  });

  /// Polyline points (in lat/lng) — the road-following route.
  final List<LatLng> points;

  /// Total distance in meters.
  final double distance;

  /// Total duration in seconds (walking time).
  final double duration;

  /// Step-by-step instructions (e.g. "Turn right onto Suyeong-ro").
  final List<RouteStep> steps;

  /// Human-readable distance label, e.g. "850 m" or "1.2 km".
  String get distanceLabel {
    if (distance < 1000) return '${distance.round()} m';
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  /// Human-readable duration label, e.g. "5 min walk".
  String get durationLabel {
    final minutes = (duration / 60).round();
    if (minutes < 60) return '$minutes min walk';
    final hours = minutes ~/ 60;
    final remainingMin = minutes % 60;
    return '${hours}h ${remainingMin}min walk';
  }
}

class RouteStep {
  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
  });

  final String instruction;
  final double distance;
  final double duration;

  String get distanceLabel {
    if (distance < 1000) return '${distance.round()} m';
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }
}
