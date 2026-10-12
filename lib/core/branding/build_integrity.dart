// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'author_info.dart';

/// Result of one individual integrity check.
class IntegrityCheckDetail {
  const IntegrityCheckDetail(this.label, this.passed);

  final String label;
  final bool passed;
}

/// Aggregate integrity verdict for this process.
class BuildIntegrityReport {
  const BuildIntegrityReport({
    required this.isUntampered,
    required this.details,
  });

  /// False when the authorship constants do not match the value baked in at
  /// build time. Callers must block login on this.
  final bool isUntampered;

  /// Per-check breakdown, surfaced on the About page.
  final List<IntegrityCheckDetail> details;

  String? get firstFailure =>
      details.where((d) => !d.passed).map((d) => d.label).firstOrNull;
}

/// Authorship integrity gate.
///
/// Threat model, stated plainly: anything computed inside a Dart process can be
/// altered by someone who repackages the APK, so this is a *speed bump and a
/// tripwire*, not a guarantee. It raises the cost of a rebranded clone and,
/// more usefully, produces an auditable signal. The authoritative gate is
/// server-side — see `assert_build_allowed` in migration 0018 and
/// [BuildGateRepository], which decide on data the attacker cannot reach.
///
/// Layering: the same check is invoked from several call sites (startup, login,
/// settings) so that patching one out leaves the others live, and every
/// evaluation appends to the server-side `build_assertions` log.
abstract final class BuildIntegrity {
  /// SHA-256 over the canonical authorship tuple, injected at build time by
  /// `--dart-define`. See docs/RELEASING.md for how it is produced.
  static const String expectedHash = String.fromEnvironment('AUTHOR_HASH');

  /// Overridable so tests can inject a tampered constant set.
  @visibleForTesting
  static Future<String> Function() computeHash = _computeHash;

  static BuildIntegrityReport? _cached;

  /// Evaluates the authorship hash.
  ///
  /// The result is cached because this is called on hot paths; pass
  /// `force: true` to re-evaluate, which the About page does so the displayed
  /// verdict always matches this launch.
  static Future<BuildIntegrityReport> evaluate({bool force = false}) async {
    if (!force && _cached != null) return _cached!;

    final details = <IntegrityCheckDetail>[];

    if (expectedHash.isEmpty) {
      // A release build that forgot AUTHOR_HASH must never read as verified,
      // so it fails closed. A debug build has no manifest to compare against,
      // so it is allowed through with a note — otherwise every local run would
      // need the flag added by hand.
      if (kReleaseMode) {
        details.add(
          const IntegrityCheckDetail(
            'Build manifest hash is absent — this is not a signed release build.',
            false,
          ),
        );
        _cached = BuildIntegrityReport(isUntampered: false, details: details);
        return _cached!;
      }
      details.add(
        const IntegrityCheckDetail(
          'Debug build: no build manifest hash to verify against.',
          true,
        ),
      );
      _cached = BuildIntegrityReport(isUntampered: true, details: details);
      return _cached!;
    }

    final actual = await computeHash();
    final match = actual == expectedHash;
    details.add(
      IntegrityCheckDetail(
        match
            ? 'Authorship constants match the signed build manifest.'
            : 'Authorship constants differ from the signed build manifest.',
        match,
      ),
    );

    _cached = BuildIntegrityReport(isUntampered: match, details: details);
    return _cached!;
  }

  /// Maps an integrity verdict to the startup outcome.
  ///
  /// Returns null when the app may run normally, or a human-readable reason
  /// when it must show [UnofficialBuildScreen] instead. Kept pure and separate
  /// from `evaluate` so the wiring in `main.dart` can be tested without
  /// booting the whole app.
  static String? startupBlockReason(BuildIntegrityReport report) {
    if (report.isUntampered) return null;
    return report.firstFailure ??
        'The authorship manifest for this build could not be verified.';
  }

  /// Discards the cached verdict. Used by tests and after a forced re-check.
  static void invalidateCache() => _cached = null;

  /// The hashed message is a fixed-order, pipe-joined tuple over the exact
  /// values in [author_info]. Any edit to any constant changes the digest.
  static String canonicalPayload() => [
        kAuthorName,
        kAuthorTitle,
        kCopyrightHolder,
        kContactPhone,
        kCreditLine,
        kFullAttribution,
      ].join('|');

  static Future<String> _computeHash() async =>
      sha256.convert(utf8.encode(canonicalPayload())).toString();

  /// Reads the platform signing certificate fingerprint.
  ///
  /// Returns null when the platform channel is unavailable (web, desktop, or a
  /// test harness) — callers must treat "unknown" as a distinct state from
  /// "mismatched" and defer to the server-side gate rather than blocking.
  static Future<String?> signingCertificates() async {
    try {
      final channel = const MethodChannel('com.clintoniwoloma.safedepot_pro/integrity');
      final result = await channel.invokeMethod<String>('signingCertificates');
      return result;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Convenience predicate used by the guard widgets.
extension BuildIntegrityReportX on BuildIntegrityReport {
  bool get isUntamperedAndKnown => isUntampered;
}
