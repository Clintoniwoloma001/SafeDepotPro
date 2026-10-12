// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../data/models/workflows.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';
import '../../data/repositories/auth_repository.dart';

/// Corrective actions list and approval workflow.
final capaProvider = FutureProvider((ref) async {
  return ref.read(capaRepositoryProvider).listCapa();
});

class CapaScreen extends ConsumerWidget {
  const CapaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capa = ref.watch(capaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Corrective actions')),
      body: AsyncListView(
        value: capa,
        loadingMessage: 'Loading actions…',
        onRetry: () => ref.refresh(capaProvider.future),
        emptyTitle: 'No open actions',
        emptyMessage: 'Actions raised from incidents, inspections and audits will appear here.',
        itemBuilder: (context, index) {
          final list = capa.value ?? const [];
          final c = list[index];
          return _CapaCard(
            id: c.id,
            number: c.capaNumber,
            title: c.title,
            priority: c.priority,
            status: c.status,
            dueDate: c.dueDate,
            completionRate: c.completionRate,
            responsibleName: c.responsibleName,
          );
        },
      ),
    );
  }
}

class _CapaCard extends StatelessWidget {
  const _CapaCard({
    required this.id,
    required this.number,
    required this.title,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.completionRate,
    required this.responsibleName,
  });

  final String id;
  final String number;
  final String title;
  final Priority priority;
  final CapaStatus status;
  final DateTime? dueDate;
  final int completionRate;
  final String? responsibleName;

  bool get _isOverdue =>
      dueDate != null && status.isActive && dueDate!.isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: () => _openDetail(context, id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(number, style: theme.textTheme.labelMedium)),
                  StatusChip.priority(priority),
                  const SizedBox(width: 6),
                  StatusChip.capa(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _isOverdue ? Icons.warning_amber_outlined : Icons.schedule,
                    size: 13,
                    color: _isOverdue ? theme.colorScheme.error : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dueDate == null ? 'No due date' : 'Due ${_formatDate(dueDate!)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _isOverdue ? theme.colorScheme.error : theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.person_outline, size: 13, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      responsibleName ?? 'Unassigned',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: completionRate / 100),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, String id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CapaDetailSheet(id: id),
    );
  }
}

/// CAPA detail with the assignment guard.
///
/// Management fields (title, priority, due date, responsible person) are only
/// editable by admins; an assignee can only advance status and completion.
/// This is not just UI politeness — the database trigger rejects assignee
/// edits to management fields, so the two stay in sync.
class CapaDetailSheet extends ConsumerStatefulWidget {
  const CapaDetailSheet({super.key, required this.id});

  final String id;

  @override
  ConsumerState<CapaDetailSheet> createState() => _CapaDetailSheetState();
}

class _CapaDetailSheetState extends ConsumerState<CapaDetailSheet> {
  bool _working = false;
  String? _error;

  Future<void> _setStatus(Capa item, CapaStatus status, int rate) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final profile = ref.read(profileProvider).profile;
      if (profile == null) throw const AuthFailure('You are not signed in.');
      await ref.read(capaRepositoryProvider).updateProgress(
            id: item.id,
            status: status,
            completionRate: rate,
            completedByUserId: profile.id,
          );
      if (!mounted) return;
      ref.invalidate(capaProvider);
      ref.invalidate(dashboardCountsProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked ${status.name}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capaAsync = ref.watch(capaProvider);
    final theme = Theme.of(context);

    return capaAsync.when(
      loading: () => const LoadingView(message: 'Loading action…'),
      error: (e, _) => ErrorView(message: readableError(e)),
      data: (list) {
        final item = list.where((c) => c.id == widget.id).firstOrNull;
        if (item == null) {
          return const ErrorView(message: 'That action was not found or is no longer available to you.');
        }
        final profile = ref.watch(profileProvider).profile;
        final isAdmin = profile?.role.isAdmin ?? false;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${item.capaNumber} · ${item.sourceType}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                if (item.description != null) Text(item.description!),
                const SizedBox(height: 14),
                _Field(label: 'Status', value: item.status.name),
                _Field(
                  label: 'Priority',
                  value: item.priority.wire,
                ),
                _Field(label: 'Due', value: item.dueDate == null ? '—' : _formatDate(item.dueDate!)),
                _Field(label: 'Assigned to', value: item.responsibleName ?? 'Unassigned'),
                if (item.correctiveAction != null)
                  _Field(label: 'Action taken', value: item.correctiveAction!),
                if (item.rootCause != null) _Field(label: 'Root cause', value: item.rootCause!),
                const SizedBox(height: 8),
                if (_error != null) ...[
                  InlineError(_error!),
                  const SizedBox(height: 12),
                ],
                const Divider(),
                const SizedBox(height: 8),
                Text('Advance status', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (item.status != CapaStatus.closed)
                      FilledButton.tonal(
                        onPressed: _working ? null : () => _setStatus(item, CapaStatus.inProgress, 50),
                        child: const Text('In progress'),
                      ),
                    if (item.status != CapaStatus.closed)
                      FilledButton.tonal(
                        onPressed: _working
                            ? null
                            : () => _setStatus(item, CapaStatus.verification, 90),
                        child: const Text('Verification'),
                      ),
                    FilledButton(
                      onPressed: _working || item.status == CapaStatus.closed
                          ? null
                          : () => _confirmClose(item),
                      child: const Text('Close'),
                    ),
                  ],
                ),
                if (!isAdmin) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Only an administrator can change the due date, priority or assignee.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClose(Capa item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close this action?'),
        content: Text(
          'Closing "${item.title}" records it as complete. The action stays in the audit trail and cannot be deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close action')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _setStatus(item, CapaStatus.closed, 100);
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) => '${d.year}-${_p(d.month)}-${_p(d.day)}';
String _p(int n) => n.toString().padLeft(2, '0');
