// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
/// Model layer for the operational modules: permits, inspections, incidents
/// and corrective actions.
library;

import 'models.dart';
import 'enums.dart';

// ---------------------------------------------------------------------------
// Permits / approvals (0006_permits.sql)
// ---------------------------------------------------------------------------

class Permit {
  const Permit({
    required this.id,
    required this.permitNumber,
    required this.depotId,
    this.permitType,
    required this.jobTitle,
    this.jobDescription,
    this.tasks = const [],
    this.location,
    this.startDatetime,
    this.endDatetime,
    this.hazardAssessment = const [],
    this.additionalControls,
    this.ppe = const [],
    this.isolationLoto,
    this.attachmentPaths = const [],
    this.status = PermitStatus.draft,
    this.rejectionReason,
    this.approvedAt,
    this.approvedBy,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String permitNumber;
  final String depotId;
  final String? permitType;
  final String jobTitle;
  final String? jobDescription;
  final List<Map<String, dynamic>> tasks;
  final String? location;
  final DateTime? startDatetime;
  final DateTime? endDatetime;
  final List<Map<String, dynamic>> hazardAssessment;
  final String? additionalControls;
  final List<Map<String, dynamic>> ppe;
  final String? isolationLoto;
  final List<String> attachmentPaths;
  final PermitStatus status;
  final String? rejectionReason;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Permit.fromJson(Map<String, dynamic> j) => Permit(
        id: Json.str(j, 'id'),
        permitNumber: Json.str(j, 'permit_number'),
        depotId: Json.str(j, 'depot_id'),
        permitType: Json.strOrNull(j, 'permit_type'),
        jobTitle: Json.str(j, 'job_title'),
        jobDescription: Json.strOrNull(j, 'job_description'),
        tasks: Json.listOfMaps(j, 'tasks'),
        location: Json.strOrNull(j, 'location'),
        startDatetime: DateTime.tryParse(Json.str(j, 'start_datetime', fallback: '')),
        endDatetime: DateTime.tryParse(Json.str(j, 'end_datetime', fallback: '')),
        hazardAssessment: Json.listOfMaps(j, 'hazard_assessment'),
        additionalControls: Json.strOrNull(j, 'additional_controls'),
        ppe: Json.listOfMaps(j, 'ppe'),
        isolationLoto: Json.strOrNull(j, 'isolation_loto'),
        attachmentPaths: Json.strList(j, 'attachment_paths'),
        status: PermitStatus.fromWire(Json.strOrNull(j, 'status')),
        rejectionReason: Json.strOrNull(j, 'rejection_reason'),
        approvedAt: DateTime.tryParse(Json.str(j, 'approved_at', fallback: '')),
        approvedBy: Json.strOrNull(j, 'approved_by'),
        createdBy: Json.strOrNull(j, 'created_by'),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );
}

// ---------------------------------------------------------------------------
// Inspections (0007_checklists_and_inspections.sql)
// ---------------------------------------------------------------------------

class ChecklistTemplate {
  const ChecklistTemplate({
    required this.id,
    required this.name,
    required this.type,
    this.sections = const [],
    this.description,
    this.isFactory = false,
    this.isActive = true,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String type;
  final List<Map<String, dynamic>> sections;
  final String? description;
  final bool isFactory;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ChecklistTemplate.fromJson(Map<String, dynamic> j) => ChecklistTemplate(
        id: Json.str(j, 'id'),
        name: Json.str(j, 'name'),
        type: Json.str(j, 'type', fallback: ChecklistType.hse),
        sections: Json.listOfMaps(j, 'sections'),
        description: Json.strOrNull(j, 'description'),
        isFactory: Json.boolOr(j, 'is_factory'),
        isActive: Json.boolOr(j, 'is_active', fallback: true),
        createdBy: Json.strOrNull(j, 'created_by'),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );

  int get questionCount => sections.fold(
        0,
        (sum, s) => sum + ((s['questions'] as List?)?.length ?? 0),
      );
}

class Inspection {
  const Inspection({
    required this.id,
    required this.checklistName,
    required this.type,
    required this.status,
    required this.depotId,
    required this.templateId,
    required this.answers,
    required this.completedBy,
    this.compliance = 0,
    this.notes,
    this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? depotId;
  final String? templateId;
  final String checklistName;
  final String type;
  final InspectionStatus status;
  final String? completedBy;
  final List<Map<String, dynamic>> answers;
  final double compliance;
  final String? notes;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Inspection.fromJson(Map<String, dynamic> j) => Inspection(
        id: Json.str(j, 'id'),
        depotId: Json.strOrNull(j, 'depot_id'),
        templateId: Json.strOrNull(j, 'template_id'),
        checklistName: Json.str(j, 'checklist_name'),
        type: Json.str(j, 'type', fallback: ChecklistType.hse),
        status: InspectionStatus.fromWire(Json.strOrNull(j, 'status')),
        completedBy: Json.strOrNull(j, 'completed_by'),
        answers: Json.listOfMaps(j, 'answers'),
        compliance: Json.doubleOrNull(j, 'compliance') ?? 0,
        notes: Json.strOrNull(j, 'notes'),
        submittedAt: DateTime.tryParse(Json.str(j, 'submitted_at', fallback: '')),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );

  int get answeredCount => answers.length;
  int get failCount => answers
      .where((a) => a['response'] == InspectionResponse.fail.wire)
      .length;
}

// ---------------------------------------------------------------------------
// Incidents (0009_incidents_and_hazards.sql)
// ---------------------------------------------------------------------------

class Incident {
  const Incident({
    required this.id,
    required this.incidentNumber,
    required this.depotId,
    this.incidentType,
    required this.severity,
    required this.description,
    required this.status,
    required this.occurredAt,
    required this.photoPaths,
    required this.involvedPersonnel,
    this.rootCause,
    this.actionsTaken,
    this.reportedBy,
    this.reportedByName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String incidentNumber;
  final String depotId;
  final String? incidentType;
  final Severity severity;
  final String description;
  final IncidentStatus status;
  final DateTime occurredAt;
  final List<String> photoPaths;
  final List<Map<String, dynamic>> involvedPersonnel;
  final String? rootCause;
  final String? actionsTaken;
  final String? reportedBy;
  final String? reportedByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
        id: Json.str(j, 'id'),
        incidentNumber: Json.str(j, 'incident_number'),
        depotId: Json.str(j, 'depot_id'),
        incidentType: Json.strOrNull(j, 'incident_type'),
        severity: Severity.fromWire(Json.strOrNull(j, 'severity')),
        description: Json.str(j, 'description'),
        status: IncidentStatus.fromWire(Json.strOrNull(j, 'status')),
        occurredAt: DateTime.parse(Json.str(j, 'occurred_at')),
        photoPaths: Json.strList(j, 'photo_paths'),
        involvedPersonnel: Json.listOfMaps(j, 'involved_personnel'),
        rootCause: Json.strOrNull(j, 'root_cause'),
        actionsTaken: Json.strOrNull(j, 'actions_taken'),
        reportedBy: Json.strOrNull(j, 'reported_by'),
        reportedByName: Json.strOrNull(j, 'reported_by_name'),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );
}

// ---------------------------------------------------------------------------
// Corrective actions / CAPA (0010_corrective_actions.sql)
// ---------------------------------------------------------------------------

class Capa {
  const Capa({
    required this.id,
    required this.capaNumber,
    required this.depotId,
    required this.title,
    required this.sourceType,
    required this.sourceId,
    required this.status,
    required this.priority,
    required this.dueDate,
    required this.completionRate,
    this.description,
    this.rootCause,
    this.correctiveAction,
    this.responsibleUserId,
    this.responsibleName,
    this.assignerUserId,
    this.assignerName,
    required this.completedAt,
    required this.completedBy,
    required this.proofPaths,
    this.signaturePath,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String capaNumber;
  final String depotId;
  final String title;
  final String sourceType;
  final String? sourceId;
  final CapaStatus status;
  final Priority priority;
  final DateTime? dueDate;
  final int completionRate;
  final String? description;
  final String? rootCause;
  final String? correctiveAction;
  final String? responsibleUserId;
  final String? responsibleName;
  final String? assignerUserId;
  final String? assignerName;
  final DateTime? completedAt;
  final String? completedBy;
  final List<String> proofPaths;
  final String? signaturePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Capa.fromJson(Map<String, dynamic> j) => Capa(
        id: Json.str(j, 'id'),
        capaNumber: Json.str(j, 'capa_number'),
        depotId: Json.str(j, 'depot_id'),
        title: Json.str(j, 'title'),
        sourceType: Json.str(j, 'source_type', fallback: SourceType.standalone),
        sourceId: Json.strOrNull(j, 'source_id'),
        status: CapaStatus.fromWire(Json.strOrNull(j, 'status')),
        priority: Priority.fromWire(Json.strOrNull(j, 'priority')),
        dueDate: DateTime.tryParse(Json.str(j, 'due_date', fallback: '')),
        completionRate: Json.intOr(j, 'completion_rate'),
        description: Json.strOrNull(j, 'description'),
        rootCause: Json.strOrNull(j, 'root_cause'),
        correctiveAction: Json.strOrNull(j, 'corrective_action'),
        responsibleUserId: Json.strOrNull(j, 'responsible_user_id'),
        responsibleName: Json.strOrNull(j, 'responsible_name'),
        assignerUserId: Json.strOrNull(j, 'assigner_user_id'),
        assignerName: Json.strOrNull(j, 'assigner_name'),
        completedAt: DateTime.tryParse(Json.str(j, 'completed_at', fallback: '')),
        completedBy: Json.strOrNull(j, 'completed_by'),
        proofPaths: Json.strList(j, 'proof_paths'),
        signaturePath: Json.strOrNull(j, 'signature_path'),
        createdAt: DateTime.parse(Json.str(j, 'created_at')),
        updatedAt: DateTime.parse(Json.str(j, 'updated_at')),
      );

  bool get isOverdue =>
      dueDate != null &&
      status.isActive &&
      dueDate!.isBefore(DateTime.now());
}
