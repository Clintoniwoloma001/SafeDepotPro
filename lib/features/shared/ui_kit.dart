/// Every data-driven screen renders one of these four states. The app never
/// shows a bare spinner with no explanation, and never shows an empty list
/// without saying what would fill it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';
/// Full-screen loading state with a message, so the user always knows what is
/// being waited on.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Full-screen error state with a retry affordance.
///
/// The message is shown verbatim so a permission failure is distinguishable
/// from a network failure — telling a user "something went wrong" when the
/// database rejected their write is unhelpful.
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
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

/// Empty state that states what action would populate it.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.title = 'Nothing here yet',
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
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

/// Inline error banner for failed mutations, so a rejected write is visible
/// without losing the form the user just filled in.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: 10),
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
// Status chips
// ---------------------------------------------------------------------------

/// Colour-coded chip for any enum-backed status field.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory StatusChip.severity(Severity s) => StatusChip(
        label: s.wire,
        color: _severityColor(s),
      );

  factory StatusChip.priority(Priority p) => StatusChip(
        label: p.wire,
        color: _severityColor(
          switch (p) {
            Priority.low => Severity.low,
            Priority.medium => Severity.medium,
            Priority.high => Severity.high,
            Priority.critical => Severity.critical,
          },
        ),
      );

  factory StatusChip.incident(IncidentStatus s) => StatusChip(
        label: _titleCase(s.wire),
        color: switch (s) {
          IncidentStatus.open => AppColors.statusOpen,
          IncidentStatus.inProgress => AppColors.statusInProgress,
          IncidentStatus.resolved || IncidentStatus.closed => AppColors.statusClosed,
        },
        icon: s.isActive ? Icons.circle : Icons.check_circle_outline,
      );

  factory StatusChip.capa(CapaStatus s) => StatusChip(
        label: _titleCase(s.wire),
        color: switch (s) {
          CapaStatus.open => AppColors.statusOpen,
          CapaStatus.inProgress => AppColors.statusInProgress,
          CapaStatus.verification => AppColors.statusVerification,
          CapaStatus.closed => AppColors.statusClosed,
        },
      );

  factory StatusChip.permit(PermitStatus s) => StatusChip(
        label: _titleCase(s.wire),
        color: switch (s) {
          PermitStatus.draft || PermitStatus.cancelled => AppColors.statusDraft,
          PermitStatus.submitted => AppColors.statusInProgress,
          PermitStatus.approved || PermitStatus.completed => AppColors.statusClosed,
          PermitStatus.rejected => AppColors.statusOpen,
        },
      );

  factory StatusChip.inspection(InspectionStatus s) => StatusChip(
        label: _titleCase(s.wire),
        color: switch (s) {
          InspectionStatus.draft => AppColors.statusDraft,
          InspectionStatus.submitted => AppColors.statusInProgress,
          InspectionStatus.approved => AppColors.statusClosed,
          InspectionStatus.closed => AppColors.statusDraft,
        },
      );

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

Color _severityColor(Severity s) => switch (s) {
      Severity.low => AppColors.severityLow,
      Severity.medium => AppColors.severityMedium,
      Severity.high => AppColors.severityHigh,
      Severity.critical => AppColors.severityCritical,
    };

String _titleCase(String wire) {
  if (wire.isEmpty) return wire;
  final lower = wire.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

// ---------------------------------------------------------------------------
// KPI tile
// ---------------------------------------------------------------------------

class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: tint),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen header used by every feature list.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Switches on an [AsyncValue] and renders one of the four canonical states.
///
/// This exists so no screen hand-rolls its own `when` and drifts from the
/// loading / empty / error contract.
class AsyncListView<T> extends StatelessWidget {
  const AsyncListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.onRetry,
    this.loadingMessage = 'Loading…',
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.actions = const [],
  });

  final AsyncValue<T> value;
  final IndexedWidgetBuilder itemBuilder;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final VoidCallback? onRetry;
  final String loadingMessage;
  final EdgeInsets padding;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => LoadingView(message: loadingMessage),
      error: (e, _) => ErrorView(
        message: readableError(e),
        onRetry: onRetry,
      ),
      data: (data) {
        final items = data is List ? data as List : const [];
        if (items.isEmpty) {
          return EmptyView(
            title: emptyTitle,
            message: emptyMessage,
            icon: emptyIcon,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => onRetry?.call(),
          child: ListView.separated(
            padding: padding,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: itemBuilder,
          ),
        );
      },
    );
  }
}

/// Turns a PostgREST/HTTP exception into something a human can act on.
///
/// Row Level Security rejections in particular must not surface as an opaque
/// 403 — they almost always mean "your role does not cover this depot".
/// Public so feature screens can reuse the same translation.
String readableError(Object error) {
  final text = error.toString();
  final lower = text.toLowerCase();
  if (lower.contains('permission denied') || lower.contains('42501') || lower.contains('row-level security')) {
    return 'You do not have permission to view this. Your role and depot assignment decide what you can see — contact an administrator if this looks wrong.';
  }
  if (lower.contains('violates row-level security policy')) {
    return 'The database rejected this write because your role or depot assignment does not allow it.';
  }
  if (lower.contains('unique constraint') || lower.contains('duplicate key')) {
    return 'This record already exists — it was probably submitted from another device.';
  }
  if (lower.contains('pgrst116') || lower.contains('no rows')) {
    return 'That record was not found, or you do not have access to it.';
  }
  if (lower.contains('check constraint')) {
    return 'A value in this record is outside its allowed range.';
  }
  return text.replaceFirst('Exception: ', '');
}
