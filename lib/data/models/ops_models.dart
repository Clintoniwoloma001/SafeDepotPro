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

  /// Scheduled time slot / time of completion for grouping and filtering.
  String get timeSlot {
    for (final key in const ['time_slot', 'timeSlot', 'scheduled_time', 'scheduledTime', 'time']) {
      final v = sourceMeta[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return 'Unscheduled';
  }

  factory RoutineTask.fromJson(Map<String, dynamic> j) {
    final meta = Json.mapOr(j, 'source_meta');
    return RoutineTask(
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
      priority: (meta['priority'] is String ? meta['priority'] as String : null),
      responsiblePerson:
          (meta['responsible_person'] is String
              ? meta['responsible_person'] as String
              : null),
      kpi: (meta['kpi'] is String ? meta['kpi'] as String : null),
      sourceMeta: meta,
    );
  }
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

/// A row from `inspection_types`.
class InspectionType {
  const InspectionType({
    required this.inspectionTypeId,
    required this.inspectionCode,
    required this.inspectionName,
    this.frequencyId,
    this.displayOrder,
    this.passScore,
    this.isScored = false,
    this.isActive = true,
    this.recordStatusId,
  });

  final String inspectionTypeId;
  final String? inspectionCode;
  final String inspectionName;
  final String? frequencyId;
  final int? displayOrder;
  final int? passScore;
  final bool isScored;
  final bool isActive;
  final String? recordStatusId;

  factory InspectionType.fromJson(Map<String, dynamic> j) => InspectionType(
    inspectionTypeId: Json.str(j, 'InspectionTypeID'),
    inspectionCode: Json.strOrNull(j, 'InspectionCode'),
    inspectionName: Json.str(j, 'InspectionName'),
    frequencyId: Json.strOrNull(j, 'FrequencyID'),
    displayOrder: Json.intOrNull(j, 'DisplayOrder'),
    passScore: Json.intOrNull(j, 'PassScore'),
    isScored: Json.boolOr(j, 'IsScored'),
    isActive: Json.boolOr(j, 'IsActive', fallback: true),
    recordStatusId: Json.strOrNull(j, 'RecordStatusID'),
  );
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
    this.templateId,
    this.templateVersion,
    this.itemResponses = const [],
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
  final String? templateId;
  final int? templateVersion;
  final List<TruckInspectionItemResponse> itemResponses;
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
        templateId: Json.strOrNull(j, 'template_id'),
        templateVersion: Json.intOrNull(j, 'template_version'),
        itemResponses: Json.listOr(j, 'item_responses')
            .map((e) => TruckInspectionItemResponse.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );
}

/// A response to a truck inspection template item.
class TruckInspectionItemResponse {
  const TruckInspectionItemResponse({
    required this.itemId,
    required this.responseType,
    this.passFailValue,
    this.numericValue,
    this.textValue,
    this.photoPaths = const [],
    this.signaturePath,
  });

  final String itemId;
  final TruckItemResponseType responseType;
  final bool? passFailValue;
  final double? numericValue;
  final String? textValue;
  final List<String> photoPaths;
  final String? signaturePath;

  factory TruckInspectionItemResponse.fromJson(Map<String, dynamic> j) =>
      TruckInspectionItemResponse(
        itemId: Json.str(j, 'item_id'),
        responseType: TruckItemResponseType.fromWire(Json.strOrNull(j, 'response_type')),
        passFailValue: Json.boolOrNull(j, 'pass_fail_value'),
        numericValue: Json.doubleOrNull(j, 'numeric_value'),
        textValue: Json.strOrNull(j, 'text_value'),
        photoPaths: Json.strList(j, 'photo_paths'),
        signaturePath: Json.strOrNull(j, 'signature_path'),
      );

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'response_type': responseType.wire,
        if (passFailValue != null) 'pass_fail_value': passFailValue,
        if (numericValue != null) 'numeric_value': numericValue,
        if (textValue != null) 'text_value': textValue,
        'photo_paths': photoPaths,
        if (signaturePath != null) 'signature_path': signaturePath,
      };
}

/// Truck inspection template type.
enum TruckTemplateType {
  global('GLOBAL'),
  customer('CUSTOMER');

  const TruckTemplateType(this.wire);
  final String wire;

  static TruckTemplateType fromWire(String? wire) {
    switch (wire) {
      case 'CUSTOMER':
        return TruckTemplateType.customer;
      case 'GLOBAL':
      default:
        return TruckTemplateType.global;
    }
  }
}

/// A row from `truck_inspection_templates` (migration 0027).
class TruckInspectionTemplate {
  const TruckInspectionTemplate({
    required this.id,
    required this.name,
    this.type = TruckTemplateType.global,
    this.description,
    this.isActive = true,
    this.version = 1,
    this.depotId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final TruckTemplateType type;
  final String? description;
  final bool isActive;
  final int version;
  final String? depotId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TruckInspectionTemplate.fromJson(Map<String, dynamic> j) =>
      TruckInspectionTemplate(
        id: Json.str(j, 'id'),
        name: Json.str(j, 'name'),
        type: TruckTemplateType.fromWire(Json.strOrNull(j, 'type')),
        description: Json.strOrNull(j, 'description'),
        isActive: Json.boolOr(j, 'is_active', fallback: true),
        version: Json.intOr(j, 'version', fallback: 1),
        depotId: Json.strOrNull(j, 'depot_id'),
        createdBy: Json.strOrNull(j, 'created_by'),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );
}

/// Truck inspection item response type.
enum TruckItemResponseType {
  passFail('PASS_FAIL'),
  numeric('NUMERIC'),
  text('TEXT'),
  photo('PHOTO'),
  signature('SIGNATURE');

  const TruckItemResponseType(this.wire);
  final String wire;

  static TruckItemResponseType fromWire(String? wire) {
    switch (wire) {
      case 'NUMERIC':
        return TruckItemResponseType.numeric;
      case 'TEXT':
        return TruckItemResponseType.text;
      case 'PHOTO':
        return TruckItemResponseType.photo;
      case 'SIGNATURE':
        return TruckItemResponseType.signature;
      case 'PASS_FAIL':
      default:
        return TruckItemResponseType.passFail;
    }
  }
}

/// A row from `truck_inspection_template_items` (migration 0027).
class TruckInspectionTemplateItem {
  const TruckInspectionTemplateItem({
    required this.id,
    required this.templateId,
    required this.section,
    required this.itemText,
    this.responseType = TruckItemResponseType.passFail,
    this.weight = 1.0,
    this.isCritical = false,
    this.requiresPhoto = false,
    this.minValue,
    this.maxValue,
    this.unit,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String templateId;
  final String section;
  final String itemText;
  final TruckItemResponseType responseType;
  final double weight;
  final bool isCritical;
  final bool requiresPhoto;
  final double? minValue;
  final double? maxValue;
  final String? unit;
  final int sortOrder;
  final bool isActive;

  factory TruckInspectionTemplateItem.fromJson(Map<String, dynamic> j) =>
      TruckInspectionTemplateItem(
        id: Json.str(j, 'id'),
        templateId: Json.str(j, 'template_id'),
        section: Json.str(j, 'section'),
        itemText: Json.str(j, 'question_text'),
        responseType: TruckItemResponseType.fromWire(Json.strOrNull(j, 'response_type')),
        weight: Json.doubleOrNull(j, 'weight') ?? 1.0,
        isCritical: Json.boolOr(j, 'is_critical'),
        requiresPhoto: Json.boolOr(j, 'requires_photo'),
        minValue: Json.doubleOrNull(j, 'min_value'),
        maxValue: Json.doubleOrNull(j, 'max_value'),
        unit: Json.strOrNull(j, 'unit'),
        sortOrder: Json.intOr(j, 'sort_order'),
        isActive: Json.boolOr(j, 'is_active', fallback: true),
      );
}

/// Reminder delivery channel.
enum ReminderChannel {
  push('PUSH'),
  email('EMAIL'),
  sms('SMS'),
  inApp('IN_APP');

  const ReminderChannel(this.wire);
  final String wire;

  static ReminderChannel fromWire(String? wire) {
    switch (wire) {
      case 'EMAIL':
        return ReminderChannel.email;
      case 'SMS':
        return ReminderChannel.sms;
      case 'IN_APP':
        return ReminderChannel.inApp;
      case 'PUSH':
      default:
        return ReminderChannel.push;
    }
  }
}

/// Task reminder status.
enum ReminderStatus {
  pending('PENDING'),
  sent('SENT'),
  failed('FAILED'),
  cancelled('CANCELLED');

  const ReminderStatus(this.wire);
  final String wire;

  static ReminderStatus fromWire(String? wire) {
    switch (wire) {
      case 'SENT':
        return ReminderStatus.sent;
      case 'FAILED':
        return ReminderStatus.failed;
      case 'CANCELLED':
        return ReminderStatus.cancelled;
      case 'PENDING':
      default:
        return ReminderStatus.pending;
    }
  }
}

/// A row from `task_reminders` (migration 0027).
class TaskReminder {
   const TaskReminder({
     required this.id,
     required this.taskId,
     required this.title,
     required this.scheduledAt,
     this.channel = ReminderChannel.push,
     this.status = ReminderStatus.pending,
     this.recipientUserId,
     this.sentAt,
     this.errorMessage,
     this.retryCount = 0,
     required this.createdAt,
     required this.updatedAt,
   });

   final String id;
   final String taskId;
   final String title;
   final DateTime scheduledAt;
   final ReminderChannel channel;
   final ReminderStatus status;
   final String? recipientUserId;
   final DateTime? sentAt;
   final String? errorMessage;
   final int retryCount;
   final DateTime createdAt;
   final DateTime updatedAt;

   factory TaskReminder.fromJson(Map<String, dynamic> j) => TaskReminder(
         id: Json.str(j, 'id'),
         taskId: Json.str(j, 'task_id'),
         title: Json.str(j, 'title'),
         scheduledAt: DateTime.parse(Json.str(j, 'scheduled_at')),
         channel: ReminderChannel.fromWire(Json.strOrNull(j, 'channel')),
         status: ReminderStatus.fromWire(Json.strOrNull(j, 'status')),
         recipientUserId: Json.strOrNull(j, 'recipient_user_id'),
         sentAt: DateTime.tryParse(Json.strOrNull(j, 'sent_at') ?? ''),
         errorMessage: Json.strOrNull(j, 'error_message'),
         retryCount: Json.intOr(j, 'retry_count', fallback: 0),
         createdAt: DateTime.parse(Json.str(j, 'created_at')),
         updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
       );
}

/// A row from `toolbox_talks`.
class ToolboxTalk {
  const ToolboxTalk({
    required this.id,
    required this.depotId,
    required this.title,
    this.description,
    required this.company,
    this.location,
    required this.date,
    required this.time,
    this.facilitator,
    this.category,
    this.isHighRisk = false,
    this.tag,
    this.photoPaths = const [],
    this.latitude,
    this.longitude,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String depotId;
  final String title;
  final String? description;
  final String company;
  final String? location;
  final String date;
  final String time;
  final String? facilitator;
  final String? category;
  final bool isHighRisk;
  final String? tag;
  final List<String> photoPaths;
  final double? latitude;
  final double? longitude;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ToolboxTalk.fromJson(Map<String, dynamic> j) => ToolboxTalk(
        id: Json.str(j, 'id'),
        depotId: Json.str(j, 'depot_id'),
        title: Json.str(j, 'title'),
        description: Json.strOrNull(j, 'description'),
        company: Json.str(j, 'company'),
        location: Json.strOrNull(j, 'location'),
        date: Json.str(j, 'date'),
        time: Json.str(j, 'time'),
        facilitator: Json.strOrNull(j, 'facilitator'),
        category: Json.strOrNull(j, 'category'),
        isHighRisk: Json.boolOr(j, 'is_high_risk'),
        tag: Json.strOrNull(j, 'tag'),
        photoPaths: Json.strList(j, 'photo_paths'),
        latitude: Json.doubleOrNull(j, 'latitude'),
        longitude: Json.doubleOrNull(j, 'longitude'),
        createdBy: Json.strOrNull(j, 'created_by'),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );
}

/// A row from `toolbox_topics` (shared weekly topics).
class ToolboxTopic {
  const ToolboxTopic({
    required this.id,
    required this.title,
    required this.content,
    this.category,
    this.isHighRisk = false,
    this.weekOfYear,
    this.isActive = true,
    this.isFactory = false,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String? category;
  final bool isHighRisk;
  final int? weekOfYear;
  final bool isActive;
  final bool isFactory;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ToolboxTopic.fromJson(Map<String, dynamic> j) => ToolboxTopic(
        id: Json.str(j, 'id'),
        title: Json.str(j, 'title'),
        content: Json.str(j, 'content'),
        category: Json.strOrNull(j, 'category'),
        isHighRisk: Json.boolOr(j, 'is_high_risk'),
        weekOfYear: Json.intOrNull(j, 'week_of_year'),
        isActive: Json.boolOr(j, 'is_active', fallback: true),
        isFactory: Json.boolOr(j, 'is_factory'),
        createdBy: Json.strOrNull(j, 'created_by'),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );
}

/// A row from `toolbox_attendees`.
class ToolboxAttendee {
  const ToolboxAttendee({
    required this.id,
    required this.toolboxTalkId,
    required this.name,
    this.employeeNumber,
    this.signaturePath,
    this.signedAt,
    required this.createdAt,
  });

  final String id;
  final String toolboxTalkId;
  final String name;
  final String? employeeNumber;
  final String? signaturePath;
  final DateTime? signedAt;
  final DateTime createdAt;

  factory ToolboxAttendee.fromJson(Map<String, dynamic> j) => ToolboxAttendee(
        id: Json.str(j, 'id'),
        toolboxTalkId: Json.str(j, 'toolbox_talk_id'),
        name: Json.str(j, 'name'),
        employeeNumber: Json.strOrNull(j, 'employee_number'),
        signaturePath: Json.strOrNull(j, 'signature_path'),
        signedAt: DateTime.tryParse(Json.strOrNull(j, 'signed_at') ?? ''),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
      );
}

/// A row from `toolbox_talk_images`.
class ToolboxTalkImage {
  const ToolboxTalkImage({
    required this.id,
    required this.toolboxTalkId,
    required this.storagePath,
    this.caption,
    this.sortOrder = 0,
    required this.createdAt,
  });

  final String id;
  final String toolboxTalkId;
  final String storagePath;
  final String? caption;
  final int sortOrder;
  final DateTime createdAt;

   factory ToolboxTalkImage.fromJson(Map<String, dynamic> j) => ToolboxTalkImage(
         id: Json.str(j, 'id'),
         toolboxTalkId: Json.str(j, 'toolbox_talk_id'),
         storagePath: Json.str(j, 'storage_path'),
         caption: Json.strOrNull(j, 'caption'),
         sortOrder: Json.intOr(j, 'sort_order'),
         createdAt: DateTime.parse(Json.str(j, 'created_at')),
       );
 }
