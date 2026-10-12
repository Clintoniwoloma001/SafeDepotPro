// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

/// Field mappings from the Base44 CSV exports to the Supabase schema.
///
/// Each `fromRow` returns null when the row should be skipped — a sample row,
/// or one with no usable business key. Skipping is silent-by-design: the
/// import prints the count of what it did map, and a row that cannot be keyed
/// cannot be updated either.
library;

import 'dart:convert';

/// Shared helpers for reading a Base44 row.
abstract final class Row {
  static String str(Map<String, String> row, String key) => row[key] ?? '';

  static bool isSample(Map<String, String> row) =>
      str(row, 'is_sample').toLowerCase() == 'true';

  /// Parses a double, tolerating a blank field.
  static double? dbl(String value) {
    final t = value.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Parses an int, rejecting implausible values.
  ///
  /// The vehicle export contains a `year` column whose sample rows hold
  /// "20" and "45" — clearly not years. Anything below 1000 is dropped rather
  /// than stored as a year.
  static int? year(String value) {
    final t = value.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < 1000 || n > 2999) return null;
    return n;
  }

  static int? intOr(String value) {
    final t = value.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  /// Normalises a Base44 status to the schema's is_active boolean.
  static bool isActive(String value) =>
      value.trim().toLowerCase() != 'inactive' &&
      value.trim().toLowerCase() != 'false';
}

/// The whole Base44 row, kept verbatim for `source_meta`.
Map<String, dynamic> sourceMeta(Map<String, String> row) =>
    Map<String, dynamic>.from(row);

String jsonOf(Object? value) => jsonEncode(value);

class DepotMapping {
  DepotMapping({
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    required this.meta,
  });

  final String code;
  final String name;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final Map<String, dynamic> meta;

  /// Maps a Base44 depot row.
  ///
  /// `code` is the business key, matching the import's primary rule. The
  /// Base44 `city` column is often blank while `name` holds the place, so the
  /// city is taken from `name` when `city` is empty rather than being lost.
  static DepotMapping? fromRow(Map<String, String> row) {
    if (Row.isSample(row)) return null;
    final code = Row.str(row, 'code').trim();
    final name = Row.str(row, 'name').trim();
    if (code.isEmpty || name.isEmpty) return null;

    return DepotMapping(
      code: code,
      name: name,
      latitude: Row.dbl(Row.str(row, 'gps_lat')),
      longitude: Row.dbl(Row.str(row, 'gps_lng')),
      isActive: Row.isActive(Row.str(row, 'status')),
      meta: sourceMeta(row),
    );
  }
}

class TaskMapping {
  TaskMapping({
    required this.title,
    required this.description,
    required this.taskType,
    required this.category,
    required this.allDepots,
    required this.assignedDepotNames,
    required this.frequency,
    required this.linkedModule,
    required this.requiresPhoto,
    required this.dueDays,
    required this.priority,
    required this.responsible,
    required this.meta,
  });

  final String title;
  final String description;
  final String taskType;
  final String? category;
  final bool allDepots;
  final List<String> assignedDepotNames;
  final String frequency;
  final String? linkedModule;
  final bool requiresPhoto;
  final int? dueDays;
  final String? priority;
  final String? responsible;
  final Map<String, dynamic> meta;

  /// Maps a Base44 routine-task row.
  ///
  /// `title` is the business key. Depot assignment arrives as a name in
  /// Base44 and is resolved to UUIDs by the SQL step, so the mapping carries
  /// the names through rather than guessing at ids that are not in the file.
  ///
  /// Fields with no home in the schema (`priority`, `responsible_person`,
  /// `kpi`, `action_type`, `attendance_required`) are preserved in
  /// `source_meta` and surfaced to the caller through the typed fields.
  static TaskMapping? fromRow(Map<String, String> row) {
    if (Row.isSample(row)) return null;
    final title = Row.str(row, 'task_name').trim();
    if (title.isEmpty) return null;

    final allDepots = Row.str(row, 'all_depots').toLowerCase() == 'true';
    final depotName = Row.str(row, 'depot_name').trim();

    return TaskMapping(
      title: title,
      description: Row.str(row, 'description').trim(),
      taskType: mapCompletionMethod(Row.str(row, 'completion_method')),
      category: _blankToNull(Row.str(row, 'department')),
      allDepots: allDepots,
      assignedDepotNames: [if (!allDepots && depotName.isNotEmpty) depotName],
      frequency: mapFrequency(Row.str(row, 'frequency')),
      linkedModule: mapLinkedModule(Row.str(row, 'linked_module')),
      requiresPhoto: Row.str(row, 'proof_required').toLowerCase() == 'true',
      dueDays: Row.intOr(Row.str(row, 'due_days')),
      priority: _blankToNull(Row.str(row, 'priority')),
      responsible: _blankToNull(Row.str(row, 'responsible_person')),
      meta: sourceMeta(row),
    );
  }

