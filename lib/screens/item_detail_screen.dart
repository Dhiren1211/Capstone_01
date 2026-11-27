import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/item_model.dart';
import '../services/firestore_service.dart';
import '../services/image_upload_service.dart';
import '../services/matching_service.dart';
import '../services/messaging_service.dart';
import '../state/auth_state.dart';
import '../state/items_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../utils/contact_method.dart';
import '../utils/formatters.dart';
import '../utils/ksu_buildings.dart';
import '../widgets/app_card.dart';
import '../widgets/info_banner.dart';
import '../widgets/item_card.dart';
import '../widgets/motion.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_badge.dart';
import '../widgets/user_avatar.dart';
import 'building_detail_screen.dart';
import 'chat_detail_screen.dart';

/// One report in full: photo, description, where it happened, where the
/// reporter can be found and which other reports look like it.
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.item});

  final ItemModel item;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  /// Local override after an action (reunited) until the feed catches up.
  ItemModel? _local;
  bool _closing = false;
  bool _saved = false;
  bool _busy = false;

  /// "Read more" state of the description.
  bool _expanded = false;

  List<ItemModel>? _feedSeen;
  List<ScoredMatch> _matches = const [];

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.error : null,
        ),
      );
  }

  Future<void> _loadSavedState() async {
    final user = context.read<AuthState>().user;
    if (user == null) return;
    try {
      final saved = await FirestoreService.instance.isSaved(
        user.id,
        widget.item.id,
      );
      if (mounted) setState(() => _saved = saved);
    } catch (e) {
      debugPrint('[item] could not read saved state: $e');
    }
  }

  ItemModel _current(List<ItemModel> feed) {
    final local = _local;
    if (local != null) return local;
    for (final i in feed) {
      if (i.id == widget.item.id) return i;
    }
    return widget.item;
  }

  void _refreshMatches(ItemModel item, List<ItemModel> feed) {
    if (identical(feed, _feedSeen)) return;
    _feedSeen = feed;
    _matches = item.reunited
        ? const []
        : MatchingService.instance.rank(
            item,
            feed,
            minScore: MatchingService.matchThreshold,
            limit: 5,
          );
  }

  Future<void> _toggleSaved() async {
    final user = context.read<AuthState>().user;
    if (user == null || _busy) return;
    final want = !_saved;
    setState(() {
      _saved = want;
      _busy = true;
    });
    try {
      if (want) {
        await FirestoreService.instance.saveItem(user.id, widget.item.id);
        _toast('Saved');
      } else {
        await FirestoreService.instance.unsaveItem(user.id, widget.item.id);
        _toast('Removed from saved');
      }
    } catch (e) {
      debugPrint('[item] save toggle failed: $e');
      if (mounted) setState(() => _saved = !want);
      _toast('Could not update saved items. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: destructive
                ? TextButton.styleFrom(
                    foregroundColor: AppColors.errorFgOf(ctx),
                  )
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _markReunited(ItemModel item) async {
    final go = await _confirm(
      title: 'Mark as reunited?',
      message:
          'This closes the report. It leaves the feed and is no longer '
          'compared with new reports.',
      action: 'Mark reunited',
    );
    if (!go) return;
    setState(() => _closing = true);
    try {
      await FirestoreService.instance.markReunited(item.id);
      if (!mounted) return;
      setState(() => _local = item.copyWith(status: 'reunited', reunited: true));
      _toast('Marked as reunited');
    } catch (e) {
      debugPrint('[item] markReunited failed: $e');
      _toast('Could not update the report. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _delete(ItemModel item) async {
    final go = await _confirm(
      title: 'Delete this report?',
      message: 'It is removed for everyone and cannot be restored.',
      action: 'Delete',
      destructive: true,
    );
    if (!go) return;
    try {
      await FirestoreService.instance.deleteItem(item);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (e) {
      debugPrint('[item] delete failed: $e');
      _toast('Could not delete the report. Try again.', error: true);
    }
  }

  Future<void> _message(ItemModel item) async {
    final user = context.read<AuthState>().user;
    if (user == null || _busy) return;
    setState(() => _busy = true);
    try {
      final chat = await MessagingService.instance.getOrCreateChat(
        currentUserId: user.id,
        currentUserDisplayName: user.displayName,
        otherUserId: item.reporterId,
        otherUserDisplayName: item.reporterName,
        itemId: item.id,
        itemTitle: item.title,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ChatDetailScreen(chat: chat)),
      );
    } catch (e) {
      debugPrint('[item] could not open chat: $e');
      _toast('Could not open the chat. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('$what copied');
  }

  void _share(ItemModel item) {
    final where = item.meetBuilding.isEmpty
        ? ''
        : '\nReporter can be found at: ${item.meetBuilding}'
              '${item.pickupLocation.isEmpty ? '' : ', ${item.pickupLocation}'}';
    SharePlus.instance.share(
      ShareParams(
        text:
            '${item.title} (${item.statusEnum.label})\n'
            'Location: ${item.location}$where\n\n'
            'Shared from smartFind',
      ),
    );
  }

  void _openPhoto(ItemModel item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewer(url: item.imageUrl, title: item.title),
      ),
    );
  }

  void _openBuilding(KsuBuilding b) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => BuildingDetailScreen(building: b)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<ItemsState>().items;
    final me = context.watch<AuthState>().user;
    final item = _current(feed);
    _refreshMatches(item, feed);
    final own = me?.id == item.reporterId;
    final placeBuilding = findKsuBuildingByName(item.location);
    final meetBuilding = findKsuBuildingByName(item.meetBuilding);
    final hasMeet =
        item.meetBuilding.isNotEmpty ||
        item.pickupLocation.isNotEmpty ||
        item.availabilitySchedule.isNotEmpty;
    final contact = contactMethodOf(item.preferredContactMethod);
    final first = item.reporterName.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: item.imageUrl.isEmpty ? 0 : 380,
            backgroundColor: AppColors.backgroundOf(context),
            leading: _AppBarCircle(
              child: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            actions: [
              _AppBarCircle(
                child: IconButton(
                  tooltip: _saved ? 'Remove from saved' : 'Save',
                  icon: Icon(
                    _saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                  onPressed: _toggleSaved,
                ),
              ),
              _AppBarCircle(
                child: IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: () => _share(item),
                ),
              ),
              if (own)
                _AppBarCircle(
                  child: PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (v) {
                      if (v == 'delete') _delete(item);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Delete report')),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: item.imageUrl.isEmpty
                ? null
                : FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    // Inset photo with large rounded corners and a soft shadow,
                    // floating on the page like a card.
                    background: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.paddingOf(context).top + 8,
                        16,
                        4,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: AppColors.softShadowOf(context),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: GestureDetector(
                      onTap: () => _openPhoto(item),
                      child: Semantics(
                        button: true,
                        label: 'Open photo',
                        child: CachedNetworkImage(
                          imageUrl: ImageUploadService.optimizedUrl(
                            item.imageUrl,
                            width: 1000,
                          ),
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              ColoredBox(color: AppColors.chipIdleOf(context)),
                          errorWidget: (_, _, _) => ColoredBox(
                            color: AppColors.chipIdleOf(context),
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 40,
                              color: AppColors.textTertiaryOf(context),
                            ),
                          ),
                        ),
                      ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: FadeSlideIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + "Show map" link.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: AppTextStyles.h1.copyWith(
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                            ),
                            if (placeBuilding != null)
                              TextButton(
                                onPressed: () => _openBuilding(placeBuilding),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 40),
                                  foregroundColor: AppColors.accentOf(context),
                                ),
                                child: const Text('Show map'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Status + category + time, like a rating line.
                        Row(
                          children: [
                            StatusBadge(status: item.statusEnum, compact: true),
                            if (item.verified) ...[
                              const SizedBox(width: 4),
                              const VerifiedMark(size: 16),
                            ],
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${ItemCategory.fromValue(item.category).label}'
                                '  ·  ${AppFormatters.timeAgo(item.createdAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textTertiaryOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (item.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: Text(
                              item.description,
                              maxLines: _expanded ? null : 3,
                              overflow: _expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(
                                height: 1.6,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ),
                          if (item.description.length > 140)
                            Pressable(
                              onTap: () =>
                                  setState(() => _expanded = !_expanded),
                              semanticLabel: _expanded ? 'Read less' : 'Read more',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _expanded ? 'Read less' : 'Read more',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.accentOf(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    AnimatedRotation(
                                      turns: _expanded ? 0.5 : 0,
                                      duration: const Duration(milliseconds: 260),
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                        color: AppColors.accentOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Details',
                          style: AppTextStyles.h3Bold.copyWith(
                            fontSize: 18,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Facilities-style tiles.
                        Row(
                          children: [
                            Expanded(
                              child: _DetailTile(
                                icon: ItemCategory.fromValue(item.category).icon,
                                label: ItemCategory.fromValue(item.category).label,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DetailTile(
                                icon: Icons.event_outlined,
                                label: AppFormatters.shortDate(item.eventDate),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DetailTile(
                                icon: Icons.apartment_rounded,
                                label: placeBuilding?.numberLabel ?? 'Campus',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DetailTile(
                                icon: contact.icon,
                                label: contact.label,
                              ),
                            ),
                          ],
                        ),
                        if (item.reunited) ...[
                          const SizedBox(height: 16),
                          const InfoBanner(
                            tone: BannerTone.success,
                            title: 'Reunited',
                            message:
                                'This item is back with its owner. The report is closed.',
                          ),
                        ],
                        const SizedBox(height: 20),
                        _Section(
                          title: item.status == 'found'
                              ? 'Where it was found'
                              : 'Where it was lost',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Fact(
                                icon: Icons.place_outlined,
                                label: 'Place',
                                value: placeBuilding == null
                                    ? item.location
                                    : '${placeBuilding.numberLabel}  ${placeBuilding.name}',
                              ),
                              const SizedBox(height: 12),
                              _Fact(
                                icon: Icons.event_outlined,
                                label: item.status == 'found'
                                    ? 'Date found'
                                    : 'Date lost',
                                value: AppFormatters.shortDate(item.eventDate),
                              ),
                              if (placeBuilding != null) ...[
                                const SizedBox(height: 12),
                                _LinkRow(
                                  label: 'View building details',
                                  onTap: () => _openBuilding(placeBuilding),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Section(
                          title: own
                              ? 'Where people can find you'
                              : 'Where to find $first',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  UserAvatar(name: item.reporterName, size: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.reporterName,
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: AppColors.textPrimaryOf(
                                                  context,
                                                ),
                                              ),
                                        ),
                                        Text(
                                          own ? 'Your report' : 'Reporter',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textSecondaryOf(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (!hasMeet)
                                Text(
                                  'The reporter did not add a meeting place. '
                                  'Send a message to arrange one.',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                )
                              else ...[
                                if (item.meetBuilding.isNotEmpty) ...[
                                  _Fact(
                                    icon: Icons.apartment_rounded,
                                    label: 'Building',
                                    value: meetBuilding == null
                                        ? item.meetBuilding
                                        : '${meetBuilding.numberLabel}  ${meetBuilding.name}',
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (item.pickupLocation.isNotEmpty) ...[
                                  _Fact(
                                    icon: Icons.meeting_room_outlined,
                                    label: 'Room or spot',
                                    value: item.pickupLocation,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (item.availabilitySchedule.isNotEmpty) ...[
                                  _Fact(
                                    icon: Icons.schedule_rounded,
                                    label: 'Usually there',
                                    value: item.availabilitySchedule,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
                              _Fact(
                                icon: contact.icon,
                                label: 'Prefers',
                                value: contact.label,
                              ),
                              if (item.contactInfo.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _Fact(
                                  icon: Icons.alternate_email_rounded,
                                  label: 'Contact details',
                                  value: item.contactInfo,
                                  trailing: IconButton(
                                    tooltip: 'Copy contact details',
                                    icon: const Icon(Icons.copy_rounded, size: 18),
                                    onPressed: () =>
                                        _copy(item.contactInfo, 'Contact details'),
                                  ),
                                ),
                              ],
                              if (meetBuilding != null) ...[
                                const SizedBox(height: 12),
                                _LinkRow(
                                  label: 'Show ${meetBuilding.name}',
                                  onTap: () => _openBuilding(meetBuilding),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_matches.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            own ? 'Possible matches' : 'Similar reports',
                            style: AppTextStyles.h3Bold.copyWith(
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Compared by title, description, category and place.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final m in _matches) ...[
                            ItemCard(
                              item: m.item,
                              matchConfidence: m.score,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ItemDetailScreen(item: m.item),
                                ),
                              ),
                            ),
                            if (m.reasons.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                                child: Text(
                                  'Why: ${m.reasons.take(3).join(', ')}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: item.reunited
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowOf(context),
                      blurRadius: 30,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                // "Price | Book now" layout: the item's status as the big
                // coloured value on the left, the action on the right.
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Row(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              own ? 'Your report' : 'Status',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                            Text(
                              item.statusEnum.label,
                              style: AppTextStyles.h1.copyWith(
                                fontSize: 22,
                                color: item.statusEnum == ItemStatus.found
                                    ? AppColors.successFgOf(context)
                                    : AppColors.errorFgOf(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: own
                              ? PrimaryButton(
                                  label: 'Mark reunited',
                                  trailingIcon: Icons.check_rounded,
                                  isLoading: _closing,
                                  onPressed: () => _markReunited(item),
                                )
                              : PrimaryButton(
                                  label: item.status == 'found'
                                      ? "It's mine"
                                      : 'I found it',
                                  trailingIcon: Icons.arrow_forward_rounded,
                                  isLoading: _busy,
                                  onPressed: () => _message(item),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Light-blue square with an icon and a short label (like a "Facilities"
/// row). The label wraps to two lines at most, so it never overflows.
class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primarySurfaceOf(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: AppColors.primaryOf(context)),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.micro.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round, surface-coloured background so app-bar icons stay readable on top
/// of a photo.
class _AppBarCircle extends StatelessWidget {
  const _AppBarCircle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context).withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h3Bold.copyWith(
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Icon + small label + value. The value wraps over as many lines as needed.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primarySurfaceOf(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryOf(context)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.accentOf(context),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.accentOf(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: ImageUploadService.optimizedUrl(url, width: 1600),
            fit: BoxFit.contain,
            placeholder: (_, _) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
