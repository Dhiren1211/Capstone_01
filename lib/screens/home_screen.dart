import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
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
import '../utils/formatters.dart';
import '../widgets/category_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/motion.dart';
import '../widgets/section_header.dart';
import '../widgets/user_avatar.dart';
import 'chats_screen.dart';
import 'main_shell.dart';

/// Landing tab: greeting, search, category pills, a photo carousel of the
/// latest reports, quick actions, campus stats, possible matches for the
/// user's own reports and the newest reports.
///
/// The category pills here are local to this screen. They are NOT shared with
/// the Search tab - what is typed or tapped there never changes this list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _category = 'all';

  // Cached so the (CPU-bound) comparison only runs when the feed or the
  // user's own reports changed - not on every rebuild.
  List<ItemModel>? _feedSeen;
  String? _userSeen;
  List<_OwnMatch> _matches = const [];

  void _refreshMatches(List<ItemModel> feed, String userId) {
    if (identical(feed, _feedSeen) && userId == _userSeen) return;
    _feedSeen = feed;
    _userSeen = userId;
    if (userId.isEmpty || feed.isEmpty) {
      _matches = const [];
      return;
    }
    final mine = feed
        .where((i) => i.reporterId == userId && !i.reunited)
        .take(4)
        .toList();
    final found = <String, _OwnMatch>{};
    for (final own in mine) {
      final top = MatchingService.instance.rank(
        own,
        feed.where((i) => i.reporterId != userId),
        minScore: MatchingService.matchThreshold,
        limit: 1,
      );
      if (top.isEmpty) continue;
      final m = top.first;
      final prev = found[m.item.id];
      if (prev == null || prev.score < m.score) {
        found[m.item.id] = _OwnMatch(own: own, other: m.item, score: m.score);
      }
    }
    _matches = found.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  void _open(ItemModel item) {
    Navigator.of(
      context,
    ).pushNamed(AppConstants.routeItemDetail, arguments: item);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final feed = context.watch<ItemsState>();
    final userId = auth.user?.id ?? '';
    _refreshMatches(feed.items, userId);

    var lost = 0, found = 0, reunited = 0;
    for (final i in feed.items) {
      if (i.reunited) {
        reunited++;
      } else if (i.statusEnum == ItemStatus.found) {
        found++;
      } else {
        lost++;
      }
    }

    final open = feed.items
        .where(
          (i) => !i.reunited && (_category == 'all' || i.category == _category),
        )
        .toList(growable: false);
    // "Popular"-style row: found items with a photo (falls back to any open
    // report with a photo). "Recommended"-style row: lost items people can
    // help with.
    var featured = open
        .where((i) => i.imageUrl.isNotEmpty && i.statusEnum == ItemStatus.found)
        .take(8)
        .toList(growable: false);
    if (featured.isEmpty) {
      featured = open
          .where((i) => i.imageUrl.isNotEmpty)
          .take(8)
          .toList(growable: false);
    }
    final helpFind = open
        .where((i) => i.statusEnum == ItemStatus.lost)
        .take(10)
        .toList(growable: false);
    final recent = open.take(12).toList(growable: false);
    final loading = feed.isLoading && feed.items.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primaryOf(context),
          onRefresh: () async => context.read<ItemsState>().refresh(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                  child: FadeSlideIn(
                    child: _Header(
                      name: auth.user?.displayName ?? '',
                      firstName: auth.user?.firstName ?? 'there',
                      avatarUrl: auth.user?.avatarUrl,
                      userId: userId,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: _SearchEntry(
                      onTap: () => switchMainShellTab(context, 1),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      itemCount: AppConstants.categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final c = AppConstants.categories[i];
                        return CategoryChip(
                          category: c,
                          selected: _category == c.value,
                          onTap: () => setState(() => _category = c.value),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (featured.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Recently found',
                    actionLabel: 'See all',
                    onAction: () => switchMainShellTab(context, 1),
                    padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 248,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: featured.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 16),
                      itemBuilder: (_, i) => FadeSlideIn(
                        key: ValueKey('f-${featured[i].id}'),
                        delay: FadeSlideIn.stagger(i, stepMs: 60),
                        offset: 24,
                        child: _FeatureCard(
                          item: featured[i],
                          onTap: () => _open(featured[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (helpFind.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Help find these',
                    actionLabel: 'See all',
                    onAction: () => switchMainShellTab(context, 1),
                    padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 196,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: helpFind.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, i) => FadeSlideIn(
                        key: ValueKey('h-${helpFind[i].id}'),
                        delay: FadeSlideIn.stagger(i, stepMs: 60),
                        offset: 24,
                        child: _CompactCard(
                          item: helpFind[i],
                          onTap: () => _open(helpFind[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Quick actions',
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _QuickActions(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: _StatsCard(
                    lost: lost,
                    found: found,
                    reunited: reunited,
                    loading: loading,
                  ),
                ),
              ),
              if (_matches.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Possible matches for you',
                    padding: EdgeInsets.fromLTRB(24, 28, 24, 12),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList.separated(
                    itemCount: _matches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) {
                      final m = _matches[i];
                      return FadeSlideIn(
                        delay: FadeSlideIn.stagger(i),
                        child: _MatchRow(match: m, onTap: () => _open(m.other)),
                      );
                    },
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Recent reports',
                  actionLabel: 'See all',
                  onAction: () => switchMainShellTab(context, 1),
                  padding: const EdgeInsets.fromLTRB(24, 28, 16, 8),
                ),
              ),
              if (loading)
                const SliverToBoxAdapter(child: _FeedSkeleton())
              else if (feed.error != null && feed.items.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: EmptyState(
                      title: 'Could not load reports',
                      subtitle: feed.error!,
                      icon: Icons.cloud_off_rounded,
                      ctaLabel: 'Try again',
                      onCtaTap: feed.refresh,
                    ),
                  ),
                )
              else if (recent.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: EmptyState(
                      title: _category == 'all'
                          ? 'No reports yet'
                          : 'Nothing in this category',
                      subtitle: _category == 'all'
                          ? 'Be the first to report a lost or found item on campus.'
                          : 'No open reports in this category right now.',
                      icon: Icons.inbox_outlined,
                      ctaLabel: _category == 'all'
                          ? 'Report an item'
                          : 'Show all',
                      onCtaTap: _category == 'all'
                          ? () => Navigator.of(
                              context,
                            ).pushNamed(AppConstants.routeReportLost)
                          : () => setState(() => _category = 'all'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList.separated(
                    itemCount: recent.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => FadeSlideIn(
                      key: ValueKey(recent[i].id),
                      delay: FadeSlideIn.stagger(i),
                      child: ItemCard(
                        item: recent[i],
                        onTap: () => _open(recent[i]),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnMatch {
  const _OwnMatch({
    required this.own,
    required this.other,
    required this.score,
  });

  /// The user's own report.
  final ItemModel own;

  /// The other person's report that looks like it.
  final ItemModel other;
  final int score;
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match, required this.onTap});

  final _OwnMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Looks like your ${match.own.statusEnum.label.toLowerCase()} report '
            '"${match.own.title}"',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ),
        ItemCard(item: match.other, matchConfidence: match.score, onTap: onTap),
      ],
    );
  }
}

/// "Good morning / Hi, Name" with a campus location line, plus message and
/// alert buttons.
class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.firstName,
    required this.avatarUrl,
    required this.userId,
  });

  final String name;
  final String firstName;
  final String? avatarUrl;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppFormatters.greeting(DateTime.now()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hi, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display.copyWith(
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: AppColors.primaryOf(context),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Kyungsung University',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.captionMedium.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _ChatsButton(userId: userId),
        _NotificationsButton(userId: userId),
        Pressable(
          onTap: () => switchMainShellTab(context, 3),
          semanticLabel: 'Open profile',
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: UserAvatar(name: name, imageUrl: avatarUrl, size: 40),
            ),
          ),
        ),
      ],
    );
  }
}

/// Search bar (opens the Search tab): a hairline card with an ink filter key.
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Search reports',
      child: Container(
        height: 56,
        padding: const EdgeInsets.only(left: 18, right: 6),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.borderOf(context)),
          boxShadow: AppColors.softShadowOf(context),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 22,
              color: AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search items or buildings',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textTertiaryOf(context),
                ),
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.textPrimaryOf(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: AppColors.backgroundOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tall photo card for the "Recently reported" carousel: the photo fills the
/// card and the title sits on a frosted pill at the bottom.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item, required this.onTap});

  final ItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final found = item.statusEnum == ItemStatus.found;
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      semanticLabel:
          '${item.statusEnum.label}: ${item.title}, ${item.location}',
      child: Container(
        width: 188,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppColors.softShadowOf(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: ImageUploadService.optimizedUrl(
                  item.imageUrl,
                  width: 480,
                ),
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 220),
                placeholder: (_, _) =>
                    ColoredBox(color: AppColors.primarySurfaceOf(context)),
                errorWidget: (_, _, _) => ColoredBox(
                  color: AppColors.primarySurfaceOf(context),
                  child: Icon(
                    ItemCategory.fromValue(item.category).icon,
                    size: 36,
                    color: AppColors.primaryOf(context),
                  ),
                ),
              ),
              // Bottom shade keeps the frosted labels readable on any photo.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x8C000000)],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _Frosted(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: found ? AppColors.fresh : AppColors.heart,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.statusEnum.label,
                        style: AppTextStyles.captionMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Frosted(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.captionMedium.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Frosted(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            AppFormatters.timeAgo(item.createdAt),
                            style: AppTextStyles.micro.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
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

/// Landscape card for the "Help find these" row: photo (or category icon) on
/// top with a time badge, title and place below.
class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.item, required this.onTap});

  final ItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = ItemCategory.fromValue(item.category);
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      semanticLabel:
          '${item.statusEnum.label}: ${item.title}, ${item.location}',
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderOf(context)),
          boxShadow: AppColors.softShadowOf(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 112,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.imageUrl.isEmpty)
                      ColoredBox(
                        color: AppColors.primarySurfaceOf(context),
                        child: Icon(
                          cat.icon,
                          size: 34,
                          color: AppColors.primaryOf(context),
                        ),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: ImageUploadService.optimizedUrl(
                          item.imageUrl,
                          width: 420,
                        ),
                        fit: BoxFit.cover,
                        placeholder: (_, _) => ColoredBox(
                          color: AppColors.primarySurfaceOf(context),
                        ),
                        errorWidget: (_, _, _) => ColoredBox(
                          color: AppColors.primarySurfaceOf(context),
                          child: Icon(
                            cat.icon,
                            size: 34,
                            color: AppColors.primaryOf(context),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xD916181D),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _shortAgo(item.createdAt),
                          semanticsLabel: AppFormatters.timeAgo(item.createdAt),
                          style: AppTextStyles.micro.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 6, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: AppColors.primaryOf(context),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact age for small badges: "now", "5m", "3h", "2d", "3w", "2mo", "1y".
String _shortAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 30) return '${d.inDays ~/ 7}w';
  if (d.inDays < 365) return '${d.inDays ~/ 30}mo';
  return '${d.inDays ~/ 365}y';
}

/// Small frosted-glass pill used on top of photos.
class _Frosted extends StatelessWidget {
  const _Frosted({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: const Color(0x4D16181D),
          child: child,
        ),
      ),
    );
  }
}

/// Four hairline tiles (lost / found / map / chats), each with a tinted icon
/// disc in its own semantic colour.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.search_off_rounded,
            label: 'I lost',
            fg: AppColors.errorFgOf(context),
            onTap: () =>
                Navigator.of(context).pushNamed(AppConstants.routeReportLost),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.volunteer_activism_outlined,
            label: 'I found',
            fg: AppColors.successFgOf(context),
            onTap: () =>
                Navigator.of(context).pushNamed(AppConstants.routeReportFound),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.map_outlined,
            label: 'Map',
            fg: AppColors.primaryOf(context),
            onTap: () => switchMainShellTab(context, 2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chats',
            fg: AppColors.accentOf(context),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ChatsScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      semanticLabel: label,
      child: AspectRatio(
        aspectRatio: 0.9,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: fg),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.captionMedium.copyWith(
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White card with the live campus counts.
class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.lost,
    required this.found,
    required this.reunited,
    required this.loading,
  });

  final int lost;
  final int found;
  final int reunited;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, int value, Color dot) => Expanded(
      child: Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              loading ? '–' : '$value',
              style: AppTextStyles.display.copyWith(
                fontSize: 30,
                color: AppColors.textPrimaryOf(context),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    Widget divider() =>
        Container(width: 1, height: 36, color: AppColors.dividerOf(context));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          stat('Lost', lost, AppColors.heart),
          divider(),
          stat('Found', found, AppColors.fresh),
          divider(),
          stat('Reunited', reunited, AppColors.primaryOf(context)),
        ],
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 92, height: 92, radius: 18),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 70, height: 14),
                          SizedBox(height: 10),
                          SkeletonBox(height: 16),
                          SizedBox(height: 8),
                          SkeletonBox(width: 120, height: 12),
                        ],
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
}

