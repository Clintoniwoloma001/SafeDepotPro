// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Audit trail.
///
/// The table is append-only: there is no update or delete path here, and RLS
/// only ever grants INSERT to a superadmin. Every state change the user can
/// see on screen should have a row here, written by the caller.
class AuditRepository {
  AuditRepository(this._client);

  final SupabaseClient _client;

  static const table = 'audit_log';

  Future<void> record({
    required String action,
    required String actorUserId,
    required String actorName,
    String? target,
    Map<String, dynamic> meta = const {},
  }) async {
    await _client.from(table).insert({
      'action': action,
      'actor_user_id': actorUserId,
      'actor_name': actorName,
      'target': target,
      'meta': meta,
    });
  }

  Future<List<AuditEntry>> recent({int limit = 100}) async {
    final rows = await _client
        .from(table)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map<AuditEntry>(AuditEntry.fromJson).toList(growable: false);
  }
}

/// In-app notifications.
///
/// Rows are targeted at a single user, so a supervisor never sees another
/// person's notifications.
class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  static const table = 'notifications';

  Future<List<AppNotification>> forUser(String userId, {int limit = 50}) async {
    final rows = await _client
        .from(table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map<AppNotification>(AppNotification.fromJson)
        .toList(growable: false);
  }

  Future<int> unreadCount(String userId) async {
    final rows = await _client
        .from(table)
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return rows.length;
  }

  Future<void> markRead(String id) =>
      _client.from(table).update({'is_read': true}).eq('id', id);

  Future<void> markAllRead(String userId) => _client
      .from(table)
      .update({'is_read': true})
      .eq('user_id', userId)
      .eq('is_read', false);
}
