import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';

/// Radio button. No `liquid_glass_widgets` equivalent — local control.
class AppRadio<T> extends StatelessWidget {
  const AppRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final accent = AppColors.accent.resolveFrom(context);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(value),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? accent : AppColors.separator.resolveFrom(context),
            width: 1.5,
          ),
        ),
        child: selected
            ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
