// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';

/// Shown instead of the app when build-time configuration is missing.
///
/// This is the deliberate first-launch failure mode: a missing
/// `--dart-define-from-file` must never present as an unexplained crash.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key, required this.missing});

  final String missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Configuration missing',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The app was started without its build-time configuration. '
                    'Missing values: $missing.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Run it with the project config file:',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _CodeBlock(
                    lines: const [
                      r'flutter run --dart-define-from-file=env/app.json',
                      '',
                      '# or for a release build',
                      r'shorebird release android --artifact apk \',
                      r'  -- --dart-define-from-file=env/app.json',
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create env/app.json from env/app.json.example. '
                    'It holds the Supabase URL and the anon (publishable) key, '
                    'which are safe to ship — all data access is governed by '
                    'Row Level Security. Never put the service-role key or the '
                    'database password in that file.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
