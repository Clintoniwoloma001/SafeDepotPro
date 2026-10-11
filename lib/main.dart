import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  runApp(const ProviderScope(child: SafeDepotApp()));
}

class SafeDepotApp extends ConsumerWidget {
  const SafeDepotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
