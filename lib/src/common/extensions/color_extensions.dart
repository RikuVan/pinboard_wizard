import 'package:flutter/material.dart';

extension ColorUtils on Color {
  /// Lightens the color by [amount].
  ///
  /// [amount] should be between 0.0 (no change) and 1.0 (white).
  Color lighten([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness(
      (hsl.lightness + amount).clamp(0.0, 1.0),
    );
    return hslLight.toColor();
  }

  /// Darkens the color by [amount].
  ///
  /// [amount] should be between 0.0 (no change) and 1.0 (black).
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
