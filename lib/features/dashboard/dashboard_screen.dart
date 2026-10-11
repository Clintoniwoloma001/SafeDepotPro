import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../data/models/enums.dart';
import '../../providers/providers.dart';
import '../shared/app_shell.dart';
import '../shared/ui_kit.dart';
import '../../core/theme/app_colors.dart';

/// Role-specific dashboard.
///
/// What a supervisor needs is not what a country head needs, so the tiles are
/// chosen by role rather than showing every number to everyone. An inspector
/// sees their own queue; management sees the compliance posture.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    final counts = ref.watch(dashboardCountsProvider);
    final userName = profile?.displayName ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [LogoutButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardCountsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            PageHeader(
              title: 'Welcome, $userName',
              subtitle: _roleSubtitle(profile?.role),
            ),
            const PageHeader(title: 'Attention needed'),
            counts.when(
              loading: () => const LoadingView(message: 'Counting open work…'),
              error: (e, _) => ErrorView(
                message: readableError(e),
                onRetry: () => ref.refresh(dashboardCountsProvider.future),
              ),
              data: (c) => _KpiGrid(counts: c, role: profile?.role),
            ),
            const SizedBox(height: 28),
            const PageHeader(title: 'Quick actions'),
            _QuickActions(role: profile?.role),
            const SizedBox(height: 28),
            const PageHeader(title: 'Your depot'),
            const _DepotCard(),
          ],
        ),
      ),
    );
  }

  static String _roleSubtitle(UserRole? role) => switch (role) {
        UserRole.superadmin => 'Full platform oversight',
        UserRole.countryHead => 'Cross-depot oversight',
        UserRole.admin => 'Depot administration',
        UserRole.user || null => 'Field safety operations',
      };
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.counts, this.role});

  final DashboardCounts counts;
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      KpiTile(
        label: 'Open incidents',
        value: '${counts.openIncidents}',
        icon: Icons.report_gmailerrorred_outlined,
        color: AppColors.statusOpen,
        onTap: () => context.go(Routes.incidents),
      ),
      KpiTile(
        label: 'Overdue actions',
        value: '${counts.overdueCapa}',
        icon: Icons.schedule_outlined,
        color: AppColors.severityHigh,
        onTap: () => context.go(Routes.capa),
      ),
    ];

    if (role?.isAdmin ?? false) {
      tiles.add(
        KpiTile(
          label: 'Pending permits',
          value: '${counts.pendingPermits}',
          icon: Icons.approval_outlined,
          color: AppColors.statusVerification,
          onTap: () => context.go(Routes.permits),
        ),
      );
    }

    tiles.add(
      KpiTile(
        label: 'Inspections (30d)',
        value: '${counts.inspections30d}',
        icon: Icons.checklist_outlined,
        color: AppColors.statusClosed,
        onTap: () => context.go(Routes.inspections),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 460 ? 2 : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: tiles,
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.role});

  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => context.go('${Routes.incidents}?report=1'),
          icon: const Icon(Icons.report_gmailerrorred_outlined),
          label: const Text('Report incident'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.go(Routes.inspections),
          icon: const Icon(Icons.checklist),
          label: const Text('Start inspection'),
        ),
        if (role?.isAdmin ?? false)
          FilledButton.tonalIcon(
            onPressed: () => context.go(Routes.permits),
            icon: const Icon(Icons.approval),
            label: const Text('Review permits'),
          ),
      ],
    );
  }
}

class _DepotCard extends ConsumerWidget {
  const _DepotCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    final depotsAsync = ref.watch(_myDepotsProvider);

    return depotsAsync.when(
      loading: () => const LoadingView(message: 'Finding your depots…'),
      error: (e, _) => ErrorView(message: readableError(e)),
      data: (depots) {
        final current = profile?.depotId;
        final depot = depots.where((d) => d.id == current).firstOrNull;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  depot?.displayName ?? 'No depot assigned',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  depot != null
                      ? [
                          if (depot.city != null) depot.city!,
                          if (depot.region != null) depot.region!,
                        ].join(', ')
                      : 'Your account is not yet assigned to a depot. You can still see records assigned to you, but site-scoped data is unavailable.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Depots the caller can read. The list itself is RLS-scoped.
final _myDepotsProvider = FutureProvider((ref) async {
  return ref.read(depotRepositoryProvider).listDepots();
});
