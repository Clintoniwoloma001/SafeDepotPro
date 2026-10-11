import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';

/// Append-only audit trail.
///
/// Visibility is a deliberate exception to the normal isolation rules:
/// `audit_read` grants SELECT only to a SUPERADMIN. That means a user opening
/// this screen without the role gets an empty result rather than a rejection,
/// which is why the role guard is applied on the route too.
class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(auditProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit trail')),
      body: AsyncListView(
        value: entries,
        loadingMessage: 'Loading audit trail…',
        onRetry: () => ref.refresh(auditProvider.future),
        emptyTitle: 'No audit entries',
        emptyMessage: 'Approvals, corrections and status changes are recorded here.',
        emptyIcon: Icons.history_outlined,
        itemBuilder: (context, index) {
          final list = entries.value ?? const [];
          return _AuditTile(entry: list[index]);
        },
      ),
    );
  }
}

final auditProvider = FutureProvider<List<AuditEntry>>((ref) async {
  return ref.read(auditRepositoryProvider).recent();
});

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.action,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatTimestamp(entry.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.actorName ?? entry.actorUserId ?? 'system'} · ${entry.target ?? 'no target'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (entry.meta.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.meta.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join(', '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime d) =>
    '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';
String _p(int n) => n.toString().padLeft(2, '0');
