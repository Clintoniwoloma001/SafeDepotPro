// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../data/models/enums.dart';
import '../../../../providers/providers.dart';
import '../../../../core/router/routes.dart';
import '../shared/components.dart';

/// Settings hub screen with access to all settings modules.
///
/// Shows theme, profile, and About sections for all users.
/// Shows Company Settings section only for SUPERADMIN, COUNTRY_HEAD, and ADMIN roles.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;
    final isLoading = profileState.isLoading;

    if (isLoading || profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool canAccessCompanySettings =
        profile.role == UserRole.admin || profile.role == UserRole.countryHead || profile.role == UserRole.superadmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SectionHeader(
            title: 'Account',
            subtitle: 'Personal settings and information',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: Text('View and edit your profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(Routes.profile),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: Text('Version, credits, and license information'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(Routes.about),
          ),
          const Divider(height: 1),
          if (canAccessCompanySettings) ...[
            const SectionHeader(
              title: 'Company',
              subtitle: 'Organization-wide settings (admin only)',
            ),
            const SizedBox(height: AppTokens.spaceSm),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Appearance'),
              subtitle: Text('Theme, colors, and branding'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .pushNamed(Routes.appearance),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Depot & Geofence'),
              subtitle: Text('Manage depot locations and geofences'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .pushNamed(Routes.depotGeofence),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('User Management'),
              subtitle: Text('Manage user accounts and roles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .pushNamed(Routes.userManagement),
            ),
            const Divider(height: 1),
          ],
          const SizedBox(height: AppTokens.spaceLg),
        ],
      ),
    );
  }
}