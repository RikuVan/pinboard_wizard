import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

extension ThemeExtensions on BuildContext {
  /// Returns appropriate secondary label color for current theme
  Color get secondaryLabelColor {
    return MacosTheme.of(this).brightness == Brightness.dark
        ? MacosColors.systemGrayColor.darkColor
        : MacosColors.secondaryLabelColor;
  }

  /// Returns appropriate tertiary label color for current theme
  Color get tertiaryLabelColor {
    return MacosTheme.of(this).brightness == Brightness.dark
        ? MacosColors.tertiaryLabelColor
        : MacosColors.secondaryLabelColor;
  }

  /// Returns appropriate helper text color for current theme
  Color get helperTextColor {
    return MacosTheme.of(this).brightness == Brightness.dark
        ? MacosColors.systemGrayColor
        : MacosColors.secondaryLabelColor;
  }

  /// Returns appropriate subtitle text color for current theme
  Color get subtitleTextColor {
    return MacosTheme.of(this).brightness == Brightness.dark
        ? MacosColors.systemGrayColor
        : MacosColors.secondaryLabelColor;
  }

  /// Returns appropriate URL text color for current theme
  Color get urlTextColor {
    return MacosTheme.of(this).brightness == Brightness.dark
        ? MacosColors.secondaryLabelColor.resolveFrom(this)
        : MacosColors.labelColor.withOpacity(0.75);
  }

  /// Returns whether the current theme is dark mode
  bool get isDarkMode => MacosTheme.of(this).brightness == Brightness.dark;
}
