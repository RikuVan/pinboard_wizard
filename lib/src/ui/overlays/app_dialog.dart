import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Alert dialog. Replaces macos_ui `MacosAlertDialog`. Local glass panel built
/// on `GlassContainer`.
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.appIcon,
    required this.title,
    this.message,
    required this.primaryButton,
    this.secondaryButton,
    this.suppress,
  });

  final Widget? appIcon;
  final Widget title;
  final Widget? message;
  final Widget primaryButton;
  final Widget? secondaryButton;
  final Widget? suppress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Material(
          type: MaterialType.transparency,
          child: GlassContainer(
            quality: GlassQuality.standard,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (appIcon != null) ...[appIcon!, const SizedBox(height: 12)],
                DefaultTextStyle.merge(
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  child: title,
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    child: message!,
                  ),
                ],
                const SizedBox(height: 20),
                primaryButton,
                if (secondaryButton != null) ...[
                  const SizedBox(height: 8),
                  secondaryButton!,
                ],
                if (suppress != null) ...[const SizedBox(height: 8), suppress!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Presents a dialog. Replaces macos_ui `showMacosAlertDialog`.
Future<T?> showAppAlertDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}
