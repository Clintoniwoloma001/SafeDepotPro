// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../data/models/ops_models.dart';
import '../../data/models/workflows.dart';
import '../../data/repositories/storage_repository.dart';
import '../../providers/providers.dart';
import '../shared/photo_capture_sheet.dart';
import '../shared/signature_pad.dart';
import '../shared/ui_kit.dart' hide LoadingView, ErrorView, InlineError;

class ShiftHandoverScreen extends ConsumerStatefulWidget {
  const ShiftHandoverScreen({super.key});

  @override
  ConsumerState<ShiftHandoverScreen> createState() => _ShiftHandoverScreenState();
}

class _ShiftHandoverScreenState extends ConsumerState<ShiftHandoverScreen> {
  final _summary = TextEditingController();
  final _equipmentNotes = TextEditingController();
  final _pendingIssues = TextEditingController();
  final _outgoingSignature = SignatureController();
  final _incomingSignature = SignatureController();
  String? _outgoingSignaturePath;
  String? _incomingSignaturePath;
  List<String> _photoPaths = const [];
  String _shift = 'DAY';
  DateTime _date = DateTime.now();
  String? _incomingUserId;
  List<Profile> _incomingUsers = const [];
  bool _saving = false;
  String? _error;
  List<RoutineTask> _openTasks = const [];
  List<Permit> _openPermits = const [];
  bool _autoPopulated = false;
  List<ShiftHandover> _awaiting = const [];
  bool _loadingAwaiting = false;

  @override
  void initState() {
    super.initState();
    _loadAwaiting();
  }

  @override
  void dispose() {
    _summary.dispose();
    _equipmentNotes.dispose();
    _pendingIssues.dispose();
    _outgoingSignature.dispose();
    _incomingSignature.dispose();
    super.dispose();
  }

