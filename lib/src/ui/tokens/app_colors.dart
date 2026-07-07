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
