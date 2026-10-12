// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../data/models/enums.dart';
import '../../providers/providers.dart';

/// Navigation rail / drawer wrapper.
///
/// Destinations are filtered by role so an inspector never sees admin-only
/// destinations, and item counts (unread notifications, pending approvals)
/// are surfaced as badges.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    if (profile == null) return child;

    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 700;

    final destinations = _destinationsFor(profile.role);
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = destinations.indexWhere((d) => d.matches(location));
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    if (isCompact) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => _go(context, destinations[i].location),
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: _Leading(dest: d, badge: d.location == Routes.notifications ? unread : null),
                label: d.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) => _go(context, destinations[i].location),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: FlutterLogo(size: 28),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: _Leading(dest: d, badge: d.location == Routes.notifications ? unread : null),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  void _go(BuildContext context, String location) => context.go(location);
}

class _Leading extends StatelessWidget {
  const _Leading({required this.dest, this.badge});

  final _Destination dest;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(dest.icon);
    if (badge == null || badge! <= 0) return icon;
    return Badge.count(count: badge!, child: icon);
  }
}

class _Destination {
  const _Destination({
    required this.location,
    required this.label,
    required this.icon,
    required this.matches,
  });

  final String location;
  final String label;
  final IconData icon;
  final bool Function(String loc) matches;
}

/// Role-filtered destinations. Admin destinations are not just hidden — the
/// routes themselves also check the role, so a deep link is not a bypass.
List<_Destination> _destinationsFor(UserRole role) {
  final base = [
    _Destination(
      location: Routes.home,
      label: 'Home',
      icon: Icons.dashboard_outlined,
      matches: (l) => l == Routes.home,
    ),
    _Destination(
      location: Routes.inspections,
      label: 'Inspections',
      icon: Icons.checklist_outlined,
      matches: (l) => l.startsWith('/inspections'),
    ),
    _Destination(
      location: Routes.incidents,
      label: 'Incidents',
      icon: Icons.report_gmailerrorred_outlined,
      matches: (l) => l.startsWith('/incidents'),
    ),
    _Destination(
      location: Routes.capa,
      label: 'Actions',
      icon: Icons.task_outlined,
      matches: (l) => l.startsWith('/corrective-actions'),
    ),
  ];

  if (role.isAdmin) {
    base.add(
      _Destination(
        location: Routes.permits,
        label: 'Permits',
        icon: Icons.approval_outlined,
        matches: (l) => l.startsWith('/permits'),
      ),
    );
    base.add(
      _Destination(
        location: Routes.audit,
        label: 'Audit',
        icon: Icons.history_outlined,
        matches: (l) => l == Routes.audit,
      ),
    );
  }

  base.add(
    _Destination(
      location: Routes.notifications,
      label: 'Alerts',
      icon: Icons.notifications_outlined,
      matches: (l) => l == Routes.notifications,
    ),
  );
  base.add(
    _Destination(
      location: Routes.profile,
      label: 'Profile',
      icon: Icons.person_outline,
      matches: (l) => l == Routes.profile,
    ),
  );
  return base;
}

/// Convenience wrapper so routes that require admin can reject a deep link
/// from a non-admin session without rendering the underlying screen.
class RoleGuard extends ConsumerWidget {
  const RoleGuard({super.key, required this.child, required this.allowed});

  final Widget child;
  final bool Function(UserRole role) allowed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(profileProvider).profile?.role;
    if (role == null) return const SizedBox.shrink();
    if (!allowed(role)) return const ForbiddenView();
    return child;
  }
}

class ForbiddenView extends StatelessWidget {
  const ForbiddenView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Not available to your role', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'This area is restricted by your role and depot assignment. '
              'Ask an administrator if you need access.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sign-out control used in the dashboard app bar and the profile screen.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () async {
        await ref.read(profileProvider.notifier).signOut();
        if (context.mounted) context.go(Routes.login);
      },
      icon: const Icon(Icons.logout, size: 18),
      label: const Text('Sign out'),
    );
  }
}
