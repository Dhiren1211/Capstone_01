import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';

/// Small tag showing Lost / Found / Reunited.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.compact = false});

  final ItemStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      ItemStatus.lost => (
        AppColors.errorBgOf(context),
        AppColors.errorFgOf(context),
      ),
      ItemStatus.found => (
        AppColors.successBgOf(context),
        AppColors.successFgOf(context),
      ),
      ItemStatus.reunited => (
        AppColors.primarySurfaceOf(context),
        AppColors.primaryOf(context),
      ),
    };
    final dot = switch (status) {
      ItemStatus.lost => AppColors.heart,
      ItemStatus.found => AppColors.fresh,
      ItemStatus.reunited => AppColors.primaryOf(context),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            status.label.toUpperCase(),
            maxLines: 1,
            style: AppTextStyles.overline.copyWith(
              color: fg,
              fontSize: compact ? 9.5 : 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Green check shown next to a report an admin has verified.
class VerifiedMark extends StatelessWidget {
  const VerifiedMark({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Verified by smartFind admins',
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.verified_rounded,
          size: size,
          color: AppColors.success,
          semanticLabel: 'Verified',
        ),
      ),
    );
  }
}
