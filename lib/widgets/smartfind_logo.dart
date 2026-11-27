import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Renders the smartFind brand mark — a heart formed by two interlocking hands
/// (left half blue #0055A4, right half green #009B77, white gaps between
/// fingers).
///
/// Uses the bundled PNG asset `assets/images/logo_heart_hands.png` for the
/// image. Falls back to a simplified programmatic heart if the asset fails
/// to load.
class SmartfindMark extends StatelessWidget {
  const SmartfindMark({super.key, this.size = 120, this.color});

  final double size;

  /// Colour of the fallback icon; defaults to the theme's primary colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/logo_heart_hands.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback: simple heart icon if the asset fails to load.
          return Icon(
            Icons.favorite_rounded,
            size: size * 0.8,
            color: color ?? AppColors.primaryOf(context),
          );
        },
      ),
    );
  }
}

/// Full smartFind logo: mark + wordmark + optional tagline.
class SmartfindLogo extends StatelessWidget {
  const SmartfindLogo({
    super.key,
    this.markSize = 64,
    this.wordmarkSize = 32,
    this.showTagline = false,
    this.taglineText = 'Lost Items. Found Faster.',
    this.subTaglineText = 'Report · Search · Reunite',
    this.color,
    this.alignment = MainAxisAlignment.start,
    this.axis = Axis.horizontal,
  });

  final double markSize;
  final double wordmarkSize;
  final bool showTagline;
  final String taglineText;
  final String subTaglineText;
  final Color? color;
  final MainAxisAlignment alignment;
  final Axis axis;

  // Brand colours of the logo, with lighter tints for dark backgrounds.
  static const Color _blue = Color(0xFF0055A4);
  static const Color _green = Color(0xFF009B77);
  static const Color _blueOnDark = Color(0xFF7FB2EA);
  static const Color _greenOnDark = Color(0xFF4FCBA7);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mark = SmartfindMark(size: markSize, color: color);

    final wordmark = RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'InstrumentSans',
          fontWeight: FontWeight.w700,
          fontSize: wordmarkSize,
          letterSpacing: -1.5,
          height: 1.1,
        ),
        children: [
          TextSpan(
            text: 'smart',
            style: TextStyle(color: dark ? _blueOnDark : _blue),
          ),
          TextSpan(
            text: 'Find',
            style: TextStyle(color: dark ? _greenOnDark : _green),
          ),
        ],
      ),
    );

    final taglines = showTagline
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                taglineText,
                style: TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: wordmarkSize * 0.32,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subTaglineText,
                style: TextStyle(
                  fontFamily: 'InstrumentSans',
                  fontSize: wordmarkSize * 0.25,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          )
        : const SizedBox.shrink();

    if (axis == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          mark,
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              wordmark,
              if (showTagline) ...[const SizedBox(height: 4), taglines],
            ],
          ),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          mark,
          const SizedBox(height: 16),
          wordmark,
          if (showTagline) ...[const SizedBox(height: 8), taglines],
        ],
      );
    }
  }
}

/// App launcher icon — squircle background with the brand mark.
class SmartfindAppIcon extends StatelessWidget {
  const SmartfindAppIcon({
    super.key,
    this.size = 160,
    this.backgroundColor,
    this.cornerRadius,
  });

  final double size;
  final Color? backgroundColor;
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    final radius = cornerRadius ?? size * 0.21;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: backgroundColor ?? AppColors.primaryOf(context),
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.all(size * 0.04),
          child: Image.asset(
            'assets/images/logo_heart_hands.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
