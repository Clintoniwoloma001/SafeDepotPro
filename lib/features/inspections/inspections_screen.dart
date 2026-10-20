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
import '../shared/ui_kit.dart';

/// Inspection list.
final inspectionsProvider = FutureProvider((ref) async {
  return ref.read(inspectionRepositoryProvider).listInspections();
});

final templatesProvider = FutureProvider((ref) async {
  return ref.read(inspectionRepositoryProvider).listTemplates();
});

class InspectionsScreen extends ConsumerWidget {
  const InspectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspections = ref.watch(inspectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inspections')),
      body: AsyncListView(
        value: inspections,
        loadingMessage: 'Loading inspections…',
        onRetry: () => ref.refresh(inspectionsProvider.future),
        emptyTitle: 'No inspections recorded',
        emptyMessage: 'Run your first checklist below. Records stay on this device until they sync.',
        itemBuilder: (context, index) {
          final list = inspections.value ?? const [];
          final inspection = list[index];
          return _InspectionCard(
            checklist: inspection.checklistName,
            type: inspection.type,
            status: inspection.status,
            compliance: inspection.compliance,
            createdAt: inspection.createdAt,
            fails: inspection.failCount,
            answered: inspection.answeredCount,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.inspectionsTypes),
        icon: const Icon(Icons.add),
        label: const Text('New inspection'),
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({
    required this.checklist,
    required this.type,
    required this.status,
    required this.compliance,
    required this.createdAt,
    required this.fails,
    required this.answered,
  });

  final String checklist;
  final String type;
  final InspectionStatus status;
  final double compliance;
  final DateTime createdAt;
  final int fails;
  final int answered;

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
                  child: Text(checklist, style: theme.textTheme.titleMedium),
                ),
                StatusChip.inspection(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${compliance.toStringAsFixed(0)}% compliance · $answered answered · $fails failed',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';
  static String _p(int n) => n.toString().padLeft(2, '0');
}
