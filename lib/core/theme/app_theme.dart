// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// The user's theme preference, persisted across launches.
enum ThemePreference { system, light, dark }

/// Owns the persisted theme choice.
///
/// The choice is written synchronously on change so the toggle feels immediate
/// even on a slow device, and read back on the next cold start.
final themePreferenceProvider =
    NotifierProvider<ThemePreferenceNotifier, ThemePreference>(
  ThemePreferenceNotifier.new,
);

class ThemePreferenceNotifier extends Notifier<ThemePreference> {
  @override
  ThemePreference build() {
    // Restored after the initial build so the first frame is not blocked on
    // SharedPreferences; the persisted value then replaces the default.
    SharedPreferences.getInstance().then(_restore);
    return ThemePreference.system;
  }

  static const storageKey = 'theme_preference';

  void _restore(SharedPreferences prefs) {
    final stored = prefs.getString(storageKey);
    if (stored == null) return;
    state = ThemePreference.values.firstWhere(
      (v) => v.name == stored,
      orElse: () => ThemePreference.system,
    );
  }

  Future<void> set(ThemePreference value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value.name);
  }

  /// Cycles system → light → dark → system, for a control that has no label
  /// space. Used by the compact app-bar toggle.
  Future<void> cycle() => set(switch (state) {
        ThemePreference.system => ThemePreference.light,
        ThemePreference.light => ThemePreference.dark,
        ThemePreference.dark => ThemePreference.system,
      });
}

/// ThemeData pair plus the mode requested by the user.
///
/// Kept in one provider so a screen can watch a single object and get both the
/// data and the mode without a second lookup.
class AppThemeState {
  const AppThemeState({
    required this.light,
    required this.dark,
    required this.mode,
    required this.preference,
  });

  final ThemeData light;
  final ThemeData dark;
  final ThemeMode mode;
  final ThemePreference preference;
}

final appThemeProvider = Provider<AppThemeState>((ref) {
  final preference = ref.watch(themePreferenceProvider);
  return AppThemeState(
    light: buildLightTheme(),
    dark: buildDarkTheme(),
    mode: modeFor(preference),
    preference: preference,
  );
});

/// Maps the persisted preference to a [ThemeMode].
ThemeMode modeFor(ThemePreference preference) => switch (preference) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
    };

/// Builds the light theme from tokens. Never seeds from a Material colour.
ThemeData buildLightTheme() => _base(
      colorScheme: const ColorScheme.light(
        primary: AppTokens.brandRed,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFFFE1E1),
        onPrimaryContainer: Color(0xFF410000),
        secondary: Color(0xFF4A4A4F),
        onSecondary: Colors.white,
        error: AppTokens.bad,
        onError: Colors.white,
        errorContainer: Color(0xFFFCE8E6),
        onErrorContainer: Color(0xFF410001),
        surface: AppTokens.lightSurface,
        onSurface: AppTokens.lightText,
        onSurfaceVariant: AppTokens.lightTextSecondary,
        outline: AppTokens.lightOutline,
        outlineVariant: Color(0xFFF0F0F1),
      ),
      background: AppTokens.lightBackground,
      ext: AppColorsExtension.light,
    );

ThemeData buildDarkTheme() => _base(
      colorScheme: const ColorScheme.dark(
        primary: AppTokens.brandRedOnDark,
        onPrimary: Color(0xFF1A0000),
        primaryContainer: Color(0xFF8C0009),
        onPrimaryContainer: Color(0xFFFFDAD6),
        secondary: AppTokens.darkTextSecondary,
        onSecondary: Color(0xFF1A1A1C),
        error: Color(0xFFFF8A80),
        onError: Color(0xFF410001),
        errorContainer: Color(0xFF4A1C1A),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: AppTokens.darkSurface,
        onSurface: AppTokens.darkText,
        onSurfaceVariant: AppTokens.darkTextSecondary,
        outline: AppTokens.darkOutline,
        outlineVariant: Color(0xFF242427),
      ),
      background: AppTokens.darkBackground,
      ext: AppColorsExtension.dark,
    );

ThemeData _base({
  required ColorScheme colorScheme,
  required Color background,
  required AppColorsExtension ext,
}) {
  final text = _textTheme;
  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: colorScheme.brightness,
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: background,
  );

  return base.copyWith(
    textTheme: text,
    extensions: <ThemeExtension<dynamic>>[ext],
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(color: colorScheme.outline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      border: _border(colorScheme.outline),
      enabledBorder: _border(colorScheme.outline),
      focusedBorder: _border(AppTokens.brandRed, width: 1.5),
      errorBorder: _border(colorScheme.error),
      focusedErrorBorder: _border(colorScheme.error, width: 1.5),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceMd,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size(0, AppTokens.touchTarget),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        minimumSize: const Size(0, AppTokens.touchTarget),
        side: BorderSide(color: colorScheme.outline),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ext.brandRed,
        minimumSize: const Size(0, AppTokens.touchTarget),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.onSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: colorScheme.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: ext.activeNavTint,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusSm)),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      side: BorderSide(color: colorScheme.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      labelStyle: text.labelMedium,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: colorScheme.outlineVariant,
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: AppTokens.spaceSm,
      iconColor: colorScheme.onSurfaceVariant,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.outline),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

OutlineInputBorder _border(Color color, {double width = 1}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );

/// The pinned type scale.
///
/// Line heights are set as multiples of the size rather than absolute pixels,
/// so 130% text scaling does not clip descenders.
final TextTheme _textTheme = const TextTheme(
  displaySmall: TextStyle(fontSize: AppTokens.displaySmall, fontWeight: FontWeight.w800, height: 1.2),
  headlineMedium: TextStyle(fontSize: AppTokens.headlineMedium, fontWeight: FontWeight.w700, height: 1.25),
  headlineSmall: TextStyle(fontSize: AppTokens.headlineSmall, fontWeight: FontWeight.w700, height: 1.3),
  titleLarge: TextStyle(fontSize: AppTokens.titleLarge, fontWeight: FontWeight.w700, height: 1.35),
  titleMedium: TextStyle(fontSize: AppTokens.titleMedium, fontWeight: FontWeight.w600, height: 1.4),
  titleSmall: TextStyle(fontSize: AppTokens.titleSmall, fontWeight: FontWeight.w600, height: 1.4),
  bodyLarge: TextStyle(fontSize: AppTokens.bodyLarge, fontWeight: FontWeight.w400, height: 1.5),
  bodyMedium: TextStyle(fontSize: AppTokens.bodyMedium, fontWeight: FontWeight.w400, height: 1.5),
  bodySmall: TextStyle(fontSize: AppTokens.bodySmall, fontWeight: FontWeight.w400, height: 1.45),
  labelLarge: TextStyle(fontSize: AppTokens.labelLarge, fontWeight: FontWeight.w600, height: 1.3),
  labelMedium: TextStyle(fontSize: AppTokens.labelMedium, fontWeight: FontWeight.w500, height: 1.3),
  labelSmall: TextStyle(fontSize: AppTokens.labelSmall, fontWeight: FontWeight.w500, height: 1.3),
);
