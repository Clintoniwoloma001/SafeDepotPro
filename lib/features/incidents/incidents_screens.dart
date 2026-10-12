// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/router/routes.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/storage_repository.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/supabase/outbox.dart';

/// Incident list.
final incidentsProvider = FutureProvider((ref) async {
  return ref.read(incidentRepositoryProvider).listIncidents();
});

class IncidentsScreen extends ConsumerWidget {
  const IncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Incidents')),
      body: AsyncListView(
        value: incidents,
        loadingMessage: 'Loading incidents…',
        onRetry: () => ref.refresh(incidentsProvider.future),
        emptyTitle: 'No incidents reported',
        emptyMessage: 'A clear incident log is the fastest way to stop repeat events.',
        emptyActionLabel: 'Report incident',
        onEmptyAction: () => context.go('${Routes.incidents}?report=1'),
        itemBuilder: (context, index) {
          final list = incidents.value ?? const [];
          final i = list[index];
          return _IncidentCard(
            number: i.incidentNumber,
            severity: i.severity,
            status: i.status,
            description: i.description,
            occurredAt: i.occurredAt,
            photos: i.photoPaths.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('${Routes.incidents}?report=1'),
        icon: const Icon(Icons.add),
        label: const Text('Report'),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.number,
    required this.severity,
    required this.status,
    required this.description,
    required this.occurredAt,
    required this.photos,
  });

  final String number;
  final Severity severity;
  final IncidentStatus status;
  final String description;
  final DateTime occurredAt;
  final int photos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(number, style: theme.textTheme.labelMedium)),
                StatusChip.severity(severity),
                const SizedBox(width: 6),
                StatusChip.incident(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 13, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(occurredAt),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
                if (photos > 0) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.photo_outlined, size: 13, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    '$photos',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick incident report.
///
/// Deliberately short: description, severity and a photo. Everything else is
/// filled in by the server or by the follow-up workflow, so a supervisor can
/// report in seconds on the depot floor.
class ReportIncidentScreen extends ConsumerStatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  ConsumerState<ReportIncidentScreen> createState() =>
      _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends ConsumerState<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  Severity _severity = Severity.medium;
  final List<String> _photoPaths = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null) return;
    if (!mounted) return;

    final profile = ref.read(profileProvider).profile;
    final storage = ref.read(storageRepositoryProvider);
    try {
      final path = await storage.uploadBytes(
        bucket: StorageRepository.photos,
        depotId: profile?.depotId ?? 'unassigned',
        fileName: file.name,
        bytes: await file.readAsBytes(),
      );
      if (!mounted) return;
      setState(() => _photoPaths.add(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: ${readableError(e)}')),
      );
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = ref.read(profileProvider).profile;
      if (profile == null) throw const AuthFailure('You are not signed in.');
      if (profile.depotId == null) {
        throw const AuthFailure(
          'Your account has no depot assigned, so an incident cannot be filed. '
          'Ask an administrator to assign you to a depot.',
        );
      }

      await ref.read(incidentRepositoryProvider).createIncident(
            depotId: profile.depotId!,
            description: _description.text,
            severity: _severity,
            reportedBy: profile.id,
            reportedByName: profile.displayName,
            idempotencyKey: newIdempotencyKey(),
            photoPaths: _photoPaths,
          );

      if (!mounted) return;
      ref.invalidate(incidentsProvider);
      ref.invalidate(dashboardCountsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident reported.')),
      );
      context.go(Routes.incidents);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Report incident')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'What happened',
                hintText: 'Describe the event plainly — location, people involved, and what was done.',
              ),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Describe the incident in at least a sentence.'
                  : null,
            ),
            const SizedBox(height: 18),
            Text('Severity', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in Severity.values)
                  ChoiceChip(
                    label: Text(s.wire),
                    selected: _severity == s,
                    onSelected: (_) => setState(() => _severity = s),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _capturePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(
                _photoPaths.isEmpty ? 'Add photo' : '${_photoPaths.length} attached',
              ),
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              InlineError(_error!),
              const SizedBox(height: 18),
            ],
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.send),
              label: Text(_saving ? 'Submitting…' : 'Submit report'),
            ),
            const SizedBox(height: 8),
            Text(
              'Reports are written to the depot incident log and are visible to '
              'site managers and the safety team. They cannot be deleted.',
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

String _formatDateTime(DateTime d) =>
    '${d.year}-${_p(d.month)}-${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';
String _p(int n) => n.toString().padLeft(2, '0');
