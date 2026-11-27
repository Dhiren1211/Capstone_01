import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import '../widgets/bottom_nav_bar.dart';
import 'campus_map_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

/// Hosts the 4-tab bottom nav (Home, Search, Map, Profile) plus the central
/// "+" which opens the "Report lost or found?" sheet.
///
/// Tabs are built the first time they are opened (the map is expensive) and
/// then kept alive, so scrolling positions and typed text survive tab changes.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.tabController});

  /// Optional external tab controller.
  final ValueNotifier<int>? tabController;

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late final ValueNotifier<int> _tabController =
      widget.tabController ?? ValueNotifier<int>(0);
  final Set<int> _visited = {0};

  ValueNotifier<int> get tabController => _tabController;

  void setTab(int i) {
    _visited.add(i);
    _tabController.value = i;
  }

  @override
  void initState() {
    super.initState();
    // A pop-up tapped while the app was closed is opened once we are showing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.flushPendingTap();
    });
  }

  void _openReportSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _ReportActionSheet(),
    );
  }

  @override
  void dispose() {
    if (widget.tabController == null) {
      _tabController.dispose();
    }
    super.dispose();
  }

  static const _pages = <Widget Function()>[
    HomeScreen.new,
    SearchScreen.new,
    CampusMapScreen.new,
    ProfileScreen.new,
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _tabController,
      builder: (context, current, _) {
        return PopScope(
          canPop: current == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setTab(0);
          },
          child: Scaffold(
            body: IndexedStack(
              index: current,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  _visited.contains(i) ? _pages[i]() : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: AppBottomNavBar(
              current: current,
              onSelect: setTab,
              onReportTap: _openReportSheet,
            ),
            backgroundColor: AppColors.backgroundOf(context),
          ),
        );
      },
    );
  }
}

/// Convenience: find the nearest MainShell ancestor and switch its tab.
void switchMainShellTab(BuildContext context, int index) {
  final state = context.findAncestorStateOfType<MainShellState>();
  state?.setTab(index);
}

class _ReportActionSheet extends StatelessWidget {
  const _ReportActionSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What happened?',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'We compare every new report with the others and alert you '
              'when something looks like a match.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 20),
            _ReportOption(
              icon: Icons.search_off_rounded,
              fg: AppColors.errorFgOf(context),
              bg: AppColors.errorBgOf(context),
              title: 'I lost something',
              subtitle: 'Describe it so people who find it can reach you.',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(AppConstants.routeReportLost);
              },
            ),
            const SizedBox(height: 12),
            _ReportOption(
              icon: Icons.inventory_2_outlined,
              fg: AppColors.successFgOf(context),
              bg: AppColors.successBgOf(context),
              title: 'I found something',
              subtitle: 'Tell us where you left it so the owner can claim it.',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(AppConstants.routeReportFound);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportOption extends StatelessWidget {
  const _ReportOption({
    required this.icon,
    required this.fg,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color fg;
  final Color bg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySurfaceOf(context),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: fg, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h3Bold.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
        ),
      ),
    );
  }
}
