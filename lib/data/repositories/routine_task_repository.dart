// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';
import '../models/ops_models.dart';

/// Reads routine tasks.
///
/// The record set returned is decided by RLS on `routine_tasks_read`: a USER
/// sees tasks assigned to all depots, to their own depot, or to them by name
/// in the Base44 import. No depot filter is applied here, because the database
/// already enforces isolation.
class RoutineTaskRepository {
  RoutineTaskRepository(this._client);

  final SupabaseClient _client;

  static const table = 'routine_tasks';

  Future<List<RoutineTask>> listTasks({bool activeOnly = true}) async {
    var query = _client.from(table).select();
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final rows = await query
        .order(
          isOrderableColumn(table: table, column: 'sequence_order'),
          ascending: true,
        )
        .order('title', ascending: true);
    return rows.map<RoutineTask>(RoutineTask.fromJson).toList(growable: false);
  }

  /// Tasks due today for a given date, honouring the recurrence rules.
  ///
  /// Daily, weekly and monthly tasks are shown as due today. Quarterly,
  /// biannual and annual tasks are due only on their anniversary, which the
  /// server's `expected_occurrences` bookkeeping tracks.
  Future<List<RoutineTask>> dueToday(DateTime day) async {
    final all = await listTasks();
    return all.where((t) => _matchesDate(t, day)).toList(growable: false);
  }

  static bool _matchesDate(RoutineTask t, DateTime day) {
    switch (t.frequency) {
      case Frequency.daily:
        return true;
      case Frequency.weekly:
        return true;
      case Frequency.monthly:
        return true;
      case Frequency.quarterly:
      case Frequency.biannual:
      case Frequency.annual:
        return false;
    }
  }
}

/// Reads trucks.
class TruckRepository {
  TruckRepository(this._client);

  final SupabaseClient _client;

  static const table = 'trucks';

  Future<List<Truck>> listTrucks({String? depotId, int limit = 500}) async {
    var query = _client.from(table).select();
    if (depotId != null) {
      query = query.eq('depot_id', depotId);
    }
    final rows = await query.order('reg_no', ascending: true).limit(limit);
    return rows.map<Truck>(Truck.fromJson).toList(growable: false);
  }

  Future<int> countForDepot(String depotId) async {
    final rows = await _client.from(table).select('id').eq('depot_id', depotId);
    return rows.length;
  }
}

/// Small helper so `order` can take a computed column name.
String isOrderableColumn({required String table, required String column}) =>
    column;

/// Reads and writes shift handovers, man-hours records, and truck inspections.
class OpsRepository {
  OpsRepository(this._client);

  final SupabaseClient _client;

  // -- Shift handovers ------------------------------------------------

  Future<List<ShiftHandover>> listShiftHandovers({
    String? depotId,
    int limit = 100,
  }) async {
    var query = _client.from('shift_handovers').select();
    if (depotId != null) query = query.eq('depot_id', depotId);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map<ShiftHandover>(ShiftHandover.fromJson).toList(growable: false);
  }

  Future<ShiftHandover> createShiftHandover({
    required String depotId,
    required String shift,
    required String date,
    String? outgoingUserId,
    String? incomingUserId,
    String? summary,
    List<String> pendingIssues = const [],
    String? equipmentNotes,
    String? signatureOutgoing,
    String? signatureIncoming,
  }) async {
    final row = await _client
        .from('shift_handovers')
        .insert({
          'depot_id': depotId,
          'shift': shift,
          'date': date,
          'outgoing_user_id': outgoingUserId,
          'incoming_user_id': incomingUserId,
          'summary': summary,
          'pending_issues': pendingIssues,
          'equipment_notes': equipmentNotes,
          'signature_outgoing': signatureOutgoing,
          'signature_incoming': signatureIncoming,
        })
        .select()
        .single();
    return ShiftHandover.fromJson(row);
  }

  Future<void> updateShiftHandover({
    required String id,
    String? summary,
    List<String>? pendingIssues,
    String? equipmentNotes,
    String? signatureOutgoing,
    String? signatureIncoming,
  }) async {
    final updates = <String, dynamic>{};
    if (summary != null) updates['summary'] = summary;
    if (pendingIssues != null) updates['pending_issues'] = pendingIssues;
    if (equipmentNotes != null) updates['equipment_notes'] = equipmentNotes;
    if (signatureOutgoing != null) {
      updates['signature_outgoing'] = signatureOutgoing;
    }
    if (signatureIncoming != null) {
      updates['signature_incoming'] = signatureIncoming;
    }
    if (updates.isNotEmpty) {
      updates['status'] = ShiftStatus.confirmed.wire;
      updates['confirmed_at'] = DateTime.now().toUtc().toIso8601String();
      await _client.from('shift_handovers').update(updates).eq('id', id);
    }
  }

  // -- Man hours -------------------------------------------------------

  Future<List<ManHours>> listManHours({
    String? depotId,
    int limit = 100,
  }) async {
    var query = _client.from('man_hours').select();
    if (depotId != null) query = query.eq('depot_id', depotId);
    final rows = await query.order('period_start', ascending: false).limit(limit);
    return rows.map<ManHours>(ManHours.fromJson).toList(growable: false);
  }

  Future<ManHours> createManHours({
    required String depotId,
    required DateTime periodStart,
    DateTime? periodEnd,
    double hoursWorked = 0,
    double overtimeHours = 0,
    int headcount = 0,
    int recordableIncidents = 0,
    int lostTimeIncidents = 0,
    int nearMisses = 0,
  }) async {
    final row = await _client
        .from('man_hours')
        .insert({
          'depot_id': depotId,
          'period_start': periodStart.toIso8601String(),
          'period_end': periodEnd?.toIso8601String(),
          'hours_worked': hoursWorked,
          'overtime_hours': overtimeHours,
          'headcount': headcount,
          'recordable_incidents': recordableIncidents,
          'lost_time_incidents': lostTimeIncidents,
          'near_misses': nearMisses,
        })
        .select()
        .single();
    return ManHours.fromJson(row);
  }

  // -- Truck inspections -----------------------------------------------

  Future<List<TruckInspection>> listTruckInspections({
    String? depotId,
    int limit = 100,
  }) async {
    var query = _client.from('truck_inspections').select();
    if (depotId != null) query = query.eq('depot_id', depotId);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows
        .map<TruckInspection>(TruckInspection.fromJson)
        .toList(growable: false);
  }

  Future<TruckInspection> recordTruckInspection({
    required String truckId,
    required String depotId,
    required String inspectedBy,
    required TruckResult result,
    String? notes,
    List<String> photoPaths = const [],
    double? latitude,
    double? longitude,
    String? signaturePath,
  }) async {
    final row = await _client
        .from('truck_inspections')
        .insert({
          'truck_id': truckId,
          'depot_id': depotId,
          'inspected_by': inspectedBy,
          'result': result.wire,
          'notes': notes,
          'photo_paths': photoPaths,
          'latitude': latitude,
          'longitude': longitude,
          'signature_path': signaturePath,
        })
        .select()
        .single();
    return TruckInspection.fromJson(row);
  }
}
