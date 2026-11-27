import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import 'motion.dart';

/// Empty / error state: icon, title, explanation and an optional action.
/// Scrolls if the available height is tiny, so it can never overflow.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.search_off_rounded,
    this.ctaLabel,
    this.onCtaTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spaceXl),
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? (constraints.maxHeight - AppConstants.spaceXl * 2).clamp(
                    0,
                    double.infinity,
                  )
                : 0,
          ),
          child: Center(
            child: FadeSlideIn(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurfaceOf(context),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: 38,
                      color: AppColors.primaryOf(context),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceLg),
                  Text(
                    title,
                    style: AppTextStyles.h3Bold.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      subtitle,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (ctaLabel != null && onCtaTap != null) ...[
                    const SizedBox(height: AppConstants.spaceLg),
                    OutlinedButton(
                      onPressed: onCtaTap,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: Text(ctaLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
