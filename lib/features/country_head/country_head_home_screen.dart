// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../data/models/workflows.dart';
import '../../data/supabase/supabase_service.dart';
import '../../providers/providers.dart';
import '../shared/components.dart';
import '../manhours/man_hour_reminder.dart';

/// Home view for Country Head / Super Admin: cross-depot overview.
class CountryHeadHomeScreen extends ConsumerWidget {
  const CountryHeadHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    final data = ref.watch(countryHeadHomeDataProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const _ChAppBarTitle(),
        actions: const [_ChAppBarActions()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(countryHeadHomeDataProvider);
          await ref.read(countryHeadHomeDataProvider.future);
        },
        child: data.when(
          loading: () => const LoadingView(message: 'Loading overview…'),
          error: (e, _) => ErrorView(
            message: _readableError(e),
            onRetry: () => ref.invalidate(countryHeadHomeDataProvider),
          ),
          data: (d) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceLg,
              AppTokens.spaceSm,
              AppTokens.spaceLg,
              AppTokens.spaceXl,
            ),
            children: [
              _GreetingHeader(profile: profile),
              const SizedBox(height: AppTokens.spaceMd),
              const ManHourReminderCard(countryHead: true),
              const SizedBox(height: AppTokens.spaceLg),
              SectionHeader(
                title: 'Depot routine-task completion',
                subtitle: 'Today • ${d.dayLabel}',
              ),
              const SizedBox(height: AppTokens.spaceSm),
              _DepotTaskTable(data: d),
              const SizedBox(height: AppTokens.spaceLg),
              SectionHeader(
                title: 'Task-based risk assessment',
                subtitle: 'Permits to work • ongoing & completed',
              ),
              const SizedBox(height: AppTokens.spaceSm),
              _PermitRiskSection(data: d),
              const SizedBox(height: AppTokens.spaceLg),
              SectionHeader(
                title: 'Inspections across depots',
                subtitle: 'Who carried them out, result, next due',
              ),
              const SizedBox(height: AppTokens.spaceSm),
              _InspectionsSection(data: d),
              const SizedBox(height: AppTokens.spaceLg),
              SectionHeader(
                title: 'Lagging / no-data users',
                subtitle: 'Non-superadmin users with no activity',
              ),
              const SizedBox(height: AppTokens.spaceSm),
              _LaggingUsersSection(data: d),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChAppBarTitle extends ConsumerWidget {
  const _ChAppBarTitle();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: Theme.of(context).appColors.accentGradient),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 17),
        ),
        const SizedBox(width: AppTokens.spaceSm),
        const Expanded(child: Text('Country Head Home', overflow: TextOverflow.ellipsis)),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push(Routes.notifications),
          icon: Badge.count(
            count: unread,
            isLabelVisible: unread > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      ],
    );
  }
}

class _ChAppBarActions extends ConsumerWidget {
  const _ChAppBarActions();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: AppChip(label: 'All depots', hue: SemanticHue.info, dense: true),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.profile});
  final Profile? profile;
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
              Text('Good day', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(p?.displayName ?? 'Country Head', style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
        AppChip(label: p?.role.label ?? 'Country Head', hue: SemanticHue.info),
      ],
    );
  }
}

// ---------------- Data model ----------------

class DepotTaskStat {
  const DepotTaskStat({
    required this.depot,
    required this.users,
    required this.completedByUser,
    required this.totalCompleted,
    required this.dailyDue,
  });
  final Depot depot;
  final List<Profile> users;
  final Map<String, int> completedByUser; // userId -> count
  final int totalCompleted;
  final int dailyDue;
}

class CountryHeadHomeData {
  const CountryHeadHomeData({
    required this.day,
    required this.dayLabel,
    required this.depots,
    required this.users,
    required this.depotStats,
    required this.permits,
    required this.inspections,
    required this.taskHistoryRows,
  });
  final DateTime day;
  final String dayLabel;
  final List<Depot> depots;
  final List<Profile> users;
  final List<DepotTaskStat> depotStats;
  final List<Permit> permits;
  final List<Inspection> inspections;
  final List<Map<String, dynamic>> taskHistoryRows;
}

