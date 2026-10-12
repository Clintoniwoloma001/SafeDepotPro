// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/app_logo.dart';
import '../../core/router/routes.dart';
import '../../providers/providers.dart';

/// Flutter splash shown immediately after the native splash hands over.
///
/// It runs the real session check rather than sleeping — the router redirect
/// already decides login vs home, so the only work here is to hold the frame
/// long enough for the logo to be visible. A fixed artificial delay would add
/// the delay to every cold start with no benefit.
class FlutterSplash extends ConsumerStatefulWidget {
  const FlutterSplash({super.key});

  @override
  ConsumerState<FlutterSplash> createState() => _FlutterSplashState();
}

class _FlutterSplashState extends ConsumerState<FlutterSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  @override
  void initState() {
    super.initState();
    _navigateWhenReady();
  }

  void _navigateWhenReady() {
    // The profile state settles on its own; the listener below fires once it
    // is no longer loading. That is the earliest honest moment to route.
    ref.listenManual(profileProvider, (previous, next) {
      if (!next.isLoading && mounted) {
        final target =
            next.isSignedIn ? Routes.home : Routes.login;
        context.go(target);
      }
    });

    // If the state is already resolved (a warm start with a cached session)
    // the listener never fires, so route immediately after the animation.
    final current = ref.read(profileProvider);
    if (!current.isLoading) {
      Future<void>.delayed(const Duration(milliseconds: 520), () {
        if (!mounted) return;
        context.go(current.isSignedIn ? Routes.home : Routes.login);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Fade-in then a very slight scale-up. Subtle on purpose: this is
          // seen on every cold start and irritation is cumulative.
          final t = Curves.easeOutCubic.transform(_controller.value);
          return Center(
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.94 + (0.06 * t),
                child: const AppLogo(size: 120),
              ),
            ),
          );
        },
      ),
    );
  }
}
