// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/enums.dart';
import '../../data/models/workflows.dart';

/// Permits to work and their approval workflow.
///
/// Status transitions follow the schema enum: DRAFT → SUBMITTED →
/// APPROVED / REJECTED, with CANCELLED and COMPLETED as terminal exits.
/// Only an admin may approve or reject; the client enforces this by
/// gating the UI, and `permits_update` RLS enforces it on the server.
class PermitRepository {
  PermitRepository(this._client);

  final SupabaseClient _client;

  static const table = 'permits';

  Future<List<Permit>> listPermits({PermitStatus? status, int limit = 200}) async {
    var query = _client.from(table).select();
    if (status != null) {
      query = query.eq('status', status.wire);
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map<Permit>(Permit.fromJson).toList(growable: false);
  }

  Future<Permit> createPermit({
    required String depotId,
    required String jobTitle,
    required String permitType,
    required String idempotencyKey,
    String? jobDescription,
    String? location,
    DateTime? startDatetime,
    DateTime? endDatetime,
    List<String> attachmentPaths = const [],
  }) async {
    final row = await _client.from(table).insert({
      'depot_id': depotId,
      'job_title': jobTitle.trim(),
      'permit_type': permitType,
      'job_description': jobDescription,
      'location': location,
      'start_datetime': startDatetime?.toIso8601String(),
      'end_datetime': endDatetime?.toIso8601String(),
      'attachment_paths': attachmentPaths,
      'status': PermitStatus.submitted.wire,
      'client_request_id': idempotencyKey,
    }).select().single();
    return Permit.fromJson(row);
  }

  /// Approves a permit.
  ///
  /// `actorId` must be an admin per the `permits_update` policy; the write
  /// will simply fail if it is not, which the UI surfaces as an error.
  Future<void> approve(String id, String actorId) => _decide(id, PermitStatus.approved, actorId);

  /// Rejects a permit with a mandatory reason, which is what makes a rejection
  /// actionable rather than anonymous.
  Future<void> reject(String id, String actorId, String reason) =>
      _decide(id, PermitStatus.rejected, actorId, reason: reason);

  Future<void> _decide(
    String id,
    PermitStatus status,
    String actorId, {
    String? reason,
  }) async {
    await _client.from(table).update({
      'status': status.wire,
      'approved_at': DateTime.now().toUtc().toIso8601String(),
      'approved_by': actorId,
      if (reason != null) 'rejection_reason': reason.trim(),
    }).eq('id', id);
  }
}
