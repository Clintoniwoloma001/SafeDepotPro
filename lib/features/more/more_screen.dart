// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/credit_footer.dart';
import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';
import '../../providers/providers.dart';
import '../shared/components.dart';

/// The More tab: a grouped list of every destination, plus account actions.
///
/// Replaces the seven-tab bar. Sign-out lives here in an Account section with
/// a confirmation, not in the top app bar where a stray tap could end a shift.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(profileProvider).profile?.role ?? UserRole.user;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          0,
          AppTokens.spaceSm,
          0,
          AppTokens.spaceXl,
        ),
        children: [
          _Group(
            title: 'Operations',
            items: [
              _Item('Toolbox Talks', Icons.groups_outlined, Routes.toolbox),
              _Item('Shift Handover', Icons.swap_horiz_rounded, Routes.handover),
              _Item('Man-Hour Sheets & Analytics', Icons.grid_on_outlined,
                  Routes.manHourManagement),
            ],
          ),
          _Group(
            title: 'Assets',
            items: [
              _Item('Equipment & Assets', Icons.inventory_2_outlined, Routes.assets),
            ],
          ),
          if (role.isAdmin) ...[
            _Group(
              title: 'People & Depots',
              items: [
                _Item('Personnel', Icons.people_outline, Routes.personnel),
                _Item('Depots', Icons.warehouse_outlined, Routes.depots),
              ],
            ),
            _Group(
              title: 'Admin',
              items: [
                _Item('Checklist Builder', Icons.rule_outlined, Routes.checklistBuilder),
                _Item('DSO Stand-In', Icons.switch_account_outlined, Routes.standIn),
                _Item('Settings', Icons.settings_outlined, Routes.settings),
              ],
            ),
          ],
          if (role.seesAllDepots) ...[
            _Group(
              title: 'Platform',
              items: [
                _Item('User Management', Icons.admin_panel_settings_outlined,
                    Routes.userManagement),
                _Item('Platform Export', Icons.download_outlined, Routes.platformExport),
              ],
            ),
          ],
          _Group(
            title: 'Account',
            items: [
              _Item('Appearance', Icons.brightness_auto_outlined, Routes.appearance),
              _Item('Notifications', Icons.notifications_outlined, Routes.notifications),
              _Item('Audit trail', Icons.history_outlined, Routes.audit),
              _Item('About', Icons.info_outline, Routes.about),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),
          const _SignOutTile(),
          const SizedBox(height: AppTokens.spaceLg),
          const SafeArea(top: false, child: CreditFooter()),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.items});

  final String title;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceLg,
            AppTokens.spaceMd,
            AppTokens.spaceLg,
            AppTokens.spaceXs,
          ),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        for (final item in items) item,
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, size: 21),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 19),
      // 48dp minimum touch target, enforced by the tile's height rather than
      // left to chance.
      minTileHeight: AppTokens.touchTarget,
      onTap: () => context.push(route),
      shape: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
    );
  }
}

/// Sign-out, with the consequence stated and a confirm dialog.
class _SignOutTile extends ConsumerWidget {
  const _SignOutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).appColors;
    return ListTile(
      minTileHeight: AppTokens.touchTarget,
      leading: Icon(Icons.logout, color: colors.bad),
      title: Text('Sign out', style: TextStyle(color: colors.bad)),
      onTap: () async {
        final confirmed = await ConfirmDialog.show(
          context,
          title: 'Sign out?',
          message:
              'You will need your email and password to sign back in. Anything '
              'already saved stays on this device and synchronises on next '
              'sign-in.',
          confirmLabel: 'Sign out',
          destructive: true,
        );
        if (!confirmed || !context.mounted) return;
        await ref.read(profileProvider.notifier).signOut();
        if (context.mounted) context.go(Routes.login);
      },
    );
  }
}
