// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [LocalStorage] implementation backed by [FlutterSecureStorage].
///
/// The default Supabase Flutter session store is plain SharedPreferences. We
/// override it so the session blob (which contains the access and refresh
/// tokens) lives in the platform keystore — iOS Keychain, Android
/// Keystore-backed EncryptedSharedPreferences — rather than in world-readable
/// app prefs, which matters on rooted or jailbroken devices.
///
/// The methods are named after the tokens by accident of the base class API;
/// we store and return the whole persisted session JSON, exactly like
/// [SharedPreferencesLocalStorage] does.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _sessionKey = 'supabase_session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(key: _sessionKey))?.isNotEmpty ?? false;

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);
}
