// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/ops_models.dart';
import '../../data/repositories/storage_repository.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';
import '../shared/signature_pad.dart';
import 'package:signature/signature.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ToolboxTalksScreen extends StatefulWidget {
  const ToolboxTalksScreen({super.key});

  @override
  State<ToolboxTalksScreen> createState() => _ToolboxTalksScreenState();
}

class _ToolboxTalksScreenState extends State<ToolboxTalksScreen> {
  String? _selectedTalkId;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final profile = ref.watch(profileProvider).profile;
        final depotId = profile?.depotId;

        if (profile == null) return const ErrorView(message: 'Not signed in.');
        if (depotId == null) return const ErrorView(message: 'No depot assigned.');

        final talksAsync = ref.watch(toolboxTalksProvider(depotId));

        return Scaffold(
          appBar: AppBar(title: const Text('Toolbox Talks')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateTalkDialog(context, ref, depotId),
            icon: const Icon(Icons.add),
            label: const Text('New Talk'),
          ),
          body: talksAsync.when(
            loading: () => const LoadingView(message: 'Loading talks…'),
            error: (e, _) => ErrorView(message: readableError(e)),
            data: (talks) {
              if (talks.isEmpty) {
                return const EmptyView(
                  title: 'No toolbox talks',
                  message: 'Create your first toolbox talk using the button below.',
                  icon: Icons.groups_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: talks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final talk = talks[i];
                  final isSelected = _selectedTalkId == talk.id;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.groups_outlined, size: 20),
                      title: Text(talk.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${talk.date} ${talk.time} · ${talk.facilitator ?? 'TBD'}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          if (talk.category != null)
                            Text(
                              talk.category!,
                              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? Theme.of(ctx).colorScheme.primary : null,
                            ),
                            onPressed: () => setState(() => _selectedTalkId = talk.id),
                            tooltip: 'Select for attendance',
                          ),
                        ],
                      ),
                      onTap: () => _manageAttendance(context, ref, talk),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showCreateTalkDialog(BuildContext context, WidgetRef ref, String depotId) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final facilitatorController = TextEditingController();
    final locationController = TextEditingController();
    final categoryController = TextEditingController();
    final dateController = TextEditingController(text: _formatDate(DateTime.now()));
    final timeController = TextEditingController(text: _formatTime(DateTime.now()));
    bool saving = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New Toolbox Talk'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g., Forklift Safety',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g., Heavy Equipment',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: facilitatorController,
                  decoration: const InputDecoration(
                    labelText: 'Facilitator',
                    hintText: 'e.g., John Smith (HSE Officer)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g., Warehouse A',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => dateController.text = _formatDate(picked));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: timeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          suffixIcon: Icon(Icons.access_time),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setState(() => timeController.text = picked.format(ctx));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Talk content summary',
                  ),
                  maxLines: 3,
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        setState(() => error = 'Title is required.');
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        final profile = ref.read(profileProvider).profile;
                        await ref.read(opsRepositoryProvider).createToolboxTalk(
                          depotId: depotId,
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          date: dateController.text.trim(),
                          time: timeController.text.trim(),
                          facilitator: facilitatorController.text.trim().isEmpty
                              ? null
                              : facilitatorController.text.trim(),
                          location: locationController.text.trim().isEmpty
                              ? null
                              : locationController.text.trim(),
                          category: categoryController.text.trim().isEmpty
                              ? null
                              : categoryController.text.trim(),
                          createdBy: profile?.id,
                        );
                        ref.invalidate(toolboxTalksProvider(depotId));
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Toolbox talk created.')),
                        );
                      } catch (e) {
                        setState(() => error = readableError(e));
                      } finally {
                        if (ctx.mounted) setState(() => saving = false);
                      }
                    },
              child: saving ? const Text('Creating…') : const Text('Create Talk'),
            ),
          ],
        ),
      ),
    );
  }

  void _manageAttendance(BuildContext context, WidgetRef ref, ToolboxTalk talk) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ToolboxParticipantSheet(talk: talk),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Provider for attendees of a specific toolbox talk.
final toolboxTalkAttendeesProvider = FutureProvider.family<List<ToolboxAttendee>, String>((ref, talkId) async {
  return ref.read(opsRepositoryProvider).listAttendees(talkId);
});

/// A single participant row in the Toolbox Talk entry sheet.
class _Participant {
  _Participant({this.id, String name = '', String role = '', this.signaturePath});

  String? id;
  final nameController = TextEditingController();
  final roleController = TextEditingController();
  final sigController = SignatureController();
  String? signaturePath;

  void dispose() {
    nameController.dispose();
    roleController.dispose();
    sigController.dispose();
  }
}

class _ToolboxParticipantSheet extends ConsumerStatefulWidget {
  const _ToolboxParticipantSheet({required this.talk});

  final ToolboxTalk talk;

