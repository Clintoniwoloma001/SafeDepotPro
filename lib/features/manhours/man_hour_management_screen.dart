// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/man_hour_draft_cache.dart';
import '../../data/models/man_hour_models.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';
import 'man_hour_analytics_view.dart';
import 'man_hour_exporter.dart';

/// Monthly man-hour sheet capture, submission and export.
///
/// A sheet belongs to one depot and one calendar month. It is edited as a
/// grid that mirrors the corporate workbook — NAMES, NO. OF WORKER, NO. OF
/// DAYS, NO. OF HOURS, TOTAL — and it can be exported on its own or as part
/// of the cross-depot master workbook.
class ManHourManagementScreen extends ConsumerStatefulWidget {
  const ManHourManagementScreen({super.key});

  @override
  ConsumerState<ManHourManagementScreen> createState() =>
      _ManHourManagementScreenState();
}

class _ManHourManagementScreenState extends ConsumerState<ManHourManagementScreen> {
  static const _firstYear = 2023;

  String? _depotId;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  int _tab = 0;

  final List<_GridRow> _rows = <_GridRow>[];

  String _sheetId = '';
  bool _submitted = false;
  bool _offline = false;
  bool _saving = false;
  bool _hydrated = false;
  bool _busy = false;

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty) {
      // Best effort: the last keystroke is flushed to the server and to the
      // device copy so a closed app never loses a half-filled sheet.
      unawaited(_save());
    }
    super.dispose();
  }

  bool get _dirty => _rows.any(
        (r) => r.name.trim().isNotEmpty || r.workers > 0 || r.days > 0,
      );

  bool get _isAdmin {
    final role = ref.read(profileProvider).profile?.role;
    return role?.isAdmin ?? false;
  }

  int get _totalHours => _rows.fold(0, (a, r) => a + r.total);
  int get _totalWorkers => _rows.fold(0, (a, r) => a + r.workers);

  List<int> get _years => List<int>.generate(
        DateTime.now().year + 2 - _firstYear,
        (i) => _firstYear + i,
      );

  Future<void> _save() async {
    _debounce?.cancel();
    final depotId = _depotId;
    if (depotId == null) return;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final cacheRows = _rows
          .asMap()
          .entries
          .map((e) => e.value.toEntry(_sheetId, e.key).toJson())
          .toList();
      await ManHourDraftCache.write(
        depotId: depotId,
        year: _year,
        month: _month,
        rows: cacheRows,
        submitted: _submitted,
      );
      if (_sheetId.isNotEmpty) {
        final repo = ref.read(manHourSheetRepositoryProvider);
        await repo.saveEntries(
          _sheetId,
          _rows
              .asMap()
              .entries
              .map((e) => e.value.toEntry(_sheetId, e.key))
              .toList(),
        );
        if (mounted) {
          setState(() => _offline = false);
          ref.invalidate(manHourYearProvider(_year));
        }
      } else if (mounted) {
        setState(() => _offline = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _offline = true);
        _toast('Saved on this device — the server is unreachable.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), () {
      unawaited(_save());
    });
  }

  void _hydrate(ManHourSheetBundle bundle) {
    if (!mounted) return;
    setState(() {
      _sheetId = bundle.sheet.id;
      _submitted = bundle.isSubmitted;
      _offline = bundle.offline;
      _rows
        ..clear()
        ..addAll(bundle.entries.map(_GridRow.fromEntry));
      if (_rows.isEmpty) _rows.add(_GridRow());
      _hydrated = true;
    });
  }

  void _selectDepot(String? depotId) {
    if (depotId == null || depotId == _depotId) return;
    setState(() {
      _depotId = depotId;
      _rows.clear();
      _sheetId = '';
      _submitted = false;
      _hydrated = false;
    });
  }

  void _selectPeriod({int? year, int? month}) {
    setState(() {
      if (year != null) _year = year;
      if (month != null) _month = month;
      _rows.clear();
      _sheetId = '';
      _submitted = false;
      _hydrated = false;
    });
  }

  Future<void> _submit() async {
    if (_rows.every((r) => r.name.trim().isEmpty)) {
      _toast('Add at least one name before submitting.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit man-hour sheet'),
        content: const Text(
          'A submitted sheet is locked for editing. An administrator has to '
          'reopen it before anything can be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _save();
    if (_sheetId.isEmpty) {
      _toast('Offline: the sheet is queued on this device and will be sent '
          'when the connection returns.');
      setState(() => _submitted = true);
      return;
    }
    setState(() => _busy = true);
    try {
      final profile = ref.read(profileProvider).profile;
      await ref.read(manHourSheetRepositoryProvider).setStatus(
            sheetId: _sheetId,
            status: ManHourSheetStatus.submitted,
            userId: profile?.id ?? '',
          );
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _busy = false;
      });
      ref.invalidate(manHourYearProvider(_year));
      _toast('Sheet submitted and locked.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Could not submit: $e');
    }
  }

  Future<void> _reopen() async {
    if (_sheetId.isEmpty) return;
    setState(() => _busy = true);
    try {
      final profile = ref.read(profileProvider).profile;
      await ref.read(manHourSheetRepositoryProvider).setStatus(
            sheetId: _sheetId,
            status: ManHourSheetStatus.draft,
            userId: profile?.id ?? '',
          );
      if (!mounted) return;
      setState(() {
        _submitted = false;
        _busy = false;
      });
      ref.invalidate(manHourYearProvider(_year));
      _toast('Sheet reopened for editing.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Could not reopen: $e');
    }
  }

  Future<void> _exportDepot() async {
    final depot = _selectedDepot;
    if (depot == null) return;
    setState(() => _busy = true);
    try {
      final file = await ManHourExporter.writeDepotWorkbook(
        depotName: ManHourExporter.corporateLabelFor(depot.name),
        year: _year,
        month: _month,
        rows: _rows
            .where((r) => r.name.trim().isNotEmpty || r.total > 0)
            .map((r) => r.toEntry(_sheetId, 0))
            .toList(),
        submitted: _submitted,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _shareFile(file, 'Man-hour sheet exported.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Export failed: $e');
    }
  }

  Future<void> _exportMaster() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(manHourSheetRepositoryProvider);
      final names = ref.read(depotNameMapProvider);
      final sheets = await repo.listSheets(
        year: _year,
        month: _month,
        depotNames: names,
      );
      final entries = await repo.listEntriesForSheets(
        sheets.map((s) => s.id).where((id) => id.isNotEmpty).toList(),
      );
      final byDepot = <String, List<ManHourSheetEntry>>{};
      final submitted = <String>{};
      for (final sheet in sheets) {
        final label = ManHourExporter.corporateLabelFor(
          sheet.depotName.isEmpty
              ? (names[sheet.depotId] ?? sheet.depotId)
              : sheet.depotName,
        );
        byDepot[label] = entries[sheet.id] ?? const <ManHourSheetEntry>[];
        if (sheet.isSubmitted) submitted.add(label);
      }
      final file = await ManHourExporter.writeMasterWorkbook(
        year: _year,
        month: _month,
        sheets: byDepot,
        submittedDepots: submitted,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _shareFile(file, 'Master workbook exported.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Export failed: $e');
    }
  }

  Future<void> _shareFile(File file, String message) async {
    if (!mounted) return;
    _toast(message);
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: file.uri.pathSegments.last,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Depot? get _selectedDepot {
    final depots = ref.read(depotListProvider).value ?? const <Depot>[];
    for (final d in depots) {
      if (d.id == _depotId) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depots = ref.watch(depotListProvider).value ?? const <Depot>[];
    final profile = ref.watch(profileProvider).profile;

    // Default to the depot of the signed-in user, then to the first depot
    // the user is allowed to read.
    if (_depotId == null || !depots.any((d) => d.id == _depotId)) {
      final fallback = profile?.depotId ??
          (depots.isNotEmpty ? depots.first.id : null);
      if (fallback != null) {
        _depotId = fallback;
      }
    }

    final key = _depotId == null
        ? null
        : ManHourSheetKey(depotId: _depotId!, year: _year, month: _month);

    if (key != null) {
      ref.listen<AsyncValue<ManHourSheetBundle>>(
        manHourSheetProvider(key),
        (previous, next) {
          next.whenData((bundle) {
            if (!_hydrated) _hydrate(bundle);
          });
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Man-hour Management'),
        actions: [
          if (_tab == 0)
            IconButton(
              tooltip: 'Save now',
              onPressed: _busy ? null : () => _save(),
              icon: const Icon(Icons.save_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Data Entry')),
                ButtonSegment(value: 1, label: Text('Analytics')),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) {
                setState(() => _tab = selection.first);
              },
            ),
          ),
          if (_tab == 0) _filters(theme, depots),
          Expanded(
            child: _tab == 0
                ? _entryTab(theme, key)
                : ManHourAnalyticsView(year: _year, month: _month),
          ),
        ],
      ),
    );
  }

  Widget _filters(ThemeData theme, List<Depot> depots) {
    final depot = _selectedDepot;
    final status = _submitted
        ? 'SUBMITTED'
        : (_offline ? 'OFFLINE DRAFT' : 'DRAFT');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _label(
                  'DEPOT',
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _depotId,
                      isExpanded: true,
                      items: depots
                          .map(
                            (d) => DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(
                                ManHourExporter.corporateLabelFor(d.name),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _selectDepot,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _label(
                  'MONTH',
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _month,
                      isExpanded: true,
                      items: List<DropdownMenuItem<int>>.generate(
                        12,
                        (i) => DropdownMenuItem<int>(
                          value: i + 1,
                          child: Text(manHourMonthNames[i]),
                        ),
                      ),
                      onChanged: (v) => _selectPeriod(month: v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _label(
                  'YEAR',
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _year,
                      isExpanded: true,
                      items: _years
                          .map((y) => DropdownMenuItem<int>(
                                value: y,
                                child: Text('$y'),
                              ))
                          .toList(),
                      onChanged: (v) => _selectPeriod(year: v),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatusChip(
                label: status,
                color: _submitted
                    ? AppColors.statusClosed
                    : (_offline
                        ? AppColors.statusInProgress
                        : AppColors.statusVerification),
              ),
              const SizedBox(width: 8),
              if (_saving)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : _exportDepot,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export depot'),
              ),
              if (_isAdmin)
                TextButton.icon(
                  onPressed: _busy ? null : _exportMaster,
                  icon: const Icon(Icons.folder_zip_outlined, size: 18),
                  label: const Text('Master export'),
                ),
            ],
          ),
          if (depot != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${ManHourExporter.corporateLabelFor(depot.name)} — '
                '${manHourMonthNames[_month - 1]} $_year',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          child,
        ],
      );

  Widget _entryTab(ThemeData theme, ManHourSheetKey? key) {
    if (key == null) {
      return const EmptyView(
        title: 'No depot available',
        message: 'Your account is not linked to a depot yet.',
      );
    }
    final bundle = ref.watch(manHourSheetProvider(key));
    if (bundle.isLoading && !_hydrated) {
      return const LoadingView(message: 'Loading the man-hour sheet…');
    }
    if (bundle.hasError && !_hydrated) {
      return ErrorView(
        message: readableError(bundle.error!),
        onRetry: () => ref.invalidate(manHourSheetProvider(key)),
      );
    }

    final editable = !_submitted;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Man-hour grid',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (editable)
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _rows.add(_GridRow()));
                          _scheduleSave();
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add entry'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    columns: const [
                      DataColumn(label: Text('CATEGORY')),
                      DataColumn(label: Text('NAMES')),
                      DataColumn(label: Text('NO. OF WORKER')),
                      DataColumn(label: Text('NO. OF DAYS')),
                      DataColumn(label: Text('NO. OF HOURS')),
                      DataColumn(label: Text('TOTAL')),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (var i = 0; i < _rows.length; i++)
                        _row(theme, i, editable),
                      DataRow(
                        cells: [
                          const DataCell(SizedBox()),
                          const DataCell(
                            Text(
                              'TOTAL',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          DataCell(
                            Text(
                              '$_totalWorkers',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const DataCell(SizedBox()),
                          const DataCell(SizedBox()),
                          DataCell(
                            Text(
                              '$_totalHours',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const DataCell(SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'TOTAL = workers × days × hours. Changes are saved '
                  'automatically.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (editable)
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: const Text('Submit sheet'),
                      ),
                    if (!editable && _isAdmin)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _reopen,
                        icon: const Icon(Icons.lock_open_outlined, size: 18),
                        label: const Text('Reopen (admin)'),
                      ),
                    if (!editable && !_isAdmin)
                      const Expanded(
                        child: Text(
                          'This sheet is submitted and locked for editing.',
                        ),
                      ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _busy ? null : () => _save(),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sheet totals',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: KpiTile(
                        label: 'Man-hours',
                        value: '$_totalHours',
                        icon: Icons.schedule_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KpiTile(
                        label: 'Workers',
                        value: '$_totalWorkers',
                        icon: Icons.groups_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KpiTile(
                        label: 'Entries',
                        value: '${_rows.length}',
                        icon: Icons.list_alt_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _row(ThemeData theme, int index, bool editable) {
    final row = _rows[index];
    return DataRow(
      cells: [
        DataCell(
          PopupMenuButton<ManHourCategory>(
            enabled: editable,
            initialValue: row.category,
            onSelected: (value) {
              setState(() => row.category = value);
              _scheduleSave();
            },
            itemBuilder: (context) => ManHourCategory.values
                .map(
                  (c) => PopupMenuItem<ManHourCategory>(
                    value: c,
                    child: Text(c.label),
                  ),
                )
                .toList(),
            child: Chip(
              label: Text(row.category.label),
              labelStyle: const TextStyle(fontSize: 11),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 190,
            child: _TextCell(
              value: row.name,
              enabled: editable,
              hint: 'Name of worker / team',
              onChanged: (v) {
                row.name = v;
                _scheduleSave();
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 96,
            child: _NumberCell(
              value: row.workers,
              enabled: editable,
              onChanged: (v) {
                setState(() => row.workers = v);
                _scheduleSave();
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 96,
            child: _NumberCell(
              value: row.days,
              enabled: editable,
              onChanged: (v) {
                setState(() => row.days = v);
                _scheduleSave();
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 96,
            child: _NumberCell(
              value: row.hours,
              enabled: editable,
              onChanged: (v) {
                setState(() => row.hours = v);
                _scheduleSave();
              },
            ),
          ),
        ),
        DataCell(
          Text(
            '${row.total}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          editable
              ? IconButton(
                  tooltip: 'Remove entry',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() => _rows.removeAt(index));
                    _scheduleSave();
                  },
                )
              : const SizedBox(),
        ),
      ],
    );
  }
}

/// A working copy of one grid row.
class _GridRow {
  _GridRow({
    this.id = '',
    this.category = ManHourCategory.fte,
    this.name = '',
    this.workers = 0,
    this.days = 0,
    this.hours = 8,
  });

  final String id;
  ManHourCategory category;
  String name;
  int workers;
  int days;
  int hours;

  int get total => workers * days * hours;

  factory _GridRow.fromEntry(ManHourSheetEntry entry) => _GridRow(
        id: entry.id,
        category: entry.category,
        name: entry.entryName,
        workers: entry.workerCount,
        days: entry.daysWorked,
        hours: entry.hoursPerDay,
      );

  ManHourSheetEntry toEntry(String sheetId, int index) => ManHourSheetEntry(
        id: id,
        sheetId: sheetId,
        rowIndex: index,
        category: category,
        entryName: name.trim(),
        workerCount: workers,
        daysWorked: days,
        hoursPerDay: hours,
        totalHours: total,
      );
}

/// Editable text cell that keeps its own controller.
class _TextCell extends StatefulWidget {
  const _TextCell({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.hint,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  State<_TextCell> createState() => _TextCellState();
}

class _TextCellState extends State<_TextCell> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  bool _internal = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant _TextCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _internal = true;
      _controller.text = widget.value;
      _internal = false;
    }
  }

  void _handleChanged() {
    if (_internal) return;
    widget.onChanged(_controller.text);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        hintStyle: const TextStyle(fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(),
      ),
    );
  }
}

/// Editable integer cell that keeps its own controller.
class _NumberCell extends StatefulWidget {
  const _NumberCell({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberCell> createState() => _NumberCellState();
}

class _NumberCellState extends State<_NumberCell> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.value}');
  bool _internal = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant _NumberCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ('${widget.value}' != _controller.text) {
      _internal = true;
      _controller.text = '${widget.value}';
      _internal = false;
    }
  }

  void _handleChanged() {
    if (_internal) return;
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) return;
    if (parsed == widget.value) return;
    widget.onChanged(parsed);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(),
      ),
    );
  }
}
