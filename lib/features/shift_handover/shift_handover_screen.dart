// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../data/models/ops_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/storage_repository.dart';
import '../../data/models/enums.dart';
import '../../providers/providers.dart';
import '../shared/signature_pad.dart';
import '../shared/ui_kit.dart';

class ShiftHandoverScreen extends ConsumerStatefulWidget {
  const ShiftHandoverScreen({super.key});

  @override
  ConsumerState<ShiftHandoverScreen> createState() =>
      _ShiftHandoverScreenState();
}

class _ShiftHandoverScreenState extends ConsumerState<ShiftHandoverScreen> {
  final _summary = TextEditingController();
  final _equipmentNotes = TextEditingController();
  final _pendingIssues = TextEditingController();
  final _outgoingSignature = SignatureController();
  final _incomingSignature = SignatureController();
  String? _outgoingSignaturePath;
  String? _incomingSignaturePath;
  String _shift = 'DAY';
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _summary.dispose();
    _equipmentNotes.dispose();
    _pendingIssues.dispose();
    _outgoingSignature.dispose();
    _incomingSignature.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final profile = ref.read(profileProvider).profile;
    if (profile == null) {
      setState(() => _error = 'Not signed in.');
      return;
    }
    final depotId = profile.depotId;
    if (depotId == null) {
      setState(() => _error = 'No depot assigned to your profile.');
      return;
    }

    setState(() => _saving = true);

    try {
      final dateStr =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      final pendingList = _pendingIssues.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);

      await ref.read(opsRepositoryProvider).createShiftHandover(
            depotId: depotId,
            shift: _shift,
            date: dateStr,
            outgoingUserId: profile.id,
            summary: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
            pendingIssues: pendingList,
            equipmentNotes:
                _equipmentNotes.text.trim().isEmpty ? null : _equipmentNotes.text.trim(),
            signatureOutgoing: _outgoingSignaturePath,
            signatureIncoming: _incomingSignaturePath,
          );

      ref.invalidate(shiftHandoversProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift handover recorded.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = readableError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).profile;
    final handovers = ref.watch(shiftHandoversProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shift Handover')),
      body: profile == null
          ? const ErrorView(message: 'Not signed in.')
          : Column(
              children: [
                Expanded(
                  child: handovers.when(
                    loading: () =>
                        const LoadingView(message: 'Loading handovers…'),
                    error: (e, _) => ErrorView(
                      message: readableError(e),
                      onRetry: () => ref.refresh(shiftHandoversProvider.future),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return const EmptyView(
                          title: 'No handover records',
                          message:
                              'Record your first shift handover by pressing the button below.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final h = list[i];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                h.status == ShiftStatus.confirmed
                                    ? Icons.check_circle
                                    : Icons.access_time,
                                color: h.status == ShiftStatus.confirmed
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              title: Text(
                                '${h.shift} shift · ${h.date}',
                                style: Theme.of(ctx).textTheme.bodyMedium,
                              ),
                              subtitle: Text(
                                h.summary ?? 'No summary',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                              trailing: h.isCompleted
                                  ? const Icon(Icons.verified, size: 16)
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _showForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('New shift handover'),
                  ),
                ),
              ],
            ),
    );
  }

  void _showForm() {
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
        onOutgoingSignatureSaved: (path) => setState(() => _outgoingSignaturePath = path),
        onIncomingSignatureSaved: (path) => setState(() => _incomingSignaturePath = path),
        onShiftChanged: (v) => setState(() => _shift = v ?? _shift),
        onDateChanged: (v) => setState(() => _date = v ?? _date),
        onSave: _save,
        saving: _saving,
        error: _error,
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
    required this.onOutgoingSignatureSaved,
    required this.onIncomingSignatureSaved,
    required this.onShiftChanged,
    required this.onDateChanged,
    required this.onSave,
    required this.saving,
    this.error,
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
  final ValueChanged<String> onOutgoingSignatureSaved;
  final ValueChanged<String> onIncomingSignatureSaved;
  final ValueChanged<String?> onShiftChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final VoidCallback onSave;
  final bool saving;
  final String? error;

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('New shift handover',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: shift,
            decoration: const InputDecoration(labelText: 'Shift'),
            items: const [
              DropdownMenuItem(value: 'DAY', child: Text('Day')),
              DropdownMenuItem(value: 'NIGHT', child: Text('Night')),
            ],
            onChanged: onShiftChanged,
          ),
          const SizedBox(height: 12),
          TextFormField(
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Date',
              suffixIcon: Icon(Icons.calendar_today),
            ),
            controller: TextEditingController(text: _formatDate(date)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 7)),
              );
              if (picked != null) onDateChanged(picked);
            },
          ),
          const SizedBox(height: 12),
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
          TextFormField(
            controller: pendingIssuesController,
            decoration: const InputDecoration(
              labelText: 'Pending issues (one per line)',
              hintText: 'Enter any unresolved items',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: equipmentNotesController,
            decoration: const InputDecoration(
              labelText: 'Equipment notes',
              hintText: 'Any equipment issues or concerns',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          SignaturePad(
            controller: outgoingSignature,
            label: 'Outgoing person signature',
            savedPath: outgoingSignaturePath,
            onSaved: onOutgoingSignatureSaved,
          ),
          const SizedBox(height: 16),
          SignaturePad(
            controller: incomingSignature,
            label: 'Incoming person signature',
            savedPath: incomingSignaturePath,
            onSaved: onIncomingSignatureSaved,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            InlineError(error!),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const Text('Saving…')
                      : const Text('Record handover'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
