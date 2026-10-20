// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Reads depots the signed-in user is allowed to see.
///
/// Which depots come back is decided by the `can_read_depot` RLS helper: a
/// `COUNTRY_HEAD`/`SUPERADMIN` sees everything, a `USER` only sees their own
/// depot and any depot they are covering via an active `stand_ins` row. The
/// client never constructs that filter — sending one would be a lie the
/// database simply ignores.
class DepotRepository {
  DepotRepository(this._client);

  final SupabaseClient _client;

  static const table = 'depots';

  Future<List<Depot>> listDepots({bool activeOnly = true}) async {
    var query = _client.from(table).select();
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('code', ascending: true);
    return rows.map<Depot>(Depot.fromJson).toList(growable: false);
  }

  /// Creates a depot. Requires an admin-capable session; `depots_insert` RLS
  /// rejects the write otherwise and the caller surfaces the error.
  Future<Depot> createDepot({
    required String code,
    required String name,
    String? city,
    String? region,
    double? latitude,
    double? longitude,
    int radiusMeters = 50,
    bool isActive = true,
  }) async {
    final row = await _client
        .from(table)
        .insert({
          'code': code.trim().toUpperCase(),
          'name': name.trim(),
          'city': city?.trim(),
          'region': region?.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'allowed_radius_meters': radiusMeters,
          'is_active': isActive,
        })
        .select()
        .single();
    return Depot.fromJson(row);
  }

  /// Updates a depot's geofence (and the human-editable descriptive fields).
  Future<void> updateDepotGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? name,
    String? city,
    String? region,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'allowed_radius_meters': radiusMeters,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (name != null) updates['name'] = name.trim();
    if (city != null) updates['city'] = city.trim();
    if (region != null) updates['region'] = region.trim();
    if (isActive != null) updates['is_active'] = isActive;
    await _client.from(table).update(updates).eq('id', id);
  }

  Future<List<DepotZone>> listZones(String depotId) async {
    final rows = await _client
        .from('depot_zones')
        .select()
        .eq('depot_id', depotId)
        .order('name', ascending: true);
    return rows.map<DepotZone>(DepotZone.fromJson).toList(growable: false);
  }

  Future<AppSettings?> settings() async {
    final row = await _client
        .from('app_settings')
        .select()
        .limit(1)
        .maybeSingle();
    return row == null ? null : AppSettings.fromJson(row);
  }
}

/// People directory used to assign corrective actions.
///
/// Only profiles the caller may read are returned; RLS scopes `profiles` to
/// authenticated users, and the depot visibility rules apply elsewhere.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const table = 'profiles';

  Future<List<Profile>> listAssignable({String? depotId}) async {
    var query = _client.from(table).select().isFilter('is_active', true);
    if (depotId != null) {
      query = query.eq('depot_id', depotId);
    }
    final rows = await query.order('full_name', ascending: true);
    return rows.map<Profile>(Profile.fromJson).toList(growable: false);
  }
}
