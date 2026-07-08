import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'app_colors.dart';

ThemeData appLightTheme() => ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorSchemeSeed: AppColors.accent.color,
      scaffoldBackgroundColor: Colors.transparent,
    );

ThemeData appDarkTheme() => ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorSchemeSeed: AppColors.accent.color,
      scaffoldBackgroundColor: Colors.transparent,
    );

/// App-wide glass defaults passed to `LiquidGlassWidgets.wrap(theme:)`.
GlassThemeData appGlassTheme() => GlassThemeData.simple(
      blur: 8,
      thickness: 24,
      quality: GlassQuality.standard,
    );
