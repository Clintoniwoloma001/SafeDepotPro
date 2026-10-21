// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';
import '../../data/models/ops_models.dart';
import '../../data/repositories/storage_repository.dart';
import '../../providers/providers.dart';
import '../../data/repositories/routine_task_repository.dart';
import '../shared/components.dart';
import '../shared/ui_kit.dart' hide LoadingView, ErrorView, InlineError;

/// Routine tasks for the signed-in user's depot.
final routineTasksProvider = FutureProvider<List<RoutineTask>>((ref) async {
  return ref.read(routineTaskRepositoryProvider).listTasks();
});

/// User-selected frequency filter for the task list. Defaults to Daily.
class _FrequencyFilterNotifier extends Notifier<Frequency> {
  @override
  Frequency build() => Frequency.daily;

  void setFrequency(Frequency frequency) => state = frequency;
}

final taskFrequencyFilterProvider =
    NotifierProvider<_FrequencyFilterNotifier, Frequency>(_FrequencyFilterNotifier.new);

/// Selected date for the Open tab.
class _TaskDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDate(DateTime date) => state = date;
}

final taskDateProvider =
    NotifierProvider<_TaskDateNotifier, DateTime>(_TaskDateNotifier.new);

/// Selected time slot filter for the Open tab (null = all).
class _TaskTimeSlotNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setSlot(String? slot) => state = slot;
}

final taskTimeSlotFilterProvider =
    NotifierProvider<_TaskTimeSlotNotifier, String?>(
      _TaskTimeSlotNotifier.new,
    );

/// Filtered task list honouring the selected frequency.
final filteredTasksProvider = FutureProvider.family<List<RoutineTask>, Frequency>((ref, frequency) async {
  final repo = ref.read(routineTaskRepositoryProvider);
  final date = ref.watch(taskDateProvider);
  final slot = ref.watch(taskTimeSlotFilterProvider);
  final open = await repo.dueToday(date);
  var result = open.where((t) => t.frequency == frequency).toList(growable: false);
  if (slot != null && slot.isNotEmpty) {
    result = result.where((t) => t.timeSlot == slot).toList(growable: false);
  }
  return result;
});

final completedTasksByFrequencyProvider = FutureProvider.family<List<RoutineTask>, Frequency>((ref, frequency) async {
  final repo = ref.read(routineTaskRepositoryProvider);
  final done = await repo.completedTasks(DateTime.now());
  return done.where((t) => t.frequency == frequency).toList(growable: false);
});

final taskCompletionPhotoProvider = FutureProvider.family<String?, String>((ref, taskId) async {
  return ref.read(routineTaskRepositoryProvider).latestCompletionPhoto(taskId);
});

/// Selected date for the Completed tab (defaults to today).
class _CompletedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDate(DateTime date) => state = date;
}

final completedDateProvider =
    NotifierProvider<_CompletedDateNotifier, DateTime>(_CompletedDateNotifier.new);

final completedRecordsProvider = FutureProvider.family<List<TaskCompletionRecord>, DateTime>((ref, day) async {
  return ref.read(routineTaskRepositoryProvider).completedTaskRecords(day);
});


class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frequency = ref.watch(taskFrequencyFilterProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(148),
            child: Column(
              children: [
                _FrequencyFilterBar(
                  frequency: frequency,
                  onChanged: (f) =>
                      ref.read(taskFrequencyFilterProvider.notifier).setFrequency(f),
                ),
                _TaskDateAndSlotFilter(),
                TabBar(
                  tabs: const [
                    Tab(text: 'Open'),
                    Tab(text: 'Completed'),
                  ],
                  labelColor: theme.colorScheme.onSurface,
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _TaskList(provider: filteredTasksProvider(frequency), frequency: frequency, emptyTitle: 'No open tasks'),
            _CompletedTab(frequency: frequency),
          ],
        ),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.provider, required this.frequency, required this.emptyTitle});

  final FutureProvider<List<RoutineTask>> provider;
  final Frequency frequency;
  final String emptyTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(provider);
    return tasks.when(
      loading: () => const LoadingView(message: 'Loading tasks…'),
      error: (e, _) => ErrorView(message: readableError(e)),
      data: (list) {
        final theme = Theme.of(context);
        if (list.isEmpty) {
          return EmptyView(
            title: emptyTitle,
            message: 'No routine tasks with ${frequency.wire.toLowerCase()} frequency.',
            icon: Icons.task_outlined,
          );
        }
        // Group by time slot / time of completion.
        final groups = <String, List<RoutineTask>>{};
        for (final t in list) {
          groups.putIfAbsent(t.timeSlot, () => []).add(t);
        }
        final orderedSlots = groups.keys.toList()..sort();
        final items = <Widget>[];
        for (final slot in orderedSlots) {
          items.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(slot, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ));
          for (final t in groups[slot]!) {
            items.add(Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _TaskCard(task: t),
            ));
          }
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
          children: items,
        );
      },
    );
  }
}

