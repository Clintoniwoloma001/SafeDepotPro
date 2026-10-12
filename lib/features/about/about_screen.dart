// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/branding/app_logo.dart';
import '../../core/branding/author_info.dart';
import '../../core/branding/build_integrity.dart';
import '../../core/branding/credit_footer.dart';

/// About page: full attribution, build identity, and the integrity result.
///
/// Showing the integrity check result here is intentional rather than
/// diagnostic: a user on a sideloaded build should be able to see why the app
/// considers itself unofficial, instead of being blocked with no explanation.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const Center(child: AppLogo(size: 96)),
                const SizedBox(height: 18),
                Text(
                  kProductName,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attribution',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          kFullAttribution,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        _Row(label: 'Copyright', value: kCopyrightNotice),
                        _Row(label: 'Developer', value: kAuthorName),
                        _Row(
                          label: 'Contact',
                          value: '$kContactPhone\n$kContactEmail',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Build integrity', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                const _IntegrityCard(),
                const SizedBox(height: 20),
                Text('Licence', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Proprietary and confidential software owned by '
                      '$kCopyrightHolder. Unauthorized copying, modification, '
                      'distribution or reuse is prohibited. See the LICENSE '
                      'and NOTICE files distributed with this project.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const CreditFooter(),
        ],
      ),
    );
  }

  String _subtitle() {
    final info = _info;
    if (info == null) return 'Depot safety and workflow management';
    return 'Version ${info.version} (build ${info.buildNumber}) · '
        'Depot safety and workflow management';
  }
}

class _IntegrityCard extends ConsumerStatefulWidget {
  const _IntegrityCard();

  @override
  ConsumerState<_IntegrityCard> createState() => _IntegrityCardState();
}

class _IntegrityCardState extends ConsumerState<_IntegrityCard> {
  BuildIntegrityReport? _report;

  @override
  void initState() {
    super.initState();
    // Re-evaluated on entry so the page reflects this launch, not a cached one.
    BuildIntegrity.evaluate(force: true).then((r) {
      if (mounted) setState(() => _report = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;

    if (report == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Verifying build…'),
            ],
          ),
        ),
      );
    }

    final color =
        report.isUntampered ? theme.colorScheme.primary : theme.colorScheme.error;
    final icon = report.isUntampered ? Icons.verified_user_outlined : Icons.gpp_bad_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    report.isUntampered ? 'Verified official build' : 'Unofficial build',
                    style: theme.textTheme.titleSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...report.details.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      d.passed ? Icons.check : Icons.close,
                      size: 14,
                      color: d.passed ? theme.colorScheme.primary : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(d.label, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
