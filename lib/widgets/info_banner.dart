import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum BannerTone { info, success, warning, error }

/// Inline message box. The text always wraps - it never overflows.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = BannerTone.info,
    this.icon,
    this.action,
  });

  final String message;
  final String? title;
  final BannerTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, defaultIcon) = switch (tone) {
      BannerTone.info => (
        AppColors.primarySurfaceOf(context),
        AppColors.primaryOf(context),
        Icons.info_outline_rounded,
      ),
      BannerTone.success => (
        AppColors.successBgOf(context),
        AppColors.successFgOf(context),
        Icons.check_circle_outline_rounded,
      ),
      BannerTone.warning => (
        AppColors.warningBgOf(context),
        AppColors.warning,
        Icons.warning_amber_rounded,
      ),
      BannerTone.error => (
        AppColors.errorBgOf(context),
        AppColors.errorFgOf(context),
        Icons.error_outline_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 20, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                Text(
                  message,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    height: 1.5,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
