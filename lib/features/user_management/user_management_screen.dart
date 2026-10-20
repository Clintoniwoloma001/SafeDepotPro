// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../shared/components.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddUserDialog(context, ref),
            tooltip: 'Add user',
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => const LoadingView(message: 'Loading users…'),
        error: (e, _) => ErrorView(
          message: _readableError(e),
          onRetry: () => ref.invalidate(usersProvider),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const EmptyState(
              title: 'No users found',
              message: 'Add your first user using the + button.',
              actionLabel: 'Add user',
              onAction: null,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final u = users[i];
              return _UserTile(user: u);
            },
          );
        },
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _AddUserDialog(),
    );
  }

  String _readableError(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('network is unreachable')) {
      return 'You appear to be offline.';
    }
    if (lower.contains('permission denied') ||
        lower.contains('42501') ||
        lower.contains('row-level security')) {
      return 'You do not have permission to manage users.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});

  final Profile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _roleColor(user.role).withValues(alpha: 0.15),
          child: Icon(
            Icons.person,
            color: _roleColor(user.role),
            size: 20,
          ),
        ),
        title: Text(user.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.fullName ?? 'No email'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                AppChip(label: user.role.label, hue: _roleHue(user.role)),
                if (user.depotId != null)
                  AppChip(label: 'Assigned depot', hue: SemanticHue.info, dense: true)
                else
                  AppChip(label: 'No depot', hue: SemanticHue.warn, dense: true),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _onMenuSelected(value, context, ref),
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit role / depot'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (user.id != ref.read(profileProvider).profile?.id)
              const PopupMenuItem(
                value: 'deactivate',
                child: ListTile(
                  leading: Icon(Icons.block_outlined, color: Colors.red),
                  title: Text('Deactivate', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onMenuSelected(String value, BuildContext context, WidgetRef ref) {
    switch (value) {
      case 'edit':
        _showEditDialog(context, ref, user);
        break;
      case 'deactivate':
        _showDeactivateDialog(context, ref, user);
        break;
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Profile user) {
    showDialog(
      context: context,
      builder: (ctx) => _EditUserDialog(user: user),
    );
  }

  void _showDeactivateDialog(BuildContext context, WidgetRef ref, Profile user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate user?'),
        content: Text('This will disable ${user.displayName}\'s access. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(authRepositoryProvider).deactivateUser(user.id);
                ref.invalidate(usersProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${user.displayName} deactivated')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $_readableError(e)')),
                  );
                }
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.superadmin:
        return Colors.purple;
      case UserRole.countryHead:
        return Colors.blue;
      case UserRole.admin:
        return Colors.green;
      case UserRole.user:
        return Colors.grey;
    }
  }

  SemanticHue _roleHue(UserRole role) {
    switch (role) {
      case UserRole.superadmin:
        return SemanticHue.info;
      case UserRole.countryHead:
        return SemanticHue.info;
      case UserRole.admin:
        return SemanticHue.good;
      case UserRole.user:
        return SemanticHue.neutral;
    }
  }

  String _readableError(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('network is unreachable')) {
      return 'You appear to be offline.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class _AddUserDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<_AddUserDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  UserRole _selectedRole = UserRole.user;
  String? _selectedDepotId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depotsAsync = ref.watch(_allDepotsProvider);

    return AlertDialog(
      title: const Text('Add user'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: UserRole.values
                    .where((r) => r != UserRole.superadmin).map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
              const SizedBox(height: 12),
              depotsAsync.when(
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
                data: (depots) => DropdownButtonFormField<String>(
                  initialValue: _selectedDepotId,
                  decoration: const InputDecoration(labelText: 'Depot (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No depot')),
                    ...depots.map((d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(d.displayName),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedDepotId = v),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                InlineError(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const Text('Saving…') : const Text('Add user'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_email.text.trim().isEmpty || _name.text.trim().isEmpty) {
      setState(() => _error = 'Email and name are required.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).inviteUser(
            email: _email.text.trim(),
            displayName: _name.text.trim(),
            role: _selectedRole,
            depotId: _selectedDepotId,
          );
      ref.invalidate(usersProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = _readableError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _readableError(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('already exists') || lower.contains('duplicate')) {
      return 'A user with this email already exists.';
    }
    if (lower.contains('permission denied') || lower.contains('42501')) {
      return 'You do not have permission to add users.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class _EditUserDialog extends ConsumerStatefulWidget {
  const _EditUserDialog({required this.user});

  final Profile user;

  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  late final _name = TextEditingController();
  late UserRole _selectedRole;
  String? _selectedDepotId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = widget.user.displayName;
    _selectedRole = widget.user.role;
    _selectedDepotId = widget.user.depotId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depotsAsync = ref.watch(_allDepotsProvider);

    return AlertDialog(
      title: Text('Edit ${widget.user.displayName}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Email: ${widget.user.fullName ?? "Unknown"}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: UserRole.values
                    .where((r) => r != UserRole.superadmin).map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
              const SizedBox(height: 12),
              depotsAsync.when(
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
                data: (depots) => DropdownButtonFormField<String>(
                  initialValue: _selectedDepotId,
                  decoration: const InputDecoration(labelText: 'Depot (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No depot')),
                    ...depots.map((d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(d.displayName),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedDepotId = v),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                InlineError(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const Text('Saving…') : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateUserProfile(
            userId: widget.user.id,
            displayName: _name.text.trim(),
            role: _selectedRole,
            depotId: _selectedDepotId,
          );
      ref.invalidate(usersProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = _readableError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _readableError(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('permission denied') || lower.contains('42501')) {
      return 'You do not have permission to edit users.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}

final _allDepotsProvider = FutureProvider<List<Depot>>((ref) async {
  return ref.read(depotRepositoryProvider).listDepots();
});