import 'package:flutter/material.dart';
import 'app_colors.dart';

extension AppThemeContext on BuildContext {
  Brightness get appBrightness => Theme.of(this).brightness;
  bool get isDarkMode => appBrightness == Brightness.dark;

  Color get canvasColor => AppColors.canvas.resolveFrom(this);

  Color get secondaryLabelColor => isDarkMode
      ? AppColors.systemGrey.darkColor
      : AppColors.secondaryLabel.resolveFrom(this);

  Color get tertiaryLabelColor => isDarkMode
      ? AppColors.tertiaryLabel.resolveFrom(this)
      : AppColors.secondaryLabel.resolveFrom(this);

  Color get helperTextColor => isDarkMode
      ? AppColors.systemGrey.resolveFrom(this)
      : AppColors.secondaryLabel.resolveFrom(this);

  Color get subtitleTextColor => helperTextColor;

  Color get urlTextColor => isDarkMode
      ? AppColors.secondaryLabel.resolveFrom(this)
      : AppColors.label.resolveFrom(this).withValues(alpha: 0.75);
}