/// Messages icon with the total number of unread messages as a badge.
///
/// A StatefulWidget so the Firestore stream is created once (not on every
/// rebuild of the home screen).
class _ChatsButton extends StatefulWidget {
  const _ChatsButton({required this.userId});

  final String userId;

  @override
  State<_ChatsButton> createState() => _ChatsButtonState();
}

class _ChatsButtonState extends State<_ChatsButton> {
  Stream<List<ChatModel>>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = _open();
  }

  @override
  void didUpdateWidget(covariant _ChatsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _stream = _open();
  }

  Stream<List<ChatModel>>? _open() => widget.userId.isEmpty
      ? null
      : MessagingService.instance.watchChats(widget.userId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        final unread = snapshot.hasData
            ? snapshot.data!.fold<int>(
                0,
                (sum, c) => sum + c.unreadFor(widget.userId),
              )
            : 0;
        return _HeaderIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Messages',
          count: unread,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ChatsScreen())),
        );
      },
    );
  }
}

/// Bell icon with the number of unread notifications as a badge.
class _NotificationsButton extends StatefulWidget {
  const _NotificationsButton({required this.userId});

  final String userId;

  @override
  State<_NotificationsButton> createState() => _NotificationsButtonState();
}

class _NotificationsButtonState extends State<_NotificationsButton> {
  Stream<int>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = _open();
  }

  @override
  void didUpdateWidget(covariant _NotificationsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _stream = _open();
  }

  Stream<int>? _open() => widget.userId.isEmpty
      ? null
      : FirestoreService.instance.watchUnreadCount(widget.userId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      builder: (context, snapshot) => _HeaderIconButton(
        icon: Icons.notifications_none_rounded,
        tooltip: 'Notifications',
        count: snapshot.data ?? 0,
        onTap: () =>
            Navigator.of(context).pushNamed(AppConstants.routeNotifications),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.count = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Semantics(
      label: count > 0 ? '$tooltip, $count unread' : tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Pressable(
          onTap: onTap,
          scale: 0.92,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 24, color: AppColors.textPrimaryOf(context)),
                if (count > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.heart,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: AppColors.backgroundOf(context),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: AppTextStyles.overline.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
