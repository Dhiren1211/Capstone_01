import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/constants.dart';
import 'motion.dart';

/// Pill-style category filter used on the home + search screens.
///
/// Selected: a solid ink pill. Idle: a hairline-outlined pill on the card
/// colour, so the active filter reads at a glance.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    this.onTap,
  });

  final ItemCategory category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppColors.backgroundOf(context)
        : AppColors.textSecondaryOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: category.label,
      child: Pressable(
        onTap: onTap,
        scale: 0.95,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.textPrimaryOf(context)
                : AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? AppColors.textPrimaryOf(context)
                  : AppColors.borderOf(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 16, color: fg),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                child: Text(category.label, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
