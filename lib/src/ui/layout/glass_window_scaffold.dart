import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Desktop shell: muted wallpaper backdrop + [sidebar] beside [body].
/// Replaces macos_ui `MacosWindow` + `ContentArea`.
class GlassWindowScaffold extends StatelessWidget {
  const GlassWindowScaffold({
    super.key,
    required this.sidebar,
    required this.body,
  });

  final Widget sidebar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallpaper =
        isDark ? 'assets/wallpaper_dark.png' : 'assets/wallpaper_light.png';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidGlassScope(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(wallpaper, fit: BoxFit.cover),
            Row(
              children: [
                sidebar,
                Expanded(child: body),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
