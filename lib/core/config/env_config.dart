// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/foundation.dart';

/// Build-time configuration supplied via `--dart-define-from-file=env/app.json`.
///
/// The anon (publishable) key is a client-side key by design: it is safe to
/// ship in the app because every table is protected by Row Level Security.
/// The service-role key and the database password are never supplied here —
/// they are not safe on a client device.
///
/// If the config is absent the app shows [ConfigErrorScreen] rather than
/// crashing. This happens most often when running `flutter run` without the
/// required `--dart-define-from-file` flag.
class EnvConfig {
  const EnvConfig._();

  /// Supabase project URL, e.g. `https://<ref>.supabase.co`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pgyxrgolldmiaxazjsjp.supabase.co',
  );

  /// The publishable (formerly "anon") key.
  ///
  /// This is a client key by design and is safe to ship in the app: every
  /// table is protected by Row Level Security, so possession of this key
  /// grants no data access beyond what an authenticated, authorised user of a
  /// given role can already read. It must never be replaced with a
  /// service-role key — that key bypasses RLS and would hand the whole
  /// database to anyone who unzips the APK.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBneXhyZ29sbGRtaWF4YXpqc2pwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk5NzQwMzksImV4cCI6MjEwNTU1MDAzOX0.HoknjXqMXSxoMXCHp2jeD6lBW_WD-_74EQVnk8dUuj4',
  );

  /// True when both required values were supplied at build time.
  static bool get isComplete =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// True when the build is a debug build, used to decide how loudly to
  /// complain about a missing configuration.
  static bool get isDebug => kDebugMode;

  static String get missingHints {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];
    return missing.join(', ');
  }
}
