// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/supabase/supabase_service.dart';
import 'providers.dart';

/// A row from `feature_flags`.
///
/// `roles` is empty when a flag applies to every role. `min_build` is compared
/// against the installed build number, so a flag can be introduced for a
/// future build without locking out the current one.
class FeatureFlag {
  const FeatureFlag({
    required this.key,
    required this.enabled,
    this.minBuild,
    this.roles = const [],
    this.message,
  });

  final String key;
  final bool enabled;
  final int? minBuild;
  final List<String> roles;
  final String? message;

  static FeatureFlag fromJson(Map<String, dynamic> j) => FeatureFlag(
        key: j['key'] as String,
        enabled: j['enabled'] == true,
        minBuild: (j['min_build'] as num?)?.toInt(),
        roles: (j['roles'] as List?)?.map((e) => e.toString()).toList(growable: false) ?? const [],
        message: j['message'] as String?,
      );
}

/// The set of enabled flag keys for the current user and build.
///
/// Deliberately a `Set<String>` rather than a map: the gate only asks "is this
/// on", and the extra fields belong to the settings screen that lists flags.
final featureFlagsProvider = NotifierProvider<
    FeatureFlagsNotifier, AsyncValue<Set<String>>>(FeatureFlagsNotifier.new);

/// Reads and caches the feature-flag table.
///
/// The cache is what makes a flag-driven module usable offline: the last
/// successful read is persisted, so a device that opens the app with no
/// network still honours the flags it saw last time. A stale flag cache is an
/// availability problem, not a data problem, which is why it is preferred over
/// failing closed and blanking modules on a flaky depot connection.
class FeatureFlagsNotifier extends Notifier<AsyncValue<Set<String>>> {
  @override
  AsyncValue<Set<String>> build() {
    // Deferred so build() returns the loading state before touching it.
    Future.microtask(_restore);
    return const AsyncValue.loading();
  }

  Ref get _ref => ref;

  static const _cacheKey = 'feature_flags_cache';
  static const _cacheAtKey = 'feature_flags_cached_at';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) _applyCache(cached);
    await refresh();
  }

  void _applyCache(String raw) {
    final decoded = (jsonDecode(raw) as List).cast<String>().toSet();
    state = AsyncValue.data(decoded);
  }

  /// Re-reads the flags from the server, falling back to the cache on failure.
  Future<void> refresh() async {
    try {
      final rows = await SupabaseService.client
          .from('feature_flags')
          .select()
          .eq('enabled', true);
      final flags = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(FeatureFlag.fromJson)
          .toList(growable: false);

      final keys = <String>{};
      for (final f in flags) {
        if (f.minBuild != null && f.minBuild! > _installedBuild) continue;
        if (f.roles.isNotEmpty && !f.roles.contains(_currentRole)) continue;
        keys.add(f.key);
      }

      state = AsyncValue.data(keys);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(keys.toList()));
      await prefs.setString(
        _cacheAtKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  int get _installedBuild => _ref.read(installedBuildProvider);
  String get _currentRole =>
      _ref.read(profileProvider).profile?.role.wire ?? 'USER';
}

/// Build number currently running, from the app manifest.
final installedBuildProvider = Provider<int>((ref) => 1);

/// Full flag rows for the settings screen.
final allFeatureFlagsProvider = FutureProvider<List<FeatureFlag>>((ref) async {
  final rows = await SupabaseService.client.from('feature_flags').select().order('key');
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map(FeatureFlag.fromJson)
      .toList(growable: false);
});

/// A row from `app_builds` (extended in migration 0019).
class RemoteBuild {
  const RemoteBuild({
    required this.buildNumber,
    required this.version,
    this.status,
    this.apkUrl,
    this.minSupportedBuild,
    this.releaseNotes,
    this.sha256,
  });

  final int buildNumber;
  final String version;
  final String? status;
  final String? apkUrl;
  final int? minSupportedBuild;
  final String? releaseNotes;
  final String? sha256;

  static RemoteBuild fromJson(Map<String, dynamic> j) => RemoteBuild(
        buildNumber: (j['build_number'] as num?)?.toInt() ?? 0,
        version: j['version'] as String? ?? '',
        status: j['status'] as String?,
        apkUrl: j['apk_url'] as String?,
        minSupportedBuild: (j['min_supported_build'] as num?)?.toInt(),
        releaseNotes: j['release_notes'] as String?,
        sha256: j['sha256'] as String?,
      );
}

/// The newest published build, used to decide whether to prompt for a full
/// update (patches are handled by Shorebird, this covers native changes).
final latestRemoteBuildProvider = FutureProvider<RemoteBuild?>((ref) async {
  final rows = await SupabaseService.client
      .from('app_builds')
      .select()
      .eq('application_id', 'com.clintoniwoloma.safedepot_pro')
      .order('build_number', ascending: false)
      .limit(1);
  final list = (rows as List).cast<Map<String, dynamic>>();
  if (list.isEmpty) return null;
  return RemoteBuild.fromJson(list.first);
});
