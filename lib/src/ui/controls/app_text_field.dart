import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Text field. Replaces macos_ui `MacosTextField` (wraps `GlassTextField`).
/// `maxLines: null` (unbounded editors) maps to a very large line cap since
/// `GlassTextField.maxLines` is a non-nullable `int`.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.placeholderStyle,
    this.maxLines = 1,
    this.onChanged,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final TextStyle? placeholderStyle;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return GlassTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      placeholderStyle: placeholderStyle,
      maxLines: maxLines ?? 100000,
      onChanged: onChanged,
      suffixIcon: suffixIcon,
      onSuffixTap: onSuffixTap,
      obscureText: obscureText,
      quality: GlassQuality.standard,
    );
  }
}
