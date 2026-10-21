// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../../data/models/man_hour_models.dart';

/// The depots that make up the corporate West Depots man-hour workbook.
///
/// The order is the order the depots appear in the corporate template.
const List<String> corporateDepots = <String>[
  'Abeokuta',
  'Agbara',
  'Ado Ekiti',
  'Ajah',
  'Akure',
  'Ewekoro',
  'Ijebu Ode',
  'Ogba',
  'Iseyin',
  'Osogbo',
  'Ikorodu',
  'Eleyele',
];

/// Month labels used in the workbook and on screen.
const List<String> manHourMonthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Builds the Excel workbooks for the man-hour module.
///
/// A depot sheet reproduces the corporate layout: the five grid columns
/// (NAMES, NO. OF WORKER, NO. OF DAYS, NO. OF HOURS, TOTAL), the grid rows
/// grouped by workforce category, and a totals block. The master workbook
/// repeats that sheet for every depot and adds a summary sheet.
class ManHourExporter {
  const ManHourExporter._();

  static const _headerFill = '#1F4E79';
  static const _sectionFill = '#D9E1F2';
  static const _totalFill = '#FCE4D6';

  /// Writes a single-depot workbook and returns the file.
  static Future<File> writeDepotWorkbook({
    required String depotName,
    required int year,
    required int month,
    required List<ManHourSheetEntry> rows,
    bool submitted = false,
  }) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = _safeSheetName(depotName);
    _writeDepotSheet(
      sheet,
      depotName: depotName,
      year: year,
      month: month,
      rows: rows,
      submitted: submitted,
    );
    return _save(workbook, 'Manhour_${_slug(depotName)}_${manHourMonthNames[month - 1]}_$year.xlsx');
  }

  /// Writes the multi-depot workbook and returns the file.
  ///
  /// [sheets] maps a depot display name to its grid rows. Depots without rows
  /// are still written so the workbook keeps the corporate shape.
  static Future<File> writeMasterWorkbook({
    required int year,
    required int month,
    required Map<String, List<ManHourSheetEntry>> sheets,
    Set<String> submittedDepots = const {},
  }) async {
    final workbook = xlsio.Workbook();

    var first = true;
    for (final depotName in corporateDepots) {
      final rows = sheets[depotName] ?? const <ManHourSheetEntry>[];
      final sheet = first
          ? workbook.worksheets[0]
          : workbook.worksheets.addWithName(_safeSheetName(depotName));
      sheet.name = _safeSheetName(depotName);
      _writeDepotSheet(
        sheet,
        depotName: depotName,
        year: year,
        month: month,
        rows: rows,
        submitted: submittedDepots.contains(depotName),
      );
      first = false;
    }

    // Any depot that is not part of the corporate template but has data is
    // appended, so nothing recorded in the app is lost from the export.
    for (final depotName in sheets.keys) {
      if (corporateDepots.any((d) => d.toLowerCase() == depotName.toLowerCase())) {
        continue;
      }
      final rows = sheets[depotName] ?? const <ManHourSheetEntry>[];
      if (rows.isEmpty) continue;
      final sheet = workbook.worksheets.addWithName(_safeSheetName(depotName));
      _writeDepotSheet(
        sheet,
        depotName: depotName,
        year: year,
        month: month,
        rows: rows,
        submitted: submittedDepots.contains(depotName),
      );
    }

    final summary = workbook.worksheets.addWithName('Summary');
    _writeSummarySheet(
      summary,
      year: year,
      month: month,
      sheets: sheets,
      submittedDepots: submittedDepots,
    );

    return _save(
      workbook,
      'West_Depots_Manhour_Sheet_${manHourMonthNames[month - 1]}_$year.xlsx',
    );
  }

  /// Lays out one depot sheet.
  static void _writeDepotSheet(
    xlsio.Worksheet sheet, {
    required String depotName,
    required int year,
    required int month,
    required List<ManHourSheetEntry> rows,
    required bool submitted,
  }) {
    sheet.setColumnWidthInPixels(1, 240);
    sheet.setColumnWidthInPixels(2, 120);
    sheet.setColumnWidthInPixels(3, 110);
    sheet.setColumnWidthInPixels(4, 110);
    sheet.setColumnWidthInPixels(5, 110);

    final title = sheet.getRangeByIndex(1, 1);
    title.setText('WEST DEPOTS MANHOUR SHEET');
    title.cellStyle.bold = true;
    title.cellStyle.fontSize = 14;

    final subtitle = sheet.getRangeByIndex(2, 1);
    subtitle.setText(
      'Depot: $depotName    Month: ${manHourMonthNames[month - 1]} $year    '
      'Status: ${submitted ? 'SUBMITTED' : 'DRAFT'}',
    );
    subtitle.cellStyle.bold = true;

    const headers = <String>[
      'NAMES',
      'NO. OF WORKER',
      'NO. OF DAYS',
      'NO. OF HOURS',
      'TOTAL',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(3, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = _headerFill;
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
    }

    var row = 4;
    var workers = 0;
    var manHours = 0;

    for (final category in ManHourCategory.values) {
      final categoryRows =
          rows.where((r) => r.category == category).toList(growable: false);
      if (categoryRows.isEmpty) continue;

      final section = sheet.getRangeByIndex(row, 1);
      section.setText(category.label.toUpperCase());
      section.cellStyle.bold = true;
      section.cellStyle.backColor = _sectionFill;
      row++;

      for (final entry in categoryRows) {
        sheet.getRangeByIndex(row, 1).setText(
              entry.entryName.trim().isEmpty
                  ? category.label
                  : entry.entryName.trim(),
            );
        sheet.getRangeByIndex(row, 2).setNumber(entry.workerCount.toDouble());
        sheet.getRangeByIndex(row, 3).setNumber(entry.daysWorked.toDouble());
        sheet.getRangeByIndex(row, 4).setNumber(entry.hoursPerDay.toDouble());
        sheet.getRangeByIndex(row, 5).setNumber(entry.total.toDouble());
        workers += entry.workerCount;
        manHours += entry.total;
        row++;
      }
    }

    if (rows.isEmpty) {
      sheet.getRangeByIndex(row, 1).setText('No entries recorded');
      row++;
    }

    final totalLabel = sheet.getRangeByIndex(row, 1);
    totalLabel.setText('TOTAL');
    totalLabel.cellStyle.bold = true;
    totalLabel.cellStyle.backColor = _totalFill;
    final totalWorkers = sheet.getRangeByIndex(row, 2);
    totalWorkers.setNumber(workers.toDouble());
    totalWorkers.cellStyle.bold = true;
    totalWorkers.cellStyle.backColor = _totalFill;
    final totalHours = sheet.getRangeByIndex(row, 5);
    totalHours.setNumber(manHours.toDouble());
    totalHours.cellStyle.bold = true;
    totalHours.cellStyle.backColor = _totalFill;
    row += 2;

    final summaryTitle = sheet.getRangeByIndex(row, 1);
    summaryTitle.setText('SUMMARY');
    summaryTitle.cellStyle.bold = true;
    row++;
    sheet.getRangeByIndex(row, 1).setText('Total Man Hours');
    sheet.getRangeByIndex(row, 2).setNumber(manHours.toDouble());
    row++;
    sheet.getRangeByIndex(row, 1).setText('Total Workers');
    sheet.getRangeByIndex(row, 2).setNumber(workers.toDouble());
    row++;
    sheet.getRangeByIndex(row, 1).setText('Entries');
    sheet.getRangeByIndex(row, 2).setNumber(rows.length.toDouble());
  }

  /// Lays out the cross-depot summary sheet.
  static void _writeSummarySheet(
    xlsio.Worksheet sheet, {
    required int year,
    required int month,
    required Map<String, List<ManHourSheetEntry>> sheets,
    required Set<String> submittedDepots,
  }) {
    sheet.setColumnWidthInPixels(1, 220);
    sheet.setColumnWidthInPixels(2, 120);
    sheet.setColumnWidthInPixels(3, 120);
    sheet.setColumnWidthInPixels(4, 140);

    final title = sheet.getRangeByIndex(1, 1);
    title.setText('WEST DEPOTS MANHOUR SUMMARY');
    title.cellStyle.bold = true;
    title.cellStyle.fontSize = 14;

    sheet.getRangeByIndex(2, 1).setText(
      'Month: ${manHourMonthNames[month - 1]} $year    Depots: ${corporateDepots.length}',
    );

    const headers = <String>[
      'DEPOT',
      'NO. OF WORKER',
      'TOTAL MAN HOURS',
      'STATUS',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(4, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = _headerFill;
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.hAlign = xlsio.HAlignType.center;
    }

    var row = 5;
    var grandWorkers = 0;
    var grandHours = 0;
    for (final depotName in corporateDepots) {
      final rows = sheets[depotName] ?? const <ManHourSheetEntry>[];
      final workers = rows.fold(0, (a, e) => a + e.workerCount);
      final hours = rows.fold(0, (a, e) => a + e.total);
      grandWorkers += workers;
      grandHours += hours;

      sheet.getRangeByIndex(row, 1).setText(depotName);
      sheet.getRangeByIndex(row, 2).setNumber(workers.toDouble());
      sheet.getRangeByIndex(row, 3).setNumber(hours.toDouble());
      sheet.getRangeByIndex(row, 4).setText(
            submittedDepots.contains(depotName) ? 'SUBMITTED' : 'DRAFT',
          );
      row++;
    }

    final label = sheet.getRangeByIndex(row, 1);
    label.setText('TOTAL');
    label.cellStyle.bold = true;
    label.cellStyle.backColor = _totalFill;
    final workersCell = sheet.getRangeByIndex(row, 2);
    workersCell.setNumber(grandWorkers.toDouble());
    workersCell.cellStyle.bold = true;
    workersCell.cellStyle.backColor = _totalFill;
    final hoursCell = sheet.getRangeByIndex(row, 3);
    hoursCell.setNumber(grandHours.toDouble());
    hoursCell.cellStyle.bold = true;
    hoursCell.cellStyle.backColor = _totalFill;
  }

  static Future<File> _save(xlsio.Workbook workbook, String fileName) async {
    final bytes = workbook.saveAsStream();
    workbook.dispose();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Resolves a corporate depot label to the depot name used in the app.
  ///
  /// Depot names in the database are not spelled the same way as the labels
  /// in the corporate template ("Osogbo" against "OSHOGBO"), so the match
  /// falls back to a normalised and then an edit-distance comparison.
  static String? resolveDepotName(
    String corporateName,
    Iterable<String> knownNames,
  ) {
    final known = knownNames.toList(growable: false);
    final target = _normalise(corporateName);
    for (final name in known) {
      if (_normalise(name) == target) return name;
    }
    for (final name in known) {
      final value = _normalise(name);
      if (value.contains(target) || target.contains(value)) return name;
    }
    for (final name in known) {
      if (_distance(_normalise(name), target) <= 2) return name;
    }
    return null;
  }

  /// Maps a depot name as stored in the database onto the corporate label.
  ///
  /// Returns the original name when the depot is not part of the corporate
  /// template, so no depot is silently dropped from an export.
  static String corporateLabelFor(String depotName) {
    for (final corporate in corporateDepots) {
      if (_normalise(corporate) == _normalise(depotName)) return corporate;
    }
    for (final corporate in corporateDepots) {
      final a = _normalise(corporate);
      final b = _normalise(depotName);
      if (a.contains(b) || b.contains(a)) return corporate;
    }
    for (final corporate in corporateDepots) {
      if (_distance(_normalise(corporate), _normalise(depotName)) <= 2) {
        return corporate;
      }
    }
    return depotName;
  }

  static String _normalise(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '')
      .replaceAll('H', '');

  static int _distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty || b.isEmpty) return a.length + b.length;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        final deletion = previous[j + 1] + 1;
        final insertion = current[j] + 1;
        final substitution = previous[j] + cost;
        current[j + 1] = deletion < insertion
            ? (deletion < substitution ? deletion : substitution)
            : (insertion < substitution ? insertion : substitution);
      }
      previous = current;
    }
    return previous[b.length];
  }

  /// Excel sheet names are capped at 31 characters and cannot hold []:*?/\.
  static String _safeSheetName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    if (cleaned.isEmpty) return 'Sheet';
    return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
  }

  static String _slug(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
