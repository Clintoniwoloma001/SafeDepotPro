// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

/// The single source of truth for colour, spacing, radius and type.
///
/// Every theme is derived from these tokens rather than from a Material seed:
/// a blue seed produces a blue app, and the brand is red. Anything that needs a
/// colour reads it from here, so light/dark/white-label changes are a single
/// edit.
library;

import 'package:flutter/material.dart';

abstract final class AppTokens {
  /// Brand red. Used for fills, the active indicator and the launcher icon.
  static const Color brandRed = Color(0xFFCC0000);

  /// Two reds are needed because a single one cannot satisfy contrast on both
  /// #FFFFFF and #0F0F10 within WCAG AA.
  /// On light surfaces, small text sits on #CC0000 itself, so white-on-red is
  /// the readable pairing. On dark surfaces #CC0000 has 2.0:1 contrast against
  /// #0F0F10, so text and icons use the lighter tint instead.
  static const Color brandRedOnDark = Color(0xFFFF5252);

  /// Accent gradient for hero elements only — never for body text or icons.
  static const List<Color> accentGradient = [
    Color(0xFFCC0000),
    Color(0xFFFF3333),
  ];

  // -------------------------------------------------------------------------
  // Light scheme
  // -------------------------------------------------------------------------
  static const Color lightBackground = Color(0xFFF7F7F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOutline = Color(0xFFE5E5E7);
  static const Color lightText = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF6B6B70);

  // -------------------------------------------------------------------------
  // Dark scheme
  // -------------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF0F0F10);
  static const Color darkSurface = Color(0xFF1A1A1C);
  static const Color darkElevated = Color(0xFF242427);
  static const Color darkOutline = Color(0xFF2E2E32);
  static const Color darkText = Color(0xFFF2F2F3);
  static const Color darkTextSecondary = Color(0xFFA0A0A8);

  // -------------------------------------------------------------------------
  // Semantic palette — one hue per meaning, resolved per mode.
  // -------------------------------------------------------------------------
  // Status/severity/priority labels are never shown to the person filling in a
  // checklist (the severity of a checklist item drives CAPA and escalation
  // only). They are shown everywhere else, which is why they are modelled
  // explicitly rather than borrowed from the enum names.
  static const Color good = Color(0xFF1E8E3E);
  static const Color warn = Color(0xFFE08C00);
  static const Color bad = Color(0xFFD93025);
  static const Color info = Color(0xFF1A73E8);
  static const Color neutral = Color(0xFF5F6368);

  /// Pastel surface + readable foreground pairs, per mode.
  ///
  /// Deliberately not generated from the base hue: the point of a chip is that
  /// the fill is quiet and the text is legible, which is the opposite of what
  /// `withValues(alpha:)` on a saturated base produces.
  static const List<Color> lightStatusChips = [
    Color(0xFFE6F4EA),
    Color(0xFFFEF7E0),
    Color(0xFFFCE8E6),
    Color(0xFFE8F0FE),
    Color(0xFFF1F3F4),
  ];

  static const List<Color> darkStatusChips = [
    Color(0xFF0B3D20),
    Color(0xFF4A3608),
    Color(0xFF4A1C1A),
    Color(0xFF172A54),
    Color(0xFF2E2E32),
  ];

  /// Foreground colours that stay AA-legible on the chips above.
  ///
  /// The dark chips are deep saturated tints (#0B3D20 and friends), not the
  /// light pastels, so their text is near-white rather than dark.
  static const Color lightStatusChipText = Color(0xFF1A1A1A);
  static const Color darkStatusChipText = Color(0xFFF2F2F3);

  /// Raised tint used for the active navigation indicator, applied at low alpha
  /// over the surface so it reads as a tint rather than a fill.
  static const Color activeNavTint = Color(0x1FCC0000);

  // -------------------------------------------------------------------------
  // Compliance scale
  // -------------------------------------------------------------------------
  /// Inspection compliance is a percentage; these bands are fixed by the domain
  /// rules and are also used for routine-task and scorecard RAG.
  static const double complianceGood = 80;
  static const double complianceWarn = 60;

  /// Returns the semantic tone for a completion ratio.
  ///
  /// `null` (unknown) is treated as at-risk rather than good — an inspection
  /// nobody has done yet is not a passing inspection.
  static ComplianceTone complianceTone(double? ratio) {
    if (ratio == null) return ComplianceTone.bad;
    if (ratio >= complianceGood) return ComplianceTone.good;
    if (ratio >= complianceWarn) return ComplianceTone.warn;
    return ComplianceTone.bad;
  }

  static Color complianceColor(double? ratio) =>
      switch (complianceTone(ratio)) {
        ComplianceTone.good => good,
        ComplianceTone.warn => warn,
        ComplianceTone.bad => bad,
      };

  // -------------------------------------------------------------------------
  // Risk rating — risk = likelihood (1-5) × severity (1-4)
  // -------------------------------------------------------------------------
  /// Thresholds carried over from the existing app: >=15 critical, >=8 high,
  /// >=4 medium, otherwise low.
  static RiskRating riskRating(int score) {
    if (score >= 15) return RiskRating.critical;
    if (score >= 8) return RiskRating.high;
    if (score >= 4) return RiskRating.medium;
    return RiskRating.low;
  }

  static Color riskColor(RiskRating rating) => switch (rating) {
        RiskRating.low => good,
        RiskRating.medium => warn,
        RiskRating.high => bad,
        RiskRating.critical => const Color(0xFF9B1FA8),
      };

