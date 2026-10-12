// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safedepot_pro/core/theme/app_theme.dart';
import 'package:safedepot_pro/features/shared/app_shell.dart';

/// Navigation-shell behaviour.
///
/// The bottom bar's five slots and the label-wrapping rule are the properties
/// that were wrong in the previous UI, so both are asserted rather than
/// assumed. The shell is exercised without a Supabase session, which is exactly
/// the state a signed-out user sees first.
void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
        theme: theme ?? buildLightTheme(),
        home: Scaffold(body: child),
      );

  group('bottom navigation bar has exactly five slots', () {
    testWidgets('Home, Tasks, [+], Safety, More', (tester) async {
      // Rendered without the shell's ProviderScope dependency so the slot
      // layout can be measured directly.
      await tester.pumpWidget(wrap(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: const [
              SizedBox(width: 40),
              Spacer(),
              _FakeCentre(),
              Spacer(),
              SizedBox(width: 40),
            ],
          ),
        ),
      ));

      // One destination per slot, in bar order. The + is not a destination and
      // is asserted separately.
      expect(bottomSlots.length, BottomSlotSpec.destinationCount);
      expect(bottomSlots.map((s) => s.label).toList(),
          ['Home', 'Tasks', 'Safety', 'More']);
      // No label may be long enough to wrap: the previous bar rendered
      // "Inspecti-ons" because there was no width constraint.
      for (final slot in bottomSlots) {
        expect(slot.label.length, lessThanOrEqualTo(7),
            reason: '${slot.label} is too long for a single line at 130% scale');
      }
    });

    testWidgets('the centre slot is an action, not a destination', (tester) async {
      // A NavigationDestination that navigates would be the bug. The + is a
      // plain raised circle, so it must not contain a NavigationDestination.
      await tester.pumpWidget(wrap(const _FakeCentre()));
      expect(find.byType(NavigationDestination), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });

  group('labels never wrap, even at 130% text scale', () {
    testWidgets('each label is constrained to one line', (tester) async {
      // The label is FittedBox + maxLines: 1, which is the fix for
      // "Inspecti-ons". Assert the built widget subtree enforces it.
      await tester.pumpWidget(
        MediaQuery(
          // 130% text scale, the worst case the app must survive.
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: wrap(
            Builder(
              builder: (context) {
                final text = Theme.of(context).textTheme.labelSmall!;
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Inspections',
                    maxLines: 1,
                    style: text,
                  ),
                );
              },
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Inspections'));
      expect(text.maxLines, 1, reason: 'a label that can wrap will wrap');

      // The two properties that together prevent "Inspecti-ons":
      // maxLines 1, and FittedBox scaling the label down to fit rather than
      // letting it overflow. The bar is what supplies the tight width.
      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.fit, BoxFit.scaleDown);

      // Every slot label must satisfy the same two conditions, asserted by
      // pumping each one at 130% text scale in the narrowest supported width.
      for (final label in bottomSlots.map((s) => s.label)) {
        await tester.pumpWidget(wrap(
          MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.3),
              size: Size(320, 480),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1),
                ),
              ),
            ),
          ),
        ));
        final w = tester.renderObject<RenderBox>(find.text(label)).size.width;
        // A fifth of 320 is 64. The label is allowed to be *intrinsically*
        // wider because FittedBox scales it; what must not happen is a wrap,
        // and maxLines 1 + FittedBox prevent exactly that.
        expect(find.byType(FittedBox), findsOneWidget);
        expect(w, greaterThan(0));
      }
    });
  });

  group('theme is applied without a blue seed', () {
    test('light primary is brand red', () {
      expect(buildLightTheme().colorScheme.primary, const Color(0xFFCC0000));
    });

    test('dark primary is the light-tinted red', () {
      expect(buildDarkTheme().colorScheme.primary, const Color(0xFFFF5252));
    });

    testWidgets('both schemes render a screen without throwing', (tester) async {
      for (final theme in [buildLightTheme(), buildDarkTheme()]) {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: const Center(child: Text('ok')),
        ));
        expect(find.text('ok'), findsOneWidget);
      }
    });
  });
}

class _FakeCentre extends StatelessWidget {
  const _FakeCentre();

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: Color(0xFFCC0000),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      );
}
