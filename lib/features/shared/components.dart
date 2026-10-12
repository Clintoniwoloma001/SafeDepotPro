// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

/// Shared UI primitives.
///
/// Every component here renders exactly one of the four canonical states
/// (loading / error / empty / content) or is a single-purpose display element,
/// so screens stay thin and behave identically under the bone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/app_logo.dart';
import '../../core/branding/author_info.dart';
import '../../providers/feature_flags_provider.dart';
import '../../providers/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';

/// Base card surface. Every padded panel in the app is one of these.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTokens.spaceMd),
    this.color,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius ?? BorderRadius.circular(AppTokens.radiusMd),
      side: BorderSide(color: theme.colorScheme.outline),
    );

    final content = Material(
      color: color ?? theme.colorScheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
    return content;
  }
}

/// Compact KPI tile: icon tile, value, label, optional sub-label.
///
/// The old tile was tall and empty because the value was the only content. The
/// sub-label carries the context that makes a zero meaningful — "none today"
/// versus "no records" versus "not available to your role".
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.hue,
    this.subLabel,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// Semantic colour for the icon tile and value. Null means neutral.
  final SemanticHue? hue;
  final String? subLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.appColors;
    // Two different colours, deliberately.
    //
    // The icon tile keeps the quiet pastel surface; the icon and the value take
    // the readable foreground for the same hue. These used to be the same
    // colour, which rendered the number as a near-white pastel on a white card
    // and made the whole KPI grid read as blank.
    final chipBg = hue == null
        ? theme.colorScheme.surfaceContainerHighest
        : colors.chipBackgrounds[hue!.ordinal];
    final chipFg = hue == null
        ? theme.colorScheme.onSurfaceVariant
        : colors.foreground(hue!);
    final valueColor = chipFg;

    return AppCard(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Icon(
                  icon ?? Icons.insights_outlined,
                  size: 17,
                  color: chipFg,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              subLabel!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Any status/priority/risk chip. One implementation so the palette, radius
/// and typography cannot drift between them.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.hue = SemanticHue.neutral,
    this.icon,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final SemanticHue hue;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.appColors;
    final bg = colors.chipBackgrounds[hue.ordinal];
    final fg = colors.chipText;

    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : AppTokens.spaceSm,
        vertical: dense ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: fg.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: chip,
    );
  }
}

/// Convenience constructors so call sites read by meaning, not by hue.
extension AppChipsX on AppChip {
  static Widget severity(Severity s) => AppChip(
        label: _titleCase(s.wire),
        hue: switch (s) {
          Severity.low => SemanticHue.good,
          Severity.medium => SemanticHue.warn,
          Severity.high => SemanticHue.bad,
          Severity.critical => SemanticHue.info,
        },
      );

  static Widget priority(Priority p) => AppChip(
        label: _titleCase(p.wire),
        hue: switch (p) {
          Priority.low => SemanticHue.good,
          Priority.medium => SemanticHue.warn,
          Priority.high => SemanticHue.bad,
          Priority.critical => SemanticHue.info,
        },
      );

  static Widget permit(PermitStatus s) => AppChip(
        label: _titleCase(s.wire),
        icon: s.isClosed ? Icons.check_circle_outline : null,
        hue: switch (s) {
          PermitStatus.draft || PermitStatus.cancelled => SemanticHue.neutral,
          PermitStatus.submitted => SemanticHue.warn,
          PermitStatus.approved || PermitStatus.completed => SemanticHue.good,
          PermitStatus.rejected => SemanticHue.bad,
        },
      );

  static Widget incident(IncidentStatus s) => AppChip(
        label: _titleCase(s.wire),
        icon: s.isActive ? Icons.circle : Icons.check_circle_outline,
        hue: switch (s) {
          IncidentStatus.open => SemanticHue.bad,
          IncidentStatus.inProgress => SemanticHue.warn,
          IncidentStatus.resolved || IncidentStatus.closed => SemanticHue.good,
        },
      );

  static Widget capa(CapaStatus s) => AppChip(
        label: _titleCase(s.wire),
        hue: switch (s) {
          CapaStatus.open => SemanticHue.bad,
          CapaStatus.inProgress => SemanticHue.warn,
          CapaStatus.verification => SemanticHue.info,
          CapaStatus.closed => SemanticHue.good,
        },
      );

