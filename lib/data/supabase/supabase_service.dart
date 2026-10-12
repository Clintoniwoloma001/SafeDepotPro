// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_session_storage.dart';

/// Central bootstrap for the shared [SupabaseClient].
///
/// `Supabase.initialize` must be called exactly once before any query. This
/// class makes that explicit, and wires the session store to
/// [SecureSessionStorage] so the access/refresh tokens live in the platform
/// keystore rather than in plain SharedPreferences.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize({
    required String url,
    required String publishableKey,
  }) async {
    if (_initialized) return;
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: FlutterAuthClientOptions(
        // Sessions persist across restarts so a field user is not thrown back
        // to the login screen every time the app is backgrounded.
        localStorage: const SecureSessionStorage(
          FlutterSecureStorage(aOptions: AndroidOptions()),
        ),
        persistSession: true,
        autoRefreshToken: true,
      ),
      debug: false,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
