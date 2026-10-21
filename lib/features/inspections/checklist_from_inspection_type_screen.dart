// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../core/router/routes.dart';
import '../../data/models/ops_models.dart';
import '../../data/repositories/storage_repository.dart';
import '../../providers/providers.dart';
import '../shared/signature_pad.dart';
import '../shared/ui_kit.dart';

/// Checklist runner driven by an inspection type name.
///
/// The template items are pulled from `truck_inspection_template_items`
/// where `section` matches the selected inspection type name (e.g. 'Housekeeping').
/// Each item is answered PASS / FAIL / N/A. Fails require a comment and, when
/// `requires_photo` is true, an attached photo.
class ChecklistFromInspectionTypeScreen extends ConsumerStatefulWidget {
  const ChecklistFromInspectionTypeScreen({
    super.key,
    required this.inspectionTypeName,
    required this.inspectionTypeId,
  });

  final String inspectionTypeName;
  final String inspectionTypeId;

  @override
  ConsumerState<ChecklistFromInspectionTypeScreen> createState() =>
      _ChecklistFromInspectionTypeScreenState();
}

class _ChecklistItemResult {
  _ChecklistItemResult({
    required this.itemId,
    required this.responseType,
    this.passFailValue,
    this.numericValue,
    this.textValue,
    this.comment = '',
    this.photoPaths = const [],
  });

  final String itemId;
  final TruckItemResponseType responseType;
  bool? passFailValue;
  double? numericValue;
  String? textValue;
  String comment;
  List<String> photoPaths;
}