  @override
  ConsumerState<_ToolboxParticipantSheet> createState() =>
      _ToolboxParticipantSheetState();
}

class _ToolboxParticipantSheetState
    extends ConsumerState<_ToolboxParticipantSheet> {
  bool _loading = true;
  final List<_Participant> _participants = [];
  final _dsoNameController = TextEditingController();
  final _dsoDesignationController =
      TextEditingController(text: 'Safety Officer (DSO)');
  final _dsoSigController = SignatureController();
  String? _dsoSignaturePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).profile;
    _dsoNameController.text = profile?.displayName ?? '';
    _load();
  }

  Future<void> _load() async {
    try {
      final attendees =
          await ref.read(opsRepositoryProvider).listAttendees(widget.talk.id);
      for (final a in attendees) {
        if (a.employeeNumber?.startsWith('DSO_SIGNOFF') == true) {
          _dsoNameController.text = a.name;
          final parts = a.employeeNumber!.split('|');
          if (parts.length > 1) {
            _dsoDesignationController.text = parts[1];
          }
          _dsoSignaturePath = a.signaturePath;
        } else {
          final p = _Participant(
            id: a.id,
            name: a.name,
            role: a.employeeNumber ?? '',
            signaturePath: a.signaturePath,
          );
          p.nameController.text = a.name;
          p.roleController.text = a.employeeNumber ?? '';
          _participants.add(p);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final p in _participants) {
      p.dispose();
    }
    _dsoNameController.dispose();
    _dsoDesignationController.dispose();
    _dsoSigController.dispose();
    super.dispose();
  }

  Future<String?> _uploadController(
      SignatureController ctrl, String depotId) async {
    final bytes = await ctrl.toPngBytes(width: 300, height: 150);
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return await ref.read(storageRepositoryProvider).uploadBytes(
            bucket: StorageRepository.signatures,
            depotId: depotId,
            fileName:
                'signature_${DateTime.now().millisecondsSinceEpoch}.png',
            bytes: bytes,
            contentType: 'image/png',
          );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _showDsoModal() async {
    final sigCtrl = SignatureController();
    String? path;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Safety Officer (DSO) Sign-Off'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _dsoNameController,
                decoration: const InputDecoration(labelText: 'DSO Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dsoDesignationController,
                decoration:
                    const InputDecoration(labelText: 'Designation'),
              ),
              const SizedBox(height: 12),
              SignaturePad(
                controller: sigCtrl,
                label: 'DSO signature',
                onSaved: (p) {
                  path = p;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (path == null && sigCtrl.isNotEmpty) {
                final profile = ref.read(profileProvider).profile;
                final depotId = profile?.depotId ?? 'unassigned';
                path = await _uploadController(sigCtrl, depotId);
              }
              if (!mounted) return;
              if (path == null || path!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please sign before completing.')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    sigCtrl.dispose();
    if (result == true) return path;
    return null;
  }

  Future<void> _saveParticipants() async {
    for (final p in _participants) {
      if (p.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('All participants need a name.')),
        );
        return;
      }
    }
    setState(() => _saving = true);
    final profile = ref.read(profileProvider).profile;
    final depotId = profile?.depotId ?? 'unassigned';
    try {
      for (final p in _participants) {
        if (p.signaturePath == null && p.sigController.isNotEmpty) {
          p.signaturePath = await _uploadController(p.sigController, depotId);
        }
        if (p.id == null) {
          final created = await ref.read(opsRepositoryProvider).addAttendee(
                toolboxTalkId: widget.talk.id,
                name: p.nameController.text.trim(),
                employeeNumber: p.roleController.text.trim().isEmpty
                    ? null
                    : p.roleController.text.trim(),
                signaturePath: p.signaturePath,
              );
          p.id = created.id;
        } else {
          await ref.read(opsRepositoryProvider).updateAttendee(
                id: p.id!,
                name: p.nameController.text.trim(),
                employeeNumber: p.roleController.text.trim().isEmpty
                    ? null
                    : p.roleController.text.trim(),
                signaturePath: p.signaturePath,
              );
        }
      }
      setState(() => _saving = false);

      final dsoPath = await _showDsoModal();
      if (dsoPath == null) return;
      _dsoSignaturePath = dsoPath;

      final attendees =
          await ref.read(opsRepositoryProvider).listAttendees(widget.talk.id);
      final existingDso = attendees
          .where((a) => a.employeeNumber?.startsWith('DSO_SIGNOFF') == true)
          .firstOrNull;
      final designation = _dsoDesignationController.text.trim().isEmpty
          ? 'Safety Officer (DSO)'
          : _dsoDesignationController.text.trim();
      final marker = 'DSO_SIGNOFF|$designation';
      if (existingDso == null) {
        await ref.read(opsRepositoryProvider).addAttendee(
              toolboxTalkId: widget.talk.id,
              name: _dsoNameController.text.trim(),
              employeeNumber: marker,
              signaturePath: _dsoSignaturePath,
            );
      } else {
        await ref.read(opsRepositoryProvider).updateAttendee(
              id: existingDso.id,
              name: _dsoNameController.text.trim(),
              employeeNumber: marker,
              signaturePath: _dsoSignaturePath,
            );
      }

      await _generatePdf();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toolbox talk saved.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _signatureBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('data:')) {
      final comma = path.indexOf(',');
      if (comma != -1) {
        try {
          return base64Decode(path.substring(comma + 1));
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    try {
      return await ref
          .read(storageRepositoryProvider)
          .downloadBytes(StorageRepository.signatures, path);
    } catch (_) {
      return null;
    }
  }

static const String _hbmLogoBase64 = '''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AwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIeCHQAAECBAgQIJCAk4EMCBAgQIAAAYNAAwQIECBAgIAXAg0QIECAAAECCTgZyIAAAQIECBAwCDRAgAABAgQIbBcgqC3KRMLE0QAAAABJRU5ErkJggg==''';

  Future<void> _generatePdf() async {
    final profile = ref.read(profileProvider).profile;
    final depotId = profile?.depotId;
    String depotName = depotId ?? '';
    try {
      final depots = await ref.read(depotRepositoryProvider).listDepots();
      final depot = depots.where((d) => d.id == depotId).firstOrNull;
      if (depot != null) depotName = depot.name;
    } catch (_) {}

    final logoBytes = base64Decode(_hbmLogoBase64);

    final sigBytes = <Uint8List?>[];
    for (final p in _participants) {
      sigBytes.add(await _signatureBytes(p.signaturePath));
    }
    final dsoSigBytes = await _signatureBytes(_dsoSignaturePath);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Image(pw.MemoryImage(logoBytes), width: 60, height: 60),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Toolbox Talk Report',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Topic: ${widget.talk.title}'),
                  pw.Text('Depot: $depotName'),
                  pw.Text('Date: ${widget.talk.date}'),
                  pw.Text('Time: ${widget.talk.time}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('S/N',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Participant Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Role/Company',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Signature',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ],
              ),
              for (int i = 0; i < _participants.length; i++)
                pw.TableRow(
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('${i + 1}')),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child:
                            pw.Text(_participants[i].nameController.text)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child:
                            pw.Text(_participants[i].roleController.text)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: sigBytes[i] != null
                          ? pw.Image(pw.MemoryImage(sigBytes[i]!),
                              width: 90, height: 40)
                          : pw.SizedBox(height: 40),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Safety Officer Sign-Off',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Name: ${_dsoNameController.text}'),
          pw.Text('Designation: ${_dsoDesignationController.text}'),
          if (dsoSigBytes != null)
            pw.Image(pw.MemoryImage(dsoSigBytes), width: 120, height: 60),
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(
        bytes: bytes, filename: 'toolbox_talk_${widget.talk.id}.pdf');
  }

  Future<void> _downloadStoredPdf() async {
    final attendees =
        await ref.read(opsRepositoryProvider).listAttendees(widget.talk.id);
    for (final p in _participants) {
      p.dispose();
    }
    _participants.clear();
    for (final a in attendees) {
      if (a.employeeNumber?.startsWith('DSO_SIGNOFF') == true) {
        _dsoNameController.text = a.name;
        final parts = a.employeeNumber!.split('|');
        _dsoDesignationController.text =
            parts.length > 1 ? parts[1] : 'Safety Officer (DSO)';
        _dsoSignaturePath = a.signaturePath;
      } else {
        final p = _Participant(
          id: a.id,
          name: a.name,
          role: a.employeeNumber ?? "",
          signaturePath: a.signaturePath,
        );
        p.nameController.text = a.name;
        p.roleController.text = a.employeeNumber ?? '';
        _participants.add(p);
      }
    }
    await _generatePdf();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Participants — ${widget.talk.title}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _participants.length,
              itemBuilder: (ctx, i) {
                final p = _participants[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: p.nameController,
                                decoration: const InputDecoration(
                                    labelText: 'Participant Name'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: p.roleController,
                                decoration: const InputDecoration(
                                    labelText: 'Role/Company'),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                p.dispose();
                                setState(() => _participants.removeAt(i));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SignaturePad(
                          controller: p.sigController,
                          label: 'Participant signature',
                          savedPath: p.signaturePath,
                          onSaved: (path) {
                            p.signaturePath = path;
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _participants.add(_Participant())),
            icon: const Icon(Icons.add),
            label: const Text('Add Participant'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveParticipants,
              child: Text(_saving ? 'Saving…' : 'Save Participants'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _downloadStoredPdf,
              icon: const Icon(Icons.download),
              label: const Text('Download Attendance PDF'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}
