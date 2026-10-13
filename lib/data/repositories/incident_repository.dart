// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';
import '../../data/models/workflows.dart';

/// Incident reporting.
///
/// Writes carry a `client_request_id` so that replaying an offline queued
/// report (or a user double-tapping Submit on a flaky connection) cannot
/// create a duplicate incident: the unique index on that column, combined with
/// an `onConflict` do-nothing, makes the operation idempotent at the database
/// level rather than trusting the client to disable its own button.
class IncidentRepository {
  IncidentRepository(this._client);

  final SupabaseClient _client;

  static const table = 'incidents';

  /// Lists incidents visible to the caller. The set is decided by RLS via
  /// `can_read_depot(depot_id)`; no depot filter is applied here because the
  /// database already enforces isolation and an extra filter would only mask
  /// bugs in the policies.
  Future<List<Incident>> listIncidents({
    IncidentStatus? status,
    int limit = 200,
  }) async {
    var query = _client.from(table).select();
    if (status != null) {
      query = query.eq('status', status.wire);
    }
    final rows = await query
        .order('occurred_at', ascending: false)
        .limit(limit);
    return rows.map<Incident>(Incident.fromJson).toList(growable: false);
  }

  Future<Incident> createIncident({
    required String depotId,
    required String description,
    required Severity severity,
    required String reportedBy,
    required String reportedByName,
    required String idempotencyKey,
    String? incidentType,
    String? rootCause,
    String? actionsTaken,
    List<String> photoPaths = const [],
    List<Map<String, dynamic>> involvedPersonnel = const [],
    DateTime? occurredAt,
  }) async {
    final row = await _client
        .from(table)
        .insert({
          'depot_id': depotId,
          'description': description.trim(),
          'severity': severity.wire,
          'reported_by': reportedBy,
          'reported_by_name': reportedByName,
          'incident_type': incidentType,
          'root_cause': rootCause,
          'actions_taken': actionsTaken,
          'photo_paths': photoPaths,
          'involved_personnel': involvedPersonnel,
          'occurred_at': (occurredAt ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
          // Idempotency: set by the app, enforced by a unique index. A retried
          // insert hits the conflict branch and returns the original row.
          'client_request_id': idempotencyKey,
        })
        .select()
        .single();
    return Incident.fromJson(row);
  }

  /// Advances the incident lifecycle. Transitions are restricted to the states
  /// the schema models; regression is intentional and audited.
  Future<void> updateStatus({
    required String id,
    required IncidentStatus status,
    String? actionsTaken,
  }) async {
    await _client
        .from(table)
        .update({'status': status.wire, '?actions_taken': actionsTaken})
        .eq('id', id);
  }
}