final countryHeadHomeDataProvider = FutureProvider<CountryHeadHomeData>((ref) async {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final depots = await ref.read(depotRepositoryProvider).listDepots(activeOnly: true);
  final users = await ref.read(authRepositoryProvider).listAllUsers();
  final permits = await ref.read(permitRepositoryProvider).listPermits(limit: 500);
  final inspections = await ref.read(inspectionRepositoryProvider).listInspections(limit: 500);
  final tasks = await ref.read(routineTaskRepositoryProvider).listTasks();
  final history = await ref.read(routineTaskRepositoryProvider).taskHistoryForDay(day);

  final dailyTasks = tasks.where((t) => t.isActive && t.frequency == Frequency.daily).toList();

  int dailyDueForDepot(Depot d) =>
      dailyTasks.where((t) => t.allDepots || t.assignedDepotIds.contains(d.id)).length;

  final depotStats = <DepotTaskStat>[];
  for (final depot in depots) {
    final depotUsers = users.where((u) => u.depotId == depot.id && u.isActive).toList();
    final counts = <String, int>{};
    for (final u in depotUsers) {
      counts[u.id] = 0;
    }
    for (final row in history) {
      final uid = row['user_id']?.toString();
      final did = row['depot_id']?.toString();
      if (did != depot.id) continue;
      if (uid == null) continue;
      // ensure task applies to depot
      final tid = row['task_id']?.toString();
      final task = tasks.firstWhere((t) => t.id == tid, orElse: () => tasks.first);
      if (!(task.allDepots || task.assignedDepotIds.contains(depot.id))) continue;
      counts[uid] = (counts[uid] ?? 0) + 1;
    }
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    depotStats.add(DepotTaskStat(
      depot: depot,
      users: depotUsers,
      completedByUser: counts,
      totalCompleted: total,
      dailyDue: dailyDueForDepot(depot),
    ));
  }

  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final label = '${day.day} ${months[day.month - 1]} ${day.year}';
  return CountryHeadHomeData(
    day: day,
    dayLabel: label,
    depots: depots,
    users: users,
    depotStats: depotStats,
    permits: permits,
    inspections: inspections,
    taskHistoryRows: history,
  );
});

// ---------------- Sections ----------------

