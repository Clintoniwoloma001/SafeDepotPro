// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 theming for SafeDepot Pro.
///
/// Light and dark schemes are both hand-tuned rather than generated so that
/// contrast stays predictable across the dense, data-heavy screens the app is
/// built from (tables, status chips, KPI tiles).
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    // Seed from the shield red but force the primary surface to that exact
    // colour: seeding alone yields a harmonised tint that drifts from the icon.
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandLight,
      brightness: brightness,
      primary: AppColors.brandLight,
      onPrimary: AppColors.onBrandLight,
      primaryContainer: brightness == Brightness.light
          ? AppColors.brandContainerLight
          : const Color(0xFF8C1D18),
      onPrimaryContainer: brightness == Brightness.light
          ? AppColors.onBrandContainerLight
          : const Color(0xFFFFDAD6),
    );
    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
    );

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: scheme.outlineVariant,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: _inputBorder(scheme, scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme, scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme, scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme, scheme.error),
        focusedErrorBorder: _inputBorder(scheme, scheme.error, width: 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(
    ColorScheme scheme,
    Color color, {
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