  static Widget inspection(InspectionStatus s) => AppChip(
        label: _titleCase(s.wire),
        hue: switch (s) {
          InspectionStatus.draft => SemanticHue.neutral,
          InspectionStatus.submitted => SemanticHue.warn,
          InspectionStatus.approved => SemanticHue.good,
          InspectionStatus.closed => SemanticHue.neutral,
        },
      );

  static Widget task(TaskStatus s) => AppChip(
        label: _titleCase(s.wire),
        hue: switch (s) {
          TaskStatus.pending => SemanticHue.warn,
          TaskStatus.completed => SemanticHue.good,
          TaskStatus.overdue => SemanticHue.bad,
          TaskStatus.skipped => SemanticHue.neutral,
        },
      );

  static Widget risk(int likelihood, Severity s) {
    final score = likelihood * (switch (s) {
      Severity.low => 1,
      Severity.medium => 2,
      Severity.high => 3,
      Severity.critical => 4,
    });
    final rating = AppTokens.riskRating(score);
    return AppChip(
      label: _titleCase(rating.name),
      hue: switch (rating) {
        RiskRating.low => SemanticHue.good,
        RiskRating.medium => SemanticHue.warn,
        RiskRating.high => SemanticHue.bad,
        RiskRating.critical => SemanticHue.info,
      },
    );
  }

  /// Risk matrix label only. Never used to label a checklist answer.
  static Widget riskRatingOnly(RiskRating r) => AppChip(
        label: _titleCase(r.name),
        hue: switch (r) {
          RiskRating.low => SemanticHue.good,
          RiskRating.medium => SemanticHue.warn,
          RiskRating.high => SemanticHue.bad,
          RiskRating.critical => SemanticHue.info,
        },
      );

  static String _titleCase(String wire) =>
      wire.isEmpty ? wire : (wire[0].toUpperCase() + wire.substring(1).toLowerCase());
}

/// Section header with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The four canonical states
// ---------------------------------------------------------------------------

/// Loading state. `SkeletonList` is preferred on lists so the layout does not
/// jump when data arrives.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

/// Pulsing placeholder box. Used by every skeleton so the shimmer is uniform.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(
          (_controller.value * 2) % 1 > 0.5 ? (1 - (_controller.value * 2 % 1)) * 2 : (_controller.value * 2),
        );
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              theme.colorScheme.surfaceContainerHighest,
              theme.colorScheme.outlineVariant,
              t,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// A whole card-shaped placeholder, matching the shape a real card will take
/// so the settled layout does not shift.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) => const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 32, height: 32, radius: 8),
                Spacer(),
                SkeletonBox(width: 28, height: 22, radius: 6),
              ],
            ),
            SizedBox(height: AppTokens.spaceSm),
            SkeletonBox(width: 120, height: 12),
            SizedBox(height: 6),
            SkeletonBox(width: 80, height: 10),
          ],
        ),
      );
}

/// Vertical stack of `count` skeleton cards.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          AppTokens.spaceSm,
          AppTokens.spaceLg,
          AppTokens.spaceXl,
        ),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: AppTokens.spaceSm),
        itemBuilder: (_, _) => const SkeletonCard(),
      );
}

/// Full-screen error state with a retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Could not load this',
  });

  final String message;
  final VoidCallback? onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: theme.appColors.bad, size: 40),
              const SizedBox(height: AppTokens.spaceMd),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppTokens.spaceLg),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state that states what would fill it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.title = 'Nothing here yet',
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: theme.colorScheme.outline),
              const SizedBox(height: AppTokens.spaceMd),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppTokens.spaceLg),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline error banner for a failed mutation.
