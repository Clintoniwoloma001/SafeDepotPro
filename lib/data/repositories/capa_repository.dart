// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';
import '../../data/models/workflows.dart';

/// Corrective actions (CAPA) and the approval workflow that closes them.
///
/// Two properties are enforced here in addition to RLS:
///
///  1. Idempotency — every insert carries `client_request_id`, guarded by a
///     unique index, so a replayed offline queued action cannot duplicate.
///  2. Assignment integrity — `responsible_user_id`, `due_date`, `priority`
///     and `capa_number` cannot be changed by an assignee. Only `status`,
///     `completion_rate`, `proof_paths` and `completed_at` are assignee-owned.
///     The database trigger (migration 0018) rejects anything else.
class CapaRepository {
  CapaRepository(this._client);

  final SupabaseClient _client;

  static const table = 'capa';

  Future<List<Capa>> listCapa({
    CapaStatus? status,
    String? depotId,
    int limit = 200,
  }) async {
    var query = _client.from(table).select();
    if (status != null) {
      query = query.eq('status', status.wire);
    }
    final rows = await query.order('due_date', ascending: true).limit(limit);
    return rows.map<Capa>(Capa.fromJson).toList(growable: false);
  }

  Future<Capa> createCapa({
    required String depotId,
    required String title,
    required String description,
    required Priority priority,
    required String sourceType,
    required String idempotencyKey,
    String? sourceId,
    String? responsibleUserId,
    String? responsibleName,
    String? assignerName,
    String? rootCause,
    String? correctiveAction,
    DateTime? dueDate,
  }) async {
    final row = await _client
        .from(table)
        .insert({
          'depot_id': depotId,
          'title': title.trim(),
          'description': description.trim(),
          'priority': priority.wire,
          'source_type': sourceType,
          'source_id': sourceId,
          'responsible_user_id': responsibleUserId,
          'responsible_name': responsibleName,
          'assigner_name': assignerName,
          'root_cause': rootCause,
          'corrective_action': correctiveAction,
          'due_date': dueDate?.toIso8601String().split('T').first,
          'client_request_id': idempotencyKey,
        })
        .select()
        .single();
    return Capa.fromJson(row);
  }

  /// Progress update by the assignee.
  ///
  /// Deliberately restricted to the three assignee-owned columns. Attempting
  /// to edit `due_date`, `priority` or `responsible_user_id` here would be
  /// rejected by the `capa_assignee_guard` trigger.
  Future<void> updateProgress({
    required String id,
    required CapaStatus status,
    required int completionRate,
    required String completedByUserId,
  }) async {
    final payload = <String, dynamic>{
      'status': status.wire,
      'completion_rate': completionRate.clamp(0, 100),
      if (status == CapaStatus.closed) ...{
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'completed_by': completedByUserId,
      },
    };
    await _client.from(table).update(payload).eq('id', id);
  }

  /// Adds completion evidence (photos/signature) to an action.
  Future<void> attachProof({
    required String id,
    required List<String> proofPaths,
    String? signaturePath,
  }) async {
    await _client
        .from(table)
        .update({'proof_paths': proofPaths, '?signature_path': signaturePath})
        .eq('id', id);
  }
}
