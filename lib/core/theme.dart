// DDE-Mart handyman app — design system.
//
// Brand: orange primary on soft neutral surfaces. Modern sleek reskin:
// full type scale, generous radii, soft layered shadows, orange gradient
// heroes, floating pill bottom bar. Dark mode fully supported — no
// hardcoded off-theme colors on screens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DdeHandymanTheme {
  static const primary = Color(0xFFEA580C);
  static const primaryDeep = Color(0xFFC2410C);
  static const accent = Color(0xFFF59E0B);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFE11D48);

  static const radiusCard = 22.0;
  static const radiusCardSm = 20.0;
  static const radiusSheet = 28.0;
  static const radiusPill = 999.0;
  static const pad = 16.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: accent,
      brightness: Brightness.light,
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: accent,
      brightness: Brightness.dark,
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final text = _typeScale(scheme);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSheet),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
      chipTheme: scheme.brightness == Brightness.dark
          ? null
          : ChipThemeData(
              backgroundColor: scheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusPill),
              ),
            ),
    );
  }

  /// Full type scale: display w800 -0.5, titles w700, body/labels regular.
  static TextTheme _typeScale(ColorScheme scheme) {
    TextStyle base(double size, FontWeight weight, double spacing,
        {double? height}) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
        color: scheme.onSurface,
      );
    }

    return TextTheme(
      displayLarge: base(40, FontWeight.w800, -0.5, height: 1.1),
      displayMedium: base(32, FontWeight.w800, -0.5, height: 1.15),
      displaySmall: base(26, FontWeight.w800, -0.5, height: 1.2),
      headlineLarge: base(24, FontWeight.w800, -0.5),
      headlineMedium: base(22, FontWeight.w700, -0.5),
      headlineSmall: base(20, FontWeight.w700, -0.5),
      titleLarge: base(19, FontWeight.w700, -0.2),
      titleMedium: base(16, FontWeight.w700, -0.1),
      titleSmall: base(14, FontWeight.w700, 0),
      bodyLarge: base(16, FontWeight.w400, 0),
      bodyMedium: base(14, FontWeight.w400, 0),
      bodySmall: base(12, FontWeight.w400, 0),
      labelLarge: base(14, FontWeight.w700, 0),
      labelMedium: base(12, FontWeight.w700, 0.2),
      labelSmall: base(11, FontWeight.w700, 0.4),
    );
  }

  /// Soft layered card shadow that adapts to brightness.
  static List<BoxShadow> softShadow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: dark
            ? Colors.black.withValues(alpha: 0.35)
            : const Color(0xFFEA580C).withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: dark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Orange -> deep-orange hero gradient (adapts to dark mode).
  static LinearGradient headerGradient(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9A3412), Color(0xFF431407)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, primaryDeep],
    );
  }

  static LinearGradient accentGradient(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFFB45309), Color(0xFF92400E)]
          : const [accent, primary],
    );
  }

  static LinearGradient successGradient(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF22C55E), Color(0xFF15803D)]
          : const [Color(0xFF16A34A), Color(0xFF15803D)],
    );
  }

  static BoxDecoration headerDecoration(BuildContext context) {
    return BoxDecoration(gradient: headerGradient(context));
  }

  /// Floating bottom-bar container: rounded 24, margin 12, soft shadow.
  static BoxDecoration navBarDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      boxShadow: softShadow(context),
    );
  }
}

/// App theme mode (system / light / dark), persisted locally.
class ThemeModeStore extends StateNotifier<ThemeMode> {
  ThemeModeStore() : super(ThemeMode.system) {
    _restore();
  }

  static const _key = 'ui.theme_mode';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Corrupt prefs never block launch.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeStore, ThemeMode>(
  (ref) => ThemeModeStore(),
);
