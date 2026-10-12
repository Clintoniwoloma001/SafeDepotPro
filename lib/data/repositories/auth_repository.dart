// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';
import '../models/models.dart';

/// Outcome of an authentication attempt.
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess(this.profile);
  final Profile profile;
}

class AuthFailure extends AuthResult {
  const AuthFailure(this.message);
  final String message;
}

/// Owns everything auth-related: sign-in, sign-out, session restore and the
/// profile row that carries the user's role and depot.
///
/// Note on privilege: this class never writes `profiles.role`. The mobile app
/// has no legitimate reason to change a role, and RLS makes it impossible
/// anyway. Role changes are performed by an administrator through the web
/// console or a service-role migration.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static const profilesTable = 'profiles';

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Signs in with email and password, then loads the caller's profile.
  Future<AuthResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final userId = res.user?.id;
      if (userId == null) return const AuthFailure('No user on session.');

      final profile = await fetchProfile(userId);
      if (profile == null) {
        await _client.auth.signOut();
        return const AuthFailure(
          'Signed in, but no profile row exists for this account. '
          'Ask an administrator to create it before the account can use the app.',
        );
      }
      if (!profile.isActive) {
        await _client.auth.signOut();
        return const AuthFailure(
          'Your account has been deactivated. Contact your administrator.',
        );
      }
      return AuthSuccess(profile);
    } on AuthException catch (e) {
      return AuthFailure(_authMessage(e));
    } catch (e) {
      return AuthFailure('Unexpected error during sign-in: $e');
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Loads the caller's own profile.
  ///
  /// Returns null rather than throwing when the row is absent; the caller turns
  /// that into a user-visible message because the UI must never crash on a
  /// half-provisioned account.
  Future<Profile?> fetchProfile(String userId) async {
    try {
      final row = await _client.from(profilesTable).select().eq('id', userId).maybeSingle();
      if (row == null) return null;
      return Profile.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Restores the session that secure storage persisted, and re-reads the
  /// profile so role and depot changes take effect on relaunch.
  Future<Profile?> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    return fetchProfile(session.user.id);
  }

  static String _authMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Your email address has not been confirmed yet.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Too many attempts. Wait a moment before trying again.';
    }
    return e.message.isEmpty ? 'Sign-in failed.' : e.message;
  }
}

/// Human-readable capability checks derived from the profile role.
///
/// These mirror what the RLS policies allow, so the UI never offers an action
/// the database will reject. They are for presentation only — enforcement
/// lives in PostgreSQL.
extension UserRoleCapabilities on UserRole {
  bool get canManageSetup => isAdmin;

  bool get canApprove => isAdmin;

  bool get canSeeAllDepots =>
      this == UserRole.countryHead || this == UserRole.superadmin;
}
