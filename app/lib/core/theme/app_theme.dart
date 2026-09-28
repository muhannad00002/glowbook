import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'tokens.dart';

/// The single source of styling. Screens use `context.text.*`, `context.colors.*`
/// and `context.glow.*` — never raw fonts, hex values or ad-hoc shapes.
abstract final class AppTheme {
  static ThemeData light(Locale locale) => _build(
        locale: locale,
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Palette.rosewood,
          onPrimary: Colors.white,
          primaryContainer: Palette.rosewoodSoft,
          onPrimaryContainer: Palette.rosewoodDeep,
          secondary: Palette.champagne,
          onSecondary: Colors.white,
          secondaryContainer: Palette.champagneSoft,
          onSecondaryContainer: Color(0xFF4A3120),
          tertiary: Palette.sage,
          onTertiary: Colors.white,
          tertiaryContainer: Palette.sageSoft,
          onTertiaryContainer: Color(0xFF1F3A30),
          error: Color(0xFFB3261E),
          onError: Colors.white,
          errorContainer: Color(0xFFF9DEDC),
          onErrorContainer: Color(0xFF410E0B),
          surface: Colors.white,
          onSurface: Palette.ink,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Palette.porcelain,
          surfaceContainer: Palette.linen,
          surfaceContainerHigh: Color(0xFFEDE6E1),
          surfaceContainerHighest: Palette.sand,
          onSurfaceVariant: Palette.inkMuted,
          outline: Color(0xFFBFB3AB),
          outlineVariant: Palette.sand,
          shadow: Color(0xFF2A2330),
          scrim: Color(0xFF2A2330),
          inverseSurface: Palette.ink,
          onInverseSurface: Palette.porcelain,
          inversePrimary: Palette.blush,
        ),
        scaffold: Palette.porcelain,
        glow: GlowColors.light,
      );

  static ThemeData dark(Locale locale) => _build(
        locale: locale,
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Palette.blush,
          onPrimary: Color(0xFF3E1827),
          primaryContainer: Palette.blushDeep,
          onPrimaryContainer: Color(0xFFFFD9E3),
          secondary: Palette.gold,
          onSecondary: Color(0xFF3F2A14),
          secondaryContainer: Color(0xFF4A3827),
          onSecondaryContainer: Color(0xFFFBE2C8),
          tertiary: Palette.mint,
          onTertiary: Color(0xFF12332A),
          tertiaryContainer: Color(0xFF28443A),
          onTertiaryContainer: Color(0xFFCDEBDF),
          error: Color(0xFFF2B8B5),
          onError: Color(0xFF601410),
          errorContainer: Color(0xFF8C1D18),
          onErrorContainer: Color(0xFFF9DEDC),
          surface: Palette.nightSurface,
          onSurface: Palette.moon,
          surfaceContainerLowest: Palette.night,
          surfaceContainerLow: Color(0xFF1A161C),
          surfaceContainer: Palette.nightRaised,
          surfaceContainerHigh: Color(0xFF322B38),
          surfaceContainerHighest: Palette.nightOutline,
          onSurfaceVariant: Palette.moonMuted,
          outline: Color(0xFF6A5F6E),
          outlineVariant: Palette.nightOutline,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: Palette.moon,
          onInverseSurface: Palette.ink,
          inversePrimary: Palette.rosewood,
        ),
        scaffold: Palette.night,
        glow: GlowColors.dark,
      );

  static bool _isArabic(Locale l) => l.languageCode == 'ar';

  static TextTheme _text(Locale locale, Color ink, Color muted) {
    final ar = _isArabic(locale);
    TextStyle display(double size, FontWeight w, {double h = 1.15}) =>
        (ar ? GoogleFonts.notoNaskhArabic : GoogleFonts.playfairDisplay)(
          fontSize: size,
          fontWeight: w,
          height: ar ? h + 0.25 : h,
          color: ink,
          letterSpacing: ar ? 0 : -0.3,
        );
    TextStyle body(double size, FontWeight w, {Color? color, double h = 1.45, double ls = 0}) =>
        (ar ? GoogleFonts.ibmPlexSansArabic : GoogleFonts.inter)(
          fontSize: size,
          fontWeight: w,
          height: ar ? h + 0.15 : h,
          color: color ?? ink,
          letterSpacing: ar ? 0 : ls,
        );

    return TextTheme(
      displayLarge: display(44, FontWeight.w600),
      displayMedium: display(36, FontWeight.w600),
      displaySmall: display(30, FontWeight.w600),
      headlineLarge: display(28, FontWeight.w600),
      headlineMedium: display(24, FontWeight.w600),
      headlineSmall: display(21, FontWeight.w600, h: 1.2),
      titleLarge: body(19, FontWeight.w600, h: 1.3, ls: -0.2),
      titleMedium: body(16, FontWeight.w600, h: 1.35, ls: -0.1),
      titleSmall: body(14, FontWeight.w600, h: 1.35),
      bodyLarge: body(16, FontWeight.w400),
      bodyMedium: body(14.5, FontWeight.w400),
      bodySmall: body(13, FontWeight.w400, color: muted),
      labelLarge: body(15, FontWeight.w600, ls: 0.1),
      labelMedium: body(13, FontWeight.w600, ls: 0.2),
      labelSmall: body(12, FontWeight.w600, color: muted, ls: 0.3),
    );
  }

  static ThemeData _build({
    required Locale locale,
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
    required GlowColors glow,
  }) {
    final text = _text(locale, scheme.onSurface, scheme.onSurfaceVariant);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: text,
      extensions: [glow],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: isDark ? 0.8 : 0.7)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
          foregroundColor: scheme.onSurface,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainer : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.lg),
        border: OutlineInputBorder(borderRadius: Radii.mdAll, borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: Radii.mdAll, borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: Radii.mdAll, borderSide: BorderSide(color: scheme.primary, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: Radii.mdAll, borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: Radii.mdAll, borderSide: BorderSide(color: scheme.error, width: 1.6)),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: Space.md,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
        titleTextStyle: text.headlineSmall,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHigh),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelMedium,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scaffold,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.primaryContainer),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: Radii.smAll),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}
