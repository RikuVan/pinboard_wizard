import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../tokens/app_colors.dart';

/// Indeterminate spinner. Replaces macos_ui `ProgressCircle`.
/// The old default radius was 10; `size = radius * 2`.
///
/// Colour defaults to the surrounding text colour so it stays visible on any
/// surface (white inside a filled button, dark on a light canvas, light on a
/// dark canvas). Pass [color] to override.
class AppProgress extends StatelessWidget {
  const AppProgress({super.key, this.radius = 10, this.color});
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        DefaultTextStyle.of(context).style.color ??
        AppColors.label.resolveFrom(context);
    return GlassProgressIndicator.circular(
      size: radius * 2,
      color: resolved,
      quality: GlassQuality.standard,
    );
  }
}
