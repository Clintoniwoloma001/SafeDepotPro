// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
/// Models for the monthly man-hour sheets (migration 0031).
///
/// A sheet is the header for one depot and one calendar month; it carries the
/// draft/submitted lock state. Each sheet owns an ordered list of entries —
/// the rows of the "NAMES / NO. OF WORKER / NO. OF DAYS / NO. OF HOURS /
/// TOTAL" grid that is exported to the corporate West Depots workbook.
library;

import 'models.dart';

/// Lock state of a man-hour sheet.
enum ManHourSheetStatus {
  draft('DRAFT'),
  submitted('SUBMITTED');

  const ManHourSheetStatus(this.wire);

  final String wire;

  static ManHourSheetStatus fromWire(String? value) =>
      ManHourSheetStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => ManHourSheetStatus.draft,
      );
}

/// Workforce category a man-hour entry belongs to.
enum ManHourCategory {
  fte('FTE', 'FTE'),
  dso('DSO', 'DSO'),
  contractor('CONTRACTOR', 'Contractor');

  const ManHourCategory(this.wire, this.label);

  final String wire;
  final String label;

  static ManHourCategory fromWire(String? value) =>
      ManHourCategory.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => ManHourCategory.fte,
      );
}

/// Header row of a depot/month man-hour sheet.
class ManHourSheet {
  const ManHourSheet({
    required this.id,
    required this.depotId,
    required this.depotName,
    required this.periodYear,
    required this.periodMonth,
    this.status = ManHourSheetStatus.draft,
    this.submittedAt,
    this.submittedBy,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String depotId;

  /// Joined from `depots` for display; empty when the depot row is missing.
  final String depotName;
  final int periodYear;
  final int periodMonth;
  final ManHourSheetStatus status;
  final DateTime? submittedAt;
  final String? submittedBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isSubmitted => status == ManHourSheetStatus.submitted;

  /// A submitted sheet is read-only until an administrator reopens it.
  bool get isLocked => isSubmitted;

  factory ManHourSheet.fromJson(Map<String, dynamic> j) => ManHourSheet(
        id: Json.str(j, 'id'),
        depotId: Json.str(j, 'depot_id'),
        depotName: Json.str(j, 'depot_name'),
        periodYear: Json.intOr(j, 'period_year'),
        periodMonth: Json.intOr(j, 'period_month'),
        status: ManHourSheetStatus.fromWire(Json.strOrNull(j, 'status')),
        submittedAt: _dateOrNull(j['submitted_at']),
        submittedBy: Json.strOrNull(j, 'submitted_by'),
        updatedBy: Json.strOrNull(j, 'updated_by'),
        createdAt: _dateOrNull(j['created_at']) ?? DateTime.now(),
        updatedAt: _dateOrNull(j['updated_at']) ?? DateTime.now(),
      );

  ManHourSheet copyWith({
    String? depotName,
    ManHourSheetStatus? status,
    DateTime? submittedAt,
    String? submittedBy,
    String? updatedBy,
  }) =>
      ManHourSheet(
        id: id,
        depotId: depotId,
        depotName: depotName ?? this.depotName,
        periodYear: periodYear,
        periodMonth: periodMonth,
        status: status ?? this.status,
        submittedAt: submittedAt ?? this.submittedAt,
        submittedBy: submittedBy ?? this.submittedBy,
        updatedBy: updatedBy ?? this.updatedBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// One row of the man-hour grid.
class ManHourSheetEntry {
  const ManHourSheetEntry({
    required this.id,
    required this.sheetId,
    required this.rowIndex,
    this.category = ManHourCategory.fte,
    this.entryName = '',
    this.workerCount = 0,
    this.daysWorked = 0,
    this.hoursPerDay = 8,
    this.totalHours = 0,
  });

  final String id;
  final String sheetId;
  final int rowIndex;
  final ManHourCategory category;
  final String entryName;
  final int workerCount;
  final int daysWorked;
  final int hoursPerDay;

  /// Server-computed (`worker_count * days_worked * hours_per_day`).
  final int totalHours;

  /// Workers × days × hours, computed locally so the grid stays responsive
  /// before the row has been synced.
  int get total => workerCount * daysWorked * hoursPerDay;

  factory ManHourSheetEntry.fromJson(Map<String, dynamic> j) => ManHourSheetEntry(
        id: Json.str(j, 'id'),
        sheetId: Json.str(j, 'sheet_id'),
        rowIndex: Json.intOr(j, 'row_index'),
        category: ManHourCategory.fromWire(Json.strOrNull(j, 'category')),
        entryName: Json.str(j, 'entry_name'),
        workerCount: Json.intOr(j, 'worker_count'),
        daysWorked: Json.intOr(j, 'days_worked'),
        hoursPerDay: Json.intOr(j, 'hours_per_day', fallback: 8),
        totalHours: Json.intOr(j, 'total_hours'),
      );

  ManHourSheetEntry copyWith({
    int? rowIndex,
    ManHourCategory? category,
    String? entryName,
    int? workerCount,
    int? daysWorked,
    int? hoursPerDay,
  }) =>
      ManHourSheetEntry(
        id: id,
        sheetId: sheetId,
        rowIndex: rowIndex ?? this.rowIndex,
        category: category ?? this.category,
        entryName: entryName ?? this.entryName,
        workerCount: workerCount ?? this.workerCount,
        daysWorked: daysWorked ?? this.daysWorked,
        hoursPerDay: hoursPerDay ?? this.hoursPerDay,
        totalHours: total,
      );

  Map<String, dynamic> toInsert(String sheetId) => {
        'sheet_id': sheetId,
        'row_index': rowIndex,
        'category': category.wire,
        'entry_name': entryName,
        'worker_count': workerCount,
        'days_worked': daysWorked,
        'hours_per_day': hoursPerDay,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'sheet_id': sheetId,
        'row_index': rowIndex,
        'category': category.wire,
        'entry_name': entryName,
        'worker_count': workerCount,
        'days_worked': daysWorked,
        'hours_per_day': hoursPerDay,
        'total_hours': total,
      };

  factory ManHourSheetEntry.fromJsonMap(Map<String, dynamic> j) =>
      ManHourSheetEntry.fromJson(j);
}

DateTime? _dateOrNull(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
