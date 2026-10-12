// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';

import 'author_info.dart';

/// Hard block shown when this build fails its integrity check.
///
/// This screen has no dismiss affordance and no route back: reaching it is a
/// terminal state until the check passes again. It exists so that a modified
/// clone fails visibly and early, rather than presenting a working app that
/// quietly reports someone else's authorship.
class UnofficialBuildScreen extends StatelessWidget {
  const UnofficialBuildScreen({
    super.key,
    required this.reason,
    this.onRetry,
  });

  /// Human-readable explanation, shown in full. A bare "an error occurred" is
  /// useless to a user who needs to know which build they are holding.
  final String reason;

  /// Re-runs the check without requiring a restart, for the case where the
  /// gate was tripped by a transient problem rather than a real mismatch.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.gpp_bad_outlined,
                      size: 56,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Unofficial build',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'This copy of $kProductName could not be verified as an '
                      'official build, so the app is disabled.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        reason,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Only builds distributed by $kCopyrightHolder are '
                      'supported. If you installed this app from an unofficial '
                      'source, remove it and obtain the official release. '
                      'Please report the app to:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      '$kAuthorName — $kAuthorTitle\n$kContactPhone',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Re-check'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
