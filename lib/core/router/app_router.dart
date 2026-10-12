// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../features/about/about_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/capa/capa_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/incidents/incidents_screens.dart';
import '../../features/inspections/inspection_runner_screen.dart';
import '../../features/inspections/inspections_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/permits/permits_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/audit/audit_screen.dart';
import '../../features/shared/app_shell.dart';
import '../../features/shared/components.dart';
import 'routes.dart';

/// The application router.
///
/// Declared as a provider so the GoRouter instance survives widget rebuilds,
/// and so its `refreshListenable` is tied to the Riverpod container's
/// lifetime rather than to a widget that may be rebuilt on every navigation.
///
/// The redirect is the single auth guard: no protected route renders without a
/// loaded, active profile. Role gating is applied per route with [RoleGuard]
/// rather than by hiding links, because a hidden link that still resolves is a
/// broken control.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: ref.read(routerRefreshProvider),
    redirect: (context, state) {
      final profileState = ref.read(profileProvider);
      if (profileState.isLoading) return null;

      final isSignedIn = profileState.isSignedIn;
      final isOnLogin = state.matchedLocation == Routes.login;

      if (!isSignedIn) return isOnLogin ? null : Routes.login;
      if (isOnLogin) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: Routes.incidents,
            builder: (context, state) {
              final report = state.uri.queryParameters['report'] == '1';
              return report
                  ? const ReportIncidentScreen()
                  : const IncidentsScreen();
            },
          ),
          GoRoute(
            path: Routes.inspections,
            builder: (context, state) => const InspectionsScreen(),
          ),
          GoRoute(
            path: Routes.inspectionsRun,
            builder: (context, state) => const InspectionRunnerScreen(),
          ),
          GoRoute(
            path: Routes.capa,
            builder: (context, state) => const CapaScreen(),
          ),
          GoRoute(
            path: Routes.permits,
            builder: (context, state) => RoleGuard(
              allowed: (role) => role.isAdmin,
              child: const PermitsScreen(),
            ),
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: Routes.audit,
            builder: (context, state) => RoleGuard(
              allowed: (role) => role.isAdmin,
              child: const AuditScreen(),
            ),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: Routes.about,
            builder: (context, state) => const AboutScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _NotFoundScreen(
      location: state.uri.toString(),
    ),
  );
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text('Route not found: $location')),
      );
}
