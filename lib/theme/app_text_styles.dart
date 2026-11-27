import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for smartFind (Instrument Sans, bundled in assets/fonts).
///
/// Styles deliberately carry NO colour (except [button] / [tagline]) so they
/// inherit the right one from the surrounding [DefaultTextStyle] in light and
/// dark mode. Wrap with `.copyWith(color: ...)` where a colour is needed.
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'InstrumentSans';

  static TextStyle get _base => const TextStyle(fontFamily: _fontFamily);

  /// Display - 32 / 600 - hero numbers and welcome titles.
  static TextStyle get display => _base.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -1.1,
  );

  /// H1 - 26 / 600 - screen titles.
  static TextStyle get h1 => _base.copyWith(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.8,
  );

  /// H2 - 20 / 600 - section headers.
  static TextStyle get h2 => _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.5,
  );

  /// H3 - 17 / 500 - sub-section headers, list titles.
  static TextStyle get h3 => _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: -0.2,
  );

  /// H3 Bold - 17 / 600 - card titles and section headers.
  static TextStyle get h3Bold => _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.3,
  );

  /// Body - 15 / 400 - descriptions and content.
  static TextStyle get body =>
      _base.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5);

  /// Body Medium - 15 / 500.
  static TextStyle get bodyMedium =>
      _base.copyWith(fontSize: 15, fontWeight: FontWeight.w500, height: 1.45);

  /// Caption - 13 / 400 - timestamps, hints, metadata.
  static TextStyle get caption =>
      _base.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4);

  /// Caption Medium - 13 / 500.
  static TextStyle get captionMedium =>
      _base.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);

  /// Micro - 12 / 400 - secondary line in dense lists (e.g. building titles
  /// beneath a building number).
  static TextStyle get micro =>
      _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.35);

  /// Button - 15 / 600.
  static TextStyle get button => _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.0,
    color: AppColors.surface,
    letterSpacing: 0.2,
  );

  /// Tab label - 12 / 500.
  static TextStyle get tabLabel => _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.0,
    letterSpacing: 0.3,
  );

  /// Overline / status badge - 10 / 700 / uppercase.
  static TextStyle get overline => _base.copyWith(
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: 0.8,
  );

  /// Tagline (logo subtitle).
  static TextStyle get tagline => _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Brand wordmark.
  static TextStyle brandWordmark({double size = 28}) => _base.copyWith(
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -1.0,
  );

  /// Helper for tests / const contexts (no getters involved).
  static TextStyle fallback({
    double size = 14,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: size,
    fontWeight: weight,
    color: AppColors.navy,
  );
}
