import '../models/item_model.dart';

/// What the person typed / tapped on the Search screen. Immutable; the screen
/// owns one and applies it to the shared feed locally.
class ItemFilter {
  const ItemFilter({
    this.query = '',
    this.status = 'all',
    this.category = 'all',
    this.building = '',
    this.onlyOpen = true,
  });

  final String query;

  /// `all`, `lost` or `found`.
  final String status;

  /// `all` or a category value.
  final String category;

  /// Building name ("" = anywhere).
  final String building;

  /// Hide reunited reports.
  final bool onlyOpen;

  bool get isActive =>
      query.trim().isNotEmpty ||
      status != 'all' ||
      category != 'all' ||
      building.isNotEmpty;

  ItemFilter copyWith({
    String? query,
    String? status,
    String? category,
    String? building,
    bool? onlyOpen,
  }) => ItemFilter(
    query: query ?? this.query,
    status: status ?? this.status,
    category: category ?? this.category,
    building: building ?? this.building,
    onlyOpen: onlyOpen ?? this.onlyOpen,
  );

  bool accepts(ItemModel i) {
    if (onlyOpen && i.reunited) return false;
    if (status != 'all' && i.status != status) return false;
    if (category != 'all' && i.category != category) return false;
    if (building.isNotEmpty &&
        i.location.toLowerCase() != building.toLowerCase() &&
        i.meetBuilding.toLowerCase() != building.toLowerCase()) {
      return false;
    }
    final q = query.trim();
    if (q.isEmpty) return true;
    // Every word must appear somewhere (so "black wallet" finds both words).
    return q
        .split(RegExp(r'\s+'))
        .every((word) => i.matchesQuery(word));
  }

  List<ItemModel> apply(Iterable<ItemModel> items) =>
      items.where(accepts).toList(growable: false);
}
