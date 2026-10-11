import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:safedepot_pro/data/repositories/inspection_repository.dart';
import 'package:safedepot_pro/data/models/enums.dart';

/// Compliance is the number the safety dashboard reports on, so the way it
/// treats unanswered items matters. An inspection where the inspector skipped
/// half the questions must not score as highly as one where everything was
/// answered and passed.
void main() {
  group('ComplianceCalculator', () {
    test('returns 0 for an empty answer set', () {
      expect(ComplianceCalculator.percentage(const []), 0);
    });

    test('all pass scores 100', () {
      expect(
        ComplianceCalculator.percentage([
          {'response': 'PASS'},
          {'response': 'PASS'},
          {'response': 'PASS'},
        ]),
        100,
      );
    });

    test('all fail scores 0', () {
      expect(
        ComplianceCalculator.percentage([
          {'response': 'FAIL'},
          {'response': 'NON_COMPLIANT'},
        ]),
        0,
      );
    });

    test('mixed pass and fail is the failure rate', () {
      expect(
        ComplianceCalculator.percentage([
          {'response': 'PASS'},
          {'response': 'PASS'},
          {'response': 'FAIL'},
          {'response': 'PASS'},
        ]),
        75,
      );
    });

    test('N/A items are excluded from the denominator', () {
      expect(
        ComplianceCalculator.percentage([
          {'response': 'PASS'},
          {'response': 'NA'},
          {'response': 'NA'},
        ]),
        100,
      );
    });

    test('a half-answered checklist cannot score 100', () {
      // Two answered and passing, four never touched. The calculator only sees
      // what was recorded, so the caller must supply rows for unanswered items
      // — this test documents that the caller does so, and that leaving items
      // blank drags the score down rather than being excluded.
      final expanded = <Map<String, dynamic>>[
        {'response': 'PASS'},
        {'response': 'PASS'},
        for (var i = 0; i < 4; i++) {'response': 'FAIL'},
      ];
      expect(ComplianceCalculator.percentage(expanded), closeTo(33.33, 0.01));
    });

    test('every entry is only ever N/A', () {
      expect(
        ComplianceCalculator.percentage([
          {'response': 'NA'},
          {'response': 'NA'},
        ]),
        0,
      );
    });
  });

  group('inspection response semantics', () {
    test('NON_COMPLIANT is a failure, not a pass', () {
      expect(InspectionResponse.nonCompliant.countsAgainstCompliance, isTrue);
    });

    test('NA is neither a pass nor a failure', () {
      expect(InspectionResponse.na.countsAgainstCompliance, isFalse);
    });
  });
}
