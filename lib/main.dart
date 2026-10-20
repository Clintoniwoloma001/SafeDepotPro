// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'core/branding/build_integrity.dart';
import 'core/branding/unofficial_build_screen.dart';
import 'core/config/env_config.dart';
import 'core/config/config_error_screen.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/supabase/supabase_service.dart';
import 'core/notifications/daily_task_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Shorebird for OTA updates
  final shorebird = ShorebirdUpdater();
  shorebird.checkForUpdate();

  // A missing --dart-define-from-file must never crash. Show a clear screen and
  // never attempt to initialise Supabase without credentials.
  if (!EnvConfig.isComplete) {
    runApp(
      MaterialApp(
        title: 'SafeDepot Pro',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: ConfigErrorScreen(missing: EnvConfig.missingHints),
      ),
    );
    return;
  }

  await SupabaseService.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabasePublishableKey,
  );

  // Local reminders for incomplete daily tasks.
  await DailyTaskNotifications.initialize();

  // Integrity call site 1 of 3 (see build_integrity.dart).
  //
  // A build compiled without AUTHOR_HASH is treated as unverified in release:
  // an absent manifest must never read as a pass. Debug builds have no manifest
  // to compare against, so they are allowed through with a note.
  final integrity = await BuildIntegrity.evaluate();
  final blockedReason = BuildIntegrity.startupBlockReason(integrity);

  runApp(
    ProviderScope(
      child: SafeDepotApp(blockedReason: blockedReason),
    ),
  );
}

class SafeDepotApp extends ConsumerWidget {
  const SafeDepotApp({super.key, this.blockedReason});

  /// Non-null when the integrity check failed; the app renders the lock screen
  /// instead of the router, so the whole app is inert.
  final String? blockedReason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(appThemeProvider);

    if (blockedReason != null) {
      // No router, no session: with no session there is nothing to protect.
      return MaterialApp(
        title: 'SafeDepot Pro',
        debugShowCheckedModeBanner: false,
        theme: themes.light,
        darkTheme: themes.dark,
        home: UnofficialBuildScreen(reason: blockedReason!),
      );
    }

    return MaterialApp.router(
      title: 'SafeDepot Pro',
      debugShowCheckedModeBanner: false,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: themes.mode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
