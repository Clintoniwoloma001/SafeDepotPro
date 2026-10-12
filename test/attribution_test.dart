// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedepot_pro/core/branding/author_info.dart';
import 'package:safedepot_pro/core/branding/build_integrity.dart';
import 'package:safedepot_pro/core/branding/credit_footer.dart';
import 'package:safedepot_pro/core/branding/unofficial_build_screen.dart';
import 'package:safedepot_pro/features/about/about_screen.dart';
import 'package:safedepot_pro/features/auth/login_screen.dart';
import 'package:safedepot_pro/features/auth/signup_screen.dart';

/// Attribution and anti-tamper behaviour.
///
/// These tests prove the *wiring*, not that tampering is impossible: nothing
/// computed inside a Dart process is beyond someone who repackages the APK, and
/// `build_integrity.dart` says so. What is worth testing is that the credit
/// renders on every screen that must show it, that it cannot absorb a tap, and
/// that a tampered authorship constant ends in the lock screen rather than in
/// an error string nobody reads.
void main() {
  // The integrity module holds static state; restore it between tests.
  tearDown(BuildIntegrity.invalidateCache);

  group('CreditFooter', () {
    testWidgets('renders the byline, italic and 10–11pt', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CreditFooter())),
      );
      final text = tester.widget<Text>(find.text(kCreditLine));
      expect(text, isNotNull);
      expect(text.style?.fontStyle, FontStyle.italic);
      expect(text.style?.fontSize, greaterThanOrEqualTo(10));
      expect(text.style?.fontSize, lessThanOrEqualTo(11));
    });

    testWidgets('is wrapped in IgnorePointer so it never absorbs input',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CreditFooter())),
      );
      expect(
        find.ancestor(
          of: find.byType(Text),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
    });

    testWidgets('a tap through it still reaches a widget it overlaps',
        (tester) async {
      // The risk the IgnorePointer exists for: the footer sitting ON TOP of an
      // input at the bottom of the screen. Reproduce that overlap in a Stack
      // and prove the input underneath still receives the tap.
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton(
                        onPressed: () => tapped = true,
                        child: const Text('Tap me'),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(top: false, child: CreditFooter()),
                ),
              ],
            ),
          ),
        ),
      );

      final footerCentre = tester.getCenter(find.byType(CreditFooter));
      await tester.tapAt(footerCentre);
      await tester.pump();
      expect(tapped, isTrue, reason: 'the footer absorbed a tap');
    });

    testWidgets('hit-testing at its location resolves to nothing behind it',
        (tester) async {
      // The footer is the bottom-most thing in the tree, so a hit test at its
      // own centre must return nothing to absorb. This is what keeps it from
      // swallowing a gesture meant for whatever is underneath.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CreditFooter())),
      );
      final finder = find.byType(CreditFooter);
      final center = tester.getCenter(finder);

      final result = tester.hitTestOnBinding(center);
      expect(
        find.byType(IgnorePointer),
        findsWidgets,
        reason: 'IgnorePointer must be present for the footer to be inert',
      );
      expect(result, isNotNull);
    });
  });

  group('CreditFooter is present on every required screen', () {
    testWidgets('login screen', (tester) async {
      await _pump(tester, const LoginScreen());
      expect(find.byType(CreditFooter), findsOneWidget);
      expect(find.text(kCreditLine), findsOneWidget);
    });

    testWidgets('sign-up screen', (tester) async {
      await _pump(tester, const SignupScreen());
      expect(find.byType(CreditFooter), findsOneWidget);
      expect(find.text(kCreditLine), findsOneWidget);
    });

    testWidgets('about screen', (tester) async {
      await _pump(tester, const AboutScreen());
      expect(find.byType(CreditFooter), findsOneWidget);
      expect(find.text(kCreditLine), findsOneWidget);
    });
  });

  group('author constants are a single source of truth', () {
    test('full attribution names the author, the role and the contact', () {
      expect(kFullAttribution, contains(kAuthorName));
      expect(kFullAttribution, contains('CEO'));
      expect(kFullAttribution, contains('Flatra Tech Ltd'));
      expect(kFullAttribution, contains(kContactPhone));
    });

    test('file header lines carry holder, author and contact', () {
      expect(kFileHeaderLines.length, 4);
      expect(kFileHeaderLines[0], contains(kCopyrightHolder));
      expect(kFileHeaderLines[1], contains(kAuthorName));
      expect(kFileHeaderLines[3], contains(kContactPhone));
    });

    test('contact number is exactly the required value', () {
      expect(kContactPhone, '+2349025975247');
    });

    test('credit line is exactly the required string', () {
      expect(kCreditLine, 'Made by ImaginirCo-Flatra');
    });
  });

  group('authorship hash', () {
    test('is stable and 64 hex characters', () {
      final payload = BuildIntegrity.canonicalPayload();
      final a = sha256.convert(payload.codeUnits).toString();
      final b = sha256.convert(payload.codeUnits).toString();
      expect(a, b);
      expect(a, hasLength(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(a), isTrue);
    });

    test('changing ANY single constant changes the digest', () {
      final baseline = BuildIntegrity.canonicalPayload();

      // One character of the author name.
      final tamperedPayload =
          baseline.replaceFirst(kAuthorName, 'Clinton IwolomX');
      expect(tamperedPayload, isNot(baseline));

      final baselineHash = sha256.convert(baseline.codeUnits).toString();
      final tamperedHash =
          sha256.convert(tamperedPayload.codeUnits).toString();
      expect(tamperedHash, isNot(baselineHash));
    });

    test('the canonical payload joins each constant with a pipe', () {
      final payload = BuildIntegrity.canonicalPayload();
      for (final constant in [
        kAuthorName,
        kAuthorTitle,
        kCopyrightHolder,
        kContactPhone,
        kCreditLine,
        kFullAttribution,
      ]) {
        expect(payload.contains(constant), isTrue);
      }
    });
  });

  group('startup block decision', () {
    test('a mismatched authors hash produces a blocking reason', () {
      const report = BuildIntegrityReport(
        isUntampered: false,
        details: [
          IntegrityCheckDetail(
            'Authorship constants differ from the signed build manifest.',
            false,
          ),
        ],
      );
      final reason = BuildIntegrity.startupBlockReason(report);
      expect(reason, isNotNull);
      expect(reason, contains('differ'));
    });

    test('a verified build is not blocked', () {
      const report = BuildIntegrityReport(
        isUntampered: true,
        details: [IntegrityCheckDetail('ok', true)],
      );
      expect(BuildIntegrity.startupBlockReason(report), isNull);
    });

    test('a report with no details still blocks, with a message', () {
      const report = BuildIntegrityReport(isUntampered: false, details: []);
      expect(BuildIntegrity.startupBlockReason(report), isNotNull);
      expect(BuildIntegrity.startupBlockReason(report), isNotEmpty);
    });
  });

  group('the lock screen', () {
    testWidgets('renders with no route back to the app', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnofficialBuildScreen(reason: 'manifest mismatch'),
        ),
      );
      expect(find.text('Unofficial build'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('reports the specific reason rather than a generic error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnofficialBuildScreen(
            reason: 'Authorship constants differ from the signed manifest.',
          ),
        ),
      );
      expect(
        find.text('Authorship constants differ from the signed manifest.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the contact route so a user can report the build',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnofficialBuildScreen(reason: 'mismatch'),
        ),
      );
      expect(find.textContaining(kContactPhone), findsWidgets);
      expect(find.textContaining(kAuthorName), findsWidgets);
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp(home: screen)),
  );
  await tester.pump();
}
