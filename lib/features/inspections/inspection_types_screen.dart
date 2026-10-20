// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../data/models/ops_models.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';

/// List of inspection types available to start a new inspection.
class InspectionTypesScreen extends ConsumerWidget {
  const InspectionTypesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(inspectionTypesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Inspection Type')),
      body: types.when(
        loading: () => const LoadingView(message: 'Loading inspection types…'),
        error: (e, _) => ErrorView(message: readableError(e)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              title: 'No inspection types',
              message: 'No active inspection types are available. Ask an administrator to create one.',
              icon: Icons.assessment_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final type = list[index];
              return ListTile(
                leading: const Icon(Icons.assessment_outlined, size: 20),
                title: Text(type.inspectionName),
                subtitle: Text(
                  type.inspectionCode ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.go(
                  '${Routes.checklistFromType}?typeId=${type.inspectionTypeId}&name=${Uri.encodeComponent(type.inspectionName)}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
