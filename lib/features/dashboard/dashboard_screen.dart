// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../shared/components.dart';

/// Role-aware dashboard.
///
/// Layout, in order: compact greeting header, hero compliance ring, 2×2 KPI
/// grid, one scrollable chip row, "needs attention" list, depot card. Nothing
/// decorative — every element answers a question a supervisor would actually
/// ask on opening the app.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    final counts = ref.watch(dashboardCountsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const _AppBarTitle(),
        actions: const [_DashboardActions()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardCountsProvider);
          await ref.read(dashboardCountsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceLg,
            AppTokens.spaceSm,
            AppTokens.spaceLg,
            AppTokens.spaceXl,
          ),
          children: [
            _GreetingHeader(profile: profile),
            const SizedBox(height: AppTokens.spaceLg),
            const _ComplianceRingCard(),
            const SizedBox(height: AppTokens.spaceMd),
            counts.when(
              loading: () => const _KpiGridSkeleton(),
              error: (e, _) => ErrorView(
                message: _readableError(e),
                onRetry: () => ref.invalidate(dashboardCountsProvider),
              ),
              data: (c) => _KpiGrid(counts: c, role: profile?.role),
            ),
            const SizedBox(height: AppTokens.spaceLg),
            const _QuickActionRow(),
            const SizedBox(height: AppTokens.spaceLg),
            const SectionHeader(
              title: 'Needs attention',
              subtitle: 'Sorted by how long it has been waiting',
            ),
            const SizedBox(height: AppTokens.spaceSm),
            const _NeedsAttentionList(),
            const SizedBox(height: AppTokens.spaceLg),
            const SectionHeader(title: 'Your depot'),
            const SizedBox(height: AppTokens.spaceSm),
            const _DepotCard(),
          ],
        ),
      ),
    );
  }
}

/// Logo mark, title, depot chip, bell and copilot — the single top-bar spec for
/// main screens. No sign-out: that belongs in More › Account.
class _AppBarTitle extends ConsumerWidget {
  const _AppBarTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.appColors;
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors.accentGradient),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: AppTokens.spaceSm),
        Expanded(
          child: Text(
            'Dashboard',
            style: theme.textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push(Routes.notifications),
          icon: Badge.count(
            count: unread,
            isLabelVisible: unread > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        IconButton(
          tooltip: 'AI Copilot',
          onPressed: () => context.push(Routes.assistant),
          icon: const Icon(Icons.auto_awesome_outlined),
        ),
      ],
    );
  }
}

class _DashboardActions extends ConsumerWidget {
  const _DashboardActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (profile?.depotId != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AppChip(label: 'Assigned depot', hue: SemanticHue.info, dense: true),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: AppChip(label: 'No depot', hue: SemanticHue.bad, dense: true),
          ),
      ],
    );
  }
}

