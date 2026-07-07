import 'package:flutter/material.dart';

/// Tooltip. No `liquid_glass_widgets` equivalent — wraps Flutter `Tooltip`.
class AppTooltip extends StatelessWidget {
  const AppTooltip({super.key, required this.message, required this.child});
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(message: message, child: child);
}
