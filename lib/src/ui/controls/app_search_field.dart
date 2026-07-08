import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Search field. Replaces macos_ui `MacosSearchField` (wraps `GlassSearchBar`).
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.placeholder = 'Search',
    this.onChanged,
  });

  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSearchBar(
      controller: controller,
      placeholder: placeholder,
      onChanged: onChanged,
      quality: GlassQuality.standard,
    );
  }
}
