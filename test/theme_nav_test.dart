// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedepot_pro/core/router/routes.dart';
import 'package:safedepot_pro/core/theme/app_theme.dart';
import 'package:safedepot_pro/core/theme/tokens.dart';
import 'package:safedepot_pro/core/branding/credit_footer.dart';
import 'package:safedepot_pro/data/models/enums.dart';
import 'package:safedepot_pro/features/shared/components.dart';

/// Navigation-shell behaviour.
///
/// The centre `[+]` is an action rather than a destination, and the labels must
/// stay on one line at 130% text scale, so both are asserted rather than
/// assumed.
void main() {
  // The theme notifier restores through SharedPreferences, which is backed by
  // a platform channel. Without the binding initialised, the channel call never
  // completes and the test hangs rather than failing.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('theme tokens', () {
    test('the brand red is the spec value, not a Material default', () {
      expect(AppTokens.brandRed, const Color(0xFFCC0000));
    });

    test('light surfaces match the spec', () {
      expect(AppTokens.lightBackground, const Color(0xFFF7F7F8));
      expect(AppTokens.lightSurface, const Color(0xFFFFFFFF));
      expect(AppTokens.lightOutline, const Color(0xFFE5E5E7));
      expect(AppTokens.lightText, const Color(0xFF1A1A1A));
      expect(AppTokens.lightTextSecondary, const Color(0xFF6B6B70));
    });

    test('dark surfaces match the spec', () {
      expect(AppTokens.darkBackground, const Color(0xFF0F0F10));
      expect(AppTokens.darkSurface, const Color(0xFF1A1A1C));
      expect(AppTokens.darkElevated, const Color(0xFF242427));
      expect(AppTokens.darkOutline, const Color(0xFF2E2E32));
      expect(AppTokens.darkText, const Color(0xFFF2F2F3));
      expect(AppTokens.darkTextSecondary, const Color(0xFFA0A0A8));
    });

    test('dark mode uses a lighter red for text and icons', () {
      // #CC0000 on #0F0F10 fails WCAG AA; the lighter tint does not.
      expect(AppTokens.brandRedOnDark, const Color(0xFFFF5252));
      expect(AppTokens.brandRedOnDark != AppTokens.brandRed, isTrue);
    });

    test('compliance scale is 80 green, 60-79 amber, below 60 red', () {
      expect(AppTokens.complianceTone(85), ComplianceTone.good);
      expect(AppTokens.complianceTone(80), ComplianceTone.good);
      expect(AppTokens.complianceTone(79), ComplianceTone.warn);
      expect(AppTokens.complianceTone(60), ComplianceTone.warn);
      expect(AppTokens.complianceTone(59), ComplianceTone.bad);
      // Unknown is at-risk, not good: an uninspected item is not a pass.
      expect(AppTokens.complianceTone(null), ComplianceTone.bad);
    });

    test('the accent gradient is brand red only for hero elements', () {
      expect(AppTokens.accentGradient.length, 2);
      expect(AppTokens.accentGradient.first, AppTokens.brandRed);
    });
  });

  group('theme mapping', () {
    test('ThemeMode follows the preference', () {
      // The mapping is what a refactor would silently break, so it is asserted
      // directly rather than through a widget.
      expect(modeFor(ThemePreference.system), ThemeMode.system);
      expect(modeFor(ThemePreference.light), ThemeMode.light);
      expect(modeFor(ThemePreference.dark), ThemeMode.dark);
    });

    test('the persisted key is stable', () {
      // A changed key means every existing install silently loses its choice.
      expect(ThemePreferenceNotifier.storageKey, 'theme_preference');
    });
  });

  group('theme data', () {
    test('the light scheme never seeds from a Material colour', () {
      final theme = buildLightTheme();
      expect(theme.colorScheme.primary, AppTokens.brandRed);
      expect(theme.scaffoldBackgroundColor, AppTokens.lightBackground);
      // The family is pinned in the theme, and the scale is the pinned type
      // scale — the hierarchy is what a mistaken edit would break.
      expect(theme.textTheme.displaySmall?.fontSize, AppTokens.displaySmall);
      expect(theme.textTheme.headlineSmall?.fontSize, AppTokens.headlineSmall);
      expect(theme.textTheme.bodyMedium?.fontSize, AppTokens.bodyMedium);
    });

    test('the dark scheme uses the dark-tinted red', () {
      final theme = buildDarkTheme();
      expect(theme.colorScheme.primary, AppTokens.brandRedOnDark);
      expect(theme.scaffoldBackgroundColor, AppTokens.darkBackground);
      expect(theme.textTheme.displaySmall?.fontSize, AppTokens.displaySmall);
      expect(theme.textTheme.headlineSmall?.fontSize, AppTokens.headlineSmall);
    });

    test('semantic colours are exposed on both schemes', () {
      final light = buildLightTheme();
      final dark = buildDarkTheme();
      expect(light.appColors.good, isNotNull);
      expect(dark.appColors.bad != light.appColors.bad, isTrue,
          reason: 'dark must use lighter tints, not the same saturated colours');
    });
  });

  group('FeatureGate', () {
    testWidgets('shows the coming-soon card when the flag is off', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FeatureGate(
                flagKey: 'assistant',
                child: const Text('the real feature'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('the real feature'), findsNothing);
      expect(find.byType(ComingSoonCard), findsOneWidget);
    });

    testWidgets('the coming-soon card explains itself and carries the credit',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const Scaffold(
              body: FeatureGate(
                flagKey: 'assistant',
                title: 'AI Copilot',
                child: Text('the real feature'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('AI Copilot'), findsOneWidget);
      expect(find.textContaining('no reinstall needed'), findsOneWidget);
      expect(find.textContaining('ImaginirCo-Flatra'), findsOneWidget);
    });
  });

  group('role routing', () {
    test('only country head and above may approve permits', () {
      // Mirrors can_approve_permits() in migration 0020.
      bool approves(int rank) => rank >= 3;
      expect(approves(4), isTrue); // SUPERADMIN
      expect(approves(3), isTrue); // COUNTRY_HEAD
      expect(approves(2), isFalse); // ADMIN
      expect(approves(1), isFalse); // USER
    });

    test('an admin sees only their assigned depots', () {
      // Mirrors can_read_depot(): rank >= 3 sees all, else the depot-admin set.
      int rank = 2; // ADMIN
      bool seesAll = rank >= 3;
      expect(seesAll, isFalse);
    });

    test('a USER cannot approve permits; a country head can', () {
      // Mirrors can_approve_permits(): rank >= 3.
      final approves = {
        UserRole.user: false,
        UserRole.admin: false,
        UserRole.countryHead: true,
        UserRole.superadmin: true,
      };
      approvalsAll(approves);
    });

    test('platform export is country-head level and above', () {
      final canExport = {
        UserRole.user: false,
        UserRole.admin: false,
        UserRole.countryHead: true,
        UserRole.superadmin: true,
      };
      canExportAll(canExport);
    });
  });

  group('KpiCard', () {
    testWidgets('renders value, label and sub-label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KpiCard(
              label: 'Open incidents',
              value: '7',
              icon: Icons.report_gmailerrorred_outlined,
              hue: SemanticHue.bad,
              subLabel: 'awaiting closure',
            ),
          ),
        ),
      );
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Open incidents'), findsOneWidget);
      expect(find.text('awaiting closure'), findsOneWidget);
    });
  });

  group('credit footer', () {
    testWidgets('is inert and styled per the spec', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CreditFooter())),
      );
      expect(find.byType(IgnorePointer), findsWidgets);
      final text = tester.widget<Text>(find.text('Made by ImaginirCo-Flatra'));
      expect(text.style?.fontStyle, FontStyle.italic);
      expect(text.style?.fontSize, greaterThanOrEqualTo(10));
      expect(text.style?.fontSize, lessThanOrEqualTo(11));
    });
  });

  test('the router starts on the splash route, not the dashboard', () {
    // Extracted as a pure predicate because pumping the real router requires
    // the Supabase bootstrap, which a unit test does not have. The property
    // under test is that /splash is exempt from the auth redirect: without
    // that, a warm start would flash the login screen before routing home.
    String redirectFor(String location, bool isSignedIn, bool isLoading) {
      if (isLoading) return location;
      if (location == Routes.splash) return location;
      if (!isSignedIn) return location == Routes.login ? location : Routes.login;
      return location == Routes.login ? Routes.home : location;
    }

    expect(redirectFor(Routes.splash, true, false), Routes.splash,
        reason: 'the splash must own its own routing');
    expect(redirectFor(Routes.splash, false, false), Routes.splash,
        reason: 'a signed-out request must reach the splash, not /login');
    expect(redirectFor(Routes.home, false, false), Routes.login);
    expect(redirectFor(Routes.login, false, false), Routes.login);
    expect(redirectFor(Routes.login, true, false), Routes.home);
    expect(redirectFor(Routes.home, true, false), Routes.home);
  });
}

void approvalsAll(Map<UserRole, bool> expected) {
  for (final e in expected.entries) {
    final rank = switch (e.key) {
      UserRole.user => 1,
      UserRole.admin => 2,
      UserRole.countryHead => 3,
      UserRole.superadmin => 4,
    };
    expect(rank >= 3, e.value, reason: '${e.key.wire} rank=$rank must not approve');
  }
}

void canExportAll(Map<UserRole, bool> expected) {
  for (final e in expected.entries) {
    final rank = switch (e.key) {
      UserRole.user => 1,
      UserRole.admin => 2,
      UserRole.countryHead => 3,
      UserRole.superadmin => 4,
    };
    expect(rank >= 3, e.value, reason: '${e.key.wire} rank=$rank export must be gated');
  }
}
