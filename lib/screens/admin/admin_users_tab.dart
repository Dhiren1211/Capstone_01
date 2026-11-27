import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/user_avatar.dart';
import 'admin_reports_tab.dart';
import 'admin_widgets.dart';

enum _UserFilter { all, admins, suspended }

/// Every account: search, suspend / lift suspension, grant / remove admin.
class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab>
    with AutomaticKeepAliveClientMixin {
  final Stream<List<UserModel>> _users = AdminService.instance.watchUsers();
  final Stream<Set<String>> _adminIds = AdminService.instance.watchAdminIds();
  _UserFilter _filter = _UserFilter.all;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  bool _matches(UserModel u) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return u.displayName.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        u.studentId.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<Set<String>>(
      stream: _adminIds,
      builder: (context, adminSnap) {
        final adminIds = adminSnap.data ?? const <String>{};
        return StreamBuilder<List<UserModel>>(
          stream: _users,
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                title: 'Could not load users',
                subtitle: 'Check your connection and the Firestore rules.',
                icon: Icons.cloud_off_rounded,
              );
            }
            if (!snap.hasData) return const LoadingIndicator();

            final all = snap.data!;
            bool passes(UserModel u, _UserFilter f) => switch (f) {
              _UserFilter.all => true,
              _UserFilter.admins => adminIds.contains(u.id),
              _UserFilter.suspended => u.banned,
            };
            final shown =
                all.where((u) => _matches(u) && passes(u, _filter)).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: AdminSearchField(
                    hint: 'Search name, e-mail or student ID',
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
                        (_UserFilter.all, 'All'),
                        (_UserFilter.admins, 'Admins'),
                        (_UserFilter.suspended, 'Suspended'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AdminFilterPill(
                            label: label,
                            count: all.where((u) => passes(u, f)).length,
                            selected: _filter == f,
                            onTap: () => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? const EmptyState(
                          title: 'No users found',
                          subtitle: 'Try another filter or search.',
                          icon: Icons.person_search_outlined,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: shown.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final u = shown[i];
                            final isAdmin = adminIds.contains(u.id);
                            return _UserRow(
                              user: u,
                              isAdmin: isAdmin,
                              onTap: () => _openUser(u, isAdmin),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openUser(UserModel user, bool isAdmin) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceOf(context),
      builder: (_) => _UserSheet(user: user, isAdmin: isAdmin),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isAdmin,
    required this.onTap,
  });

  final UserModel user;
  final bool isAdmin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          UserAvatar(name: user.displayName, imageUrl: user.avatarUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      AdminTag.admin(context),
                    ],
                    if (user.banned) ...[
                      const SizedBox(width: 6),
                      AdminTag.banned(context),
                    ],
                  ],
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user.postsCount}',
                style: AppTextStyles.h3Bold.copyWith(
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Text(
                'reports',
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.textTertiaryOf(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserSheet extends StatefulWidget {
  const _UserSheet({required this.user, required this.isAdmin});
  final UserModel user;
  final bool isAdmin;

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  late final Stream<List<ItemModel>> _reports = AdminService.instance
      .watchItemsOf(widget.user.id);
  late bool _isAdmin = widget.isAdmin;
  late bool _banned = widget.user.banned;
  bool _busy = false;

  UserModel get user => widget.user;

  Future<void> _toggleBan() async {
    String reason = '';
    if (!_banned) {
      final r = await _askReason();
      if (r == null || !mounted) return;
      reason = r;
    } else {
      final ok = await confirmAdminAction(
        context,
        title: 'Lift suspension?',
        message: '${user.displayName} will be able to use smartFind again.',
        confirmLabel: 'Lift suspension',
      );
      if (!ok || !mounted) return;
    }
    final next = !_banned;
    setState(() => _busy = true);
    final ok = await runAdminAction(
      context,
      () => AdminService.instance.setBanned(user.id, next, reason: reason),
      success: next ? '${user.displayName} suspended' : 'Suspension lifted',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _banned = next;
    });
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Suspend ${user.displayName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'They will be signed in to a "suspended" screen and can no '
              'longer post reports or send messages.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Reason (shown to the user)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Suspend'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _toggleAdmin() async {
    final me = context.read<AuthState>().user?.id ?? '';
    final next = !_isAdmin;
    final ok = await confirmAdminAction(
      context,
      title: next ? 'Make admin?' : 'Remove admin access?',
      message: next
          ? '${user.displayName} will be able to verify reports, move '
                'buildings and manage every user.'
          : '${user.displayName} will no longer see the admin panel.',
      confirmLabel: next ? 'Make admin' : 'Remove',
      destructive: !next,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final done = await runAdminAction(
      context,
      () => AdminService.instance.setAdmin(user, next, byUid: me),
      success: next ? '${user.displayName} is now an admin' : 'Admin removed',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (done) _isAdmin = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.select<AuthState, String?>((a) => a.user?.id);
    final isSelf = me == user.id;
    final muted = AppTextStyles.caption.copyWith(
      color: AppColors.textSecondaryOf(context),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              UserAvatar(
                name: user.displayName,
                imageUrl: user.avatarUrl,
                size: 60,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(user.email, style: muted),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (_isAdmin) AdminTag.admin(context),
                        if (_banned) AdminTag.banned(context),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoLine(
            label: 'Student ID',
            value: user.studentId.isEmpty ? '-' : user.studentId,
          ),
          _InfoLine(
            label: 'Joined',
            value: AppFormatters.shortDate(user.createdAt),
          ),
          _InfoLine(label: 'Reports posted', value: '${user.postsCount}'),
          if (_banned && user.bannedReason.isNotEmpty)
            _InfoLine(label: 'Suspension reason', value: user.bannedReason),
          const SizedBox(height: 16),
          if (isSelf)
            Text(
              'This is your own account. Another admin has to change its '
              'role or suspend it.',
              style: muted,
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _toggleAdmin,
                    icon: Icon(
                      _isAdmin
                          ? Icons.remove_moderator_outlined
                          : Icons.add_moderator_outlined,
                    ),
                    label: Text(_isAdmin ? 'Remove admin' : 'Make admin'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _toggleBan,
                    icon: Icon(
                      _banned ? Icons.lock_open_rounded : Icons.block_rounded,
                    ),
                    label: Text(_banned ? 'Lift suspension' : 'Suspend'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: _banned
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Text(
            'Their reports',
            style: AppTextStyles.h3Bold.copyWith(
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<ItemModel>>(
            stream: _reports,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox(height: 80, child: LoadingIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return Text('No reports.', style: muted);
              }
              return Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminReportRow(item: item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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
