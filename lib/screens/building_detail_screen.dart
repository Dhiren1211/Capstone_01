import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/item_model.dart';
import '../state/items_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../utils/ksu_buildings.dart';
import '../widgets/app_card.dart';
import '../widgets/item_card.dart';
import '../widgets/motion.dart';
import '../widgets/primary_button.dart';
import 'campus_vr_screen.dart';

/// Everything the app knows about one campus building: number, name, type,
/// description, position, other buildings with the same number and the open
/// lost / found reports that mention it.
class BuildingDetailScreen extends StatelessWidget {
  const BuildingDetailScreen({super.key, required this.building});

  final KsuBuilding building;

  bool _mentions(ItemModel i) =>
      !i.reunited &&
      (i.location.toLowerCase() == building.name.toLowerCase() ||
          i.meetBuilding.toLowerCase() == building.name.toLowerCase());

  Future<void> _directions(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${building.latitude},${building.longitude}'
      '&travelmode=walking',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No maps app or browser available.')),
      );
    }
  }

  void _report(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route, arguments: building.name);
  }

  void _pickReportKind(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report at ${building.name}',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textPrimaryOf(ctx),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'I lost something here',
                icon: Icons.search_off_rounded,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _report(context, AppConstants.routeReportLost);
                },
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'I found something here',
                icon: Icons.inventory_2_outlined,
                variant: PrimaryButtonVariant.outlined,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _report(context, AppConstants.routeReportFound);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = building.categoryEnum;
    final feed = context.watch<ItemsState>().items;
    final here = feed.where(_mentions).toList(growable: false);
    final siblings = ksuBuildings
        .where((b) => b.number == building.number && b.name != building.name)
        .toList(growable: false);
    final calibrated = BuildingPositions.of(building) != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(title: Text(building.numberLabel)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              FadeSlideIn(
                child: AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: cat.color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${building.number}',
                          style: AppTextStyles.h1.copyWith(
                            color: Colors.white,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              building.name,
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(cat.icon, size: 16, color: cat.color),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    cat.label,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondaryOf(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (building.description.isNotEmpty) ...[
                const _Title('About this building'),
                Text(
                  building.description,
                  style: AppTextStyles.body.copyWith(
                    height: 1.6,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ],
              const _Title('Details'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _Row(label: 'Building number', value: building.numberLabel),
                    _Row(label: 'Name', value: building.name),
                    _Row(label: 'Type', value: cat.label),
                    _Row(
                      label: 'Position',
                      value:
                          '${building.latitude.toStringAsFixed(6)}, '
                          '${building.longitude.toStringAsFixed(6)}',
                    ),
                    _Row(
                      label: 'Position source',
                      value: calibrated
                          ? 'Surveyed (OpenStreetMap)'
                          : 'Approximate, from the campus map',
                      last: true,
                    ),
                  ],
                ),
              ),
              if (siblings.isNotEmpty) ...[
                _Title('Also in building ${building.numberLabel}'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final s in siblings)
                        InkWell(
                          onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => BuildingDetailScreen(building: s),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  s.categoryEnum.icon,
                                  size: 20,
                                  color: s.categoryEnum.color,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    s.name,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimaryOf(context),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textTertiaryOf(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              _Title(
                here.isEmpty
                    ? 'Lost and found here'
                    : 'Lost and found here (${here.length})',
              ),
              if (here.isEmpty)
                Text(
                  'No open reports mention this building right now.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                )
              else
                for (final item in here.take(6)) ...[
                  ItemCard(
                    item: item,
                    onTap: () => Navigator.of(context).pushNamed(
                      AppConstants.routeItemDetail,
                      arguments: item,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 4),
              PrimaryButton(
                label: 'Campus VR tour',
                icon: Icons.vrpano_outlined,
                variant: PrimaryButtonVariant.outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CampusVrScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border(top: BorderSide(color: AppColors.borderOf(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Directions',
                  icon: Icons.directions_walk_rounded,
                  variant: PrimaryButtonVariant.outlined,
                  onPressed: () => _directions(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Report here',
                  icon: Icons.add_rounded,
                  onPressed: () => _pickReportKind(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        text,
        style: AppTextStyles.h3Bold.copyWith(
          color: AppColors.textPrimaryOf(context),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.dividerOf(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
