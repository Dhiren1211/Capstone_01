import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'motion.dart';

enum PrimaryButtonVariant { filled, outlined, text }

/// The app's main call-to-action button (full width by default).
///
/// Shows a spinner while [isLoading] and ignores taps in that state, so a
/// double tap can never submit a form twice.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.fullWidth = true,
    this.isLoading = false,
    this.variant = PrimaryButtonVariant.filled,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Optional icon after the label (e.g. an arrow on a "Book now" style CTA).
  final IconData? trailingIcon;
  final bool fullWidth;
  final bool isLoading;
  final PrimaryButtonVariant variant;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final base = destructive
        ? AppColors.errorFgOf(context)
        : AppColors.primaryOf(context);
    final filled = variant == PrimaryButtonVariant.filled;

    final fg = filled
        ? (destructive ? Colors.white : AppColors.onPrimaryOf(context))
        : base;
    final bg = filled ? base : Colors.transparent;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Pressable(
        onTap: disabled ? null : onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: onPressed == null && !isLoading ? 0.45 : 1,
          child: Container(
            width: fullWidth ? double.infinity : null,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: filled && !disabled && !destructive
                  ? AppColors.ctaShadowOf(context)
                  : null,
              border: variant == PrimaryButtonVariant.outlined
                  ? Border.all(color: AppColors.borderOf(context), width: 1.2)
                  : null,
            ),
            // heightFactor: 1 keeps the button as tall as its label. Without
            // it, Center grows to the full height its parent allows, which in
            // a Scaffold.bottomNavigationBar is the whole screen.
            child: Center(
              widthFactor: fullWidth ? null : 1,
              heightFactor: 1,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('spinner'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(fg),
                        ),
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 18, color: fg),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.button.copyWith(
                                color: fg,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (trailingIcon != null) ...[
                            const SizedBox(width: 10),
                            Icon(trailingIcon, size: 20, color: fg),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