class _DepotTaskTable extends StatelessWidget {
  const _DepotTaskTable({required this.data});
  final CountryHeadHomeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.depotStats.isEmpty) {
      return const AppCard(child: EmptyState(title: 'No depots', message: 'No active depots found.', icon: Icons.factory_outlined));
    }
    return Column(
      children: data.depotStats.map((stat) {
        final incompleteUsers = stat.users.where((u) => (stat.completedByUser[u.id] ?? 0) == 0).toList();
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(stat.depot.displayName, style: theme.textTheme.titleMedium)),
                  AppChip(
                    label: '${stat.totalCompleted}/${stat.dailyDue} done',
                    hue: stat.dailyDue == 0
                        ? SemanticHue.neutral
                        : (stat.totalCompleted >= stat.dailyDue ? SemanticHue.good : SemanticHue.warn),
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (stat.users.isEmpty)
                Text('No users assigned', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
              else ...[
                Text('Users that completed:', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                ...stat.users.map((u) {
                  final c = stat.completedByUser[u.id] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(c > 0 ? Icons.check_circle_outline : Icons.radio_button_unchecked, size: 16, color: c > 0 ? Colors.green : Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(child: Text(u.displayName, style: theme.textTheme.bodySmall)),
                        Text('$c', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                }),
                if (incompleteUsers.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Did not complete:', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.red)),
                  ...incompleteUsers.map((u) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.close, size: 16, color: Colors.red),
                            const SizedBox(width: 6),
                            Expanded(child: Text(u.displayName, style: theme.textTheme.bodySmall)),
                          ],
                        ),
                      )),
                ],
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PermitRiskSection extends StatelessWidget {
  const _PermitRiskSection({required this.data});
  final CountryHeadHomeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.permits.isEmpty) {
      return const AppCard(child: EmptyState(title: 'No permits', message: 'No permits recorded.', icon: Icons.approval_outlined));
    }
    // Ongoing = submitted/approved (in progress); completed = completed/closed
    final ongoing = data.permits.where((p) => p.status == PermitStatus.submitted || p.status == PermitStatus.approved || p.status == PermitStatus.draft).toList();
    final completed = data.permits.where((p) => p.status == PermitStatus.completed || p.status == PermitStatus.cancelled || p.status == PermitStatus.rejected).toList();

    Widget group(String title, List<Permit> list, SemanticHue hue) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.spaceSm, bottom: 4),
            child: Text(title, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ...list.take(20).map((p) {
            final depotName = data.depots.firstWhere((d) => d.id == p.depotId, orElse: () => data.depots.isNotEmpty ? data.depots.first : Depot(id: p.depotId, code: p.depotId, name: p.depotId, createdAt: DateTime.now(), updatedAt: DateTime.now())).displayName;
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('${p.permitNumber} — ${p.jobTitle}', style: theme.textTheme.titleSmall)),
                      AppChip(label: p.status.wire, hue: hue, dense: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Depot: $depotName', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (p.attachmentPaths.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: p.attachmentPaths.map((path) {
                        final url = refPublicUrl(path);
                        return ActionChip(
                          avatar: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: const Text('PDF'),
                          onPressed: url == null ? null : () => _openUrl(url),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      );
    }

    return Column(
      children: [
        group('Ongoing', ongoing, SemanticHue.warn),
        group('Completed / closed', completed, SemanticHue.good),
      ],
    );
  }

  static String? refPublicUrl(String path) {
    if (path.startsWith('http')) return path;
    try {
      return SupabaseService.client.storage.from('photos').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _InspectionsSection extends StatelessWidget {
  const _InspectionsSection({required this.data});
  final CountryHeadHomeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.inspections.isEmpty) {
      return const AppCard(child: EmptyState(title: 'No inspections', message: 'No inspections recorded.', icon: Icons.checklist_outlined));
    }
    // group by completedBy
    final byUser = <String, List<Inspection>>{};
    for (final i in data.inspections) {
      final key = i.completedBy ?? 'Unknown';
      byUser.putIfAbsent(key, () => []).add(i);
    }
    final profileById = {for (final u in data.users) u.id: u};
    final depotById = {for (final d in data.depots) d.id: d};

    return Column(
      children: byUser.entries.map((e) {
        final user = profileById[e.key];
        final name = user?.displayName ?? e.key;
        final depot = user?.depotId != null ? depotById[user!.depotId] : null;
        final latest = e.value.first;
        final avgCompliance = e.value.map((i) => i.compliance).fold<double>(0, (a, b) => a + b) / e.value.length;
        final fails = e.value.fold<int>(0, (a, i) => a + i.failCount);
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(name, style: theme.textTheme.titleSmall)),
                  if (depot != null) AppChip(label: depot.code, hue: SemanticHue.neutral, dense: true),
                ],
              ),
              const SizedBox(height: 2),
              Text('Inspections: ${e.value.length} • Avg compliance: ${avgCompliance.toStringAsFixed(0)}% • Fails: $fails',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text('Latest: ${latest.checklistName} (${latest.status.wire}) on ${_fmt(latest.submittedAt ?? latest.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Text('Next scheduled: —', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _LaggingUsersSection extends StatelessWidget {
  const _LaggingUsersSection({required this.data});
  final CountryHeadHomeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeUsers = data.users.where((u) => u.isActive && u.role != UserRole.superadmin).toList();
    final completedUserIds = <String>{};
    for (final row in data.taskHistoryRows) {
      final uid = row['user_id']?.toString();
      if (uid != null) completedUserIds.add(uid);
    }
    final inspectedUserIds = data.inspections.map((i) => i.completedBy).whereType<String>().toSet();

    final lagging = activeUsers.where((u) => !completedUserIds.contains(u.id) && !inspectedUserIds.contains(u.id)).toList();

    if (lagging.isEmpty) {
      return const AppCard(child: EmptyState(title: 'All active', message: 'Every non-superadmin user has activity.', icon: Icons.verified_outlined));
    }
    return Column(
      children: lagging.map((u) {
        final depot = data.depots.firstWhere((d) => d.id == u.depotId, orElse: () => Depot(id: u.depotId ?? '', code: '—', name: 'Unassigned', createdAt: DateTime.now(), updatedAt: DateTime.now()));
        return AppCard(
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text('${u.displayName} (${u.role.label})', style: theme.textTheme.bodySmall)),
              AppChip(label: depot.code, hue: SemanticHue.bad, dense: true),
            ],
          ),
        );
      }).toList(),
    );
  }
}

String _readableError(Object error) {
  final lower = error.toString().toLowerCase();
  if (lower.contains('failed host lookup') || lower.contains('socketexception') || lower.contains('network is unreachable')) {
    return 'You appear to be offline.';
  }
  if (lower.contains('permission denied') || lower.contains('42501') || lower.contains('row-level security')) {
    return 'You do not have permission to view this.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}