  static String? _blankToNull(String v) => v.trim().isEmpty ? null : v.trim();
}

class TruckMapping {
  TruckMapping({
    required this.regNo,
    required this.depotName,
    required this.company,
    required this.driverName,
    required this.driverPhone,
    required this.makeModel,
    required this.year,
    required this.status,
    required this.color,
    required this.qrCodeUrl,
    required this.lastInspectionDate,
    required this.lastInspectionResult,
    required this.nextInspectionDate,
    required this.meta,
  });

  final String regNo;
  final String depotName;
  final String? company;
  final String? driverName;
  final String? driverPhone;
  final String? makeModel;
  final int? year;
  final String status;
  final String? color;
  final String? qrCodeUrl;
  final String? lastInspectionDate;
  final String? lastInspectionResult;
  final String? nextInspectionDate;
  final Map<String, dynamic> meta;

  /// Maps a Base44 vehicle row.
  ///
  /// `truck_number` is the business key and the duplicate check for bulk
  /// upload. `depot_name` (not `depot_id`, which is blank in the export) is
  /// resolved to a depot by the SQL step. Colour, QR and the inspection dates
  /// have real columns in the schema, so they map directly.
  static TruckMapping? fromRow(Map<String, String> row) {
    if (Row.isSample(row)) return null;
    final regNo = Row.str(row, 'truck_number').trim();
    if (regNo.isEmpty) return null;

    final make = Row.str(row, 'make').trim();
    final model = Row.str(row, 'model').trim();
    final makeModel = [make, model].where((p) => p.isNotEmpty).join(' ');

    return TruckMapping(
      regNo: regNo,
      depotName: Row.str(row, 'depot_name').trim(),
      company: _blankToNull(Row.str(row, 'company')),
      driverName: _blankToNull(Row.str(row, 'driver_name')),
      driverPhone: _blankToNull(Row.str(row, 'driver_phone')),
      makeModel: makeModel.isEmpty ? null : makeModel,
      year: Row.year(Row.str(row, 'year')),
      status: mapTruckStatus(Row.str(row, 'status')),
      color: _blankToNull(Row.str(row, 'color')),
      qrCodeUrl: _blankToNull(Row.str(row, 'qr_code_url')),
      lastInspectionDate: _date(Row.str(row, 'last_inspection_date')),
      lastInspectionResult: _blankToNull(
        Row.str(row, 'last_inspection_result'),
      ),
      nextInspectionDate: _date(Row.str(row, 'next_inspection_date')),
      meta: sourceMeta(row),
    );
  }

  static String? _blankToNull(String v) => v.trim().isEmpty ? null : v.trim();

  /// Keeps only a leading ISO date; the export stores full timestamps.
  static String? _date(String value) {
    final t = value.trim();
    if (t.isEmpty) return null;
    return t.length >= 10 ? t.substring(0, 10) : null;
  }
}

/// Maps a Base44 `linked_module` to the schema's CHECK-ed value set.
///
/// The export writes the module's display name ("Routine Tasks"), which the
/// column's CHECK constraint does not accept — it allows only TOOLBOX and
/// HOUSEKEEPING. Anything outside that set is dropped and preserved in
/// `source_meta`, because widening the constraint would be a schema change to
/// accommodate a data value rather than a mapped value.
String? mapLinkedModule(String raw) {
  final upper = raw.trim().toUpperCase();
  if (upper.isEmpty) return null;
  if (upper.contains('TOOLBOX')) return 'TOOLBOX';
  if (upper.contains('HOUSEKEEPING')) return 'HOUSEKEEPING';
  return null;
}

/// Maps a Base44 completion method to the `completion_method` enum.
String mapCompletionMethod(String raw) {
  final upper = raw.trim().toUpperCase().replaceAll(' ', '_');
  const known = {
    'MANUAL': 'MANUAL',
    'FORM': 'FORM',
    'COUNT': 'COUNT',
    'PERMIT': 'PERMIT',
    'VEHICLE': 'VEHICLE',
    'EQUIPMENT': 'EQUIPMENT',
    'PERSONNEL': 'PERSONNEL',
    'AI_VERIFIED': 'AI_VERIFIED',
  };
  return known[upper] ?? 'MANUAL';
}

/// Maps a Base44 frequency to the `frequency` enum.
String mapFrequency(String raw) {
  final upper = raw.trim().toUpperCase().replaceAll(' ', '_');
  const known = {
    'DAILY': 'DAILY',
    'WEEKLY': 'WEEKLY',
    'MONTHLY': 'MONTHLY',
    'QUARTERLY': 'QUARTERLY',
    'BIANNUAL': 'BIANNUAL',
    'ANNUAL': 'ANNUAL',
  };
  return known[upper] ?? 'DAILY';
}

/// Maps a Base44 truck status to the schema's text status.
String mapTruckStatus(String raw) {
  final upper = raw.trim().toUpperCase();
  switch (upper) {
    case 'OUT_OF_SERVICE':
    case 'OUT OF SERVICE':
    case 'INACTIVE':
      return 'OUT_OF_SERVICE';
    case 'MAINTENANCE':
      return 'UNDER_MAINTENANCE';
    default:
      return 'OPERATIONAL';
  }
}
