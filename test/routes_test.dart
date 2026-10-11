import 'package:flutter_test/flutter_test.dart';
import 'package:safedepot_pro/core/router/routes.dart';

/// Route constants are referenced by the router, by the navigation shell and by
/// the auth-guard redirect. Duplicated string literals are how a silently
/// unprotected route happens, so they are asserted to be unique and to start
/// with a slash.
void main() {
  group('Routes', () {
    final all = <String>[
      Routes.login,
      Routes.home,
      Routes.incidents,
      Routes.inspections,
      Routes.inspectionsRun,
      Routes.capa,
      Routes.permits,
      Routes.notifications,
      Routes.audit,
      Routes.profile,
    ];

    test('no duplicate paths', () {
      expect(all.toSet().length, all.length);
    });

    test('every path is absolute', () {
      for (final path in all) {
        expect(path.startsWith('/'), isTrue, reason: path);
      }
    });

    test('home is the root and login is its own path', () {
      expect(Routes.home, '/');
      expect(Routes.login, '/login');
    });

    test('the inspection runner is nested under inspections', () {
      // The navigation shell highlights "Inspections" for both, so the runner
      // must be a child of it rather than a sibling.
      expect(Routes.inspectionsRun.startsWith(Routes.inspections), isTrue);
      expect(Routes.inspectionsRun, '/inspections/run');
    });

    test('admin-only areas are distinct leaf routes', () {
      // A deep link straight to /permits must still hit the role guard rather
      // than being reachable as a query parameter on a public route.
      expect(Routes.permits, '/permits');
      expect(Routes.audit, '/audit');
    });
  });
}
