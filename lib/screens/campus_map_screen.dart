import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../services/routing_service.dart';
import '../state/items_state.dart';
import '../state/settings_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../utils/ksu_buildings.dart';
import '../widgets/motion.dart';
import 'building_detail_screen.dart';
import 'item_detail_screen.dart';

/// Kyungsung University campus map screen — two distinct views.
///
/// Top of screen: two large action buttons (Campus + Items), styled as
/// distinct cards (not a segmented toggle).
///
/// - **Campus view**: shows all 30 KSU buildings as numbered pins
///   (color-coded by category). Tap a building → bottom sheet with details
///   + a "Navigate" button that opens Google/Apple Maps with turn-by-turn
///   directions from the user's current location.
///
/// - **Items view**: shows all reported lost/found items as status-colored
///   pins at their reported lat/lng. Tap an item pin → bottom sheet with
///   item details + Navigate button.
///
/// Real GPS: the user's current location is fetched via geolocator on
/// screen entry and re-fetched on tap of the "locate me" button. The
/// marker is a pulsing blue dot with a "You are here" label.
class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

enum _MapView { campus, items }

class _CampusMapScreenState extends State<CampusMapScreen> {
  late final MapController _mapController;
  _MapView _view = _MapView.campus;
  String _searchQuery = '';

  KsuBuilding? _selectedBuilding;
  ItemModel? _selectedItem;

  LatLng? _userLocation;
  bool _isLocating = false;

  // In-app navigation state — when set, a polyline is drawn on the map
  // following the OSRM-computed route.
  List<LatLng>? _routePoints;
  double? _routeDistance;
  double? _routeDuration;
  List<RouteStep>? _routeSteps;
  bool _isRouting = false;
  String? _routingError;

