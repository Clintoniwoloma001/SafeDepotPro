// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/credit_footer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../shared/components.dart';

/// Appearance settings: system / light / dark.
///
/// Applied immediately through the provider, and the choice is persisted by
/// `ThemePreferenceNotifier`, so a relaunch lands on the same theme.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themePreferenceProvider);
    final notifier = ref.read(themePreferenceProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          AppTokens.spaceMd,
          AppTokens.spaceLg,
          AppTokens.spaceXl,
        ),
        children: [
          const SectionHeader(
            title: 'Theme',
            subtitle: 'Follows your device by default',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            padding: EdgeInsets.zero,
            child: RadioGroup<ThemePreference>(
              groupValue: preference,
              onChanged: (v) {
                if (v != null) notifier.set(v);
              },
              child: Column(
                children: [
                  for (final option in ThemePreference.values) ...[
                    RadioListTile<ThemePreference>(
                      value: option,
                      title: Text(_label(option)),
                      subtitle: Text(_description(option)),
                    ),
                    if (option != ThemePreference.values.last)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          // A live preview beats a description: the user sees the exact
          // contrast they will get, in the mode they are choosing.
          const SectionHeader(title: 'Preview'),
          const SizedBox(height: AppTokens.spaceSm),
          const _PreviewCard(),
          const SizedBox(height: AppTokens.spaceXl),
          const CreditFooter(),
        ],
      ),
    );
  }

  static String _label(ThemePreference p) => switch (p) {
        ThemePreference.system => 'System',
        ThemePreference.light => 'Light',
        ThemePreference.dark => 'Dark',
      };

  static String _description(ThemePreference p) => switch (p) {
        ThemePreference.system => 'Match the device setting',
        ThemePreference.light => 'Light surfaces, dark text',
        ThemePreference.dark => 'Dark surfaces, light text',
      };
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sample title', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            'Body text and a secondary caption, at the sizes used across the app.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            'Secondary caption text, which must stay legible in both modes.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppTokens.spaceMd),
          const Wrap(
            spacing: AppTokens.spaceSm,
            runSpacing: AppTokens.spaceSm,
            children: [
              AppChip(label: 'Open', hue: SemanticHue.bad),
              AppChip(label: 'On track', hue: SemanticHue.good),
              AppChip(label: 'Due soon', hue: SemanticHue.warn),
            ],
          ),
        ],
      ),
    );
  }
}
