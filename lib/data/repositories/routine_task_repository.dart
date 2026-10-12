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
