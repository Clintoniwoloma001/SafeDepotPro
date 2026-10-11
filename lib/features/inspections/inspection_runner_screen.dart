import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/enums.dart';
import '../../data/models/workflows.dart';
import '../../data/repositories/storage_repository.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';
import '../../core/router/routes.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/inspection_repository.dart';
import '../../data/supabase/outbox.dart';
import '../inspections/inspections_screen.dart';

/// Checklist runner.
///
/// Every question is answerable as PASS / FAIL / NON_COMPLIANT / NA and fails
/// require a comment, because an unexplained failure is not actionable. The
/// whole run is held in one controller and written in a single insert, so a
/// submitted checklist is never half-persisted.
class InspectionRunnerScreen extends ConsumerStatefulWidget {
  const InspectionRunnerScreen({super.key});

  @override
  ConsumerState<InspectionRunnerScreen> createState() =>
      _InspectionRunnerScreenState();
}

class _QuestionResult {
  _QuestionResult(this.questionId, this.response);
  final String questionId;
  InspectionResponse response;
  String comment = '';
  List<String> photoPaths = const [];
}

class _InspectionRunnerScreenState
    extends ConsumerState<InspectionRunnerScreen> {
  final Map<String, _QuestionResult> _answers = {};
  ChecklistTemplate? _template;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Run inspection')),
      body: templatesAsync.when(
        loading: () => const LoadingView(message: 'Loading checklists…'),
        error: (e, _) => ErrorView(message: readableError(e)),
        data: (templates) {
          if (templates.isEmpty) {
            return const EmptyView(
              title: 'No checklists available',
              message: 'No active checklist templates are visible to your role. Ask an administrator to create one.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              DropdownButtonFormField<ChecklistTemplate>(
                initialValue: _template,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Checklist template'),
                items: [
                  for (final t in templates)
                    DropdownMenuItem(value: t, child: Text(t.name)),
                ],
                onChanged: (t) => setState(() {
                  _template = t;
                  _answers.clear();
                  _error = null;
                }),
              ),
              const SizedBox(height: 16),
              if (_template != null) ..._renderTemplate(_template!),
              if (_error != null) ...[
                const SizedBox(height: 16),
                InlineError(_error!),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: _template == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.send),
                  label: _saving
                      ? const Text('Submitting…')
                      : const Text('Submit inspection'),
                ),
              ),
            ),
    );
  }

  List<Widget> _renderTemplate(ChecklistTemplate template) {
    final widgets = <Widget>[];
    for (final section in template.sections) {
      final title = section['title']?.toString() ?? 'Section';
      final questions = (section['questions'] as List?) ?? const [];
      widgets.add(PageHeader(title: title));
      for (final q in questions) {
        if (q is! Map) continue;
        final map = Map<String, dynamic>.from(q);
        final questionId = map['id']?.toString() ?? '';
        widgets.add(_QuestionCard(
          questionId: questionId,
          text: map['text']?.toString() ?? 'Question',
          severityIndex: (map['severity'] as num?)?.toInt() ?? 2,
          requiresPhoto: map['requires_photo'] == true,
          current: _answers[questionId],
          onChanged: (result) => _answers[questionId] = result,
          onAddPhoto: _pickPhoto,
        ));
      }
    }
    return widgets;
  }

  Future<void> _pickPhoto(String questionId) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null) return;
    if (!mounted) return;

    final profile = ref.read(profileProvider).profile;
    final depotId = profile?.depotId ?? 'unassigned';
    final storage = ref.read(storageRepositoryProvider);

    try {
      final path = await storage.uploadBytes(
        bucket: StorageRepository.photos,
        depotId: depotId,
        fileName: file.name,
        bytes: await file.readAsBytes(),
      );
      setState(() {
        final result = _answers[questionId] ?? _QuestionResult(questionId, InspectionResponse.na);
        result.photoPaths = [...result.photoPaths, path];
        _answers[questionId] = result;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: ${readableError(e)}')),
      );
    }
  }

  Future<void> _submit() async {
    final template = _template;
    if (template == null) return;

    // Validate: every question answered, every fail with a comment.
    final missing = <String>[];
    for (final section in template.sections) {
      final questions = (section['questions'] as List?) ?? const [];
      for (final q in questions) {
        if (q is! Map) continue;
        final id = q['id']?.toString() ?? '';
        final result = _answers[id];
        if (result == null) {
          missing.add('unanswered: ${q['text']}');
        } else if (result.response.countsAgainstCompliance && result.comment.trim().isEmpty) {
          missing.add('${q['text']} failed with no comment');
        }
      }
    }
    if (missing.isNotEmpty) {
      setState(() => _error = readableError(
          'Unanswered: ${missing.length} item(s).'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = ref.read(profileProvider).profile;
      if (profile == null) throw const AuthFailure('You are not signed in.');

      final answersPayload = _answers.values
          .map((r) => {
                'question_id': r.questionId,
                'response': r.response.wire,
                'comment': r.comment,
                'photo_paths': r.photoPaths,
              })
          .toList();

      final compliance = ComplianceCalculator.percentage(answersPayload);

      await ref.read(inspectionRepositoryProvider).createInspection(
            depotId: profile.depotId,
            templateId: template.id,
            checklistName: template.name,
            type: template.type,
            completedBy: profile.id,
            idempotencyKey: newIdempotencyKey(),
            answers: answersPayload,
            compliance: compliance,
          );

      if (!mounted) return;
      ref.invalidate(inspectionsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection submitted.')),
      );
      context.go(Routes.inspections);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    required this.questionId,
    required this.text,
    required this.severityIndex,
    required this.requiresPhoto,
    required this.current,
    required this.onChanged,
    required this.onAddPhoto,
  });

  final String questionId;
  final String text;
  final int severityIndex;
  final bool requiresPhoto;
  final _QuestionResult? current;
  final ValueChanged<_QuestionResult> onChanged;
  final ValueChanged<String> onAddPhoto;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final _result = widget.current ??
      _QuestionResult(widget.questionId, InspectionResponse.pass);
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _comment.text = widget.current?.comment ?? '';
  }

  void _set(InspectionResponse response) {
    setState(() => _result.response = response);
    widget.onChanged(_result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsComment = _result.response.countsAgainstCompliance;
    final severityLabel = switch (widget.severityIndex) {
      >= 4 => 'High significance',
      == 3 => 'Medium',
      _ => 'Low',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.text, style: theme.textTheme.bodyLarge)),
                const SizedBox(width: 8),
                StatusChip.severity(
                  switch (widget.severityIndex) {
                    >= 4 => Severity.high,
                    == 3 => Severity.medium,
                    _ => Severity.low,
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              severityLabel,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final response in InspectionResponse.values)
                  ChoiceChip(
                    label: Text(response.name),
                    selected: _result.response == response,
                    onSelected: (_) => _set(response),
                  ),
              ],
            ),
            if (needsComment) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _comment,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comment (required for a failure)',
                ),
                onChanged: (v) {
                  _result.comment = v;
                  widget.onChanged(_result);
                },
              ),
            ],
            if (widget.requiresPhoto || needsComment) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => widget.onAddPhoto(widget.questionId),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(
                  _result.photoPaths.isEmpty ? 'Add photo' : 'Photo attached (${_result.photoPaths.length})',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
