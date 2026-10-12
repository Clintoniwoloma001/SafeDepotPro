// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';

import 'author_info.dart';

/// Reusable bottom credit footer.
///
/// Deliberately inert: it is wrapped in [IgnorePointer] so it can never absorb
/// a tap meant for a button or a text field behind it, and it uses
/// `SafeArea`-aware padding plus the current keyboard inset so it never lands
/// under the soft input or under a home indicator.
///
/// Used on the login screen, the sign-up screen and the About page so the
/// attribution is present without adding a persistent overlay anywhere else.
class CreditFooter extends StatelessWidget {
  const CreditFooter({super.key, this.padding});

  /// Extra padding applied below the text, e.g. to clear a bottom inset.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Once the keyboard is up the bottom safe-area inset is irrelevant — the
    // keyboard itself is what we must clear.
    final bottomInset = keyboard > 0 ? keyboard : MediaQuery.paddingOf(context).bottom;

    return IgnorePointer(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: (padding ?? EdgeInsets.zero).add(
            EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: bottomInset + 8,
              top: 6,
            ),
          ),
          child: Text(
            kCreditLine,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