  // -------------------------------------------------------------------------
  // Spacing / radius
  // -------------------------------------------------------------------------
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;

  /// Minimum touch target. Every interactive element is at least this tall.
  static const double touchTarget = 48;

  // -------------------------------------------------------------------------
  // Type scale
  // -------------------------------------------------------------------------
  /// Material 3 roles are kept but every size is pinned, so an inline tweak
  /// cannot silently break the hierarchy.
  static const double displaySmall = 30;
  static const double headlineMedium = 24;
  static const double headlineSmall = 20;
  static const double titleLarge = 18;
  static const double titleMedium = 15;
  static const double titleSmall = 13;
  static const double bodyLarge = 15;
  static const double bodyMedium = 13.5;
  static const double bodySmall = 12;
  static const double labelLarge = 13;
  static const double labelMedium = 11.5;
  static const double labelSmall = 10.5;
}

enum ComplianceTone { good, warn, bad }

enum RiskRating { low, medium, high, critical }

/// Resolved semantic colours for the current mode.
///
/// Components read this from the theme extension instead of hard-coding a
/// colour, which is what keeps dark mode correct without a second pass.
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.good,
    required this.warn,
    required this.bad,
    required this.info,
    required this.neutral,
    required this.chipBackgrounds,
    required this.chipText,
    required this.accentGradient,
    required this.activeNavTint,
    required this.brandRed,
  });

  final Color good;
  final Color warn;
  final Color bad;
  final Color info;
  final Color neutral;

  /// One pastel per semantic colour, indexed by [SemanticHue].
  final List<Color> chipBackgrounds;

  final Color chipText;
  final List<Color> accentGradient;
  final Color activeNavTint;

  /// The red appropriate for this mode: brand red on light, the lighter tint
  /// on dark, where contrast demands it.
  final Color brandRed;

  /// Readable foreground for a semantic hue, for use as *text* rather than as a
  /// chip fill. Distinct from `chipBackgrounds`, which are deliberately quiet
  /// pastel surfaces: using a pastel as a text colour is invisible on white.
  Color foreground(SemanticHue hue) => switch (hue) {
        SemanticHue.good => good,
        SemanticHue.warn => warn,
        SemanticHue.bad => bad,
        SemanticHue.info => info,
        SemanticHue.neutral => neutral,
      };

  static const light = AppColorsExtension(
    good: AppTokens.good,
    warn: AppTokens.warn,
    bad: AppTokens.bad,
    info: AppTokens.info,
    neutral: AppTokens.neutral,
    chipBackgrounds: AppTokens.lightStatusChips,
    chipText: AppTokens.lightStatusChipText,
    accentGradient: AppTokens.accentGradient,
    activeNavTint: AppTokens.activeNavTint,
    brandRed: AppTokens.brandRed,
  );

  static const dark = AppColorsExtension(
    // On a near-black surface the saturated hues lose contrast, so the dark
    // variant uses the lighter tints. Each is bright enough to satisfy AA on
    // the matching dark chip below it.
    good: Color(0xFF6FE08A),
    warn: Color(0xFFFFC659),
    bad: Color(0xFFFF8F86),
    info: Color(0xFF9CC4FF),
    neutral: Color(0xFFB4B4BC),
    // Deeper tints than the light pastels, so a chip still reads as coloured
    // against a #1A1A1C card rather than blending into it.
    chipBackgrounds: <Color>[
      Color(0xFF0E4A24),
      Color(0xFF5C3B00),
      Color(0xFF5E1A17),
      Color(0xFF1B3A78),
      Color(0xFF33333A),
    ],
    chipText: Color(0xFFF2F2F3),
    accentGradient: AppTokens.accentGradient,
    activeNavTint: Color(0x33FF5252),
    brandRed: AppTokens.brandRedOnDark,
  );

  @override
  AppColorsExtension copyWith({List<Color>? accentGradient}) =>
      AppColorsExtension(
        good: good,
        warn: warn,
        bad: bad,
        info: info,
        neutral: neutral,
        chipBackgrounds: chipBackgrounds,
        chipText: chipText,
        accentGradient: accentGradient ?? this.accentGradient,
        activeNavTint: activeNavTint,
        brandRed: brandRed,
      );

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      good: Color.lerp(good, other.good, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      info: Color.lerp(info, other.info, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      chipBackgrounds: other.chipBackgrounds,
      chipText: Color.lerp(chipText, other.chipText, t)!,
      accentGradient: other.accentGradient,
      activeNavTint: other.activeNavTint,
      brandRed: Color.lerp(brandRed, other.brandRed, t)!,
    );
  }
}

/// Index into [AppColorsExtension.chipBackgrounds].
///
/// Named rather than positional so a component cannot silently pick the wrong
/// pastel when the list is reordered.
enum SemanticHue {
  good(0),
  warn(1),
  bad(2),
  info(3),
  neutral(4);

  const SemanticHue(this.ordinal);

  /// Position in [AppTokens.lightStatusChips] / `darkStatusChips`.
  ///
  /// Named `ordinal` rather than `index` because `index` is a reserved member
  /// on enums and cannot be redeclared.
  final int ordinal;
}

/// Convenience accessor so widgets read `theme.appColors.good` rather than
/// reaching for the extension by hand.
extension AppThemeX on ThemeData {
  AppColorsExtension get appColors =>
      extension<AppColorsExtension>() ?? AppColorsExtension.light;
}
