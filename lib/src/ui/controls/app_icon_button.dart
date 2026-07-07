import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Icon button. Replaces macos_ui `MacosIconButton`.
/// When `backgroundColor == Colors.transparent`, renders a plain icon button
/// (preserving the borderless look some call-sites request); otherwise a
/// `GlassIconButton`.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.size = 32,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (backgroundColor == Colors.transparent) {
      return IconButton(
        onPressed: onPressed,
        icon: icon,
        iconSize: size * 0.5,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
      );
    }
    return GlassIconButton(
      icon: icon,
      onPressed: onPressed,
      size: size,
      quality: GlassQuality.standard,
    );
  }
}
