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

/// A row from `shift_handovers` (migration 0013).
class ShiftHandover {
  const ShiftHandover({
    required this.id,
    required this.depotId,
    required this.shift,
    required this.date,
    this.outgoingUserId,
    this.incomingUserId,
    this.summary,
    this.pendingIssues = const [],
    this.equipmentNotes,
    this.photoPaths = const [],
    this.status = ShiftStatus.pending,
    this.signatureOutgoing,
    this.signatureIncoming,
    this.confirmedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String depotId;
  final String shift;
  final String date;
  final String? outgoingUserId;
  final String? incomingUserId;
  final String? summary;
  final List<String> pendingIssues;
  final String? equipmentNotes;
  final List<String> photoPaths;
  final ShiftStatus status;
  final String? signatureOutgoing;
  final String? signatureIncoming;
  final DateTime? confirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ShiftHandover.fromJson(Map<String, dynamic> j) => ShiftHandover(
        id: Json.str(j, 'id'),
        depotId: Json.str(j, 'depot_id'),
        shift: Json.str(j, 'shift', fallback: 'DAY'),
        date: Json.str(j, 'date'),
        outgoingUserId: Json.strOrNull(j, 'outgoing_user_id'),
        incomingUserId: Json.strOrNull(j, 'incoming_user_id'),
        summary: Json.strOrNull(j, 'summary'),
        pendingIssues: Json.strList(j, 'pending_issues'),
        equipmentNotes: Json.strOrNull(j, 'equipment_notes'),
        photoPaths: Json.strList(j, 'photo_paths'),
        status: ShiftStatus.fromWire(Json.strOrNull(j, 'status')),
        signatureOutgoing: Json.strOrNull(j, 'signature_outgoing'),
        signatureIncoming: Json.strOrNull(j, 'signature_incoming'),
        confirmedAt: DateTime.tryParse(Json.str(j, 'confirmed_at', fallback: '')),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );

  bool get isCompleted => status == ShiftStatus.confirmed;
}

/// A row from `man_hours` (migration 0012).
class ManHours {
  const ManHours({
    required this.id,
    required this.depotId,
    required this.periodStart,
    required this.periodEnd,
    this.hoursWorked = 0,
    this.overtimeHours = 0,
    this.headcount = 0,
    this.recordableIncidents = 0,
    this.lostTimeIncidents = 0,
    this.nearMisses = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String depotId;
  final DateTime periodStart;
  final DateTime? periodEnd;
  final double hoursWorked;
  final double overtimeHours;
  final int headcount;
  final int recordableIncidents;
  final int lostTimeIncidents;
  final int nearMisses;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ManHours.fromJson(Map<String, dynamic> j) => ManHours(
        id: Json.str(j, 'id'),
        depotId: Json.str(j, 'depot_id'),
        periodStart: DateTime.parse(Json.str(j, 'period_start')),
        periodEnd: DateTime.tryParse(Json.str(j, 'period_end', fallback: '')),
        hoursWorked: Json.doubleOrNull(j, 'hours_worked') ?? 0,
        overtimeHours: Json.doubleOrNull(j, 'overtime_hours') ?? 0,
        headcount: Json.intOr(j, 'headcount'),
        recordableIncidents: Json.intOr(j, 'recordable_incidents'),
        lostTimeIncidents: Json.intOr(j, 'lost_time_incidents'),
        nearMisses: Json.intOr(j, 'near_misses'),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );

  /// Total man-hours worked including overtime.
  double get totalHours => hoursWorked + overtimeHours;
}

/// A row from `truck_inspections` (created by this feature).
class TruckInspection {
  const TruckInspection({
    required this.id,
    required this.truckId,
    required this.depotId,
    required this.inspectedBy,
    required this.result,
    this.notes,
    this.photoPaths = const [],
    this.compliance = 0,
    this.latitude,
    this.longitude,
    this.signaturePath,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String truckId;
  final String depotId;
  final String inspectedBy;
  final TruckResult result;
  final String? notes;
  final List<String> photoPaths;
  final double compliance;
  final double? latitude;
  final double? longitude;
  final String? signaturePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TruckInspection.fromJson(Map<String, dynamic> j) => TruckInspection(
        id: Json.str(j, 'id'),
        truckId: Json.str(j, 'truck_id'),
        depotId: Json.str(j, 'depot_id'),
        inspectedBy: Json.str(j, 'inspected_by'),
        result: TruckResult.fromWire(Json.strOrNull(j, 'result')),
        notes: Json.strOrNull(j, 'notes'),
        photoPaths: Json.strList(j, 'photo_paths'),
        compliance: Json.doubleOrNull(j, 'compliance') ?? 0,
        latitude: Json.doubleOrNull(j, 'latitude'),
        longitude: Json.doubleOrNull(j, 'longitude'),
        signaturePath: Json.strOrNull(j, 'signature_path'),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );
}
