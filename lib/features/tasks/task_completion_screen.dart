// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../data/models/ops_models.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';
import '../tasks/tasks_screen.dart';

/// Screen wrapper for task completion. Resolves the task by ID from the
/// routine tasks list and renders [TaskCompletionForm].
class TaskCompletionFormScreen extends ConsumerWidget {
  const TaskCompletionFormScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(routineTasksProvider);

    return allTasks.when(
      loading: () => const LoadingView(message: 'Loading task…'),
      error: (e, _) => ErrorView(message: readableError(e)),
      data: (tasks) {
        final task = tasks.firstWhere(
          (t) => t.id == taskId,
          orElse: () => throw Exception('Task not found'),
        );
        return TaskCompletionForm(task: task);
      },
    );
  }
}
