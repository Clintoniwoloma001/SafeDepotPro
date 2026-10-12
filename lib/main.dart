// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/build_integrity.dart';
import 'core/branding/unofficial_build_screen.dart';
import 'core/config/env_config.dart';
import 'core/config/config_error_screen.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/supabase/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A missing --dart-define-from-file must never crash. Show a clear screen and
  // never attempt to initialise Supabase without credentials.
  if (!EnvConfig.isComplete) {
    runApp(
      MaterialApp(
        title: 'SafeDepot Pro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: ConfigErrorScreen(missing: EnvConfig.missingHints),
      ),
    );
    return;
  }

  await SupabaseService.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabasePublishableKey,
  );

  // Integrity call site 1 of 3.
  //
  // A release build compiled without --dart-define=AUTHOR_HASH=… is treated as
  // unverified: an absent manifest must never read as a pass. Debug builds
  // also lack it, so this gate is enforced only in release (see build_integrity).
  final integrity = await BuildIntegrity.evaluate();
  final isUntampered = integrity.isUntampered;

  runApp(
    ProviderScope(
      child: SafeDepotApp(startBlocked: !isUntampered, blockedReason: integrity.firstFailure),
    ),
  );
}

class SafeDepotApp extends ConsumerWidget {
  const SafeDepotApp({super.key, required this.startBlocked, this.blockedReason});

  /// When true the app never reaches the router; the lock screen is shown
  /// instead. Set at startup when the authorship hash did not verify.
  final bool startBlocked;
  final String? blockedReason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (startBlocked) {
      // Deliberately no ProviderScope override: with no session there is
      // nothing to protect, and blocking here keeps the whole app inert.
      return MaterialApp(
        title: 'SafeDepot Pro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: UnofficialBuildScreen(
          reason: blockedReason ??
              'The authorship manifest for this build could not be verified.',
        ),
      );
    }

    return MaterialApp.router(
      title: 'SafeDepot Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
