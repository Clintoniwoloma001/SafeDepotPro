// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../data/models/enums.dart';
import '../../data/models/workflows.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';
import '../../data/repositories/auth_repository.dart';

/// Permit approvals.
final permitsProvider = FutureProvider((ref) async {
  return ref.read(permitRepositoryProvider).listPermits();
});

class PermitsScreen extends ConsumerWidget {
  const PermitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permits = ref.watch(permitsProvider);
    final profile = ref.watch(profileProvider).profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Safety & Inspections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => GoRouter.of(context).push(Routes.inspectionsTypes),
        icon: const Icon(Icons.add),
        label: const Text('New Inspection'),
      ),
      body: AsyncListView(
        value: permits,
        loadingMessage: 'Loading permits…',
        onRetry: () => ref.refresh(permitsProvider.future),
        emptyTitle: 'No permits to review',
        emptyMessage: 'Submitted permits awaiting a decision will appear here.',
        itemBuilder: (context, index) {
          final list = permits.value ?? const [];
          final p = list[index];
          return PermitCard(permit: p);
        },
      ),
    );
  }
}

class PermitCard extends ConsumerStatefulWidget {
  const PermitCard({super.key, required this.permit});

  final Permit permit;

  @override
  ConsumerState<PermitCard> createState() => _PermitCardState();
}

class _PermitCardState extends ConsumerState<PermitCard> {
  bool _working = false;
  String? _error;

  Future<void> _decide(PermitStatus status) async {
    String? reason;
    if (status == PermitStatus.rejected) {
      reason = await _askForReason();
      if (reason == null) return;
    }

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      final profile = ref.read(profileProvider).profile;
      if (profile == null) throw const AuthFailure('You are not signed in.');
      final repo = ref.read(permitRepositoryProvider);
      if (status == PermitStatus.approved) {
        await repo.approve(widget.permit.id, profile.id);
      } else {
        await repo.reject(widget.permit.id, profile.id, reason ?? '');
      }

      if (!mounted) return;
      ref.refresh(permitsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _askForReason() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection Reason'),
        content: TextFormField(
          decoration: const InputDecoration(
            hintText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'Rejected by reviewer'),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permit = widget.permit;
    final theme = Theme.of(context);
    final statusColor = permit.status == PermitStatus.approved
        ? Colors.green
        : permit.status == PermitStatus.rejected
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(permit.permitNumber, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Job: ${permit.jobTitle}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              '${permit.location ?? 'Site'} · ${permit.status.wire}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDateTime(permit.startDatetime),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _working ? null : () => _decide(PermitStatus.approved),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(70, 32),
              ),
              child: const Text('Approve', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: _working ? null : () => _decide(PermitStatus.rejected),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(70, 32),
              ),
              child: const Text('Reject', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? d) {
    if (d == null) return '-';
    return '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';
  }
  String _p(int n) => n.toString().padLeft(2, '0');
}
