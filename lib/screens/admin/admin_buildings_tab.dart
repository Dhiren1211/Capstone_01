import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../services/admin_service.dart';
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/ksu_buildings.dart';
import '../../widgets/app_card.dart';
import 'admin_widgets.dart';

/// Every campus building with its current position. Tap one to move it.
class AdminBuildingsTab extends StatefulWidget {
  const AdminBuildingsTab({super.key});

  @override
  State<AdminBuildingsTab> createState() => _AdminBuildingsTabState();
}

class _AdminBuildingsTabState extends State<AdminBuildingsTab>
    with AutomaticKeepAliveClientMixin {
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<int>(
      valueListenable: BuildingPositions.revision,
      builder: (context, _, _) {
        final list = _query.isEmpty
            ? ksuBuildings
            : searchKsuBuildings(_query);
        final edited = ksuBuildings.where(BuildingPositions.isAdminSet).length;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: AdminSearchField(
                hint: 'Search building name or number',
                onChanged: (q) => setState(() => _query = q.trim()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                '$edited of ${ksuBuildings.length} buildings corrected by an '
                'admin. Changes reach every phone within seconds.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _BuildingRow(building: list[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BuildingRow extends StatelessWidget {
  const _BuildingRow({required this.building});
  final KsuBuilding building;

  @override
  Widget build(BuildContext context) {
    final edited = BuildingPositions.isAdminSet(building);
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdminBuildingEditorScreen(building: building),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySurfaceOf(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${building.number}',
              style: AppTextStyles.h3Bold.copyWith(
                color: AppColors.primaryOf(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  building.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${building.latitude.toStringAsFixed(6)}, '
                  '${building.longitude.toStringAsFixed(6)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (edited)
            AdminTag(
              label: 'Edited',
              icon: Icons.edit_location_alt_outlined,
              background: AppColors.primarySurfaceOf(context),
              foreground: AppColors.primaryOf(context),
            ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiaryOf(context),
          ),
        ],
      ),
    );
  }
}

/// Move one building: pan the map until the pin sits on the building (or
/// type the coordinates), then save.
class AdminBuildingEditorScreen extends StatefulWidget {
  const AdminBuildingEditorScreen({super.key, required this.building});
  final KsuBuilding building;

  @override
  State<AdminBuildingEditorScreen> createState() =>
      _AdminBuildingEditorScreenState();
}

class _AdminBuildingEditorScreenState extends State<AdminBuildingEditorScreen> {
  final _map = MapController();
  late LatLng _pos = LatLng(widget.building.latitude, widget.building.longitude);
  late final _latCtrl = TextEditingController(text: _fmt(_pos.latitude));
  late final _lngCtrl = TextEditingController(text: _fmt(_pos.longitude));
  bool _busy = false;

  KsuBuilding get b => widget.building;
  LatLng get _original => LatLng(b.latitude, b.longitude);
  LatLng get _builtIn => LatLng(b.builtInLatitude, b.builtInLongitude);
  bool get _changed =>
      (_pos.latitude - _original.latitude).abs() > 1e-7 ||
      (_pos.longitude - _original.longitude).abs() > 1e-7;

  static String _fmt(double v) => v.toStringAsFixed(6);

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    setState(() {
      _pos = camera.center;
      _latCtrl.text = _fmt(_pos.latitude);
      _lngCtrl.text = _fmt(_pos.longitude);
    });
  }

  void _onTyped() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null || !BuildingPositions.isValid(lat, lng)) {
      return;
    }
    setState(() {
      _pos = LatLng(lat, lng);
    });
    _map.move(_pos, _map.camera.zoom);
  }

  void _jumpTo(LatLng p) {
    setState(() {
      _pos = p;
      _latCtrl.text = _fmt(p.latitude);
      _lngCtrl.text = _fmt(p.longitude);
    });
    _map.move(p, _map.camera.zoom);
  }

  Future<void> _save() async {
    final uid = context.read<AuthState>().user?.id ?? '';
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final ok = await runAdminAction(
      context,
      () => AdminService.instance.setBuildingPosition(
        b,
        _pos.latitude,
        _pos.longitude,
        byUid: uid,
      ),
      success: '${b.name} moved',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) navigator.pop();
  }

  Future<void> _reset() async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Reset ${b.name}?',
      message:
          'The building goes back to the position that ships with the app.',
      confirmLabel: 'Reset',
    );
    if (!confirmed || !mounted) return;
    final uid = context.read<AuthState>().user?.id ?? '';
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final ok = await runAdminAction(
      context,
      () => AdminService.instance.resetBuildingPosition(b, byUid: uid),
      success: '${b.name} reset',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final adminSet = BuildingPositions.isAdminSet(b);
    final primary = AppColors.primaryOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundOf(context),
        title: Text('No. ${b.number} · ${b.name}', overflow: TextOverflow.ellipsis),
        actions: [
          if (adminSet)
            TextButton(
              onPressed: _busy ? null : _reset,
              child: const Text('Reset'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _pos,
                    initialZoom: 18.5,
                    minZoom: 15,
                    maxZoom: 20,
                    onPositionChanged: _onMapMoved,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.smartfind.smartfind',
                    ),
                    MarkerLayer(
                      markers: [
                        // Where the building was before this edit.
                        Marker(
                          point: _original,
                          width: 18,
                          height: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.textTertiaryOf(context)
                                  .withValues(alpha: 0.5),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                // Fixed pin in the middle: the map moves underneath it.
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.location_on_rounded, size: 48, color: primary),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.pan_tool_alt_outlined,
                            size: 18, color: AppColors.textSecondaryOf(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Drag the map so the pin sits on the building. '
                            'The grey dot is the current position.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: _coordField('Latitude', _latCtrl)),
                      const SizedBox(width: 10),
                      Expanded(child: _coordField('Longitude', _lngCtrl)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _jumpTo(_original),
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('Undo'),
                      ),
                      TextButton.icon(
                        onPressed: () => _jumpTo(_builtIn),
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Built-in spot'),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy || !_changed ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save position'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordField(String label, TextEditingController c) {
    return TextField(
      controller: c,
      onChanged: (_) => _onTyped(),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))],
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