class _FrequencyFilterBar extends StatelessWidget {
  const _FrequencyFilterBar({
    required this.frequency,
    required this.onChanged,
  });

  final Frequency frequency;
  final ValueChanged<Frequency> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by frequency',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: Frequency.values.where(
              (f) => f == Frequency.daily || f == Frequency.weekly || f == Frequency.monthly,
            ).map((f) => _FilterChip(
              label: f.wire.toLowerCase(),
              selected: f == frequency,
              onSelected: () => onChanged(f),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: theme.colorScheme.primary,
      checkmarkColor: theme.colorScheme.onPrimary,
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final RoutineTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: _TaskActionButton(task: task),
          ),
        ],
      ),
    );
  }
}

class _TaskActionButton extends ConsumerWidget {
  const _TaskActionButton({required this.task});
  final RoutineTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(completedTasksByFrequencyProvider(task.frequency)).value ?? const [];
    final isCompleted = completed.any((t) => t.id == task.id);
    if (!isCompleted) {
      return FilledButton.icon(
        onPressed: () => context.push('${Routes.tasks}/complete?task=${task.id}'),
        icon: const Icon(Icons.check, size: 17),
        label: const Text('Complete'),
      );
    }
    final photoAsync = ref.watch(taskCompletionPhotoProvider(task.id));
    return FilledButton.icon(
      onPressed: () {
        final path = photoAsync.value;
        if (path == null) return;
        final url = ref.read(storageRepositoryProvider).publicUrl(StorageRepository.photos, path);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Submitted image'),
            content: (url != null) ? Image.network(url) : Text(path),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        );
      },
      icon: const Icon(Icons.image, size: 17),
      label: const Text('View image'),
    );
  }
}

class TaskCompletionForm extends ConsumerStatefulWidget {
  const TaskCompletionForm({super.key, required this.task});

  final RoutineTask task;

  @override
  ConsumerState<TaskCompletionForm> createState() => _TaskCompletionFormState();
}

