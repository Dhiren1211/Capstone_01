import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// The one container style used for list rows, panels and tiles:
/// white surface, soft blue-tinted shadow, 24 px radius, optional tap
/// feedback. Pass [borderColor] only when a card needs an outline (e.g. to
/// mark a selected state).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.borderColor,
    this.radius = 24,
    this.clip = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    // The shadow sits on an outer box and the clip on an inner one, so
    // clipping the content never cuts the shadow off.
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: AppColors.softShadowOf(context),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color ?? AppColors.cardOf(context),
          borderRadius: br,
          border: borderColor == null ? null : Border.all(color: borderColor!),
        ),
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, borderRadius: br, child: card);
  }
}
