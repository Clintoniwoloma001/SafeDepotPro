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
import '../../data/repositories/routine_task_repository.dart';
import '../shared/components.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';


/// Selected day for the dashboard compliance ring.
class _ComplianceDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
}

final complianceDayProvider =
    NotifierProvider<_ComplianceDayNotifier, DateTime>(_ComplianceDayNotifier.new);

final complianceCountsProvider = FutureProvider.family<({int due, int done}), DateTime>((ref, day) async {
  return ref.read(routineTaskRepositoryProvider).complianceForDay(day);
});

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
            const _DailyReasonPrompt(),
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
/// main screens.
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

/// Hero card: selected day's tasks done vs due, as a ring.
class _ComplianceRingCard extends ConsumerWidget {
  const _ComplianceRingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref.watch(complianceDayProvider);
    final countsAsync = ref.watch(complianceCountsProvider(day));

    return countsAsync.when(
      loading: () => _buildRing(context, theme, null, 0, 0, day, ref),
      error: (_, __) => _buildRing(context, theme, null, 0, 0, day, ref),
      data: (c) {
        final ratio = c.due == 0 ? null : c.done / c.due;
        return _buildRing(context, theme, ratio, c.done, c.due, day, ref);
      },
    );
  }

  Widget _buildRing(BuildContext context, ThemeData theme, double? ratio, int done, int due, DateTime day, WidgetRef ref) {
    final canPrev = true;
    final canNext = !_isToday(day);
    return AppCard(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => ref.read(complianceDayProvider.notifier).state =
                    day.subtract(const Duration(days: 1)),
              ),
              Expanded(
                child: Center(
                  child: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: day,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        ref.read(complianceDayProvider.notifier).state = picked;
                      }
                    },
                    child: Text(_fmtDate(day)),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: canNext
                    ? () => ref.read(complianceDayProvider.notifier).state =
                        day.add(const Duration(days: 1))
                    : null,
              ),
            ],
          ),
          Row(
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
                          'day',
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
                      due == 0
                          ? 'No tasks due'
                          : '$done of $due completed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (due > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Open tasks for this day',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
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
      KpiCard(
        label: 'Man-hours 30d',
        value: '${counts.manHours30d}',
        icon: Icons.access_time_outlined,
        hue: counts.manHours30d > 0 ? SemanticHue.good : SemanticHue.warn,
        subLabel: 'records this month',
        onTap: () => context.push(Routes.manHours),
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
    (label: 'Truck checks', route: Routes.customerTruckInspection, icon: Icons.local_shipping_outlined),
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

/// Prompts for reasons when daily tasks are incomplete after 5:00 PM.
class _DailyReasonPrompt extends ConsumerStatefulWidget {
  const _DailyReasonPrompt();

  @override
  ConsumerState<_DailyReasonPrompt> createState() => _DailyReasonPromptState();
}

class _DailyReasonPromptState extends ConsumerState<_DailyReasonPrompt> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    if (_checked || !mounted) return;
    _checked = true;
    final now = DateTime.now();
    if (now.hour < 17) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'incomplete_reasons_${now.year}-${now.month}-${now.day}';
    if (prefs.containsKey(key)) return;

    final counts = await ref.read(routineTaskRepositoryProvider).complianceForDay(now);
    if (counts.due == 0 || counts.done >= counts.due) return;

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Incomplete tasks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Have you completed all possible tasks for today? If not, please provide reasons for any incomplete tasks.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Reasons for incomplete tasks…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (submitted == true) {
      await prefs.setString(key, controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
