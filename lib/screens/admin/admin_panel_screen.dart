import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/empty_state.dart';
import 'admin_buildings_tab.dart';
import 'admin_overview_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_users_tab.dart';

/// Admin panel: numbers at a glance, report review, user management and
/// building positions.
///
/// Only reachable for admins (the Profile tab shows the entry point only to
/// them), and every action is also enforced by the Firestore rules.
class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthState, bool>((a) => a.isAdmin);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin panel')),
        body: const EmptyState(
          title: 'Admins only',
          subtitle: 'This account does not have admin access.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.backgroundOf(context),
        appBar: AppBar(
          backgroundColor: AppColors.backgroundOf(context),
          title: Text(
            'Admin panel',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: AppTextStyles.tabLabel,
            labelColor: AppColors.primaryOf(context),
            unselectedLabelColor: AppColors.textSecondaryOf(context),
            indicatorColor: AppColors.primaryOf(context),
            dividerColor: AppColors.dividerOf(context),
            tabs: const [
              Tab(icon: Icon(Icons.insights_rounded, size: 20), text: 'Overview'),
              Tab(icon: Icon(Icons.fact_check_outlined, size: 20), text: 'Reports'),
              Tab(icon: Icon(Icons.group_outlined, size: 20), text: 'Users'),
              Tab(icon: Icon(Icons.apartment_rounded, size: 20), text: 'Buildings'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminOverviewTab(),
            AdminReportsTab(),
            AdminUsersTab(),
            AdminBuildingsTab(),
          ],
        ),
      ),
    );
  }
}
