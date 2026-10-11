import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';
import '../../data/models/enums.dart';

/// In-app notifications.
final notificationsProvider = FutureProvider((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return const <AppNotification>[];
  return ref.read(notificationRepositoryProvider).forUser(profile.id);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);
    final profile = ref.watch(profileProvider).profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(Icons.done_all),
            onPressed: profile == null
                ? null
                : () async {
                    await ref.read(notificationRepositoryProvider).markAllRead(profile.id);
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadCountProvider);
                  },
          ),
        ],
      ),
      body: AsyncListView(
        value: list,
        loadingMessage: 'Loading notifications…',
        onRetry: () => ref.refresh(notificationsProvider.future),
        emptyTitle: 'No notifications',
        emptyMessage: 'Overdue actions, pending approvals and escalation alerts appear here.',
        emptyIcon: Icons.notifications_off_outlined,
        itemBuilder: (context, index) {
          final items = list.value ?? const [];
          final n = items[index];
          return _NotificationTile(
            notification: n,
            onTap: () async {
              if (n.isRead) return;
              await ref.read(notificationRepositoryProvider).markRead(n.id);
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = notification;
    return Card(
      color: n.isRead ? null : theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () {
          onTap();
          // Deep-link to the relevant module when the notification carries one.
          if (n.link != null) context.go(n.link!);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _iconFor(n.category),
                size: 18,
                color: _colorFor(n.severity, theme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    if (n.body != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        n.body!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(n.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (!n.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(String? category) => switch (category) {
      'incident' => Icons.report_gmailerrorred_outlined,
      'capa' => Icons.task_outlined,
      'permit' => Icons.approval_outlined,
      'inspection' => Icons.checklist_outlined,
      _ => Icons.campaign_outlined,
    };

Color _colorFor(Severity s, ThemeData theme) => switch (s) {
      Severity.low => theme.colorScheme.outline,
      Severity.medium => theme.colorScheme.primary,
      Severity.high => Colors.orange.shade700,
      Severity.critical => theme.colorScheme.error,
    };

String _formatTimestamp(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${d.year}-${_p(d.month)}-${_p(d.day)}';
}

String _p(int n) => n.toString().padLeft(2, '0');
