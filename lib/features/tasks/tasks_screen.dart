// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/ops_models.dart';
import '../../providers/providers.dart';
import '../shared/components.dart';
import '../shared/ui_kit.dart';

/// Routine tasks for the signed-in user's depot.
///
/// The record set is decided by the `routine_tasks_read` RLS policy, so a USER
/// sees tasks assigned to all depots, to their own depot, or to them by name
/// in the import. No depot filter is applied here.
final routineTasksProvider = FutureProvider<List<RoutineTask>>((ref) async {
  return ref.read(routineTaskRepositoryProvider).listTasks();
});

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(routineTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: AsyncListView(
        value: tasks,
        loadingMessage: 'Loading tasks…',
        onRetry: () => ref.refresh(routineTasksProvider.future),
        emptyTitle: 'No tasks assigned',
        emptyMessage: 'No routine tasks are assigned to you or your depot yet.',
        itemBuilder: (context, index) {
          final list = tasks.value ?? const [];
          return _TaskCard(task: list[index]);
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final RoutineTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(task.title, style: theme.textTheme.titleMedium),
              ),
              AppChip(
                label: task.frequency.wire.toLowerCase(),
                hue: SemanticHue.info,
                dense: true,
              ),
            ],
          ),
          if (task.category != null) ...[
            const SizedBox(height: 6),
            Text(
              task.category!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (task.description != null) ...[
            const SizedBox(height: 6),
            Text(
              task.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppTokens.spaceSm),
          Row(
            children: [
              if (task.requiresPhotoOnCompletion) ...[
                Icon(
                  Icons.photo_camera_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Photo required',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceMd),
              ],
              if (task.responsiblePerson?.isNotEmpty ?? false) ...[
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.responsiblePerson!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  context.push('${Routes.tasks}/complete?task=${task.id}'),
              icon: const Icon(Icons.check, size: 17),
              label: const Text('Complete'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when a completion flow does not exist yet.
class TaskCompletionPlaceholder extends StatelessWidget {
  const TaskCompletionPlaceholder({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complete task')),
    body: ComingSoonScreen(
      title: 'Task completion',
      message:
          'The completion form is not in this release yet. It arrives in an '
          'update and switches on automatically — no reinstall needed.',
    ),
  );
}
