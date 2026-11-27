import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../services/firestore_service.dart';
import '../state/auth_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/motion.dart';
import '../widgets/section_header.dart';
import '../widgets/user_avatar.dart';
import 'campus_vr_screen.dart';
import 'edit_profile_screen.dart';
import 'item_detail_screen.dart';
import 'saved_items_screen.dart';
import 'settings_screen.dart';

/// Profile tab: who is signed in, numbers, shortcuts and the person's own
/// reports.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Created once so rebuilds do not re-subscribe to Firestore.
  late final Stream<List<ItemModel>>? _myItems = _openMyItems();

  Stream<List<ItemModel>>? _openMyItems() {
    final id = context.read<AuthState>().user?.id;
    return id == null ? null : FirestoreService.instance.watchMyItems(id);
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final isAdmin = context.select<AuthState, bool>((a) => a.isAdmin);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profile',
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit profile',
                      onPressed: () => _push(const EditProfileScreen()),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () => _push(const SettingsScreen()),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: FadeSlideIn(
                  child: AppCard(
                    child: Row(
                      children: [
                        UserAvatar(
                          name: user?.displayName ?? '',
                          imageUrl: user?.avatarUrl,
                          size: 64,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? '',
                                style: AppTextStyles.h3Bold.copyWith(
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                              if ((user?.studentId ?? '').isNotEmpty)
                                Text(
                                  'Student ID ${user!.studentId}',
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
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        value: '${user?.postsCount ?? 0}',
                        label: 'Reports',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Stat(
                        value: '${user?.savedCount ?? 0}',
                        label: 'Saved',
                        onTap: () => _push(const SavedItemsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      if (isAdmin)
                        _LinkTile(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Admin panel',
                          onTap: () => Navigator.of(
                            context,
                          ).pushNamed(AppConstants.routeAdmin),
                        ),
                      _LinkTile(
                        icon: Icons.bookmark_border_rounded,
                        label: 'Saved reports',
                        onTap: () => _push(const SavedItemsScreen()),
                      ),
                      _LinkTile(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppConstants.routeNotifications),
                      ),
                      _LinkTile(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Messages',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppConstants.routeChats),
                      ),
                      _LinkTile(
                        icon: Icons.vrpano_outlined,
                        label: 'Campus VR tour',
                        onTap: () => _push(const CampusVrScreen()),
                        last: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: 'My reports',
                padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
              ),
            ),
            if (user == null || _myItems == null)
              const SliverToBoxAdapter(child: SizedBox.shrink())
            else
              StreamBuilder<List<ItemModel>>(
                stream: _myItems,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 280,
                        child: EmptyState(
                          title: 'Could not load your reports',
                          subtitle: 'Check your connection and try again later.',
                          icon: Icons.cloud_off_rounded,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const SliverToBoxAdapter(
                      child: SizedBox(height: 160, child: LoadingIndicator()),
                    );
                  }
                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: 300,
                        child: EmptyState(
                          title: 'No reports yet',
                          subtitle:
                              'Reports you post appear here, with their matches.',
                          icon: Icons.post_add_outlined,
                          ctaLabel: 'Report an item',
                          onCtaTap: () => Navigator.of(
                            context,
                          ).pushNamed(AppConstants.routeReportLost),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => ItemCard(
                        item: items[i],
                        onTap: () => _push(ItemDetailScreen(item: items[i])),
                      ),
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.h1.copyWith(
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: AppColors.dividerOf(context))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondaryOf(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
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
    );
  }
}
