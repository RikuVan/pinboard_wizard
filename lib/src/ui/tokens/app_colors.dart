import 'package:flutter/cupertino.dart';

/// Color tokens replacing macos_ui's `MacosColors`.
/// All are `CupertinoDynamicColor` so `.resolveFrom(context)` and `.darkColor` work.
class AppColors {
  const AppColors._();

  static const CupertinoDynamicColor separator = CupertinoColors.separator;
  static const CupertinoDynamicColor label = CupertinoColors.label;
  static const CupertinoDynamicColor secondaryLabel =
      CupertinoColors.secondaryLabel;
  static const CupertinoDynamicColor tertiaryLabel =
      CupertinoColors.tertiaryLabel;

  static const CupertinoDynamicColor systemRed = CupertinoColors.systemRed;
  static const CupertinoDynamicColor systemOrange =
      CupertinoColors.systemOrange;
  static const CupertinoDynamicColor systemGreen = CupertinoColors.systemGreen;
  static const CupertinoDynamicColor systemBlue = CupertinoColors.systemBlue;
  static const CupertinoDynamicColor systemPurple =
      CupertinoColors.systemPurple;
  static const CupertinoDynamicColor systemGrey = CupertinoColors.systemGrey;
  static const CupertinoDynamicColor systemYellow =
      CupertinoColors.systemYellow;

  /// Brighter blue for link/accent TEXT on surfaces (lighter in dark for legibility).
  static const CupertinoDynamicColor linkText =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF0A66D8),
        darkColor: Color(0xFF4DA6FF),
      );

  /// Brighter violet for tag/label TEXT on surfaces.
  static const CupertinoDynamicColor violetText =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFF8E44AD),
        darkColor: Color(0xFFCF9CF2),
      );

  /// Accent (was `MacosColors.controlAccentColor`).
  static const CupertinoDynamicColor accent = CupertinoColors.systemBlue;

  /// Control surface (was `MacosColors.controlBackgroundColor`).
  static const CupertinoDynamicColor controlBackground =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFFFFFF),
        darkColor: Color(0xFF3A3A3C),
      );

  /// Window canvas (was `MacosTheme.of(context).canvasColor`).
  static const CupertinoDynamicColor canvas =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFECECEC),
        darkColor: Color(0xFF1E1E1E),
      );
}
