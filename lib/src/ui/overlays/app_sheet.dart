import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Modal sheet panel. Replaces macos_ui `MacosSheet`.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeight),
        child: Material(
          type: MaterialType.transparency,
          child: GlassContainer(quality: GlassQuality.standard, child: child),
        ),
      ),
    );
  }
}

/// Presents a modal sheet. Replaces macos_ui `showMacosSheet`.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}