class _ChecklistFromInspectionTypeScreenState
    extends ConsumerState<ChecklistFromInspectionTypeScreen> {
  final Map<String, _ChecklistItemResult> _answers = {};
  final _signatureController = SignatureController();
  bool _saving = false;
  String? _error;
  String? _signaturePath;
  List<TruckInspectionTemplateItem> _items = [];
  bool _loaded = false;

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.inspectionTypeName)),
      body: _loaded && _items.isEmpty
          ? const EmptyView(
              title: 'No checklist items',
              message: 'No checklist items are defined for this inspection type.',
              icon: Icons.assessment_outlined,
            )
          : _loaded
              ? _buildChecklist(theme)
              : const LoadingView(message: 'Loading checklist items…'),
    );
  }

  Widget _buildChecklist(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        for (final item in _items) ...[
          _ChecklistItemCard(
            item: item,
            result: _answers[item.id],
            onChanged: (result) => setState(() => _answers[item.id] = result),
            onAddPhoto: _pickPhoto,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 16),
        Text(
          'Inspector Signature',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SignaturePad(
          controller: _signatureController,
          label: 'Inspector signature',
          savedPath: _signaturePath,
          onSaved: (path) => setState(() => _signaturePath = path),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          InlineError(_error!),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(_saving ? 'Submitting…' : 'Submit inspection'),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await ref.read(opsRepositoryProvider).listTruckInspectionTemplateItems(
        templateId: widget.inspectionTypeId,
        activeOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = readableError(e);
        _loaded = true;
      });
    }
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
        final result = _answers[questionId] ??
            _ChecklistItemResult(
              itemId: questionId,
              responseType: TruckItemResponseType.passFail,
            );
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
    // Validate: every pass/fail item answered, every fail with a comment,
    // every photo-required item has a photo.
    final missing = <String>[];
    for (final item in _items) {
      if (!item.isActive) continue;
      final result = _answers[item.id];
      if (result == null) {
        missing.add('unanswered: ${item.itemText}');
        continue;
      }
      if (result.responseType == TruckItemResponseType.passFail) {
        if (result.passFailValue == false && result.comment.trim().isEmpty) {
          missing.add('${item.itemText} failed with no comment');
        }
      }
      if (item.requiresPhoto && result.photoPaths.isEmpty) {
        missing.add('${item.itemText} requires a photo');
      }
    }
    if (missing.isNotEmpty) {
      setState(() => _error = readableError('Missing: ${missing.join(', ')}.'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = ref.read(profileProvider).profile;
      if (profile == null) throw Exception('You are not signed in.');

      final answersPayload = _answers.values
          .map((r) => {
                'question_id': r.itemId,
                'response_type': r.responseType.wire,
                'pass_fail_value': r.passFailValue,
                'numeric_value': r.numericValue,
                'text_value': r.textValue,
                'response': r.passFailValue != null
                    ? (r.passFailValue! ? 'PASS' : 'FAIL')
                    : r.responseType.wire,
                'comment': r.comment,
                'photo_paths': r.photoPaths,
              })
          .toList(growable: false);

      await ref.read(inspectionRepositoryProvider).createInspection(
            depotId: profile.depotId,
            templateId: widget.inspectionTypeId,
            checklistName: widget.inspectionTypeName,
            type: 'INSPECTION',
            completedBy: profile.id,
            idempotencyKey:
                '${profile.id}_${widget.inspectionTypeId}_${DateTime.now().millisecondsSinceEpoch}',
            answers: answersPayload,
            compliance: 0,
            signaturePath: _signaturePath,
            photoPaths: _answers.values.expand((r) => r.photoPaths).toList(growable: false),
          );

      if (!mounted) return;
      ref.invalidate(inspectionTypesProvider);
      context.go(Routes.inspections);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ChecklistItemCard extends StatefulWidget {
  const _ChecklistItemCard({
    required this.item,
    required this.result,
    required this.onChanged,
    required this.onAddPhoto,
  });

  final TruckInspectionTemplateItem item;
  final _ChecklistItemResult? result;
  final ValueChanged<_ChecklistItemResult> onChanged;
  final ValueChanged<String> onAddPhoto;

  @override
  State<_ChecklistItemCard> createState() => _ChecklistItemCardState();
}

class _ChecklistItemCardState extends State<_ChecklistItemCard> {
  late _ChecklistItemResult _result;

  @override
  void initState() {
    super.initState();
    _result = widget.result ??
        _ChecklistItemResult(
          itemId: widget.item.id,
          responseType: widget.item.responseType,
        );
  }

  void _set(_ChecklistItemResult result) {
    setState(() => _result = result);
    widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final needsComment = item.responseType == TruckItemResponseType.passFail &&
        _result.passFailValue == false;
    final needsPhoto = item.requiresPhoto;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.itemText,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                if (item.isCritical)
                  const Icon(Icons.warning, color: Colors.red, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.section,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (item.responseType == TruckItemResponseType.passFail) ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final v in [true, false])
                    ChoiceChip(
                      label: Text(v ? 'PASS' : 'FAIL'),
                      selected: _result.passFailValue == v,
                      onSelected: (_) {
                        final r = _ChecklistItemResult(
                          itemId: widget.item.id,
                          responseType: widget.item.responseType,
                          passFailValue: v,
                          numericValue: _result.numericValue,
                          textValue: _result.textValue,
                          comment: _result.comment,
                          photoPaths: _result.photoPaths,
                        );
                        _set(r);
                      },
                    ),
                ],
              ),
            ] else if (item.responseType == TruckItemResponseType.numeric) ...[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Numeric value',
                  hintText: 'Enter value',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final r = _ChecklistItemResult(
                    itemId: widget.item.id,
                    responseType: widget.item.responseType,
                    passFailValue: _result.passFailValue,
                    numericValue: double.tryParse(v),
                    textValue: _result.textValue,
                    comment: _result.comment,
                    photoPaths: _result.photoPaths,
                  );
                  _set(r);
                },
              ),
            ] else if (item.responseType == TruckItemResponseType.text) ...[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Text response',
                  hintText: 'Enter text',
                ),
                onChanged: (v) {
                  final r = _ChecklistItemResult(
                    itemId: widget.item.id,
                    responseType: widget.item.responseType,
                    passFailValue: _result.passFailValue,
                    numericValue: _result.numericValue,
                    textValue: v.trim().isEmpty ? null : v.trim(),
                    comment: _result.comment,
                    photoPaths: _result.photoPaths,
                  );
                  _set(r);
                },
              ),
            ],
            if (needsComment) ...[
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Comment (required for failure)',
                ),
                maxLines: 3,
                onChanged: (v) {
                  final r = _ChecklistItemResult(
                    itemId: widget.item.id,
                    responseType: widget.item.responseType,
                    passFailValue: _result.passFailValue,
                    numericValue: _result.numericValue,
                    textValue: _result.textValue,
                    comment: v,
                    photoPaths: _result.photoPaths,
                  );
                  _set(r);
                },
              ),
            ],
            if (needsPhoto || (_result.photoPaths.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Text('Photos', style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final path in _result.photoPaths)
                    Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.file(File(path), fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              final newPaths = _result.photoPaths..remove(path);
                              final r = _ChecklistItemResult(
                                itemId: widget.item.id,
                                responseType: widget.item.responseType,
                                passFailValue: _result.passFailValue,
                                numericValue: _result.numericValue,
                                textValue: _result.textValue,
                                comment: _result.comment,
                                photoPaths: newPaths,
                              );
                              widget.onChanged(r);
                            },
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  OutlinedButton.icon(
                    onPressed: () => widget.onAddPhoto(widget.item.id),
                    icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                    label: const Text('Add photo'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
