import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../data/models/enums.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';

/// Profile, role visibility and session controls.
///
/// Shows exactly what this account is allowed to do and why, so a user who
/// cannot see a depot understands that the restriction is a role assignment
/// rather than a bug.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;
    final theme = Theme.of(context);

    if (profile == null) {
      return const Scaffold(
        body: LoadingView(message: 'Loading your profile…'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 32,
            child: Text(
              profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?',
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(profile.displayName, style: theme.textTheme.titleLarge)),
          const SizedBox(height: 32),
          Card(
            child: Column(
              children: [
                _Row(label: 'Role', value: profile.role.label),
                _Row(
                  label: 'Access',
                  value: profile.role.seesAllDepots ? 'All depots' : 'Assigned depot',
                ),
                _Row(label: 'Language', value: profile.preferredLanguage),
                _Row(label: 'Phone', value: profile.phone ?? '—'),
                _Row(
                  label: 'Account',
                  value: profile.isActive ? 'Active' : 'Deactivated',
                  valueColor: profile.isActive ? theme.colorScheme.primary : theme.colorScheme.error,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'What this role can do',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          ..._capabilitiesFor(profile.role, theme),
          const SizedBox(height: 24),
          Text(
            'Mobile release',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.rocket_launch_outlined, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This app supports over-the-air Dart updates through Shorebird. '
                      'Native and manifest changes still require a new release.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              await ref.read(profileProvider.notifier).signOut();
              if (context.mounted) context.go(Routes.login);
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _capabilitiesFor(UserRole role, ThemeData theme) {
    final items = <(String, bool)>[
      ('Submit inspections and incident reports', true),
      ('Update assigned corrective actions', true),
      ('Approve permits', role.isAdmin),
      ('Manage depots and personnel', role.isAdmin),
      ('Raise corrective actions for others', role.isAdmin),
      ('View the audit trail', role.isAdmin),
      ('View all depots', role.seesAllDepots),
    ];
    return items
        .map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    item.$2 ? Icons.check_circle_outline : Icons.remove_circle_outline,
                    size: 16,
                    color: item.$2 ? theme.colorScheme.primary : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: item.$2 ? null : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(label, style: theme.textTheme.bodySmall),
      trailing: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: valueColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
