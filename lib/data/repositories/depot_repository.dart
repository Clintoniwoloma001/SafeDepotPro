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

  Future<List<DepotZone>> listZones(String depotId) async {
    final rows = await _client
        .from('depot_zones')
        .select()
        .eq('depot_id', depotId)
        .order('name', ascending: true);
    return rows.map<DepotZone>(DepotZone.fromJson).toList(growable: false);
  }

  Future<AppSettings?> settings() async {
    final row = await _client.from('app_settings').select().limit(1).maybeSingle();
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