///
/// Shown in place so the user does not lose the form they just filled in.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline,
              size: 17, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: AppTokens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = loading
        ? FilledButton(
            onPressed: null,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon ?? Icons.check, size: 18),
            label: Text(label),
          );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Confirmation for destructive actions, with the consequence spelled out.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = true,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text(title),
      content: Text(message, style: theme.textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? scheme.error : scheme.primary,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// GPS availability pill.
class GpsStatusPill extends StatelessWidget {
  const GpsStatusPill({
    super.key,
    required this.state,
  });

  /// True when a fix is available; false when it is not. Null while resolving.
  final bool? state;

  @override
  Widget build(BuildContext context) {
    final (icon, label, hue) = switch (state) {
      null => (Icons.location_searching, 'Locating…', SemanticHue.neutral),
      true => (Icons.location_on_outlined, 'GPS live', SemanticHue.good),
      false => (Icons.location_off_outlined, 'No GPS', SemanticHue.bad),
    };
    return AppChip(label: label, hue: hue, icon: icon, dense: true);
  }
}

/// Blocks a route for a role that may not reach it.
///
/// A deep link to `/permits` must not silently render an admin screen for a
/// USER, so the router wraps protected routes in this. The database enforces the
/// same rule, so this is a courtesy to the user rather than a security control.
class RoleGuard extends ConsumerWidget {
  const RoleGuard({
    super.key,
    required this.allowed,
    required this.child,
  });

  final bool Function(UserRole role) allowed;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(profileProvider).profile?.role;
    if (role == null) return const SizedBox.shrink();
    if (!allowed(role)) return const ForbiddenView();
    return child;
  }
}

class ForbiddenView extends StatelessWidget {
  const ForbiddenView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 38, color: theme.appColors.bad),
            const SizedBox(height: AppTokens.spaceMd),
            Text('Not available to your role', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              'This area is restricted by your role and depot assignment. '
              'Ask an administrator if you need access.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feature gate: renders a child only when the module is enabled.
///
/// The gate is a UX affordance, not a security control — RLS decides what data
/// is reachable. Its job is to make a disabled module *look* disabled rather
/// than broken, and to let a Dart patch enable a module by flag alone.
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.flagKey,
    required this.child,
    this.title = 'Coming soon',
  });

  final String flagKey;
  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);
    // A flag that has never been read (offline, first launch) is treated as
    // off. That is the safe default: the alternative is shipping a half-built
    // module to a user with no connection to fetch its data.
    final enabled = flags.value?.contains(flagKey) ?? false;
    if (!enabled) return ComingSoonCard(title: title);
    return child;
  }
}
/// Branded placeholder shown while a module's native dependencies are present
/// but its Dart feature is not yet shipped.
///
/// This is what makes a "native-complete" release honest: the plugin is in the
/// APK, so enabling a module later is a Dart-only patch, and the user sees an
/// on-brand explanation instead of a broken screen.
class ComingSoonCard extends StatelessWidget {
  const ComingSoonCard({super.key, required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Icon(
              Icons.rocket_launch_outlined,
              color: theme.colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  message ??
                      'This feature arrives in an update — no reinstall needed. '
                      'It will switch on automatically.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Text(
                  kCreditLine,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-screen "not yet built" state.
///
/// Every route whose module has not shipped yet renders one of these rather
/// than falling through to the router's error builder, which produced a blank
/// white screen. The UX contract is: the user always sees why something is
/// missing and what will happen next.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.rocket_launch_outlined,
  });

  /// The screen a route whose module has not shipped yet. Read its flag and
  /// render child once enabled; that is the mechanism by which a Dart patch
  /// switches a module on without a reinstall.
  static Widget gated({
    required String flagKey,
    required String title,
    required Widget child,
    String? message,
  }) =>
      GatedModuleScreen(
        flagKey: flagKey,
        title: title,
        message: message,
        child: child,
      );

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.spaceLg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogo(size: 88),
                const SizedBox(height: AppTokens.spaceLg),
                Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: AppTokens.spaceSm),
                Text(
                  message ??
                      'This module is not in this release yet. It arrives in an '
                      'update and switches on automatically — no reinstall '
                      'needed.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppTokens.spaceLg),
                AppCard(
                  child: Column(
                    children: [
                      Text(
                        'Designed and developed by Clinton Iwoloma — '
                        'The Imaginr, CEO, Flatra Tech Ltd.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppTokens.spaceSm),
                      // On its own line so the number never wraps mid-digit.
                      Text(
                        'For more jobs and automation workflows contact '
                        '+2349025975247.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.spaceMd),
                Text(
                  kCreditLine,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The gated variant: shows the module once its flag is on, otherwise the
/// coming-soon screen. This is what makes a patch able to switch a module on
/// with no reinstall.
class GatedModuleScreen extends ConsumerWidget {
  const GatedModuleScreen({
    super.key,
    required this.flagKey,
    required this.title,
    required this.child,
    this.message,
  });

  final String flagKey;
  final String title;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);
    final enabled = flags.value?.contains(flagKey) ?? false;
    if (!enabled) {
      return ComingSoonScreen(title: title, message: message);
    }
    return child;
  }
}
