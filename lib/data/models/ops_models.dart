// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

/// Field names match the PostgreSQL columns exactly. Note the distinction
/// between a mapped column and `sourceMeta`: where the import could not map a
/// Base44 field onto a column, the original is preserved verbatim in
/// `source_meta` rather than discarded.
library;

import 'models.dart';
import 'enums.dart';

/// Operational records imported from the Base44 export.
///

/// A row from `routine_tasks`.
class RoutineTask {
  const RoutineTask({
    required this.id,
    required this.title,
    this.description,
    this.taskType = CompletionMethod.manual,
    this.category,
    this.allDepots = false,
    this.assignedDepotIds = const [],
    this.frequency = Frequency.daily,
    this.linkedModule,
    this.requiresPhotoOnCompletion = false,
    this.isActive = true,
    this.priority,
    this.responsiblePerson,
    this.kpi,
    this.sourceMeta = const {},
  });

  final String id;
  final String title;
  final String? description;
  final CompletionMethod taskType;
  final String? category;
  final bool allDepots;
  final List<String> assignedDepotIds;
  final Frequency frequency;
  final String? linkedModule;
  final bool requiresPhotoOnCompletion;
  final bool isActive;

  /// Unmapped Base44 fields, surfaced so a review can still see them.
  final String? priority;
  final String? responsiblePerson;
  final String? kpi;
  final Map<String, dynamic> sourceMeta;

  factory RoutineTask.fromJson(Map<String, dynamic> j) => RoutineTask(
    id: Json.str(j, 'id'),
    title: Json.str(j, 'title'),
    description: Json.strOrNull(j, 'description'),
    taskType: CompletionMethod.fromWire(Json.strOrNull(j, 'task_type')),
    category: Json.strOrNull(j, 'category'),
    allDepots: Json.boolOr(j, 'all_depots'),
    assignedDepotIds: Json.strList(j, 'assigned_depot_ids'),
    frequency: Frequency.fromWire(Json.strOrNull(j, 'frequency')),
    linkedModule: Json.strOrNull(j, 'linked_module'),
    requiresPhotoOnCompletion: Json.boolOr(j, 'requires_photo_on_completion'),
    isActive: Json.boolOr(j, 'is_active', fallback: true),
    priority: Json.strOrNull(j, 'source_meta') == null
        ? null
        : (Json.mapOr(j, 'source_meta')['priority'] as String?),
    responsiblePerson:
        Json.mapOr(j, 'source_meta')['responsible_person'] as String?,
    kpi: Json.mapOr(j, 'source_meta')['kpi'] as String?,
    sourceMeta: Json.mapOr(j, 'source_meta'),
  );
}

/// A row from `trucks`.
class Truck {
  const Truck({
    required this.id,
    required this.regNo,
    this.depotId,
    this.company,
    this.driverName,
    this.driverPhone,
    this.makeModel,
    this.year,
    this.status = 'OPERATIONAL',
    this.color,
    this.qrCodeUrl,
    this.lastInspectionDate,
    this.lastInspectionResult,
    this.nextInspectionDate,
  });

  final String id;
  final String regNo;
  final String? depotId;
  final String? company;
  final String? driverName;
  final String? driverPhone;
  final String? makeModel;
  final int? year;
  final String status;
  final String? color;
  final String? qrCodeUrl;
  final DateTime? lastInspectionDate;
  final String? lastInspectionResult;
  final DateTime? nextInspectionDate;

  factory Truck.fromJson(Map<String, dynamic> j) => Truck(
    id: Json.str(j, 'id'),
    regNo: Json.str(j, 'reg_no'),
    depotId: Json.strOrNull(j, 'depot_id'),
    company: Json.strOrNull(j, 'company'),
    driverName: Json.strOrNull(j, 'driver_name'),
    driverPhone: Json.strOrNull(j, 'driver_phone'),
    makeModel: Json.strOrNull(j, 'make_model'),
    year: Json.intOrNull(j, 'year'),
    status: Json.str(j, 'status', fallback: 'OPERATIONAL'),
    color: Json.strOrNull(j, 'color'),
    qrCodeUrl: Json.strOrNull(j, 'qr_code_url'),
    lastInspectionDate: _date(j['last_inspection_date']),
    lastInspectionResult: Json.strOrNull(j, 'last_inspection_result'),
    nextInspectionDate: _date(j['next_inspection_date']),
  );

  static DateTime? _date(Object? v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  bool get isOperational => status == 'OPERATIONAL';
}
