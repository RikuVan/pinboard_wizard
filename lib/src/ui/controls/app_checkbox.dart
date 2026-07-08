import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';

/// Checkbox. No `liquid_glass_widgets` equivalent — local glass-styled control.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent.resolveFrom(context);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: value ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: value ? accent : AppColors.separator.resolveFrom(context),
            width: 1,
          ),
        ),
        child: value
            ? const Icon(Icons.check, size: 13, color: Colors.white)
            : null,
      ),
    );
  }
}
