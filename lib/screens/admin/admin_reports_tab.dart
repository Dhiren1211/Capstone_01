import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../services/admin_service.dart';
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/status_badge.dart';
import '../item_detail_screen.dart';
import 'admin_widgets.dart';

enum _ReportFilter { pending, verified, reunited, all }

/// Review queue: verify, un-verify or remove reports.
class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab>
    with AutomaticKeepAliveClientMixin {
  final Stream<List<ItemModel>> _items = AdminService.instance.watchAllItems();
  _ReportFilter _filter = _ReportFilter.pending;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  static bool _isOpen(ItemModel i) => !i.reunited && i.status != 'reunited';

  bool _passes(ItemModel i, _ReportFilter f) => switch (f) {
    _ReportFilter.pending => _isOpen(i) && !i.verified,
    _ReportFilter.verified => i.verified,
    _ReportFilter.reunited => !_isOpen(i),
    _ReportFilter.all => true,
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<ItemModel>>(
      stream: _items,
      builder: (context, snap) {
        if (snap.hasError) {
          return const EmptyState(
            title: 'Could not load reports',
            subtitle: 'Check your connection and the Firestore rules.',
            icon: Icons.cloud_off_rounded,
          );
        }
        if (!snap.hasData) return const LoadingIndicator();

        final all = snap.data!;
        final searched = all.where((i) => i.matchesQuery(_query) ||
            i.reporterName.toLowerCase().contains(_query.toLowerCase()));
        final shown = searched.where((i) => _passes(i, _filter)).toList();
        int countOf(_ReportFilter f) => all.where((i) => _passes(i, f)).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: AdminSearchField(
                hint: 'Search title, place or reporter',
                onChanged: (q) => setState(() => _query = q.trim()),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (f, label) in const [
                    (_ReportFilter.pending, 'Awaiting review'),
                    (_ReportFilter.verified, 'Verified'),
                    (_ReportFilter.reunited, 'Closed'),
                    (_ReportFilter.all, 'All'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AdminFilterPill(
                        label: label,
                        count: countOf(f),
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? EmptyState(
                      title: _filter == _ReportFilter.pending
                          ? 'All caught up'
                          : 'No reports here',
                      subtitle: _filter == _ReportFilter.pending
                          ? 'Every open report has been reviewed.'
                          : 'Try another filter or search.',
                      icon: _filter == _ReportFilter.pending
                          ? Icons.task_alt_rounded
                          : Icons.inbox_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => AdminReportRow(item: shown[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// One report in an admin list. Tapping opens the review sheet.
class AdminReportRow extends StatelessWidget {
  const AdminReportRow({super.key, required this.item});
  final ItemModel item;

  @override
  Widget build(BuildContext context) {
    final open = !item.reunited && item.status != 'reunited';
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => showReportReviewSheet(context, item),
      child: Row(
        children: [
          _Thumb(url: item.imageUrl, category: item.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge(status: item.statusEnum, compact: true),
                    const SizedBox(width: 6),
                    if (item.verified)
                      AdminTag.verified(context)
                    else if (open)
                      AdminTag.pending(context),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item.reporterName} · ${item.location} · '
                  '${AppFormatters.timeAgo(item.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.category});
  final String url;
  final String category;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.chipIdleOf(context),
      child: Icon(
        ItemCategory.fromValue(category).icon,
        color: AppColors.textTertiaryOf(context),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => fallback,
                placeholder: (_, _) => fallback,
              ),
      ),
    );
  }
}

/// Bottom sheet with the report's details and the admin actions.
Future<void> showReportReviewSheet(BuildContext context, ItemModel item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceOf(context),
    builder: (sheetContext) => _ReportReviewSheet(item: item),
  );
}

class _ReportReviewSheet extends StatefulWidget {
  const _ReportReviewSheet({required this.item});
  final ItemModel item;

  @override
  State<_ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends State<_ReportReviewSheet> {
  bool _busy = false;
  late bool _verified = widget.item.verified;

  ItemModel get item => widget.item;

  Future<void> _toggleVerified() async {
    final uid = context.read<AuthState>().user?.id ?? '';
    final next = !_verified;
    setState(() => _busy = true);
    final ok = await runAdminAction(
      context,
      () => AdminService.instance.setVerified(item.id, next, byUid: uid),
      success: next ? 'Report verified' : 'Verification removed',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _verified = next;
    });
    if (ok && next) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Remove this report?',
      message:
          '"${item.title}" by ${item.reporterName} will be deleted for '
          'everyone. This cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final ok = await runAdminAction(
      context,
      () => AdminService.instance.deleteItem(item),
      success: 'Report removed',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cat = ItemCategory.fromValue(item.category);
    final muted = AppTextStyles.caption.copyWith(
      color: AppColors.textSecondaryOf(context),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (item.imageUrl.isNotEmpty) const SizedBox(height: 16),
            Row(
              children: [
                StatusBadge(status: item.statusEnum),
                const SizedBox(width: 8),
                if (_verified) AdminTag.verified(context),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: AppTextStyles.h2.copyWith(
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 4),
            Text('${cat.label} · ${item.location}', style: muted),
            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.description,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Reported by ${item.reporterName} on '
              '${AppFormatters.shortDateTime(item.createdAt)}',
              style: muted,
            ),
            if (item.contactInfo.isNotEmpty)
              Text('Contact: ${item.contactInfo}', style: muted),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _toggleVerified,
                icon: Icon(
                  _verified ? Icons.remove_done_rounded : Icons.verified_rounded,
                ),
                label: Text(_verified ? 'Remove verification' : 'Verify report'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: _verified
                      ? AppColors.textSecondaryOf(context)
                      : AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            navigator.push(
                              MaterialPageRoute<void>(
                                builder: (_) => ItemDetailScreen(item: item),
                              ),
                            );
                          },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
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
