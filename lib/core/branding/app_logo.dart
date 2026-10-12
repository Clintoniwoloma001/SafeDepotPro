// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

import 'package:flutter/material.dart';

import 'author_info.dart';

/// The SafeDepot Pro mark, drawn from the vector source rather than a bitmap.
///
/// The launcher icon and splash are raster assets in `assets/branding/`, but
/// the in-app logo is a [CustomPainter] so it stays sharp at any size, themes
/// with the title colour, and does not need a dev dependency.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
    this.badgeBackground = true,
  });

  final double size;

  /// Draws the rounded squared brand plate behind the mark, matching the
  /// launcher icon so the two read as the same brand.
  final bool badgeBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'SafeDepot Pro logo',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _LogoPainter(
            helmetColor: theme.colorScheme.onSurface,
            plateColor: theme.brightness == Brightness.dark
                ? const Color(0xFF1F1F1F)
                : const Color(0xFF1F1F1F),
            showPlate: badgeBackground,
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({
    required this.helmetColor,
    required this.plateColor,
    required this.showPlate,
  });

  final Color helmetColor;
  final Color plateColor;
  final bool showPlate;

  static const _red = Color(0xFFF60711);
  static const _white = Color(0xFFFFFFFF);
  static const _grey = Color(0xFF3A3A3A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showPlate) {
      // Rounded-square plate with a brand-red left half and grey right half,
      // mirroring the split shield in the launcher icon.
      final plate = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.04, h * 0.04, w * 0.92, h * 0.92),
            Radius.circular(w * 0.22),
          ),
        );
      canvas.drawPath(plate, Paint()..color = plateColor);

      final half = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.04, h * 0.04, w * 0.46, h * 0.92),
            Radius.circular(w * 0.22),
          ),
        );
      canvas.drawPath(half, Paint()..color = _red);
    }

    // The shield outline.
    final shield = Path()
      ..moveTo(w * 0.5, h * 0.30)
      ..lineTo(w * 0.82, h * 0.42)
      ..lineTo(w * 0.82, h * 0.58)
      ..cubicTo(w * 0.82, h * 0.68, w * 0.68, h * 0.78, w * 0.5, h * 0.84)
      ..cubicTo(w * 0.32, h * 0.78, w * 0.18, h * 0.68, w * 0.18, h * 0.58)
      ..lineTo(w * 0.18, h * 0.42)
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..color = _white
        ..strokeJoin = StrokeJoin.round,
    );

    // Depot / warehouse.
    final depot = Path()
      ..moveTo(w * 0.28, h * 0.46)
      ..lineTo(w * 0.42, h * 0.35)
      ..lineTo(w * 0.58, h * 0.46)
      ..lineTo(w * 0.58, h * 0.58)
      ..lineTo(w * 0.28, h * 0.58)
      ..close();
    canvas.drawPath(depot, Paint()..color = _white);
    final roof = Path()
      ..moveTo(w * 0.22, h * 0.47)
      ..lineTo(w * 0.42, h * 0.33)
      ..lineTo(w * 0.50, h * 0.39)
      ..lineTo(w * 0.42, h * 0.44)
      ..close();
    canvas.drawPath(roof, Paint()..color = _red);
    // Two stacked crates.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.31, h * 0.49, w * 0.06, h * 0.045),
      Paint()..color = _grey,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.44, h * 0.49, w * 0.06, h * 0.045),
      Paint()..color = _grey,
    );

    // Safety helmet.
    final helmet = Path()
      ..moveTo(w * 0.26, h * 0.63)
      ..quadraticBezierTo(w * 0.34, h * 0.55, w * 0.42, h * 0.63)
      ..lineTo(w * 0.26, h * 0.63)
      ..close();
    canvas.drawPath(helmet, Paint()..color = _white);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.24, h * 0.626, w * 0.20, h * 0.035),
      Paint()..color = _white,
    );

    // Compliance tick.
    final tick = Path()
      ..moveTo(w * 0.62, h * 0.66)
      ..lineTo(w * 0.68, h * 0.72)
      ..lineTo(w * 0.80, h * 0.56);
    canvas.drawPath(
      tick,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round
        ..color = _white,
    );

    // Leaf.
    final leaf = Path()
      ..moveTo(w * 0.56, h * 0.86)
      ..quadraticBezierTo(w * 0.78, h * 0.86, w * 0.82, h * 0.68)
      ..quadraticBezierTo(w * 0.62, h * 0.68, w * 0.56, h * 0.86)
      ..close();
    canvas.drawPath(leaf, Paint()..color = _white);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.helmetColor != helmetColor ||
      old.plateColor != plateColor ||
      old.showPlate != showPlate;
}

/// A horizontal lock-up: logo plus wordmark and byline.
class AppLogoLockup extends StatelessWidget {
  const AppLogoLockup({super.key, this.logoSize = 56});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SafeDepot Pro',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              kCreditLine,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
