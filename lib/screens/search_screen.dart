import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/items_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../utils/item_filter.dart';
import '../utils/ksu_buildings.dart';
import '../widgets/building_picker.dart';
import '../widgets/category_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/motion.dart';

/// Search tab.
///
/// The query and filters live in THIS screen only (an [ItemFilter] applied to
/// the shared, unfiltered feed). Nothing typed here changes what the Home tab
/// shows.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  ItemFilter _filter = const ItemFilter();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _set(ItemFilter f) => setState(() => _filter = f);

  void _reset() {
    _ctrl.clear();
    _focus.unfocus();
    _set(const ItemFilter());
  }

  Future<void> _pickBuilding() async {
    final choice = await showBuildingPicker(
      context,
      selected: _filter.building,
      title: 'Filter by building',
      allowCustom: false,
    );
    if (choice != null && mounted) {
      _set(_filter.copyWith(building: choice.label));
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<ItemsState>();
    final results = _filter.apply(feed.items);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'Search',
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onChanged: (v) => _set(_filter.copyWith(query: v)),
                onTapOutside: (_) => _focus.unfocus(),
                decoration: InputDecoration(
                  hintText: 'Item, colour, brand or place',
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  suffixIcon: _ctrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search text',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _ctrl.clear();
                            _set(_filter.copyWith(query: ''));
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _Segment(
                    label: 'All',
                    selected: _filter.status == 'all',
                    onTap: () => _set(_filter.copyWith(status: 'all')),
                  ),
                  const SizedBox(width: 8),
                  _Segment(
                    label: 'Lost',
                    selected: _filter.status == 'lost',
                    onTap: () => _set(_filter.copyWith(status: 'lost')),
                  ),
                  const SizedBox(width: 8),
                  _Segment(
                    label: 'Found',
                    selected: _filter.status == 'found',
                    onTap: () => _set(_filter.copyWith(status: 'found')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _BuildingFilterChip(
                    building: _filter.building,
                    onTap: _pickBuilding,
                    onClear: () => _set(_filter.copyWith(building: '')),
                  ),
                  const SizedBox(width: 8),
                  for (final c in AppConstants.categories) ...[
                    CategoryChip(
                      category: c,
                      selected: _filter.category == c.value,
                      onTap: () => _set(_filter.copyWith(category: c.value)),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      feed.isLoading && feed.items.isEmpty
                          ? 'Loading reports'
                          : results.length == 1
                          ? '1 report'
                          : '${results.length} reports',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                  if (_filter.isActive)
                    TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
            ),
            Expanded(
              child: StateSwitcher(
                child: _body(context, feed, results),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ItemsState feed, List<dynamic> results) {
    if (feed.isLoading && feed.items.isEmpty) {
      return const LoadingIndicator(key: ValueKey('loading'), label: 'Loading reports');
    }
    if (feed.error != null && feed.items.isEmpty) {
      return EmptyState(
        key: const ValueKey('error'),
        title: 'Could not load reports',
        subtitle: feed.error!,
        icon: Icons.cloud_off_rounded,
        ctaLabel: 'Try again',
        onCtaTap: feed.refresh,
      );
    }
    if (results.isEmpty) {
      return EmptyState(
        key: const ValueKey('empty'),
        title: _filter.isActive ? 'No reports match' : 'No reports yet',
        subtitle: _filter.isActive
            ? 'Try fewer words, another building or a different category.'
            : 'New reports from campus will show up here.',
        icon: _filter.isActive ? Icons.search_off_rounded : Icons.inbox_outlined,
        ctaLabel: _filter.isActive ? 'Reset filters' : null,
        onCtaTap: _filter.isActive ? _reset : null,
      );
    }
    final list = _filter.apply(feed.items);
    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: () async => context.read<ItemsState>().refresh(),
      child: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final item = list[i];
          return ItemCard(
            item: item,
            onTap: () => Navigator.of(
              context,
            ).pushNamed(AppConstants.routeItemDetail, arguments: item),
          );
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primarySurfaceOf(context)
                  : AppColors.cardOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.primaryOf(context)
                    : AppColors.borderOf(context),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: selected
                    ? AppColors.primaryOf(context)
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip that opens the building picker; shows the chosen building as
/// "No. 27  Name" with a small clear button.
class _BuildingFilterChip extends StatelessWidget {
  const _BuildingFilterChip({
    required this.building,
    required this.onTap,
    required this.onClear,
  });

  final String building;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final active = building.isNotEmpty;
    final b = active ? findKsuBuildingByName(building) : null;
    final text = !active
        ? 'Building'
        : b != null
        ? '${b.numberLabel}  ${b.name}'
        : building;
    return Pressable(
      onTap: onTap,
      semanticLabel: active ? 'Building filter: $text' : 'Filter by building',
      child: Container(
        constraints: const BoxConstraints(minHeight: 40, maxWidth: 260),
        padding: EdgeInsets.only(left: 12, right: active ? 4 : 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accentSurfaceOf(context)
              : AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppColors.accentOf(context)
                : AppColors.borderOf(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.apartment_rounded,
              size: 16,
              color: active
                  ? AppColors.accentOf(context)
                  : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.captionMedium.copyWith(
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
            if (active)
              IconButton(
                tooltip: 'Clear building',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}
