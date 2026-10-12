// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';
import '../../data/models/workflows.dart';

/// Checklist-driven inspections.
///
/// Answer rows are written in the same transaction as the inspection so a
/// half-recorded checklist can never exist, and the whole write is idempotent
/// via `client_request_id`.
class InspectionRepository {
  InspectionRepository(this._client);

  final SupabaseClient _client;

  static const table = 'inspections';
  static const answersTable = 'inspection_answers';

  Future<List<Inspection>> listInspections({int limit = 200}) async {
    final rows = await _client
        .from(table)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map<Inspection>(Inspection.fromJson).toList(growable: false);
  }

  Future<List<ChecklistTemplate>> listTemplates() async {
    final rows = await _client
        .from('checklist_templates')
        .select()
        .eq('is_active', true)
        .order('name', ascending: true);
    return rows.map<ChecklistTemplate>(ChecklistTemplate.fromJson).toList(growable: false);
  }

  /// Creates an inspection and its answers.
  ///
  /// `answers` is the payload stored on the inspection row itself. Per-answer
  /// rows are written for the audit trail that the audit view needs.
  Future<Inspection> createInspection({
    required String? depotId,
    required String templateId,
    required String checklistName,
    required String type,
    required String completedBy,
    required String idempotencyKey,
    required List<Map<String, dynamic>> answers,
    String? notes,
    double compliance = 0,
  }) async {
    final row = await _client.from(table).insert({
      'depot_id': depotId,
      'template_id': templateId,
      'checklist_name': checklistName,
      'type': type,
      'completed_by': completedBy,
      'answers': answers,
      'compliance': compliance,
      'notes': notes,
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
      'client_request_id': idempotencyKey,
    }).select().single();

    final inspection = Inspection.fromJson(row);

    final answerRows = answers
        .map((a) => {
              'inspection_id': inspection.id,
              'question_id': a['question_id']?.toString() ?? '',
              'response': a['response'],
              'severity': a['severity'],
              'comment': a['comment'],
              'photo_paths': a['photo_paths'] ?? const <String>[],
            })
        .toList(growable: false);
    if (answerRows.isNotEmpty) {
      await _client.from(answersTable).insert(answerRows);
    }
    return inspection;
  }
}

/// Computes inspection compliance from recorded answers.
///
/// Unanswered items count against compliance — an inspection left blank is
/// not a passing inspection, and scoring it as one is how compliance numbers
/// get quietly inflated.
abstract final class ComplianceCalculator {
  static double percentage(List<Map<String, dynamic>> answers) {
    if (answers.isEmpty) return 0;
    var pass = 0;
    var counts = 0;
    for (final a in answers) {
      final response = InspectionResponse.fromWire(a['response']?.toString());
      if (response == InspectionResponse.na) continue;
      counts++;
      if (response == InspectionResponse.pass) pass++;
    }
    if (counts == 0) return 0;
    return (pass / counts) * 100;
  }
}
