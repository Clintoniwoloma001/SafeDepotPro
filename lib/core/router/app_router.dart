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
import '../../features/tasks/tasks_screen.dart';
import '../../features/shared/app_shell.dart';
import '../../features/shared/components.dart';
import '../../features/shared/flutter_splash.dart';
import '../../features/more/more_screen.dart';
import '../../features/settings/appearance_screen.dart';
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
      // The splash owns its own routing, so the auth guard must not redirect
      // it. Kept outside the shell so it never sees the navigation rail.
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const FlutterSplash(),
      ),
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
          // ---- Tasks (P2) ------------------------------------------------
          GoRoute(
            path: Routes.tasks,
            builder: (context, state) => ComingSoonScreen.gated(
              flagKey: 'routine_tasks',
              title: 'Routine Tasks',
              child: const TasksScreen(),
            ),
          ),

          // ---- Safety tab grid (P3) ---------------------------------------
          GoRoute(
            path: Routes.hazards,
            builder: (context, state) => ComingSoonScreen.gated(
              flagKey: 'hazards',
              title: 'Hazards',
              child: const _Placeholder('Hazards'),
            ),
          ),
          GoRoute(
            path: Routes.truckInspections,
            builder: (context, state) => ComingSoonScreen.gated(
              flagKey: 'truck_inspections',
              title: 'Truck Inspections',
              child: const _Placeholder('Truck Inspections'),
            ),
          ),

          // ---- Operations (P2/P4) ------------------------------------------
          GoRoute(
            path: Routes.toolbox,
            builder: (context, state) => ComingSoonScreen.gated(
              flagKey: 'toolbox_talks',
              title: 'Toolbox Talks',
              child: const _Placeholder('Toolbox Talks'),
            ),
          ),
          GoRoute(
            path: Routes.handover,
            builder: (context, state) => ComingSoonScreen.gated(
              flagKey: 'shift_handover',
              title: 'Shift Handover',
              child: const _Placeholder('Shift Handover'),
            ),
          ),
          GoRoute(
            path: Routes.manHours,
            builder: (context, state) => ComingSoonScreen.gated(
              flagKey: 'man_hours',
              title: 'Man-Hours',
              child: const _Placeholder('Man-Hours'),
            ),
          ),

          // ---- Assets (P5) -------------------------------------------------
          GoRoute(
            path: Routes.assets,
            builder: (context, state) => ComingSoonScreen.gated(
              flagKey: 'assets',
              title: 'Equipment & Assets',
              child: const _Placeholder('Assets'),
            ),
          ),

          // ---- Admin, role-gated -------------------------------------------
          GoRoute(
            path: Routes.personnel,
            builder: (context, state) => RoleGuard(
              allowed: (r) => r.isAdmin,
              child: ComingSoonScreen.gated(
                flagKey: 'personnel',
                title: 'Personnel',
                child: const _Placeholder('Personnel'),
              ),
            ),
          ),
          GoRoute(
            path: Routes.depots,
            builder: (context, state) => RoleGuard(
              allowed: (r) => r.isAdmin,
              child: ComingSoonScreen.gated(
                flagKey: 'depots',
                title: 'Depots',
                child: const _Placeholder('Depots'),
              ),
            ),
          ),
          GoRoute(
            path: Routes.checklistBuilder,
            builder: (context, state) => RoleGuard(
              allowed: (r) => r.isAdmin,
              child: ComingSoonScreen.gated(
                flagKey: 'checklist_builder',
                title: 'Checklist Builder',
                child: const _Placeholder('Checklist Builder'),
              ),
            ),
          ),
          GoRoute(
            path: Routes.standIn,
            builder: (context, state) => RoleGuard(
              allowed: (r) => r.isAdmin,
              child: ComingSoonScreen.gated(
                flagKey: 'stand_in',
                title: 'DSO Stand-In',
                child: const _Placeholder('DSO Stand-In'),
              ),
            ),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => RoleGuard(
              allowed: (r) => r.isAdmin,
              child: ComingSoonScreen.gated(
                flagKey: 'settings',
                title: 'Settings',
                child: const _Placeholder('Settings'),
              ),
            ),
          ),
          GoRoute(
            path: Routes.userManagement,
            builder: (context, state) => RoleGuard(
              allowed: (r) => r.seesAllDepots,
              child: ComingSoonScreen.gated(
                flagKey: 'user_management',
                title: 'User Management',
                message: 'Only a super admin may manage accounts.',
                child: const _Placeholder('User Management'),
              ),
            ),
          ),
          GoRoute(
            path: Routes.platformExport,
            builder: (context, state) => RoleGuard(
              allowed: (r) => r.seesAllDepots,
              child: ComingSoonScreen.gated(
                flagKey: 'platform_export',
                title: 'Platform Export',
                message: 'Only a country head or super admin may export.',
                child: const _Placeholder('Platform Export'),
              ),
            ),
          ),

          // ---- More tab extras ----------------------------------------------
          GoRoute(
            path: Routes.appearance,
            builder: (context, state) => const AppearanceScreen(),
          ),
          GoRoute(
            path: Routes.assistant,
            builder: (context, state) => ComingSoonScreen.gated(
              flagKey: 'ai_copilot',
              title: 'AI Copilot',
              child: const _Placeholder('AI Copilot'),
            ),
          ),
          GoRoute(
            path: Routes.more,
            builder: (context, state) => const MoreScreen(),
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

/// Stand-in for a module that is not yet built.
///
/// Only ever rendered once its feature flag is on, which means the Dart code
/// has shipped but the screen has not been written. Keeping it distinct from
/// ComingSoonScreen makes that case obvious rather than silently identical.
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => ComingSoonScreen(
        title: name,
        message:
            'This module is enabled for your account but its screens have not '
            'shipped yet. They arrive in an update and switch on automatically.',
      );
}