  // Real-time position tracking — used during navigation mode to follow
  // the user as they walk along the route.
  StreamSubscription<Position>? _positionStreamSub;
  bool _isNavigating = false; // true when actively following the route
  int _currentStepIndex = 0; // index into _routeSteps for the active step

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Redraw when an admin moves a building.
    BuildingPositions.revision.addListener(_onBuildingsMoved);
    // Fetch the user's real GPS location on screen entry.
    _fetchUserLocation();
  }

  void _onBuildingsMoved() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    BuildingPositions.revision.removeListener(_onBuildingsMoved);
    _positionStreamSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Start a background stream of the user's GPS position (every 5s or
  /// every 5m, whichever comes first). Used during navigation mode so the
  /// user marker follows them as they walk.
  void _startPositionStream() {
    _positionStreamSub?.cancel();
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // update every 5 meters
    );
    _positionStreamSub =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position pos) {
            if (!mounted) return;
            setState(() {
              _userLocation = LatLng(pos.latitude, pos.longitude);
            });
            // If we're actively navigating, advance the step index based on
            // the user's proximity to step endpoints.
            if (_isNavigating && _routeSteps != null) {
              _advanceStepIfNeeded();
            }
          },
          onError: (Object e) {
            debugPrint('[map] position stream error: $e');
          },
        );
  }

  /// Stop the position stream (when navigation ends or screen disposes).
  void _stopPositionStream() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
  }

  /// Check if the user is close to the end of the current step's segment,
  /// and advance the step index if so.
  void _advanceStepIfNeeded() {
    if (_routeSteps == null || _routeSteps!.isEmpty) return;
    if (_userLocation == null) return;

    // For now, just keep _currentStepIndex clamped to the last step. A
    // full implementation would track which polyline segment the user is
    // on and advance when they pass the segment endpoint.
    if (_currentStepIndex < _routeSteps!.length - 1) {
      // Heuristic: if we're within 15m of the destination, mark last step.
      final distToDest = _haversineMeters(_userLocation!, _routePoints!.last);
      if (distToDest < 15) {
        setState(() => _currentStepIndex = _routeSteps!.length - 1);
      }
    }
  }

  /// The campus centre, used whenever the real GPS position is unavailable.
  static const LatLng _campusCenter = LatLng(
    AppConstants.defaultMapCenterLat,
    AppConstants.defaultMapCenterLng,
  );

  Future<void> _fetchUserLocation() async {
    setState(() => _isLocating = true);
    LatLng? located;
    try {
      located = await _readGps();
    } catch (e) {
      debugPrint('[map] could not read GPS: $e');
    }
    if (!mounted) return;
    setState(() {
      // Fall back to the campus centre if GPS is off, denied or failed.
      _userLocation = located ?? _campusCenter;
      _isLocating = false;
    });
  }

  /// Returns the current GPS position, or null when location services are
  /// switched off (device or app settings) or the permission is denied.
  Future<LatLng?> _readGps() async {
    if (!SettingsStore.instance.locationEnabled) return null;
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 20));
    return LatLng(pos.latitude, pos.longitude);
  }

  /// Snap the camera to the user's current location.
  void _goToMyLocation() {
    if (_userLocation == null) return;
    _mapController.move(
      _userLocation!,
      (AppConstants.defaultMapZoom + 1).clamp(
        AppConstants.ksuCameraMinZoom,
        AppConstants.ksuCameraMaxZoom,
      ),
    );
  }

  /// Start in-app navigation from the user's current location to [destination].
  ///
  /// Uses OSRM's public routing API to compute a real road-following walking
  /// route, then draws it as a solid blue polyline on the map. Shows distance
  /// + walking duration + step-by-step instructions in the bottom sheet.
  /// Starts a real-time position stream so the user marker follows them as
  /// they walk.
  ///
  /// If the OSRM request fails, falls back to a straight dashed line.
  Future<void> _startInAppNavigation(LatLng destination) async {
    final origin = _userLocation ?? _campusCenter;

    setState(() {
      _isRouting = true;
      _routingError = null;
      _routePoints = null;
      _routeDistance = null;
      _routeDuration = null;
      _routeSteps = null;
      _isNavigating = false;
      _currentStepIndex = 0;
    });

    final route = await RoutingService.instance.getWalkingRoute(
      origin: origin,
      destination: destination,
    );

    if (!mounted) return;

    if (route == null) {
      // Fallback: straight dashed line.
      final straight = _haversineMeters(origin, destination);
      setState(() {
        _isRouting = false;
        _routingError =
            'Could not fetch a road-following route. '
            'Showing straight-line distance.';
        _routePoints = [origin, destination];
        _routeDistance = straight;
        _routeDuration = straight / 1.4; // assume 1.4 m/s walking speed
        _routeSteps = null;
      });
      return;
    }

    setState(() {
      _isRouting = false;
      _routePoints = route.points;
      _routeDistance = route.distance;
      _routeDuration = route.duration;
      _routeSteps = route.steps;
      _currentStepIndex = 0;
      _isNavigating = true;
    });

    // Start the real-time position stream so the user marker follows them.
    _startPositionStream();

    // Fit the camera to the route bounds.
    final bounds = LatLngBounds.fromPoints(route.points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
        maxZoom: AppConstants.ksuCameraMaxZoom,
      ),
    );
  }

  /// Stop in-app navigation — clears the route polyline + stops the
  /// position stream.
  void _stopNavigation() {
    _stopPositionStream();
    setState(() {
      _routePoints = null;
      _routeDistance = null;
      _routeDuration = null;
      _routeSteps = null;
      _routingError = null;
      _isNavigating = false;
      _currentStepIndex = 0;
    });
  }

  /// Haversine distance between two points, in meters. Used as a fallback
  /// when OSRM fails.
  double _haversineMeters(LatLng p1, LatLng p2) {
    const r = 6371000.0;
    final dLat = _toRad(p2.latitude - p1.latitude);
    final dLng = _toRad(p2.longitude - p1.longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(p1.latitude)) *
            math.cos(_toRad(p2.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * (math.pi / 180.0);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ItemsState>();
    final items = state.openItems;

    final filteredBuildings = _searchQuery.isEmpty
        ? ksuBuildings
        : searchKsuBuildings(_searchQuery);
    final filteredItems = items
        .where((i) => _searchQuery.isEmpty || i.matchesQuery(_searchQuery))
        .toList();

    final itemsByBuilding = <String, List<ItemModel>>{};
    for (final item in items) {
      final b = findKsuBuildingByName(item.location);
      if (b != null) {
        itemsByBuilding.putIfAbsent(b.name, () => []).add(item);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header — search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceXl,
                AppConstants.spaceLg,
                AppConstants.spaceXl,
                AppConstants.spaceMd,
              ),
              child: _SearchBar(
                query: _searchQuery,
                onChanged: (q) => setState(() {
                  _searchQuery = q;
                  _selectedBuilding = null;
                  _selectedItem = null;
                }),
              ),
            ),
            // Two distinct action buttons (Campus + Items)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceXl,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.school_rounded,
                      label: 'Buildings',
                      subtitle: 'Numbered campus map',
                      selected: _view == _MapView.campus,
                      onTap: () => setState(() {
                        _view = _MapView.campus;
                        _selectedBuilding = null;
                        _selectedItem = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceMd),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.inventory_2_rounded,
                      label: 'Reports',
                      subtitle: 'Lost and found',
                      selected: _view == _MapView.items,
                      onTap: () => setState(() {
                        _view = _MapView.items;
                        _selectedBuilding = null;
                        _selectedItem = null;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spaceMd),
            // Map
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(
                          AppConstants.defaultMapCenterLat,
                          AppConstants.defaultMapCenterLng,
                        ),
                        initialZoom: AppConstants.defaultMapZoom,
                        minZoom: AppConstants.ksuCameraMinZoom,
                        maxZoom: AppConstants.ksuCameraMaxZoom,
                        // The camera cannot pan outside the campus area.
                        cameraConstraint: CameraConstraint.contain(
                          bounds: LatLngBounds(
                            const LatLng(
                              AppConstants.ksuCameraSouth,
                              AppConstants.ksuCameraWest,
                            ),
                            const LatLng(
                              AppConstants.ksuCameraNorth,
                              AppConstants.ksuCameraEast,
                            ),
                          ),
                        ),
                        onTap: (_, _) => setState(() {
                          _selectedBuilding = null;
                          _selectedItem = null;
                        }),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.smartfind.smartfind',
                        ),
                        // In-app navigation polyline (real OSRM route).
                        // Solid blue line — when the user taps "Navigate" on
                        // a building/item, OSRM computes a road-following
                        // walking route and we draw it here.
                        if (_routePoints != null && _routePoints!.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints!,
                                color: AppColors.primaryOf(context),
                                strokeWidth: 6,
                                pattern: _routingError != null
                                    ? StrokePattern.dashed(
                                        segments: const [10, 8],
                                      )
                                    : const StrokePattern.solid(),
                              ),
                            ],
                          ),
                        if (_view == _MapView.campus)
                          MarkerLayer(
                            markers: filteredBuildings
                                .map((b) => _buildBuildingMarker(b))
                                .toList(),
                          ),
                        if (_view == _MapView.items)
                          MarkerLayer(
                            markers: filteredItems
                                .map((i) => _buildItemMarker(i))
                                .toList(),
                          ),
                        // User location marker — always visible
                        if (_userLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _userLocation!,
                                width: 80,
                                height: 80,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: const BoxDecoration(
                                        color: AppColors.mapUserRing,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: AppColors.mapUserDot,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // "You are here" label above the dot
                              Marker(
                                point: _userLocation!,
                                width: 110,
                                height: 40,
                                alignment: Alignment.topCenter,
                                child: Transform.translate(
                                  offset: const Offset(0, -25),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.textPrimaryOf(context),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'You are here',
                                      style: AppTextStyles.captionMedium
                                          .copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Floating zoom + my-location controls
                  Positioned(
                    right: AppConstants.spaceLg,
                    bottom: _selectedBuilding != null || _selectedItem != null
                        ? 230
                        : AppConstants.spaceXl,
                    child: Column(
                      children: [
                        _MapButton(
                          icon: Icons.add_rounded,
                          onTap: () {
                            final z = _mapController.camera.zoom;
                            _mapController.move(
                              _mapController.camera.center,
                              (z + 1).clamp(
                                AppConstants.ksuCameraMinZoom,
                                AppConstants.ksuCameraMaxZoom,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: Icons.remove_rounded,
                          onTap: () {
                            final z = _mapController.camera.zoom;
                            _mapController.move(
                              _mapController.camera.center,
                              (z - 1).clamp(
                                AppConstants.ksuCameraMinZoom,
                                AppConstants.ksuCameraMaxZoom,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: Icons.my_location_rounded,
                          isLoading: _isLocating,
                          onTap: () {
                            _fetchUserLocation().then((_) => _goToMyLocation());
                          },
                        ),
                      ],
                    ),
                  ),
                  // Bottom sheet — campus view
                  if (_view == _MapView.campus && _selectedBuilding != null)
                    Positioned(
                      left: AppConstants.spaceLg,
                      right: AppConstants.spaceLg,
                      bottom: AppConstants.spaceLg,
                      child: _BoundedCard(child: _SelectedBuildingCard(
                        building: _selectedBuilding!,
                        itemsAtBuilding:
                            itemsByBuilding[_selectedBuilding!.name] ?? [],
                        onClose: () => setState(() {
                          _selectedBuilding = null;
                        }),
                        onNavigate: () => _startInAppNavigation(
                          LatLng(
                            _selectedBuilding!.latitude,
                            _selectedBuilding!.longitude,
                          ),
                        ),
                        onStopNavigation: _stopNavigation,
                        isRouting: _isRouting,
                        routingError: _routingError,
                        routeDistance: _routeDistance,
                        routeDuration: _routeDuration,
                        routeSteps: _routeSteps,
                        currentStepIndex: _currentStepIndex,
                        isNavigating: _isNavigating,
                        onDetails: () {
                          final b = _selectedBuilding!;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BuildingDetailScreen(building: b),
                            ),
                          );
                        },
                        onItemTap: (item) {
                          setState(() => _selectedBuilding = null);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ItemDetailScreen(item: item),
                            ),
                          );
                        },
                      )),
                    ),
                  // Bottom sheet — items view
                  if (_view == _MapView.items && _selectedItem != null)
                    Positioned(
                      left: AppConstants.spaceLg,
                      right: AppConstants.spaceLg,
                      bottom: AppConstants.spaceLg,
                      child: _BoundedCard(child: _SelectedItemCard(
                        item: _selectedItem!,
                        onClose: () => setState(() {
                          _selectedItem = null;
                        }),
                        onNavigate: () => _startInAppNavigation(
                          LatLng(
                            _selectedItem!.latitude,
                            _selectedItem!.longitude,
                          ),
                        ),
                        onStopNavigation: _stopNavigation,
                        isRouting: _isRouting,
                        routingError: _routingError,
                        routeDistance: _routeDistance,
                        routeDuration: _routeDuration,
                        routeSteps: _routeSteps,
                        currentStepIndex: _currentStepIndex,
                        isNavigating: _isNavigating,
                        onOpen: () {
                          final item = _selectedItem!;
                          setState(() => _selectedItem = null);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ItemDetailScreen(item: item),
                            ),
                          );
                        },
                      )),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildBuildingMarker(KsuBuilding b) {
    final isSelected = _selectedBuilding?.name == b.name;
    final cat = b.categoryEnum;
    final color = cat.color;
    return Marker(
      point: LatLng(b.latitude, b.longitude),
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedBuilding = b);
          _mapController.move(
            LatLng(b.latitude, b.longitude),
            (_mapController.camera.zoom).clamp(
              AppConstants.ksuCameraMinZoom,
              AppConstants.ksuCameraMaxZoom,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          // Building number — large white bold
          child: Text(
            '${b.number}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildItemMarker(ItemModel item) {
    final isSelected = _selectedItem?.id == item.id;
    final color = item.status == 'lost' ? AppColors.errorFgOf(context) : AppColors.successFgOf(context);
    return Marker(
      point: LatLng(item.latitude, item.longitude),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => setState(() => _selectedItem = item),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            item.status == 'lost' ? Icons.help_rounded : Icons.check_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ============== Widgets ==============

/// Keeps the pop-up cards from growing taller than half the screen: if the
/// content (description, reports, route steps) is longer, the card scrolls.
class _BoundedCard extends StatelessWidget {
  const _BoundedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.query, required this.onChanged});
  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.query,
  );

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _ctrl.text) _ctrl.text = widget.query;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.primarySurfaceOf(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: AppColors.textTertiaryOf(context),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: 'Search buildings or items...',
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textTertiaryOf(context),
                ),
                // The pill above is the field; switch off the theme's own
                // fill and outlines so it does not draw a box inside a box.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: AppTextStyles.body,
            ),
          ),
          if (widget.query.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => widget.onChanged(''),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primaryOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $subtitle',
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primarySurfaceOf(context)
                : AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color: selected ? accent : AppColors.borderOf(context),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? accent : AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: AppColors.textPrimaryOf(context), size: 20),
        ),
      ),
    );
  }
}

class _SelectedBuildingCard extends StatelessWidget {
  const _SelectedBuildingCard({
    required this.building,
    required this.itemsAtBuilding,
    required this.onClose,
    required this.onNavigate,
    required this.onStopNavigation,
    required this.isRouting,
    required this.routingError,
    required this.routeDistance,
    required this.routeDuration,
    required this.routeSteps,
    required this.currentStepIndex,
    required this.isNavigating,
    required this.onItemTap,
    required this.onDetails,
  });

  final KsuBuilding building;
  final List<ItemModel> itemsAtBuilding;
  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final VoidCallback onStopNavigation;
  final bool isRouting;
  final String? routingError;
  final double? routeDistance;
  final double? routeDuration;
  final List<RouteStep>? routeSteps;
  final int currentStepIndex;
  final bool isNavigating;
  final void Function(ItemModel) onItemTap;

  /// Opens the full building page (number, description, reports, directions).
  final VoidCallback onDetails;

  /// True when an in-app route is currently shown.
  bool get hasRoute => routeDistance != null && routeDuration != null;

  @override
  Widget build(BuildContext context) {
    final cat = building.categoryEnum;
    return Material(
      color: AppColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceLg),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cat.color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${building.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building.name,
                        style: AppTextStyles.h3Bold.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bldg. No.${building.number} · ${cat.label}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spaceSm),
            // Building description (new in this round) — detailed info
            // about what the building houses.
            if (building.description.isNotEmpty) ...[
              Text(
                building.description,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondaryOf(context),
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppConstants.spaceMd),
            ],
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 4),
                Text(
                  '${building.latitude.toStringAsFixed(4)}, ${building.longitude.toStringAsFixed(4)}',
                  style: AppTextStyles.caption,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: itemsAtBuilding.isEmpty
                        ? AppColors.chipIdleOf(context)
                        : AppColors.primarySurfaceOf(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    itemsAtBuilding.isEmpty
                        ? 'No reports here'
                        : '${itemsAtBuilding.length} report${itemsAtBuilding.length == 1 ? '' : 's'}',
                    style: AppTextStyles.captionMedium.copyWith(
                      color: itemsAtBuilding.isEmpty
                          ? AppColors.textSecondaryOf(context)
                          : AppColors.primaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
            if (itemsAtBuilding.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spaceMd),
              Divider(height: 1, color: AppColors.borderOf(context)),
              const SizedBox(height: AppConstants.spaceSm),
              ...itemsAtBuilding
                  .take(3)
                  .map(
                    (item) =>
                        _ItemRow(item: item, onTap: () => onItemTap(item)),
                  ),
            ],
            const SizedBox(height: AppConstants.spaceMd),
            // Route info (distance + duration) — shown when an in-app route
            // has been computed.
            if (hasRoute) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceMd,
                  vertical: AppConstants.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurfaceOf(context),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_walk_rounded,
                      size: 18,
                      color: AppColors.primaryOf(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDistance(routeDistance!)} · ${_formatDuration(routeDuration!)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceSm),
            ],
            // Step-by-step navigation instructions
            if (isNavigating &&
                routeSteps != null &&
                routeSteps!.isNotEmpty) ...[
              _NavigationStepsPanel(
                steps: routeSteps!,
                currentIndex: currentStepIndex,
              ),
              const SizedBox(height: AppConstants.spaceSm),
            ],
            if (routingError != null) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.spaceSm),
                decoration: BoxDecoration(
                  color: AppColors.errorBgOf(context),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Text(
                  routingError!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.errorFgOf(context),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spaceSm),
            ],
            // View details + Navigate / Stop navigation
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppConstants.touchTarget,
                    child: OutlinedButton.icon(
                      onPressed: onDetails,
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: const Text('View details'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, AppConstants.touchTarget),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spaceSm),
                Expanded(
                  child: SizedBox(
                    height: AppConstants.touchTarget,
                    child: isRouting
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : hasRoute
                        ? OutlinedButton.icon(
                            onPressed: onStopNavigation,
                            icon: const Icon(Icons.stop_rounded, size: 18),
                            label: const Text('Stop'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, AppConstants.touchTarget),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              foregroundColor: AppColors.errorFgOf(context),
                              side: BorderSide(
                                color: AppColors.errorFgOf(context),
                                width: 1.4,
                              ),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: onNavigate,
                            icon: const Icon(Icons.navigation_rounded, size: 18),
                            label: const Text('Navigate'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, AppConstants.touchTarget),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Format a distance in meters as "850 m" or "1.2 km".
String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Format a duration in seconds as "5 min" or "1h 5min".
String _formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMin = minutes % 60;
  return '${hours}h ${remainingMin}min';
}

class _SelectedItemCard extends StatelessWidget {
  const _SelectedItemCard({
    required this.item,
    required this.onClose,
    required this.onNavigate,
    required this.onStopNavigation,
    required this.isRouting,
    required this.routingError,
    required this.routeDistance,
    required this.routeDuration,
    required this.routeSteps,
    required this.currentStepIndex,
    required this.isNavigating,
    required this.onOpen,
  });

  final ItemModel item;
  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final VoidCallback onStopNavigation;
  final bool isRouting;
  final String? routingError;
  final double? routeDistance;
  final double? routeDuration;
  final List<RouteStep>? routeSteps;
  final int currentStepIndex;
  final bool isNavigating;
  final VoidCallback onOpen;

  bool get hasRoute => routeDistance != null && routeDuration != null;

  @override
  Widget build(BuildContext context) {
    final color = item.status == 'lost' ? AppColors.errorFgOf(context) : AppColors.successFgOf(context);
    return Material(
      color: AppColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceLg),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.status == 'lost'
                        ? Icons.help_outline_rounded
                        : Icons.check_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppConstants.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTextStyles.h3Bold.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.statusEnum.label} at ${item.location}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spaceSm),
            Text(
              item.description,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondaryOf(context),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppConstants.spaceSm),
            // Route info — distance + walking duration
            if (hasRoute) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceMd,
                  vertical: AppConstants.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurfaceOf(context),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_walk_rounded,
                      size: 18,
                      color: AppColors.primaryOf(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDistance(routeDistance!)} · ${_formatDuration(routeDuration!)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceSm),
            ],
            // Step-by-step navigation instructions
            if (isNavigating &&
                routeSteps != null &&
                routeSteps!.isNotEmpty) ...[
              _NavigationStepsPanel(
                steps: routeSteps!,
                currentIndex: currentStepIndex,
              ),
              const SizedBox(height: AppConstants.spaceSm),
            ],
            if (routingError != null) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.spaceSm),
                decoration: BoxDecoration(
                  color: AppColors.errorBgOf(context),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Text(
                  routingError!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.errorFgOf(context),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spaceSm),
            ],
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppConstants.touchTarget,
                    child: isRouting
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : hasRoute
                        ? OutlinedButton.icon(
                            onPressed: onStopNavigation,
                            icon: const Icon(Icons.stop_rounded, size: 18),
                            label: const Text('Stop'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.errorFgOf(context),
                              side: BorderSide(
                                color: AppColors.errorFgOf(context),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd,
                                ),
                              ),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: onNavigate,
                            icon: const Icon(
                              Icons.navigation_rounded,
                              size: 18,
                            ),
                            label: const Text('Navigate'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryOf(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppConstants.spaceSm),
                SizedBox(
                  width: 100,
                  height: AppConstants.touchTarget,
                  child: OutlinedButton(
                    onPressed: onOpen,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryOf(context),
                      side: BorderSide(
                        color: AppColors.primaryOf(context),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                      ),
                    ),
                    child: const Text('View'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onTap});
  final ItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceOf(context),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceSm,
            vertical: AppConstants.spaceSm,
          ),
          child: Row(
            children: [
              Icon(
                item.status == 'lost'
                    ? Icons.help_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 20,
                color: item.status == 'lost'
                    ? AppColors.errorFgOf(context)
                    : AppColors.successFgOf(context),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: Text(
                  item.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiaryOf(context),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step-by-step navigation instructions panel — shown during active
/// navigation. The current step is highlighted in blue; upcoming steps
/// are grayed out. Max 3 visible steps at a time, scrollable.
class _NavigationStepsPanel extends StatelessWidget {
  const _NavigationStepsPanel({
    required this.steps,
    required this.currentIndex,
  });

  final List<RouteStep> steps;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceMd,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.primarySurfaceOf(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.navigation_rounded,
                  size: 16,
                  color: AppColors.primaryOf(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'Turn-by-turn directions',
                  style: AppTextStyles.captionMedium.copyWith(
                    color: AppColors.primaryOf(context),
                  ),
                ),
                const Spacer(),
                Text(
                  'Step ${currentIndex + 1} of ${steps.length}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: steps.length,
              itemBuilder: (context, i) {
                final step = steps[i];
                final isCurrent = i == currentIndex;
                final isPast = i < currentIndex;
                return _StepRow(
                  step: step,
                  isCurrent: isCurrent,
                  isPast: isPast,
                  stepNumber: i + 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isCurrent,
    required this.isPast,
    required this.stepNumber,
  });

  final RouteStep step;
  final bool isCurrent;
  final bool isPast;
  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? AppColors.primaryOf(context)
        : isPast
        ? AppColors.successFgOf(context)
        : AppColors.textSecondaryOf(context);
    final bgColor = isCurrent
        ? AppColors.primarySurfaceOf(context)
        : Colors.transparent;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMd,
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number / icon
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.primaryOf(context)
                  : isPast
                  ? AppColors.successFgOf(context)
                  : AppColors.chipIdleOf(context),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isPast
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // Step instruction
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction.isEmpty ? 'Continue' : step.instruction,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isCurrent ? AppColors.textPrimaryOf(context) : color,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (step.distance > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Continue for ${step.distanceLabel}',
                    style: AppTextStyles.caption.copyWith(
                      color: isCurrent
                          ? AppColors.textSecondaryOf(context)
                          : color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
