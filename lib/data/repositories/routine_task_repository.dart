// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/foundation.dart';
// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';
import '../models/models.dart';
import '../models/ops_models.dart';

/// Reads routine tasks.
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

  Future<String?> latestCompletionPhoto(String taskId) async {
    final rows = await _client
        .from('task_history')
        .select('photo_paths')
        .eq('task_id', taskId)
        .order('completed_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final paths = rows.first['photo_paths'];
    if (paths is List && paths.isNotEmpty) return paths.first?.toString();
    return null;
  }

  /// Tasks due today for a given date, honouring recurrence + completion period.
  Future<List<RoutineTask>> dueToday(DateTime day) async {
    final all = await listTasks();
    // Fetch recent completions to know which tasks are already done this period.
    final cutoff = day.subtract(const Duration(days: 400));
    final rows = await _client
        .from('task_history')
        .select('task_id, completed_at')
        .gte('completed_at', cutoff.toUtc().toIso8601String());
    final completionsByTask = <String, List<DateTime>>{};
    for (final r in rows) {
      final id = r['task_id']?.toString();
      final dt = DateTime.tryParse(r['completed_at']?.toString() ?? '');
      if (id == null || dt == null) continue;
      completionsByTask.putIfAbsent(id, () => []).add(dt.toUtc());
    }
    return all.where((t) {
      if (!t.isActive) return false;
      if (!_matchesDate(t, day)) return false;
      final comps = completionsByTask[t.id] ?? const [];
      return !comps.any((c) => _samePeriod(t.frequency, c, day.toUtc()));
    }).toList(growable: false);
  }

  /// Record a routine task completion in `task_history` (the routine_tasks
  /// table has no status/completed_at columns). A task resurfaces based on its
  /// frequency; completion is tracked per period.
  Future<void> updateTaskStatus({
    required String taskId,
    required TaskStatus status,
    String? photoPath,
    String? userId,
    String? depotId,
  }) async {
    if (status != TaskStatus.completed) return;
    await _client.from('task_history').insert({
      'task_id': taskId,
      'user_id': userId ?? _client.auth.currentUser?.id,
      'depot_id': depotId,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
      'photo_paths': photoPath == null ? <String>[] : <String>[photoPath],
    });
  }

  /// Tasks completed within the current period of [day] for the given frequency.
  Future<List<RoutineTask>> completedTasks(DateTime day) async {
    final all = await listTasks();
    final cutoff = day.subtract(const Duration(days: 400));
    final rows = await _client
        .from('task_history')
        .select('task_id, completed_at')
        .gte('completed_at', cutoff.toUtc().toIso8601String());
    final completionsByTask = <String, List<DateTime>>{};
    for (final r in rows) {
      final id = r['task_id']?.toString();
      final dt = DateTime.tryParse(r['completed_at']?.toString() ?? '');
      if (id == null || dt == null) continue;
      completionsByTask.putIfAbsent(id, () => []).add(dt.toUtc());
    }
    return all.where((t) {
      final comps = completionsByTask[t.id] ?? const [];
      return comps.any((c) => _samePeriod(t.frequency, c, day.toUtc()));
    }).toList(growable: false);
  }

  /// Completion records (task + completed_at + completer) for a calendar day.
  Future<List<TaskCompletionRecord>> completedTaskRecords(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day).toUtc();
    final end = start.add(const Duration(days: 1));
    final rows = await _client
        .from('task_history')
        .select('task_id, completed_at, actor_name, user_id, photo_paths')
        .gte('completed_at', start.toIso8601String())
        .lt('completed_at', end.toIso8601String())
        .order('completed_at', ascending: false);
    final all = await listTasks();
    final byId = <String, RoutineTask>{for (final t in all) t.id: t};
    final records = <TaskCompletionRecord>[];
    for (final r in rows) {
      final tid = r['task_id']?.toString();
      final task = (tid == null) ? null : byId[tid];
      if (task == null) continue;
      final completedAt = DateTime.tryParse(r['completed_at']?.toString() ?? '');
      if (completedAt == null) continue;
      final completer = (r['actor_name']?.toString().trim().isNotEmpty ?? false)
          ? r['actor_name'].toString().trim()
          : 'Unknown';
      final paths = (r['photo_paths'] is List)
          ? (r['photo_paths'] as List).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
          : const <String>[];
      records.add(TaskCompletionRecord(
        task: task,
        completedAt: completedAt.toLocal(),
        completer: completer,
        photoPath: paths.isEmpty ? null : paths.first,
      ));
    }
    return records;
  }

  static bool _matchesDate(RoutineTask t, DateTime day) {
    // A task is "due" every day within its active period until completed.
    switch (t.frequency) {
      case Frequency.daily:
      case Frequency.weekly:
      case Frequency.monthly:
      case Frequency.quarterly:
      case Frequency.biannual:
      case Frequency.annual:
        return true;
    }
  }

  static bool _samePeriod(Frequency freq, DateTime completedAt, DateTime day) {
    final c = completedAt.toUtc();
    final d = day.toUtc();
    switch (freq) {
      case Frequency.daily:
        return c.year == d.year && c.month == d.month && c.day == d.day;
      case Frequency.weekly:
        return _isoWeek(c) == _isoWeek(d) && c.year == d.year;
      case Frequency.monthly:
        return c.year == d.year && c.month == d.month;
      case Frequency.quarterly:
        return c.year == d.year && (c.month - 1) ~/ 3 == (d.month - 1) ~/ 3;
      case Frequency.biannual:
        return c.year == d.year && (c.month - 1) ~/ 6 == (d.month - 1) ~/ 6;
      case Frequency.annual:
        return c.year == d.year;
    }
  }

  /// Compliance counts for a single calendar day (Africa/Lagos).
  /// Raw task_history rows for a calendar day (UTC boundaries).
  Future<List<Map<String, dynamic>>> taskHistoryForDay(DateTime day) async {
    final startLocal = DateTime(day.year, day.month, day.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    final rows = await _client
        .from('task_history')
        .select('task_id, completed_at, user_id, depot_id, actor_name, photo_paths')
        .gte('completed_at', startLocal.toUtc().toIso8601String())
        .lt('completed_at', endLocal.toUtc().toIso8601String());
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<({int due, int done})> complianceForDay(DateTime day) async {
    final all = await listTasks();
    final daily = all.where((t) => t.isActive && t.frequency == Frequency.daily).toList();
    // Boundaries use the device's local calendar day so the count resets at
    // midnight (00:00 local time) for the current day.
    final startLocal = DateTime(day.year, day.month, day.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();
    final rows = await _client
        .from('task_history')
        .select('task_id')
        .gte('completed_at', startUtc.toIso8601String())
        .lt('completed_at', endUtc.toIso8601String());
    final completedIds = <String>{};
    for (final r in rows) {
      final id = r['task_id']?.toString();
      if (id != null) completedIds.add(id);
    }
    final done = daily.where((t) => completedIds.contains(t.id)).length;
    return (due: daily.length, done: done);
  }

  static int _isoWeek(DateTime d) {
    // Use Monday-based week number.
    final monday = d.subtract(Duration(days: d.weekday - 1));
    // Week of year by days since first Monday? Simpler: use ordinal.
    return monday.difference(DateTime(monday.year, 1, 1)).inDays ~/ 7;
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

  Future<Truck> createTruck({
    required String regNo,
    String? depotId,
    required String makeModel,
    String? driverName,
    String? driverPhone,
    String? company,
    int? year,
    String? color,
    String status = 'OPERATIONAL',
  }) async {
    final row = await _client
        .from(table)
        .insert({
          'reg_no': regNo,
          'depot_id': depotId,
          'make_model': makeModel,
          'driver_name': driverName,
          'driver_phone': driverPhone,
          'company': company,
          'year': year,
          'color': color,
          'status': status,
        })
        .select()
        .single();
    return Truck.fromJson(row);
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
    List<String> photoPaths = const [],
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
          'photo_paths': photoPaths,
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
    List<String>? photoPaths,
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
    if (photoPaths != null) {
      updates['photo_paths'] = photoPaths;
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
    String? inspectedBy,
    int limit = 500,
  }) async {
    var query = _client.from('truck_inspections').select();
    if (depotId != null) query = query.eq('depot_id', depotId);
    if (inspectedBy != null) query = query.eq('inspected_by', inspectedBy);
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
    String? templateId,
    int? templateVersion,
    List<TruckInspectionItemResponse> itemResponses = const [],
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
          'template_id': templateId,
          'template_version': templateVersion,
          'item_responses': itemResponses.map((e) => e.toJson()).toList(),
        })
        .select()
        .single();
    return TruckInspection.fromJson(row);
  }

  // -- Truck inspection templates ----------------------------------------

  Future<List<TruckInspectionTemplate>> listTruckInspectionTemplates({
    String? depotId,
    TruckTemplateType? type,
    bool activeOnly = true,
  }) async {
    var query = _client.from('truck_inspection_templates').select();
    if (depotId != null) query = query.eq('depot_id', depotId);
    if (activeOnly) query = query.eq('is_active', true);
    debugPrint('LIST TEMPLATES QUERY');
    final rows = await query.order('version', ascending: false).order('name', ascending: true);
    debugPrint('LIST TEMPLATES ROWS: ${rows.length}');
    return rows.map<TruckInspectionTemplate>(TruckInspectionTemplate.fromJson).toList(growable: false);
  }

  Future<TruckInspectionTemplate> createTruckInspectionTemplate({
    required String name,
    required TruckTemplateType type,
    String? description,
    String? depotId,
    String? createdBy,
  }) async {
    final row = await _client
        .from('truck_inspection_templates')
        .insert({
          'name': name,
          'description': description,
          'depot_id': depotId,
          'created_by': createdBy,
        })
        .select()
        .single();
    return TruckInspectionTemplate.fromJson(row);
  }

  Future<List<TruckInspectionTemplateItem>> listTruckInspectionTemplateItems({
    required String templateId,
    bool activeOnly = true,
  }) async {
    var query = _client.from('truck_inspection_template_items').select();
    query = query.eq('template_id', templateId);
    if (activeOnly) query = query.eq('is_deleted', false);
    final rows = await query.order('sort_order', ascending: true).order('section', ascending: true);
    return rows.map<TruckInspectionTemplateItem>(TruckInspectionTemplateItem.fromJson).toList(growable: false);
  }

  /// List inspection types derived from truck inspection templates.
  Future<List<InspectionType>> listInspectionTypes({bool activeOnly = true}) async {
    var query = _client.from('truck_inspection_templates').select('id,inspection_code,inspection_name,pass_score,is_active');
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('inspection_name', ascending: true);
    final list = <InspectionType>[];
    for (final r in rows) {
      list.add(InspectionType(
        inspectionTypeId: (r['id'] ?? '').toString(),
        inspectionCode: r['inspection_code']?.toString(),
        inspectionName: (r['inspection_name'] ?? r['name'] ?? '').toString(),
        passScore: (r['pass_score'] is int) ? r['pass_score'] as int : int.tryParse(r['pass_score']?.toString() ?? ''),
        isActive: r['is_active'] != false,
      ));
    }
    list.sort((a, b) => a.inspectionName.compareTo(b.inspectionName));
    return list;
  }

  /// List truck inspection template items filtered by section name.
  Future<List<TruckInspectionTemplateItem>> listTemplateItemsBySection({
    required String section,
    bool activeOnly = true,
  }) async {
    var query = _client.from('truck_inspection_template_items').select();
    query = query.eq('section', section);
    if (activeOnly) query = query.eq('is_deleted', false);
    final rows = await query.order('sort_order', ascending: true);
    return rows.map<TruckInspectionTemplateItem>(TruckInspectionTemplateItem.fromJson).toList(growable: false);
  }

  Future<TruckInspectionTemplateItem> createTruckInspectionTemplateItem({
    required String templateId,
    required String section,
    required String itemText,
    TruckItemResponseType responseType = TruckItemResponseType.passFail,
    double weight = 1.0,
    bool isCritical = false,
    bool requiresPhoto = false,
    double? minValue,
    double? maxValue,
    String? unit,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('truck_inspection_template_items')
        .insert({
          'template_id': templateId,
          'section': section,
          'question_text': itemText,
          'response_type': responseType.wire,
          'weight': weight,
          'is_critical': isCritical,
          'requires_photo': requiresPhoto,
          'min_value': minValue,
          'max_value': maxValue,
          'unit': unit,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return TruckInspectionTemplateItem.fromJson(row);
  }

  // -- Task reminders ----------------------------------------------------

  Future<List<TaskReminder>> listTaskReminders({
    String? taskId,
    ReminderStatus? status,
    String? userId,
    int limit = 100,
  }) async {
    var query = _client.from('task_reminders').select();
    if (taskId != null) query = query.eq('task_id', taskId);
    if (status != null) query = query.eq('status', status.wire);
    if (userId != null) query = query.eq('recipient_user_id', userId);
    final rows = await query.order('scheduled_at', ascending: true).limit(limit);
    return rows.map<TaskReminder>(TaskReminder.fromJson).toList(growable: false);
  }

  Future<TaskReminder> createTaskReminder({
    required String taskId,
    required DateTime scheduledAt,
    ReminderChannel channel = ReminderChannel.push,
    String? recipientUserId,
  }) async {
    final row = await _client
        .from('task_reminders')
        .insert({
          'task_id': taskId,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'channel': channel.wire,
          'recipient_user_id': recipientUserId,
        })
        .select()
        .single();
    return TaskReminder.fromJson(row);
  }

  Future<void> updateTaskReminderStatus({
    required String id,
    required ReminderStatus status,
    String? errorMessage,
  }) async {
    final updates = <String, dynamic>{
      'status': status.wire,
      if (status == ReminderStatus.sent) 'sent_at': DateTime.now().toUtc().toIso8601String(),
      'error_message': ?errorMessage,
    };
    await _client.from('task_reminders').update(updates).eq('id', id);
  }

  Future<void> deleteTaskReminder(String id) async {
    await _client.from('task_reminders').delete().eq('id', id);
  }

  // -- Toolbox talks -------------------------------------------------------

  Future<List<ToolboxTalk>> listToolboxTalks({
    String? depotId,
    int limit = 100,
  }) async {
    var query = _client.from('toolbox_talks').select();
    if (depotId != null) query = query.eq('depot_id', depotId);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map<ToolboxTalk>(ToolboxTalk.fromJson).toList(growable: false);
  }

  Future<ToolboxTalk> createToolboxTalk({
    required String depotId,
    required String title,
    required String date,
    required String time,
    String? description,
    String? company,
    String? location,
    String? facilitator,
    String? category,
    bool isHighRisk = false,
    String? tag,
    List<String> photoPaths = const [],
    double? latitude,
    double? longitude,
    String? createdBy,
  }) async {
    final row = await _client
        .from('toolbox_talks')
        .insert({
          'depot_id': depotId,
          'title': title,
          'description': description,
          'company': company ?? 'SafeDepot Services',
          'location': location,
          'date': date,
          'time': time,
          'facilitator': facilitator,
          'category': category,
          'is_high_risk': isHighRisk,
          'tag': tag,
          'photo_paths': photoPaths,
          'latitude': latitude,
          'longitude': longitude,
          'created_by': createdBy,
        })
        .select()
        .single();
    return ToolboxTalk.fromJson(row);
  }

  Future<void> updateToolboxTalk({
    required String id,
    String? title,
    String? description,
    String? date,
    String? time,
    String? location,
    String? facilitator,
    String? category,
    bool? isHighRisk,
    String? tag,
    List<String>? photoPaths,
    double? latitude,
    double? longitude,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (date != null) updates['date'] = date;
    if (time != null) updates['time'] = time;
    if (location != null) updates['location'] = location;
    if (facilitator != null) updates['facilitator'] = facilitator;
    if (category != null) updates['category'] = category;
    if (isHighRisk != null) updates['is_high_risk'] = isHighRisk;
    if (tag != null) updates['tag'] = tag;
    if (photoPaths != null) updates['photo_paths'] = photoPaths;
    if (latitude != null) updates['latitude'] = latitude;
    if (longitude != null) updates['longitude'] = longitude;
    if (updates.isNotEmpty) {
      await _client.from('toolbox_talks').update(updates).eq('id', id);
    }
  }

  // -- Toolbox topics (shared weekly) ------------------------------------

  Future<List<ToolboxTopic>> listToolboxTopics({
    bool activeOnly = true,
    int? weekOfYear,
    int limit = 100,
  }) async {
    var query = _client.from('toolbox_topics').select();
    if (activeOnly) query = query.eq('is_active', true);
    if (weekOfYear != null) query = query.eq('week_of_year', weekOfYear);
    final rows = await query.order('week_of_year', ascending: true).order('title', ascending: true).limit(limit);
    return rows.map<ToolboxTopic>(ToolboxTopic.fromJson).toList(growable: false);
  }

  Future<ToolboxTopic> createToolboxTopic({
    required String title,
    required String content,
    String? category,
    bool isHighRisk = false,
    int? weekOfYear,
    bool isFactory = false,
    String? createdBy,
  }) async {
    final row = await _client
        .from('toolbox_topics')
        .insert({
          'title': title,
          'content': content,
          'category': category,
          'is_high_risk': isHighRisk,
          'week_of_year': weekOfYear,
          'is_factory': isFactory,
          'created_by': createdBy,
        })
        .select()
        .single();
    return ToolboxTopic.fromJson(row);
  }

  Future<void> updateToolboxTopic({
    required String id,
    String? title,
    String? content,
    String? category,
    bool? isHighRisk,
    int? weekOfYear,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (category != null) updates['category'] = category;
    if (isHighRisk != null) updates['is_high_risk'] = isHighRisk;
    if (weekOfYear != null) updates['week_of_year'] = weekOfYear;
    if (isActive != null) updates['is_active'] = isActive;
    if (updates.isNotEmpty) {
      await _client.from('toolbox_topics').update(updates).eq('id', id);
    }
  }

  // -- Toolbox attendees -------------------------------------------------

  Future<List<ToolboxAttendee>> listAttendees(String toolboxTalkId) async {
    final rows = await _client
        .from('toolbox_attendees')
        .select()
        .eq('toolbox_talk_id', toolboxTalkId)
        .order('name', ascending: true);
    return rows.map<ToolboxAttendee>(ToolboxAttendee.fromJson).toList(growable: false);
  }

  Future<ToolboxAttendee> addAttendee({
    required String toolboxTalkId,
    required String name,
    String? employeeNumber,
    String? signaturePath,
  }) async {
    final row = await _client
        .from('toolbox_attendees')
        .insert({
          'toolbox_talk_id': toolboxTalkId,
          'name': name,
          'employee_number': employeeNumber,
          'signature_path': signaturePath,
        })
        .select()
        .single();
    return ToolboxAttendee.fromJson(row);
  }

  Future<void> updateAttendeeSignature({
    required String id,
    required String signaturePath,
  }) async {
    await _client
        .from('toolbox_attendees')
        .update({
          'signature_path': signaturePath,
          'signed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> updateAttendee({
    required String id,
    String? name,
    String? employeeNumber,
    String? signaturePath,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (employeeNumber != null) updates['employee_number'] = employeeNumber;
    if (signaturePath != null) {
      updates['signature_path'] = signaturePath;
      updates['signed_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (updates.isNotEmpty) {
      await _client.from('toolbox_attendees').update(updates).eq('id', id);
    }
  }

  // -- Toolbox talk images -----------------------------------------------

  Future<List<ToolboxTalkImage>> listToolboxTalkImages(String toolboxTalkId) async {
    final rows = await _client
        .from('toolbox_talk_images')
        .select()
        .eq('toolbox_talk_id', toolboxTalkId)
        .order('sort_order', ascending: true);
    return rows.map<ToolboxTalkImage>(ToolboxTalkImage.fromJson).toList(growable: false);
  }

  Future<ToolboxTalkImage> addToolboxTalkImage({
    required String toolboxTalkId,
    required String storagePath,
    String? caption,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('toolbox_talk_images')
        .insert({
          'toolbox_talk_id': toolboxTalkId,
          'storage_path': storagePath,
          'caption': caption,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return ToolboxTalkImage.fromJson(row);
  }

  Future<void> deleteToolboxTalkImage(String id) async {
    await _client.from('toolbox_talk_images').delete().eq('id', id);
  }

  // -- Users for shift handover incoming selection -----------------------

  Future<List<Profile>> listUsersByDepot(String depotId) async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('depot_id', depotId)
        .eq('is_active', true)
        .order('full_name');
    return rows.map<Profile>(Profile.fromJson).toList(growable: false);
  }
}

/// A completed routine task with its completion metadata.
class TaskCompletionRecord {
  const TaskCompletionRecord({
    required this.task,
    required this.completedAt,
    required this.completer,
    this.photoPath,
  });

  final RoutineTask task;
  final DateTime completedAt;
  final String completer;
  final String? photoPath;
}