  Future<void> _loadOpenItems() async {
    if (_autoPopulated) return;
    try {
      final tasks = await ref.read(openTasksProvider.future);
      final permits = await ref.read(permitRepositoryProvider).listPermits(
        status: PermitStatus.submitted,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _openTasks = tasks;
          _openPermits = permits;
          _autoPopulated = true;
        });
      }
    } catch (e) {
      // Silently fail - auto-population is optional
    }
  }

  Future<void> _loadAwaiting() async {
    final profile = ref.read(profileProvider).profile;
    if (profile?.depotId == null) return;
    if (!mounted) return;
    setState(() => _loadingAwaiting = true);
    try {
      final all = await ref.read(opsRepositoryProvider).listShiftHandovers(
        depotId: profile!.depotId,
        limit: 100,
      );
      final awaiting = all
          .where((h) => h.incomingUserId == profile.id && h.status == ShiftStatus.pending)
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _awaiting = awaiting;
          _loadingAwaiting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAwaiting = false);
    }
  }

  Future<void> _acceptHandover(ShiftHandover handover) async {
    final controller = SignatureController();
    String? savedPath;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Accept shift handover', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 16),
            SignaturePad(
              controller: controller,
              label: 'Incoming signature',
              onSaved: (path) => savedPath = path,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (savedPath == null || savedPath!.isEmpty) return;
                Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.check),
              label: const Text('Accept & start shift'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    controller.dispose();
    if (savedPath == null || savedPath!.isEmpty) return;
    try {
      await ref.read(opsRepositoryProvider).updateShiftHandover(
        id: handover.id,
        signatureIncoming: savedPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Handover accepted. Shift started.')),
      );
      _loadAwaiting();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(readableError(e))),
      );
    }
  }

  Future<void> _save({bool sendHandover = false}) async {
    final profile = ref.read(profileProvider).profile;
    if (profile == null) {
      setState(() => _error = 'Not signed in.');
      return;
    }
    final depotId = profile.depotId;
    if (depotId == null) {
      setState(() => _error = 'No depot assigned.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final dateStr = _date.toIso8601String();
      final pendingIssues = _pendingIssues.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      final handover = await ref.read(opsRepositoryProvider).createShiftHandover(
        depotId: depotId,
        shift: _shift,
        date: dateStr,
        outgoingUserId: profile.id,
        incomingUserId: _incomingUserId,
        summary: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
        pendingIssues: pendingIssues,
        equipmentNotes: _equipmentNotes.text.trim().isEmpty ? null : _equipmentNotes.text.trim(),
        signatureOutgoing: _outgoingSignaturePath,
        signatureIncoming: _incomingSignaturePath,
        photoPaths: _photoPaths,
      );

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shift handover ${sendHandover ? 'sent' : 'saved'} successfully.'),
        ),
      );
      _loadAwaiting();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = readableError(e);
      });
    }
  }

  void _showForm() async {
    _loadOpenItems();
    final profile = ref.read(profileProvider).profile;
    if (profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not signed in.')),
        );
      }
      return;
    }
    List<Profile> users = const [];
    if (profile.depotId != null) {
      try {
        users = await ref.read(incomingUsersByDepotProvider(profile.depotId!).future);
      } catch (_) {
        users = const [];
      }
    }
    if (!mounted) return;
    setState(() => _incomingUsers = users);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _HandoverForm(
        shift: _shift,
        date: _date,
        summaryController: _summary,
        equipmentNotesController: _equipmentNotes,
        pendingIssuesController: _pendingIssues,
        outgoingSignature: _outgoingSignature,
        incomingSignature: _incomingSignature,
        outgoingSignaturePath: _outgoingSignaturePath,
        incomingSignaturePath: _incomingSignaturePath,
        photoPaths: _photoPaths,
        openTasks: _openTasks,
        openPermits: _openPermits,
        onOutgoingSignatureSaved: (path) => setState(() => _outgoingSignaturePath = path),
        onIncomingSignatureSaved: (path) => setState(() => _incomingSignaturePath = path),
        onPhotosChanged: (paths) => setState(() => _photoPaths = paths),
        onShiftChanged: (v) => setState(() => _shift = v ?? _shift),
        onDateChanged: (v) => setState(() => _date = v ?? _date),
        onSave: () async {
          await _save(sendHandover: false);
          if (mounted) Navigator.of(context).pop();
        },
        onSend: () async {
          await _save(sendHandover: true);
          if (mounted) Navigator.of(context).pop();
        },
        saving: _saving,
        error: _error,
        incomingUsers: _incomingUsers,
        selectedIncomingUserId: _incomingUserId,
        onIncomingUserChanged: (id) => setState(() => _incomingUserId = id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shift Handover'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'New Handover'),
              Tab(text: 'Awaiting Acceptance'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shift Handover',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showForm,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('New Shift Handover'),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _openTasks.isEmpty && _openPermits.isEmpty
                        ? const EmptyView(
                            title: 'No open items',
                            message: 'No open tasks or permits found for your depot.',
                            icon: Icons.task_outlined,
                          )
                        : ListView(
                            children: [
                              if (_openTasks.isNotEmpty) ...[
                                Text('Open Tasks',
                                    style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                ..._openTasks.map((t) => ListTile(
                                  title: Text(t.title),
                                  subtitle: Text(t.frequency.wire),
                                  trailing: Text(t.isActive ? 'Active' : 'Inactive'),
                                )),
                              ],
                              if (_openPermits.isNotEmpty) ...[
                                Text('Open Permits',
                                    style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                ..._openPermits.map((p) => ListTile(
                                  title: Text(p.jobTitle),
                                  subtitle: Text(p.status.wire),
                                )),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
            _loadingAwaiting
                ? const Center(child: CircularProgressIndicator())
                : _awaiting.isEmpty
                    ? const EmptyView(
                        title: 'No pending handovers',
                        message: 'No shift handovers awaiting your acceptance.',
                        icon: Icons.inbox_outlined,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _awaiting.length,
                        itemBuilder: (context, index) {
                          final h = _awaiting[index];
                          return Card(
                            child: ListTile(
                              title: Text('${h.shift} shift'),
                              subtitle: Text(h.summary ?? 'Awaiting your acceptance'),
                              trailing: h.status == ShiftStatus.pending && (h.signatureIncoming == null || h.signatureIncoming!.isEmpty)
                                  ? FilledButton(
                                      onPressed: () => _acceptHandover(h),
                                      child: const Text('Accept'),
                                    )
                                  : const Icon(Icons.check_circle, color: Colors.green),
                            ),
                          );
                        },
                      ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showForm,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('New Handover'),
        ),
      ),
    );
  }
}

class _HandoverForm extends StatelessWidget {
  const _HandoverForm({
    required this.shift,
    required this.date,
    required this.summaryController,
    required this.equipmentNotesController,
    required this.pendingIssuesController,
    required this.outgoingSignature,
    required this.incomingSignature,
    this.outgoingSignaturePath,
    this.incomingSignaturePath,
    required this.photoPaths,
    required this.openTasks,
    required this.openPermits,
    required this.onOutgoingSignatureSaved,
    required this.onIncomingSignatureSaved,
    required this.onPhotosChanged,
    required this.onShiftChanged,
    required this.onDateChanged,
    required this.onSave,
    required this.onSend,
    required this.saving,
    this.error,
    required this.incomingUsers,
    required this.selectedIncomingUserId,
    required this.onIncomingUserChanged,
  });

  final String shift;
  final DateTime date;
  final TextEditingController summaryController;
  final TextEditingController equipmentNotesController;
  final TextEditingController pendingIssuesController;
  final SignatureController outgoingSignature;
  final SignatureController incomingSignature;
  final String? outgoingSignaturePath;
  final String? incomingSignaturePath;
  final List<String> photoPaths;
  final List<RoutineTask> openTasks;
  final List<Permit> openPermits;
  final ValueChanged<String> onOutgoingSignatureSaved;
  final ValueChanged<String> onIncomingSignatureSaved;
  final ValueChanged<List<String>> onPhotosChanged;
  final ValueChanged<String?> onShiftChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onSend;
  final bool saving;
  final String? error;
  final List<Profile> incomingUsers;
  final String? selectedIncomingUserId;
  final ValueChanged<String?> onIncomingUserChanged;

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Text('New shift handover',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextFormField(
            controller: summaryController,
            decoration: const InputDecoration(
              labelText: 'Summary',
              hintText: 'Key events from the outgoing shift',
            ),
            maxLines: 3,
            inputFormatters: [
              LengthLimitingTextInputFormatter(500),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: selectedIncomingUserId,
            decoration: const InputDecoration(
              labelText: 'Incoming Staff (who will accept handover)',
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None')),
              ...incomingUsers.map((u) => DropdownMenuItem(
                value: u.id,
                child: Text(u.fullName ?? ''),
              )),
            ],
            onChanged: onIncomingUserChanged,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: pendingIssuesController,
            decoration: const InputDecoration(
              labelText: 'Pending issues (one per line)',
              hintText: 'Enter any pending issues from the shift',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: equipmentNotesController,
            decoration: const InputDecoration(
              labelText: 'Equipment notes',
              hintText: 'Any equipment notes or concerns',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: saving ? null : onSend,
                  icon: const Icon(Icons.send),
                  label: const Text('Send Handover'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }
}
