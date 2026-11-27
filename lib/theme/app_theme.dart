import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 theme for smartFind (light + dark), built from the colour tokens
/// in [AppColors] and the bundled Instrument Sans font.
class AppTheme {
  AppTheme._();

  /// Instrument Sans is bundled under assets/fonts (declared in pubspec.yaml), so the
  /// app never downloads fonts at run time and works fully offline.
  static const String fontFamily = 'InstrumentSans';

  static const double _radius = 14;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final primary = dark ? AppColors.darkPrimary : AppColors.primary;
    final onPrimary = dark ? AppColors.darkOnPrimary : AppColors.surface;
    final background = dark ? AppColors.darkBackground : AppColors.background;
    final surface = dark ? AppColors.darkSurface : AppColors.surface;
    final card = dark ? AppColors.darkCardBackground : AppColors.surface;
    final border = dark ? AppColors.darkBorder : AppColors.border;
    final textPrimary = dark ? AppColors.darkTextPrimary : AppColors.navy;
    final textSecondary = dark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final textTertiary = dark
        ? AppColors.darkTextTertiary
        : AppColors.textTertiary;
    final chipIdle = dark ? AppColors.darkChipIdle : AppColors.chipIdle;
    final primarySurface = dark
        ? AppColors.darkPrimarySurface
        : AppColors.primarySurface;
    final error = dark ? AppColors.darkErrorFg : AppColors.error;

    final scheme = (dark ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(
          primary: primary,
          onPrimary: onPrimary,
          primaryContainer: primarySurface,
          onPrimaryContainer: dark
              ? AppColors.darkTextPrimary
              : AppColors.primaryDark,
          secondary: dark ? AppColors.darkPrimary : AppColors.accent,
          onSecondary: dark ? AppColors.darkOnPrimary : AppColors.surface,
          surface: surface,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          surfaceContainerHighest: chipIdle,
          error: error,
          onError: dark ? AppColors.darkOnPrimary : AppColors.surface,
          outline: border,
          outlineVariant: border,
          shadow: const Color(0xFF000000),
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
    );

    TextStyle label(double size, FontWeight w) =>
        TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: w);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      splashFactory: InkSparkle.splashFactory,
      // Smooth, consistent screen transitions on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 24),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: label(14, FontWeight.w400).copyWith(color: textTertiary),
        labelStyle: label(14, FontWeight.w500).copyWith(color: textSecondary),
        floatingLabelStyle: label(13, FontWeight.w500).copyWith(color: primary),
        errorStyle: label(12, FontWeight.w400).copyWith(color: error),
        errorMaxLines: 3,
        helperMaxLines: 3,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: error, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: border),
        ),
        prefixIconColor: textTertiary,
        suffixIconColor: textTertiary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: border,
          disabledForegroundColor: textTertiary,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: shape,
          textStyle: label(16, FontWeight.w600).copyWith(letterSpacing: -0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: card,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: border, width: 1),
          shape: shape,
          textStyle: label(16, FontWeight.w600).copyWith(letterSpacing: -0.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: label(15, FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: primarySurface,
        labelStyle: label(13, FontWeight.w500).copyWith(color: textPrimary),
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: shape,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onPrimary : textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : chipIdle,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : border,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primarySurface,
        circularTrackColor: primarySurface,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: textTertiary.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: label(
          19,
          FontWeight.w600,
        ).copyWith(color: textPrimary, letterSpacing: -0.4),
        contentTextStyle: label(
          14,
          FontWeight.w400,
        ).copyWith(color: textSecondary, height: 1.5),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: dark ? AppColors.darkPrimary : AppColors.accent,
        dividerColor: border,
        labelStyle: label(14, FontWeight.w600),
        unselectedLabelStyle: label(14, FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primarySurface,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => label(11, FontWeight.w600).copyWith(
            color: s.contains(WidgetState.selected)
                ? textPrimary
                : textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? primary : textSecondary,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? AppColors.darkChipIdle : AppColors.navy,
        contentTextStyle: label(
          14,
          FontWeight.w500,
        ).copyWith(color: dark ? AppColors.darkTextPrimary : AppColors.surface),
        actionTextColor: dark ? AppColors.darkPrimary : AppColors.accentSurface,
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
    );
  }
}
