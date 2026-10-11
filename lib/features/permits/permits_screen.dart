import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../data/models/workflows.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';
import '../../data/repositories/auth_repository.dart';

/// Permit approvals.
///
/// Read-only for the mobile app: permits are complex multi-section documents
/// that are authored in the web console, and duplicating that authoring on a
/// phone is how half-populated permits get approved. The phone job is review
/// and decision, which is exactly what a supervisor does in the field.
final permitsProvider = FutureProvider((ref) async {
  return ref.read(permitRepositoryProvider).listPermits();
});

class PermitsScreen extends ConsumerWidget {
  const PermitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permits = ref.watch(permitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Permit approvals')),
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
        await repo.reject(widget.permit.id, profile.id, reason!);
      }
      if (!mounted) return;
      ref.invalidate(permitsProvider);
      ref.invalidate(dashboardCountsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permit ${status.name}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _askForReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this permit'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            hintText: 'Explain what must change before this can be approved.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx, text.isEmpty ? null : text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.permit;
    final theme = Theme.of(context);
    final canDecide = p.status.isPending;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.jobTitle, style: theme.textTheme.titleMedium),
                ),
                StatusChip.permit(p.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${p.permitNumber} · ${p.permitType ?? 'Permit'}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (p.startDatetime != null) ...[
              const SizedBox(height: 6),
              Text(
                'Starts ${_formatDateTime(p.startDatetime!)}',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
            if (p.location != null) ...[
              const SizedBox(height: 2),
              Text(
                'Location: ${p.location}',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
            if (p.rejectionReason != null) ...[
              const SizedBox(height: 10),
              InlineError('Rejected: ${p.rejectionReason}'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              InlineError(_error!),
            ],
            if (canDecide) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _working ? null : () => _decide(PermitStatus.rejected),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _working ? null : () => _decide(PermitStatus.approved),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime d) =>
    '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';
String _p(int n) => n.toString().padLeft(2, '0');