class _TaskCompletionFormState extends ConsumerState<TaskCompletionForm> {
  String? _photoPath;
  bool _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Task')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: theme.textTheme.titleMedium,
            ),
            if (task.description != null) ...[
              const SizedBox(height: 8),
              Text(
                task.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Frequency: ${task.frequency.wire.toLowerCase()}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (task.requiresPhotoOnCompletion) ...[
              const SizedBox(height: 16),
              Text(
                'Photo Required',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_photoPath != null) ...[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Image.file(File(_photoPath!), fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Retake photo'),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Take photo'),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              InlineError(_error!),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(_submitting ? 'Completing…' : 'Complete Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (!widget.task.requiresPhotoOnCompletion) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null) return;
    if (!mounted) return;

    final profile = ref.read(profileProvider).profile;
    final depotId = profile?.depotId ?? 'unassigned';
    final storage = ref.read(storageRepositoryProvider);

    try {
      final path = await storage.uploadBytes(
        bucket: StorageRepository.photos,
        depotId: depotId,
        fileName: file.name,
        bytes: await file.readAsBytes(),
      );
      setState(() => _photoPath = path);
    } catch (e) {
      setState(() => _error = readableError(e));
    }
  }

  Future<void> _submit() async {
    if (widget.task.requiresPhotoOnCompletion && _photoPath == null) {
      setState(() => _error = 'A photo is required to complete this task.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final profile = ref.read(profileProvider).profile;
      if (profile == null) throw Exception('You are not signed in.');

      await ref.read(routineTaskRepositoryProvider).updateTaskStatus(
        taskId: widget.task.id,
        status: TaskStatus.completed,
        photoPath: _photoPath,
        userId: profile.id,
        depotId: profile.depotId,
      );

      if (!mounted) return;
      ref.invalidate(routineTasksProvider);
      ref.invalidate(openTasksProvider);
      ref.invalidate(filteredTasksProvider);
      ref.invalidate(completedTasksProvider);
      ref.invalidate(completedTasksByFrequencyProvider);
      ref.invalidate(taskCompletionPhotoProvider(widget.task.id));
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task completed.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _CompletedTab extends ConsumerWidget {
  const _CompletedTab({required this.frequency});

  final Frequency frequency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(completedDateProvider);
    final recordsAsync = ref.watch(completedRecordsProvider(day));
    final theme = Theme.of(context);

    String fmtDate(DateTime d) {
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}';
    }

    String groupHeader(DateTime d) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yest = today.subtract(const Duration(days: 1));
      final dd = DateTime(d.year, d.month, d.day);
      if (dd == today) return 'Today';
      if (dd == yest) return 'Yesterday';
      return fmtDate(dd);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              ActionChip(
                label: const Text('Today'),
                onPressed: () => ref.read(completedDateProvider.notifier).setDate(DateTime.now()),
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('Yesterday'),
                onPressed: () => ref.read(completedDateProvider.notifier).setDate(
                    DateTime.now().subtract(const Duration(days: 1))),
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('Pick date'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    ref.read(completedDateProvider.notifier).setDate(picked);
                  }
                },
              ),
              const Spacer(),
              Text(fmtDate(day), style: theme.textTheme.labelSmall),
            ],
          ),
        ),
        Expanded(
          child: recordsAsync.when(
            loading: () => const LoadingView(message: 'Loading completed tasks…'),
            error: (e, _) => ErrorView(message: readableError(e)),
            data: (records) {
              final filtered = records.where((r) => r.task.frequency == frequency).toList();
              if (filtered.isEmpty) {
                return const EmptyView(
                  title: 'No completed tasks',
                  message: 'No completed routine tasks for this day.',
                  icon: Icons.task_outlined,
                );
              }
              // group by date
              final groups = <String, List<TaskCompletionRecord>>{};
              for (final r in filtered) {
                final key = groupHeader(r.completedAt);
                groups.putIfAbsent(key, () => []).add(r);
              }
              final orderedKeys = groups.keys.toList();
              // sort: Today, Yesterday, then dates newest first
              orderedKeys.sort((a, b) {
                if (a == 'Today') return -1;
                if (b == 'Today') return 1;
                if (a == 'Yesterday') return -1;
                if (b == 'Yesterday') return 1;
                return 0;
              });
              final items = <Widget>[];
              for (final key in orderedKeys) {
                items.add(Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(key, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ));
                for (final r in groups[key]!) {
                  items.add(Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(r.task.title, style: theme.textTheme.titleMedium)),
                              AppChip(label: r.task.frequency.wire.toLowerCase(), hue: SemanticHue.info, dense: true),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Completed ${r.completedAt.hour.toString().padLeft(2, '0')}:${r.completedAt.minute.toString().padLeft(2, '0')} · ${r.completer}',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          if (r.photoPath != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () {
                                  final url = ref.read(storageRepositoryProvider).publicUrl(StorageRepository.photos, r.photoPath!);
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Submitted image'),
                                      content: (url != null) ? Image.network(url) : Text(r.photoPath!),
                                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.image, size: 17),
                                label: const Text('View image'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ));
                }
              }
              return ListView(children: items);
            },
          ),
        ),
      ],
    );
  }
}

class _TaskDateAndSlotFilter extends ConsumerWidget {
  const _TaskDateAndSlotFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = ref.watch(taskDateProvider);
    final slot = ref.watch(taskTimeSlotFilterProvider);
    final allTasks = ref.watch(routineTasksProvider).value ?? const <RoutineTask>[];
    final slots = allTasks.map((t) => t.timeSlot).toSet().toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text('${date.day}/${date.month}/${date.year}'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                ref.read(taskDateProvider.notifier).setDate(picked);
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in slots)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(s),
                        selected: slot == s,
                        onSelected: (_) => ref
                            .read(taskTimeSlotFilterProvider.notifier)
                            .setSlot(slot == s ? null : s),
                        labelStyle: theme.textTheme.labelSmall,
                      ),
                    ),
                  if (slot != null)
                    ActionChip(
                      label: const Text('Clear slot'),
                      onPressed: () =>
                          ref.read(taskTimeSlotFilterProvider.notifier).setSlot(null),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
