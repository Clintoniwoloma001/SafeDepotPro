// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/supabase/supabase_service.dart';
import 'build_integrity.dart';

/// Outcome of the server-side build gate (`assert_build_allowed`).
class BuildGateVerdict {
  const BuildGateVerdict({
    required this.allowed,
    required this.reason,
    this.channel,
  });

  final bool allowed;
  final String reason;
  final String? channel;

  static BuildGateVerdict fromJson(Map<String, dynamic> j) => BuildGateVerdict(
        allowed: j['allowed'] == true,
        reason: j['reason']?.toString() ?? 'unknown',
        channel: j['channel']?.toString(),
      );
}

/// Talks to the server-side build gate in migration 0018.
///
/// The important property is *where* the decision is made: `app_builds` has no
/// client write policy, so a leaked or tampered build cannot re-authorise
/// itself. Revoking a build is a single UPDATE on that table, which is also the
/// remote kill switch.
abstract final class BuildGate {
  static const applicationId = 'com.clintoniwoloma.safedepot_pro';
  static const table = 'app_builds';

  /// The app's own version, from its manifest. This is what the server compares
  /// against `app_builds.version` — never a value read back from the server.
  static Future<String> localVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Evaluates this build against the server allow-list.
  ///
  /// A network failure propagates: the caller decides whether an un-evaluable
  /// gate is acceptable for a read, and refuses sensitive writes rather than
  /// silently continuing.
  static Future<BuildGateVerdict> check({
    required String version,
    required String? certFingerprint,
  }) async {
    final client = SupabaseService.client;
    final res = await client.rpc<Map<String, dynamic>>(
      'assert_build_allowed',
      params: {
        'p_version': version,
        'p_cert_fingerprint': certFingerprint ?? '',
        'p_application_id': applicationId,
      },
    );
    return BuildGateVerdict.fromJson(res);
  }

  /// Convenience wrapper: reads the local version and device fingerprint and
  /// asks the server whether this build may act.
  static Future<BuildGateVerdict> evaluateLocal() async {
    final cert = await BuildIntegrity.signingCertificates();
    if (cert == null || cert.isEmpty) {
      // Not Android, or the platform channel is unavailable. Do not block a
      // legitimate non-Android build; the JWT still authenticates the session.
      return const BuildGateVerdict(
        allowed: true,
        reason: 'cert fingerprint unavailable on this platform',
      );
    }
    return check(
      version: await localVersion(),
      certFingerprint: cert,
    );
  }

  /// The allow-list for this application, newest first.
  ///
  /// Read-only. Exposed so the app can surface a minimum-version warning before
  /// the server begins rejecting writes.
  static Future<List<Map<String, dynamic>>> knownBuilds() async {
    return await SupabaseService.client
        .from(table)
        .select()
        .eq('application_id', applicationId)
        .order('registered_at', ascending: false);
  }
}

/// Gate verdict for the signed-in session.
final buildGateProvider = FutureProvider<BuildGateVerdict?>((ref) async {
  final client = SupabaseService.client;
  if (client.auth.currentSession == null) return null;
  return BuildGate.evaluateLocal();
});
