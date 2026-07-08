import 'package:flutter/cupertino.dart';
import '../tokens/app_colors.dart';

/// Continuous slider. Replaces macos_ui `MacosSlider`. Wraps `CupertinoSlider`
/// so it needs no Material ancestor and matches the Cupertino aesthetic.
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlider(
      value: value,
      min: min,
      max: max,
      activeColor: AppColors.accent.resolveFrom(context),
      onChanged: onChanged,
    );
  }
}
