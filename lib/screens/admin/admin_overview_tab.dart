import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';

/// Headline numbers: users, reports and the review queue. Pull to refresh.
class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab>
    with AutomaticKeepAliveClientMixin {
  late Future<AdminStats> _stats = AdminService.instance.fetchStats();

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final next = AdminService.instance.fetchStats();
    setState(() => _stats = next);
    // Errors are shown by the FutureBuilder; just wait for completion.
    await next.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<AdminStats>(
        future: _stats,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(
              children: const [
                SizedBox(
                  height: 420,
                  child: EmptyState(
                    title: 'Could not load the numbers',
                    subtitle:
                        'Pull down to try again. If it keeps failing, deploy '
                        'the latest firestore.rules.',
                    icon: Icons.cloud_off_rounded,
                  ),
                ),
              ],
            );
          }
          if (!snap.hasData) return const LoadingIndicator();
          final s = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              _HeroCount(
                value: s.users,
                label: 'Registered users',
                footnote: '+${s.newUsers7d} in the last 7 days',
              ),
              const SizedBox(height: 12),
              _Grid(
                children: [
                  _StatTile(
                    icon: Icons.shield_outlined,
                    value: s.admins,
                    label: 'Admins',
                  ),
                  _StatTile(
                    icon: Icons.block_rounded,
                    value: s.bannedUsers,
                    label: 'Suspended',
                    tone: s.bannedUsers > 0 ? _Tone.bad : _Tone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Reports',
                style: AppTextStyles.h3Bold.copyWith(
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 12),
              _Grid(
                children: [
                  _StatTile(
                    icon: Icons.inventory_2_outlined,
                    value: s.reports,
                    label: 'Total',
                  ),
                  _StatTile(
                    icon: Icons.schedule_rounded,
                    value: s.awaitingReview,
                    label: 'Awaiting review',
                    tone: s.awaitingReview > 0 ? _Tone.warn : _Tone.neutral,
                  ),
                  _StatTile(
                    icon: Icons.search_rounded,
                    value: s.lost,
                    label: 'Lost (open)',
                  ),
                  _StatTile(
                    icon: Icons.back_hand_outlined,
                    value: s.found,
                    label: 'Found (open)',
                  ),
                  _StatTile(
                    icon: Icons.handshake_outlined,
                    value: s.reunited,
                    label: 'Reunited',
                    tone: _Tone.good,
                  ),
                  _StatTile(
                    icon: Icons.verified_outlined,
                    value: s.verified,
                    label: 'Verified',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (s.reports > 0)
                Text(
                  '${(s.reunited * 100 / s.reports).round()} % of all reports '
                  'ended with the item back with its owner.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _Tone { neutral, good, warn, bad }

class _HeroCount extends StatelessWidget {
  const _HeroCount({
    required this.value,
    required this.label,
    required this.footnote,
  });

  final int value;
  final String label;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primaryOf(context),
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.captionMedium.copyWith(
                    color: AppColors.onPrimaryOf(context).withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$value',
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.onPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  footnote,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onPrimaryOf(context).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.group_rounded,
            size: 48,
            color: AppColors.onPrimaryOf(context).withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < children.length
                  ? children[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < children.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.tone = _Tone.neutral,
  });

  final IconData icon;
  final int value;
  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      _Tone.neutral => AppColors.textSecondaryOf(context),
      _Tone.good => AppColors.successFgOf(context),
      _Tone.warn => AppColors.warning,
      _Tone.bad => AppColors.errorFgOf(context),
    };
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: AppTextStyles.h1.copyWith(
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
