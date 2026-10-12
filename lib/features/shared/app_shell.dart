// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';
import '../../providers/feature_flags_provider.dart';
import '../../providers/providers.dart';

/// Navigation shell.
///
/// Five slots, one-line labels: Home | Tasks | [+] | Safety | More. The centre
/// is an action, not a destination, which is why it is a raised circle and not
/// a tab — it opens the quick-action sheet instead of navigating away.
///
/// Wide layouts use a rail so the same destinations are reachable without the
/// bottom bar stealing vertical space from a dashboard full of KPI cards.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    if (profile == null) return child;

    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 840;

    if (useRail) {
      return Row(
        children: [
          _AppRail(role: profile.role),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: _AppBottomBar(role: profile.role),
    );
  }
}

/// The five primary destinations.
enum _Primary { home, tasks, safety, more }

const _primaryDestinations = <_Primary, ({IconData icon, IconData active, String label, String path, String match})>{
  _Primary.home: (
    icon: Icons.home_outlined,
    active: Icons.home_rounded,
    label: 'Home',
    path: Routes.home,
    match: '/',
  ),
  _Primary.tasks: (
    icon: Icons.check_circle_outline,
    active: Icons.check_circle_rounded,
    label: 'Tasks',
    path: '/tasks',
    match: '/tasks',
  ),
  _Primary.safety: (
    icon: Icons.shield_outlined,
    active: Icons.shield_rounded,
    label: 'Safety',
    path: Routes.permits,
    match: '/permits',
  ),
  _Primary.more: (
    icon: Icons.menu_rounded,
    active: Icons.menu_rounded,
    label: 'More',
    path: '/more',
    match: '/more',
  ),
};

class _AppBottomBar extends StatelessWidget {
  const _AppBottomBar({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).matchedLocation;

    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.colorScheme.outline)),
        ),
        child: Row(
          children: [
            for (final dest in [_Primary.home, _Primary.tasks]) ...[
              _Slot(dest: dest, isActive: _isActive(dest, location)),
              const Spacer(),
            ],
            _CentreAction(role: role),
            const Spacer(),
            for (final dest in [_Primary.safety, _Primary.more]) ...[
              _Slot(dest: dest, isActive: _isActive(dest, location)),
              const Spacer(),
            ],
          ],
        ),
      ),
    );
  }

  bool _isActive(_Primary dest, String location) {
    final match = _primaryDestinations[dest]!.match;
    return location == match || location.startsWith('$match/');
  }
}

/// A single bar slot. Label is [FittedBox]ed and single-line so "Inspections"
/// can never wrap, even at 130% text scale.
class _Slot extends StatelessWidget {
  const _Slot({required this.dest, required this.isActive});

  final _Primary dest;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.appColors;
    final d = _primaryDestinations[dest]!;
    final color = isActive ? colors.brandRed : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.go(d.path);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                isActive ? d.active : d.icon,
                key: ValueKey(isActive),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                d.label,
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: isActive ? 18 : 0,
              decoration: BoxDecoration(
                color: colors.brandRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Raised centre action. Deliberately not a [NavigationDestination] — it opens
/// a sheet, and a destination that navigates would break that expectation.
class _CentreAction extends ConsumerWidget {
  const _CentreAction({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).appColors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _openQuickActions(context, ref, role);
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors.accentGradient),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.brandRed.withValues(alpha: 0.32),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

/// Role-aware quick actions.
class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.route,
    required this.flagKey,
  });

  final String label;
  final IconData icon;
  final String route;
  final String flagKey;
}

const List<QuickAction> _quickActions = [
  QuickAction(label: 'Report incident', icon: Icons.report_gmailerrorred_outlined, route: Routes.incidents, flagKey: 'incidents'),
  QuickAction(label: 'Start inspection', icon: Icons.checklist_rtl_rounded, route: Routes.inspections, flagKey: 'inspections'),
  QuickAction(label: 'Report hazard', icon: Icons.warning_amber_rounded, route: '/hazards', flagKey: 'hazards'),
  QuickAction(label: 'Toolbox talk', icon: Icons.groups_outlined, route: '/toolbox', flagKey: 'toolbox_talks'),
  QuickAction(label: 'Request permit', icon: Icons.approval_outlined, route: Routes.permits, flagKey: 'permits'),
  QuickAction(label: 'Truck inspection', icon: Icons.local_shipping_outlined, route: '/truck-inspections', flagKey: 'truck_inspections'),
  QuickAction(label: 'Shift handover', icon: Icons.swap_horiz_rounded, route: '/shift-handover', flagKey: 'shift_handover'),
];

void _openQuickActions(BuildContext context, WidgetRef ref, UserRole role) {
  final enabled = ref.read(featureFlagsProvider).value ?? const <String>{};

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          0,
          AppTokens.spaceLg,
          AppTokens.spaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick action', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              'Anything not yet shipped shows a coming-soon card instead of a '
              'broken screen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppTokens.spaceLg),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: AppTokens.spaceMd,
              crossAxisSpacing: AppTokens.spaceMd,
              children: [
                for (final action in _quickActions)
                  _QuickActionTile(
                    action: action,
                    enabled: enabled.contains(action.flagKey),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.enabled});

  final QuickAction action;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        context.push(action.route);
      },
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: Icon(
              action.icon,
              color: enabled
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.outline,
              size: 21,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          FittedBox(
            child: Text(
              action.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigation rail for tablets and wide windows.
///
/// Uses the brand mark in place of the Flutter logo, which is the teal circle
/// that overlapped the dashboard title.
class _AppRail extends ConsumerWidget {
  const _AppRail({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.appColors;
    final location = GoRouterState.of(context).matchedLocation;

    return NavigationRail(
      selectedIndex: _indexFor(location),
      onDestinationSelected: (i) {
        HapticFeedback.selectionClick();
        context.go(_primaryDestinations.entries.elementAt(i).value.path);
      },
      labelType: NavigationRailLabelType.all,
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: colors.activeNavTint,
      leading: Column(
        children: [
          const SizedBox(height: AppTokens.spaceMd),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors.accentGradient),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(height: AppTokens.spaceSm),
        ],
      ),
      destinations: [
        for (final d in _primaryDestinations.values)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.active),
            label: Text(d.label),
          ),
      ],
    );
  }

  int _indexFor(String location) {
    final l = location == '/' ? Routes.home : location;
    var i = 0;
    for (final entry in _primaryDestinations.entries) {
      final match = entry.value.match;
      if (l == match || l.startsWith('$match/')) return i;
      i++;
    }
    return 0;
  }
}
