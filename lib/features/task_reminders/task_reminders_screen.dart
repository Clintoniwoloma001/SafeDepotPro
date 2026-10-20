// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/ops_models.dart';
import '../../../../data/models/enums.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../providers/providers.dart';
import '../shared/components.dart';

/// Task Reminders dashboard for Country Heads.
///
/// Shows all pending task reminders across all depots for oversight and monitoring.
class TaskRemindersScreen extends ConsumerStatefulWidget {
  const TaskRemindersScreen({super.key});

  @override
  ConsumerState<TaskRemindersScreen> createState() => _TaskRemindersScreenState();
}

class _TaskRemindersScreenState extends ConsumerState<TaskRemindersScreen> {
  bool _isLoading = false;
  String? _error;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      // Refresh the providers
      ref.refresh(allTaskRemindersProvider);
      ref.refresh(profileProvider);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;
    final isLoading = profileState.isLoading;

    if (isLoading || profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Check if user is Country Head or above
    if (profile.role != UserRole.countryHead && profile.role != UserRole.superadmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Access denied: Country Head or Super Admin required',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final taskRemindersAsync = ref.watch(allTaskRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: taskRemindersAsync.when(
          data: (reminders) => _buildRemindersList(reminders, ref),
          loading: () => _isLoading
              ? const Center(child: CircularProgressIndicator())
              : const Center(child: CircularProgressIndicator()),
          error: (e, stack) => ErrorView(message: 'Failed to load task reminders: $e'),
        ),
      ),
    );
  }

  Widget _buildRemindersList(List<TaskReminder> reminders, WidgetRef ref) {
    if (reminders.isEmpty) {
      return const Center(
        child: Text(
          'No task reminders found.\nTask reminders are created automatically for routine tasks.',
          textAlign: TextAlign.center,
        ),
      );
    }

    // Group reminders by date
    final groupedByDate = <String, List<TaskReminder>>{};
    for (final reminder in reminders) {
      final dateKey = _formatDate(reminder.scheduledAt);
      if (!groupedByDate.containsKey(dateKey)) {
        groupedByDate[dateKey] = [];
      }
      groupedByDate[dateKey]!.add(reminder);
    }

    // Sort dates descending (most recent first)
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayReminders = groupedByDate[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Padding(
               padding: EdgeInsets.all(AppTokens.spaceMd),
               child: Text(
                 date,
                 style: TextStyle(
                   fontSize: AppTokens.titleMedium,
                   fontWeight: FontWeight.bold,
                   color: Theme.of(context).colorScheme.primary,
                 ),
               ),
             ),
            ...dayReminders.map((reminder) => _ReminderCard(reminder: reminder)),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({
    required this.reminder,
  });

  final TaskReminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = reminder.scheduledAt.isBefore(DateTime.now()) &&
        reminder.status == ReminderStatus.pending;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceXs,
      ),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isOverdue
                ? Colors.red[700]
                : reminder.status == ReminderStatus.sent
                    ? Colors.green[700]
                    : Colors.orange[700],
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          reminder.title.isNotEmpty
              ? reminder.title
              : 'Task Reminder #${reminder.id.substring(0, 8)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isOverdue ? Colors.red[800] : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scheduled: ${_formatTime(reminder.scheduledAt)}'),
            if (reminder.recipientUserId != null)
              Text('To: User ID: ${reminder.recipientUserId}'),
            if (reminder.errorMessage != null && reminder.errorMessage!.isNotEmpty)
               Text(
                 'Error: ${reminder.errorMessage}',
                 style: TextStyle(
                   color: Colors.red[600],
                   fontSize: AppTokens.labelSmall,
                 ),
               ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceSm,
            vertical: AppTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: isOverdue
                ? Colors.red[100]
                : reminder.status == ReminderStatus.sent
                    ? Colors.green[100]
                    : Colors.orange[100],
            borderRadius: BorderRadius.circular(AppTokens.spaceXs),
          ),
           child: Text(
             reminder.status.wire,
             style: TextStyle(
               fontSize: AppTokens.labelSmall,
               fontWeight: FontWeight.bold,
               color: isOverdue
                   ? Colors.red[700]
                   : reminder.status == ReminderStatus.sent
                       ? Colors.green[700]
                       : Colors.orange[700],
             ),
           ),
        ),
        onTap: () {
          // TODO: Show reminder details dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder details coming soon'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}