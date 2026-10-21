// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../shared/components.dart';

/// Reminds a depot to file its monthly man-hour sheet.
///
/// The reminder appears in the last three days of the month. A depot user is
/// reminded to fill and submit their own sheet; the country head sees the
/// list of depots that are still outstanding on the 30th.
class ManHourReminderCard extends ConsumerWidget {
  const ManHourReminderCard({super.key, this.countryHead = false});

  final bool countryHead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    if (now.day < 28 || now.day > 30) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final yearData = ref.watch(manHourYearProvider(now.year)).value;
    final depots = ref.watch(depotListProvider).value ?? const <Depot>[];

    final submittedDepotIds = <String>{};
    for (final sheet in yearData?.sheetsForMonth(now.month) ?? const []) {
      if (sheet.isSubmitted) submittedDepotIds.add(sheet.depotId);
    }

    if (!countryHead) {
      final profile = ref.watch(profileProvider).profile;
      final depotId = profile?.depotId;
      if (depotId == null) return const SizedBox.shrink();
      if (submittedDepotIds.contains(depotId)) return const SizedBox.shrink();
      return AppCard(
        color: theme.colorScheme.errorContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Man-hour reminder',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Please fill in this month\'s man-hour sheet and submit it before '
              '${now.day == 30 ? "today" : "the 30th"}.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => context.push(Routes.manHourManagement),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Fill man-hour sheet'),
            ),
          ],
        ),
      );
    }

    if (now.day != 30) return const SizedBox.shrink();
    final pending = depots
        .where((d) => !submittedDepotIds.contains(d.id))
        .toList(growable: false);
    if (pending.isEmpty) return const SizedBox.shrink();
    return AppCard(
      color: theme.colorScheme.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Depots yet to complete man hours',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'The following depots have not submitted man-hour sheets for this '
            'month:',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          ...pending.map(
            (d) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${d.displayName}', style: theme.textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}
