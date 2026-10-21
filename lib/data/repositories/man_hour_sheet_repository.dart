// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/man_hour_models.dart';

/// Read/write access to the monthly man-hour sheets.
///
/// Two tables back the module: `man_hour_sheets` (one header per depot and
/// month, carrying the draft/submitted lock) and
/// `man_hour_sheet_entries` (the grid rows). Row level security in the
/// database decides what a caller may see: a depot user sees their own depot,
/// administrators see every depot.
class ManHourSheetRepository {
  ManHourSheetRepository(this._client);

  final SupabaseClient _client;

  static const sheetsTable = 'man_hour_sheets';
  static const entriesTable = 'man_hour_sheet_entries';

  /// Lists sheet headers, optionally narrowed to a depot or a period.
  ///
  /// [depotNames] maps depot id to display name so the caller can label a
  /// sheet without a second round trip; entries missing from the map are
  /// returned with an empty name.
  Future<List<ManHourSheet>> listSheets({
    String? depotId,
    int? year,
    int? month,
    Map<String, String> depotNames = const {},
  }) async {
    var query = _client.from(sheetsTable).select();
    if (depotId != null) query = query.eq('depot_id', depotId);
    if (year != null) query = query.eq('period_year', year);
    if (month != null) query = query.eq('period_month', month);
    final rows = await query.order('depot_id').order('period_year');
    return rows
        .map<ManHourSheet>((j) => ManHourSheet.fromJson(j))
        .map((s) => s.copyWith(depotName: depotNames[s.depotId] ?? ''))
        .toList(growable: false);
  }

  /// Returns the sheet for a depot and period, creating it when missing.
  ///
  /// A sheet row is the lock holder, so it has to exist before entries can be
  /// attached. Creation is idempotent: a concurrent create resolves to the
  /// existing row through the unique constraint.
  Future<ManHourSheet> ensureSheet({
    required String depotId,
    required int year,
    required int month,
    required String userId,
    String depotName = '',
  }) async {
    final existing = await _client
        .from(sheetsTable)
        .select()
        .eq('depot_id', depotId)
        .eq('period_year', year)
        .eq('period_month', month)
        .maybeSingle();
    if (existing != null) {
      return ManHourSheet.fromJson(existing)
          .copyWith(depotName: depotName);
    }
    final inserted = await _client
        .from(sheetsTable)
        .insert({
          'depot_id': depotId,
          'period_year': year,
          'period_month': month,
          'status': ManHourSheetStatus.draft.wire,
          'updated_by': userId,
        })
        .select()
        .single();
    return ManHourSheet.fromJson(inserted).copyWith(depotName: depotName);
  }

  /// Grid rows of a sheet, in display order.
  Future<List<ManHourSheetEntry>> listEntries(String sheetId) async {
    if (sheetId.isEmpty) return const [];
    final rows = await _client
        .from(entriesTable)
        .select()
        .eq('sheet_id', sheetId)
        .order('row_index');
    return rows.map<ManHourSheetEntry>(ManHourSheetEntry.fromJson).toList();
  }

  /// Grid rows for many sheets at once, keyed by sheet id.
  Future<Map<String, List<ManHourSheetEntry>>> listEntriesForSheets(
    List<String> sheetIds,
  ) async {
    if (sheetIds.isEmpty) return const {};
    final rows = await _client
        .from(entriesTable)
        .select()
        .inFilter('sheet_id', sheetIds)
        .order('row_index');
    final map = <String, List<ManHourSheetEntry>>{};
    for (final row in rows) {
      final entry = ManHourSheetEntry.fromJson(row);
      map.putIfAbsent(entry.sheetId, () => []).add(entry);
    }
    return map;
  }

  /// Replaces the grid rows of a sheet with [rows].
  ///
  /// The write is a delete-then-insert so the grid on the device and the grid
  /// in the database cannot drift; the unique (sheet_id, row_index) constraint
  /// keeps the ordering stable.
  Future<void> saveEntries(
    String sheetId,
    List<ManHourSheetEntry> rows,
  ) async {
    await _client.from(entriesTable).delete().eq('sheet_id', sheetId);
    if (rows.isEmpty) return;
    await _client
        .from(entriesTable)
        .insert(rows.map((r) => r.toInsert(sheetId)).toList());
  }

  /// Moves a sheet between the draft and submitted states.
  ///
  /// A submitted sheet is read-only in the app; reopening it is an
  /// administrator action and is refused by the database for everyone else.
  Future<void> setStatus({
    required String sheetId,
    required ManHourSheetStatus status,
    required String userId,
  }) async {
    final patch = <String, dynamic>{
      'status': status.wire,
      'updated_by': userId,
    };
    if (status == ManHourSheetStatus.submitted) {
      patch['submitted_at'] = DateTime.now().toUtc().toIso8601String();
      patch['submitted_by'] = userId;
    } else {
      patch['submitted_at'] = null;
    }
    await _client.from(sheetsTable).update(patch).eq('id', sheetId);
  }
}
