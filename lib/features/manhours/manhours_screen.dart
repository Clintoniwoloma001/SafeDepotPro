// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../shared/ui_kit.dart';

class ManHoursScreen extends ConsumerStatefulWidget {
  const ManHoursScreen({super.key});

  @override
  ConsumerState<ManHoursScreen> createState() => _ManHoursScreenState();
}

class _ManHoursScreenState extends ConsumerState<ManHoursScreen> {
  final _hoursWorked = TextEditingController();
  final _overtimeHours = TextEditingController();
  final _headcount = TextEditingController();
  final _recordableIncidents = TextEditingController();
  final _lostTimeIncidents = TextEditingController();
  final _nearMisses = TextEditingController();
  DateTime _periodStart = DateTime.now();
  DateTime? _periodEnd;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _hoursWorked.dispose();
    _overtimeHours.dispose();
    _headcount.dispose();
    _recordableIncidents.dispose();
    _lostTimeIncidents.dispose();
    _nearMisses.dispose();
    super.dispose();
  }

  Future<void> _pickPeriodStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodStart,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _periodStart) {
      setState(() => _periodStart = picked);
    }
  }

  Future<void> _pickPeriodEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodEnd ?? _periodStart,
      firstDate: _periodStart,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _periodEnd = picked.isAfter(_periodStart)
          ? picked
          : _periodStart.add(const Duration(days: 1)));
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
      await ref.read(opsRepositoryProvider).createManHours(
            depotId: depotId,
            periodStart: _periodStart,
            periodEnd: _periodEnd,
            hoursWorked: double.tryParse(_hoursWorked.text) ?? 0,
            overtimeHours: double.tryParse(_overtimeHours.text) ?? 0,
            headcount: int.tryParse(_headcount.text) ?? 0,
            recordableIncidents:
                int.tryParse(_recordableIncidents.text) ?? 0,
            lostTimeIncidents: int.tryParse(_lostTimeIncidents.text) ?? 0,
            nearMisses: int.tryParse(_nearMisses.text) ?? 0,
          );

      ref.invalidate(manHoursProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Man-hours record saved.')),
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
    final records = ref.watch(manHoursProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Man-Hours'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _saving ? null : () => _showForm(),
            tooltip: 'Add record',
          ),
        ],
      ),
      body: profile == null
          ? const ErrorView(message: 'Not signed in.')
          : records.when(
              loading: () => const LoadingView(message: 'Loading…'),
              error: (e, _) => ErrorView(
                message: readableError(e),
                onRetry: () => ref.refresh(manHoursProvider.future),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyView(
                    title: 'No man-hours recorded',
                    message:
                        "Record your first man-hours entry by pressing the '+' button.",
                    actionLabel: 'Add record',
                    onAction: null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final m = list[i];
                    final totalHours = m.totalHours;
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
                                    _formatDate(m.periodStart),
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                if (m.periodEnd != null)
                                  Text(
                                    'to ${_formatDate(m.periodEnd!)}',
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 24,
                              runSpacing: 8,
                              children: [
                                _kv('Hours',
                                    m.hoursWorked.toStringAsFixed(1), ctx),
                                _kv('Overtime',
                                    m.overtimeHours.toStringAsFixed(1), ctx),
                                _kv('Total', totalHours.toStringAsFixed(1),
                                    ctx),
                                _kv('Headcount',
                                    m.headcount.toString(), ctx),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 24,
                              children: [
                                _kv('Recordable',
                                    m.recordableIncidents.toString(), ctx,
                                    color: Theme.of(ctx).colorScheme.error),
                                _kv('Lost time',
                                    m.lostTimeIncidents.toString(), ctx,
                                    color: Theme.of(ctx).colorScheme.error),
                                _kv('Near misses',
                                    m.nearMisses.toString(), ctx,
                                    color: Colors.orange),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: profile == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : () => _showForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add record'),
            ),
    );
  }

  Widget _kv(String label, String value, BuildContext ctx, {Color? color}) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(ctx)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(ctx).colorScheme.outline)),
          Text(value,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: color)),
        ],
      );

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  void _showForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add man-hours record',
                    style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Period start',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  controller: TextEditingController(
                      text: _ManHoursScreenState._formatDate(_periodStart)),
                  onTap: _pickPeriodStart,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Period end (optional)',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  controller: TextEditingController(
                      text: _periodEnd != null
                          ? _ManHoursScreenState._formatDate(_periodEnd!)
                          : ''),
                  onTap: _pickPeriodEnd,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hoursWorked,
                  decoration:
                      const InputDecoration(labelText: 'Hours worked'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _overtimeHours,
                  decoration:
                      const InputDecoration(labelText: 'Overtime hours'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _headcount,
                  decoration: const InputDecoration(labelText: 'Headcount'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recordableIncidents,
                  decoration: const InputDecoration(
                      labelText: 'Recordable incidents'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lostTimeIncidents,
                  decoration: const InputDecoration(
                      labelText: 'Lost-time incidents'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nearMisses,
                  decoration: const InputDecoration(labelText: 'Near misses'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  InlineError(_error!),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const Text('Saving…')
                            : const Text('Save record'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
