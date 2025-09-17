import 'package:flutter/material.dart';

/// A consistent app logo widget that can be used throughout the application
class AppLogo extends StatelessWidget {
  /// The size of the logo (width and height will be equal)
  final double size;

  /// Optional fit property for how the image should fit within its bounds
  final BoxFit fit;

  /// Optional filter quality for the image
  final FilterQuality filterQuality;

  const AppLogo({
    super.key,
    this.size = 64,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
  });

  /// Small logo variant (24x24)
  const AppLogo.small({
    super.key,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
  }) : size = 24;

  /// Medium logo variant (48x48)
  const AppLogo.medium({
    super.key,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
  }) : size = 48;

  /// Large logo variant (128x128)
  const AppLogo.large({
    super.key,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
  }) : size = 128;

  /// Dialog logo variant (64x64) - commonly used in dialogs
  const AppLogo.dialog({
    super.key,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
  }) : size = 64;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/app_logo.png',
      width: size,
      height: size,
      fit: fit,
      filterQuality: filterQuality,
      semanticLabel: 'Pinboard Wizard Logo',
      errorBuilder: (context, error, stackTrace) {
        // Fallback if the logo asset fails to load
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.bookmark,
            size: size * 0.6,
            color: Theme.of(context).primaryColor,
          ),
        );
      },
    );
  }
}
