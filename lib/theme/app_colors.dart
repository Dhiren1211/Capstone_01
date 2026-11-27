import 'package:flutter/material.dart';

/// Colour tokens for smartFind.
///
/// Palette "Campus Ink": warm paper backgrounds, near-black ink text, the
/// logo's deep blue as the single brand colour, the logo's green for "found"
/// and a warm vermillion for "lost". Surfaces are separated by hairlines and
/// quiet neutral shadows instead of coloured glows. Every text colour meets
/// WCAG AA (4.5:1) on the surface it is used on, in light and dark mode.
///
/// Three layers:
///  1. raw palette (private `_` values below),
///  2. semantic tokens (`primary`, `surface`, `border` ...) - what widgets use,
///  3. context-aware accessors (`primaryOf(context)` ...) - pick the light or
///     the dark value from the current [Theme].
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------- raw palette
  static const Color _blue800 = Color(0xFF083B7D);
  static const Color _blue700 = Color(0xFF0A4DA2); // logo blue, text-safe
  static const Color _blue300 = Color(0xFF86B6EC);
  static const Color _blue100 = Color(0xFFD9E5F5);
  static const Color _blue50 = Color(0xFFE8EEF7);

  static const Color _ink = Color(0xFF16181D);
  static const Color _paper = Color(0xFFF6F5F1);
  static const Color _line = Color(0xFFE6E3DB);
  static const Color _lineSoft = Color(0xFFEEECE6);

  // ---------------------------------------------------------- semantic (light)
  static const Color primary = _blue700;
  static const Color primaryDark = _blue800;
  static const Color primaryLight = _blue100;

  /// Quiet blue tint for selected states, icon tiles and highlights.
  static const Color primarySurface = _blue50;

  /// Accent = the brand blue in its text-safe shade ("See all", links).
  static const Color accent = _blue700;
  static const Color accentDark = _blue800;
  static const Color accentSurface = _blue50;

  /// Bright accent for non-text decoration (dots, indicators, markers).
  static const Color accentBright = Color(0xFF1F6FD1);

  /// "Found" green (the logo green) and "lost" vermillion, for dots / marks.
  static const Color fresh = Color(0xFF009B77);
  static const Color heart = Color(0xFFE2553F);

  static const Color navy = _ink;
  static const Color slate800 = Color(0xFF24272E);
  static const Color slate700 = Color(0xFF3A3E47);
  static const Color textSecondary = Color(0xFF565A64);
  static const Color textTertiary = Color(0xFF6B6F7A);
  static const Color border = _line;
  static const Color divider = _lineSoft;
  static const Color background = _paper;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color chipIdle = _lineSoft;

  static const Color success = Color(0xFF009B77);
  static const Color successBg = Color(0xFFDCF2E9);
  static const Color successFg = Color(0xFF00694E);
  static const Color error = Color(0xFFD5432E);
  static const Color errorBg = Color(0xFFFCE8E3);
  static const Color errorFg = Color(0xFFB3301F);
  static const Color warning = Color(0xFFC26A05);
  static const Color warningBg = Color(0xFFFDF0D5);

  static const Color mapMarker = _blue700;
  static const Color mapMarkerSelected = heart;
  static const Color mapUserDot = Color(0xFF009B77);
  static const Color mapUserRing = Color(0x4D009B77);

  // ----------------------------------------------------------- semantic (dark)
  static const Color darkBackground = Color(0xFF0E0F12);
  static const Color darkSurface = Color(0xFF16181C);
  static const Color darkCardBackground = Color(0xFF1B1E23);
  static const Color darkBorder = Color(0xFF2A2E35);
  static const Color darkChipIdle = Color(0xFF23262C);
  static const Color darkPrimary = _blue300;
  static const Color darkOnPrimary = Color(0xFF06172E);
  static const Color darkPrimarySurface = Color(0xFF1A2638);
  static const Color darkTextPrimary = Color(0xFFF1F0EC);
  static const Color darkTextSecondary = Color(0xFFA8ACB5);
  static const Color darkTextTertiary = Color(0xFF8E929C);
  static const Color darkNavy = Color(0xFFF1F0EC);

  static const Color darkErrorBg = Color(0xFF3A1A15);
  static const Color darkErrorFg = Color(0xFFFFA593);
  static const Color darkSuccessBg = Color(0xFF0F2E24);
  static const Color darkSuccessFg = Color(0xFF6FDBB5);
  static const Color darkPrimaryLight = Color(0xFF1A2638);

  // -------------------------------------------------------- context accessors
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Brand colour for filled controls and emphasised text.
  static Color primaryOf(BuildContext context) =>
      isDark(context) ? darkPrimary : primary;

  /// Text/icon colour that sits ON [primaryOf].
  static Color onPrimaryOf(BuildContext context) =>
      isDark(context) ? darkOnPrimary : surface;

  /// Accent colour that is readable on the current surface.
  static Color accentOf(BuildContext context) =>
      isDark(context) ? _blue300 : accent;

  static Color accentSurfaceOf(BuildContext context) =>
      isDark(context) ? darkPrimarySurface : accentSurface;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color cardOf(BuildContext context) =>
      isDark(context) ? darkCardBackground : cardBackground;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color dividerOf(BuildContext context) =>
      isDark(context) ? darkBorder : divider;

  static Color chipIdleOf(BuildContext context) =>
      isDark(context) ? darkChipIdle : chipIdle;

  static Color primarySurfaceOf(BuildContext context) =>
      isDark(context) ? darkPrimarySurface : primarySurface;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : navy;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color textTertiaryOf(BuildContext context) =>
      isDark(context) ? darkTextTertiary : textTertiary;

  static Color errorBgOf(BuildContext context) =>
      isDark(context) ? darkErrorBg : errorBg;

  static Color errorFgOf(BuildContext context) =>
      isDark(context) ? darkErrorFg : errorFg;

  static Color successBgOf(BuildContext context) =>
      isDark(context) ? darkSuccessBg : successBg;

  static Color successFgOf(BuildContext context) =>
      isDark(context) ? darkSuccessFg : successFg;

  static Color warningBgOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF33270F) : warningBg;

  /// Neutral shadow colour for raised surfaces.
  static Color shadowOf(BuildContext context) =>
      isDark(context) ? const Color(0x66000000) : const Color(0x0F16181D);

  /// Standard quiet elevation used by cards, sheets and floating controls:
  /// a tight contact shadow plus a wide, very soft ambient one.
  static List<BoxShadow> softShadowOf(BuildContext context) => isDark(context)
      ? const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0D16181D),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0F16181D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ];

  /// Shadow under the primary CTA: a low, brand-tinted lift.
  static List<BoxShadow> ctaShadowOf(BuildContext context) => [
    BoxShadow(
      color: isDark(context)
          ? const Color(0x59000000)
          : const Color(0x330A4DA2),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  /// Brand gradient for hero areas: deep logo blue into night ink.
  static LinearGradient heroGradientOf(BuildContext context) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark(context)
        ? const [Color(0xFF173A6B), Color(0xFF0B1A33)]
        : const [Color(0xFF1659B0), Color(0xFF062A5C)],
  );

  /// Full-bleed onboarding sky (used when no photo is available).
  static const LinearGradient onboardingGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF6E9FDA),
      Color(0xFF1659B0),
      Color(0xFF0A3F86),
      Color(0xFF061F45),
    ],
    stops: [0, 0.35, 0.65, 1],
  );

  /// Splash background.
  static LinearGradient splashGradientOf(BuildContext context) {
    final c = backgroundOf(context);
    return LinearGradient(colors: [c, c]);
  }

  /// Backward-compat flat "gradient".
  static const LinearGradient splashGradient = LinearGradient(
    colors: [_paper, _paper],
  );
}
