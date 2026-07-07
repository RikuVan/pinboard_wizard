import 'package:flutter/cupertino.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';

class ValidatedSecretField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final String? helperText;
  final bool isValidating;
  final bool? isValid;
  final String? statusMessage;
  final VoidCallback? onPressed;
  final VoidCallback? onTestPressed;
  final String? validationIconTooltip;

  const ValidatedSecretField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.helperText,
    this.isValidating = false,
    this.isValid,
    this.statusMessage,
    this.onPressed,
    this.onTestPressed,
    this.validationIconTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: AppTextField(
            controller: controller,
            placeholder: placeholder,
            placeholderStyle: TextStyle(
              fontWeight: FontWeight.w400,
              color: CupertinoColors.placeholderText.withValues(alpha: 0.5),
            ),
            obscureText: true,
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: isValidating
                  ? const AppProgress()
                  : (isValid == null
                        ? const SizedBox.shrink()
                        : AppIconButton(
                            icon: Icon(
                              isValid == true
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.xmark_octagon_fill,
                              color: isValid == true
                                  ? AppColors.systemGreen
                                  : AppColors.systemRed,
                            ),
                            onPressed: onPressed,
                          )),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: TextStyle(fontSize: 11, color: CupertinoColors.systemGrey2),
          ),
        ],
      ],
    );
  }
}