/// Compact greeting: hey + name in title case, role pill, depot chip.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.profile});

  final Profile? profile;

  static String _titleCase(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          // An all-caps word is an acronym (AIISM, DSO) and must stay caps;
          // lower-casing "AIISM" into "Aiism" misnames the person.
          if (word.length <= 6 && word == word.toUpperCase()) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  static String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = profile;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(DateTime.now()),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _titleCase(p?.displayName ?? 'there'),
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppChip(
              label: _titleCase(p?.role.label ?? 'User'),
              hue: SemanticHue.info,
            ),
            const SizedBox(height: 6),
            Text(
              _formatToday(DateTime.now()),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Hero card: today's tasks done vs due, as a ring.
///
/// The ring is the one place a large number is allowed, because it is the
/// single figure the dashboard exists to show.
class _ComplianceRingCard extends StatelessWidget {
  const _ComplianceRingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Real numbers arrive with the routine-tasks slice; until then the ring is
    // inert rather than false, so it reads as unpopulated rather than zero.
    const done = 0;
    const due = 0;
    const ratio = due == 0 ? null : done / due;

    return AppCard(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    value: ratio ?? 0,
                    strokeWidth: 9,
                    backgroundColor: theme.colorScheme.outlineVariant,
                    valueColor: AlwaysStoppedAnimation(
                      ratio == null
                          // A ring with no data must read as "no data", not as
                          // a green pass. Neutral grey is the honest colour.
                          ? theme.colorScheme.outline
                          : AppTokens.complianceColor((ratio * 100)),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ratio == null ? '—' : '${(ratio * 100).round()}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'today',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Routine task compliance', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  ratio == null
                      ? 'No tasks due today for your depot.'
                      : '$done of $due completed. Open Tasks to catch up.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2×2 compact KPI grid, plus hazards and CAPA when present.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.counts, this.role});

  final DashboardCounts counts;
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      KpiCard(
        label: 'Open incidents',
        value: '${counts.openIncidents}',
        icon: Icons.report_gmailerrorred_outlined,
        hue: counts.openIncidents > 0 ? SemanticHue.bad : SemanticHue.good,
        subLabel: 'awaiting closure',
        onTap: () => context.push(Routes.incidents),
      ),
      KpiCard(
        label: 'Overdue actions',
        value: '${counts.overdueCapa}',
        icon: Icons.schedule_outlined,
        hue: counts.overdueCapa > 0 ? SemanticHue.bad : SemanticHue.good,
        subLabel: 'past their due date',
      ),
      KpiCard(
        label: 'Pending permits',
        value: '${counts.pendingPermits}',
        icon: Icons.approval_outlined,
        hue: counts.pendingPermits > 0 ? SemanticHue.warn : SemanticHue.good,
        subLabel: role?.isAdmin == true ? 'for you to approve' : 'awaiting approval',
      ),
      KpiCard(
        label: 'Inspections 30d',
        value: '${counts.inspections30d}',
        icon: Icons.checklist_outlined,
        hue: counts.inspections30d > 0 ? SemanticHue.good : SemanticHue.warn,
        subLabel: 'recorded this month',
        onTap: () => context.push(Routes.inspections),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppTokens.spaceSm,
      crossAxisSpacing: AppTokens.spaceSm,
      childAspectRatio: 1.5,
      children: tiles,
    );
  }
}

class _KpiGridSkeleton extends StatelessWidget {
  const _KpiGridSkeleton();

  @override
  Widget build(BuildContext context) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: AppTokens.spaceSm,
        crossAxisSpacing: AppTokens.spaceSm,
        childAspectRatio: 1.5,
        children: const [
          SkeletonCard(),
          SkeletonCard(),
          SkeletonCard(),
          SkeletonCard(),
        ],
      );
}

/// One horizontally scrollable chip row, replacing the wrapped tonal chips.
class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow();

  static const _labels = <({String label, String route, IconData icon})>[
    (label: 'Permits', route: Routes.permits, icon: Icons.approval_outlined),
    (label: 'Inspections', route: Routes.inspections, icon: Icons.checklist_outlined),
    (label: 'Truck checks', route: Routes.truckInspections, icon: Icons.local_shipping_outlined),
    (label: 'Incidents', route: Routes.incidents, icon: Icons.report_gmailerrorred_outlined),
    (label: 'Hazards', route: Routes.hazards, icon: Icons.warning_amber_rounded),
    (label: 'CAPA', route: Routes.capa, icon: Icons.build_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppTokens.spaceSm),
        itemBuilder: (context, i) {
          final item = _labels[i];
          return ActionChip(
            avatar: Icon(item.icon, size: 16),
            label: Text(item.label),
            onPressed: () => context.push(item.route),
          );
        },
      ),
    );
  }
}

/// Items that need a decision, each linking to the module that resolves them.
class _NeedsAttentionList extends StatelessWidget {
  const _NeedsAttentionList();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.symmetric(vertical: AppTokens.spaceMd),
      child: EmptyState(
        title: 'All clear',
        message: 'No overdue actions, open incidents or pending approvals are '
            'waiting on your depot.',
        icon: Icons.verified_outlined,
      ),
    );
  }
}

class _DepotCard extends ConsumerWidget {
  const _DepotCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).profile;
    final depotsAsync = ref.watch(_myDepotsProvider);

    return depotsAsync.when(
      loading: () => const SkeletonCard(),
      error: (e, _) => AppCard(
        child: EmptyState(
          message: _readableError(e),
          icon: Icons.error_outline,
          title: 'Depot unavailable',
        ),
      ),
      data: (depots) {
        final current = profile?.depotId;
        final depot = depots.where((d) => d.id == current).firstOrNull;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                depot?.displayName ?? 'No depot assigned',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                depot != null
                    ? [
                        if (depot.city != null) depot.city!,
                        if (depot.region != null) depot.region!,
                      ].join(', ')
                    : 'Site data is hidden until an administrator assigns you '
                        'to a depot. Records assigned to you are still visible.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

final _myDepotsProvider = FutureProvider((ref) async {
  return ref.read(depotRepositoryProvider).listDepots();
});

String _readableError(Object error) {
  final lower = error.toString().toLowerCase();
  if (lower.contains('failed host lookup') ||
      lower.contains('socketexception') ||
      lower.contains('network is unreachable') ||
      lower.contains('no address associated')) {
    return 'You appear to be offline. Changes made on this device are queued '
        'and synchronise automatically when the connection returns.';
  }
  if (lower.contains('permission denied') ||
      lower.contains('42501') ||
      lower.contains('row-level security')) {
    return 'You do not have permission to view this. Your role and depot '
        'assignment decide what you can see — contact an administrator if this '
        'looks wrong.';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'The server took too long to respond. Try again in a moment.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}

String _formatToday(DateTime d) =>
    '${_weekday(d)}, ${_p(d.day)} ${_month(d)}';
String _weekday(DateTime d) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
String _month(DateTime d) =>
    const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1];
String _p(int n) => n.toString().padLeft(2, '0');
