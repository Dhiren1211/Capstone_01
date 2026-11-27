import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../services/messaging_service.dart';
import '../state/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/motion.dart';
import '../widgets/primary_button.dart';
import 'chat_detail_screen.dart';
import 'item_detail_screen.dart';

enum _Filter { all, matches, messages }

/// Everything the app told the person: possible matches and messages.
///
/// A row shows the whole message (it wraps over as many lines as it needs).
/// Tapping a row opens a sheet with the details and, for matches, the two
/// reports next to each other.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _Filter _filter = _Filter.all;

  // Created once so rebuilds (filter taps, auth updates) do not re-subscribe.
  late final String _userId = context.read<AuthState>().user?.id ?? '';
  late final Stream<List<NotificationModel>> _stream = FirestoreService.instance
      .watchNotifications(_userId);

  Future<void> _open(NotificationModel n) async {
    if (!n.isRead) {
      // Fire and forget: the list updates through the stream.
      FirestoreService.instance.markNotificationRead(n.id).catchError((Object e) {
        debugPrint('[notifications] could not mark read: $e');
      });
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NotificationSheet(notification: n),
    );
  }

  List<NotificationModel> _apply(List<NotificationModel> all) =>
      switch (_filter) {
        _Filter.all => all,
        _Filter.matches =>
          all.where((n) => n.type == NotificationType.matchFound).toList(),
        _Filter.messages =>
          all.where((n) => n.type == NotificationType.newMessage).toList(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _userId.isEmpty
                ? null
                : () => FirestoreService.instance.markAllNotificationsRead(
                    _userId,
                  ),
            child: const Text('Mark all read'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  _FilterTab(
                    label: 'All',
                    selected: _filter == _Filter.all,
                    onTap: () => setState(() => _filter = _Filter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    label: 'Matches',
                    selected: _filter == _Filter.matches,
                    onTap: () => setState(() => _filter = _Filter.matches),
                  ),
                  const SizedBox(width: 8),
                  _FilterTab(
                    label: 'Messages',
                    selected: _filter == _Filter.messages,
                    onTap: () => setState(() => _filter = _Filter.messages),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<NotificationModel>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const EmptyState(
                      title: 'Could not load notifications',
                      subtitle: 'Check your connection and try again later.',
                      icon: Icons.cloud_off_rounded,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const LoadingIndicator();
                  }
                  final list = _apply(snapshot.data!);
                  if (list.isEmpty) {
                    return const EmptyState(
                      title: 'Nothing here yet',
                      subtitle:
                          'When a report looks like yours or someone writes '
                          'to you, it shows up here.',
                      icon: Icons.notifications_none_rounded,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => FadeSlideIn(
                      key: ValueKey(list[i].id),
                      delay: FadeSlideIn.stagger(i, stepMs: 30, maxMs: 240),
                      child: _NotificationRow(
                        n: list[i],
                        onTap: () => _open(list[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
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
            duration: const Duration(milliseconds: 160),
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

(IconData, Color, Color) _appearance(BuildContext context, NotificationType t) {
  switch (t) {
    case NotificationType.matchFound:
      return (
        Icons.compare_arrows_rounded,
        AppColors.accentOf(context),
        AppColors.accentSurfaceOf(context),
      );
    case NotificationType.newMessage:
      return (
        Icons.chat_bubble_outline_rounded,
        AppColors.primaryOf(context),
        AppColors.primarySurfaceOf(context),
      );
    case NotificationType.system:
      return (
        Icons.notifications_none_rounded,
        AppColors.textSecondaryOf(context),
        AppColors.chipIdleOf(context),
      );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.n, required this.onTap});

  final NotificationModel n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg) = _appearance(context, n.type);
    return Pressable(
      onTap: onTap,
      semanticLabel: '${n.title}. ${n.body}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead
              ? AppColors.cardOf(context)
              : AppColors.primarySurfaceOf(context),
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppColors.softShadowOf(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: n.isRead
                                ? FontWeight.w500
                                : FontWeight.w600,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      if (!n.isRead) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.accentOf(context),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // The whole message, wrapped. Never cut off.
                  Text(
                    n.body,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppFormatters.timeAgo(n.createdAt),
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.textTertiaryOf(context),
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

/// Detail sheet for one notification. Public so a tapped system notification
/// can reuse it.
class NotificationSheet extends StatefulWidget {
  const NotificationSheet({super.key, required this.notification});

  final NotificationModel notification;

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  late final Future<List<ItemModel?>> _items = _load();

  Future<List<ItemModel?>> _load() {
    final n = widget.notification;
    Future<ItemModel?> one(String? id) async {
      if (id == null || id.isEmpty) return null;
      try {
        return await FirestoreService.instance.fetchItem(id);
      } catch (e) {
        debugPrint('[notifications] item $id: $e');
        return null;
      }
    }

    return Future.wait([one(n.otherItemId), one(n.itemId)]);
  }

  Future<void> _openChat() async {
    final n = widget.notification;
    final id = n.chatId;
    if (id == null || id.isEmpty) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final chat = await MessagingService.instance.fetchChat(id);
      if (chat == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('This conversation no longer exists.')),
        );
        return;
      }
      nav.pop();
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => ChatDetailScreen(chat: chat)),
      );
    } catch (e) {
      debugPrint('[notifications] chat: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the conversation.')),
      );
    }
  }

  void _openItem(ItemModel item) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(
      MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final (icon, fg, bg) = _appearance(context, n.type);
    final isMatch = n.type == NotificationType.matchFound;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: AppTextStyles.h3Bold.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      Text(
                        AppFormatters.shortDateTime(n.createdAt),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMatch && n.score != null) _ScorePill(score: n.score!),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              n.body,
              style: AppTextStyles.body.copyWith(
                height: 1.6,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            if (isMatch) ...[
              const SizedBox(height: 20),
              FutureBuilder<List<ItemModel?>>(
                future: _items,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: LoadingIndicator(),
                    );
                  }
                  final mine = snap.data?[0];
                  final other = snap.data?[1];
                  if (other == null) {
                    return Text(
                      'The report this refers to is no longer available.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (mine != null) ...[
                        const _SheetLabel('Your report'),
                        ItemCard(item: mine, onTap: () => _openItem(mine)),
                        const SizedBox(height: 16),
                      ],
                      const _SheetLabel('Possible match'),
                      ItemCard(
                        item: other,
                        matchConfidence: n.score,
                        onTap: () => _openItem(other),
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            if (n.type == NotificationType.newMessage &&
                (n.chatId ?? '').isNotEmpty)
              PrimaryButton(
                label: 'Open conversation',
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: _openChat,
              )
            else
              FutureBuilder<List<ItemModel?>>(
                future: _items,
                builder: (context, snap) {
                  final target = snap.data == null ? null : snap.data![1];
                  return PrimaryButton(
                    label: isMatch ? 'Open the matching report' : 'Open report',
                    onPressed: target == null ? null : () => _openItem(target),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.captionMedium.copyWith(
          color: AppColors.textSecondaryOf(context),
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentSurfaceOf(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$score%',
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.accentOf(context),
        ),
      ),
    );
  }
}
