import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Indeterminate spinner. Replaces macos_ui `ProgressCircle`.
/// The old default radius was 10; `size = radius * 2`.
class AppProgress extends StatelessWidget {
  const AppProgress({super.key, this.radius = 10});
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GlassProgressIndicator.circular(
      size: radius * 2,
      quality: GlassQuality.standard,
    );
  }
}
