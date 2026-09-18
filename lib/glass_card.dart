// lib/glass_card.dart
//
// Frosted panel. The important detail: BackdropFilter is only inserted when
// blur is enabled AND there is a background image behind it. Blurring a flat
// gradient produces the same flat gradient at real GPU cost -- v2 ran four
// stacked blur passes on a Pixel 4a and dropped 185 frames on startup, which
// is what made touch feel laggy and unresponsive.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final AppSettings settings;
  final AppPalette palette;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? borderOverride;

  const GlassCard({
    super.key,
    required this.child,
    required this.settings,
    required this.palette,
    this.radius = 24,
    this.padding = const EdgeInsets.all(14),
    this.borderOverride,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderOverride ?? palette.cardBorder,
          width: borderOverride != null ? 1.6 : 1,
        ),
      ),
      child: child,
    );

    // Only spend GPU on a real blur when it will actually be visible.
    final worthBlurring = settings.blurEnabled &&
        settings.hasBackgroundImage &&
        settings.blurIntensity > 0.5;

    if (!worthBlurring) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: body,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: settings.blurIntensity,
          sigmaY: settings.blurIntensity,
        ),
        child: body,
      ),
    );
  }
}
