import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'motion.dart';

/// Bottom navigation: Home, Search, [Report], Map, Profile.
///
/// A flat sheet separated from the content by a hairline. Every tab keeps
/// its label visible; the active tab gets a soft pill behind its icon. The
/// centre "+" is the single primary action of the app.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onReportTap,
  });

  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onReportTap;

  static const _items = <_NavItem>[
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.search_rounded, Icons.manage_search_rounded, 'Search'),
    _NavItem(Icons.map_outlined, Icons.map_rounded, 'Map'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(top: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              Expanded(child: _tab(context, 0)),
              Expanded(child: _tab(context, 1)),
              Expanded(child: _reportButton(context)),
              Expanded(child: _tab(context, 2)),
              Expanded(child: _tab(context, 3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int index) {
    final item = _items[index];
    final active = current == index;
    final labelColor = active
        ? AppColors.textPrimaryOf(context)
        : AppColors.textTertiaryOf(context);
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: () => onSelect(index),
        scale: 0.92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: active ? 56 : 40,
              height: 32,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primarySurfaceOf(context)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, a) =>
                    FadeTransition(opacity: a, child: child),
                child: Icon(
                  active ? item.activeIcon : item.icon,
                  key: ValueKey(active),
                  color: active ? AppColors.primaryOf(context) : labelColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyles.tabLabel.copyWith(
                color: labelColor,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportButton(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: 'Report a lost or found item',
        child: Pressable(
          onTap: onReportTap,
          scale: 0.9,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primaryOf(context),
              shape: BoxShape.circle,
              boxShadow: AppColors.ctaShadowOf(context),
            ),
            child: Icon(
              Icons.add_rounded,
              color: AppColors.onPrimaryOf(context),
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
