import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../tokens/app_colors.dart';

enum AppButtonSize { large, regular, small, mini }

/// Text push-button on a glass surface. Replaces macos_ui `PushButton`.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.secondary = false,
    this.color,
    this.size = AppButtonSize.regular,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool secondary;
  final Color? color;
  final AppButtonSize size;

  EdgeInsets get _padding {
    switch (size) {
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case AppButtonSize.regular:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case AppButtonSize.mini:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final accent = color ?? AppColors.accent.resolveFrom(context);
    final fill = secondary
        ? AppColors.controlBackground.resolveFrom(context)
        : accent;
    final fg = secondary ? AppColors.label.resolveFrom(context) : Colors.white;
    final content = DefaultTextStyle.merge(
      style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w500),
      child: IconTheme.merge(
        data: IconThemeData(color: fg, size: 16),
        child: child,
      ),
    );
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GlassContainer(
        quality: GlassQuality.standard,
        alignment: Alignment.center,
        padding: _padding,
        shape: const LiquidRoundedSuperellipse(borderRadius: 8),
        settings: LiquidGlassSettings(
          glassColor: fill.withValues(alpha: secondary ? 0.5 : 0.9),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: enabled ? onPressed : null,
            child: content,
          ),
        ),
      ),
    );
  }
}
