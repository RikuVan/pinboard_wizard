import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Toggle switch. Replaces macos_ui `MacosSwitch`. `mini: true` maps the old
/// `ControlSize.mini` to a smaller track.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.mini = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    return GlassSwitch(
      value: value,
      onChanged: onChanged,
      width: mini ? 40 : 58,
      height: mini ? 20 : 26,
      quality: GlassQuality.standard,
    );
  }
}
