import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';

/// Common dialog utilities to eliminate duplicate dialog code throughout the app
class CommonDialogs {
  CommonDialogs._(); // Private constructor to prevent instantiation

  /// Show a standard error dialog with warning icon
  static Future<void> showError(
    BuildContext context,
    String message, {
    String title = 'Error',
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) async {
    if (!context.mounted) return;

    return showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: SizedBox(
          width: 64,
          height: 64,
          child: Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 64,
            color: MacosColors.systemOrangeColor,
          ),
        ),
        title: Text(title),
        message: Text(message),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: onPressed ?? () => Navigator.of(context).pop(),
          child: Text(buttonText),
        ),
      ),
    );
  }

  /// Show a confirmation dialog with custom actions
  static Future<bool> showConfirmation(
    BuildContext context,
    String message, {
    String title = 'Confirm',
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData? icon,
    Color? iconColor,
    bool isDestructive = false,
  }) async {
    if (!context.mounted) return false;

    final result = await showMacosAlertDialog<bool>(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: icon != null
            ? SizedBox(
                width: 64,
                height: 64,
                child: Icon(
                  icon,
                  size: 64,
                  color: iconColor ?? MacosColors.systemOrangeColor,
                ),
              )
            : const AppLogo.dialog(),
        title: Text(title),
        message: Text(message),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
      ),
    );

    return result ?? false;
  }

  /// Show a delete confirmation dialog
  static Future<bool> showDeleteConfirmation(
    BuildContext context,
    String itemName, {
    String? customMessage,
  }) async {
    final message =
        customMessage ??
        'Are you sure you want to delete "$itemName"?\n\nThis action cannot be undone.';

    return showConfirmation(
      context,
      message,
      title: 'Delete Confirmation',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      icon: CupertinoIcons.trash_fill,
      iconColor: MacosColors.systemRedColor,
      isDestructive: true,
    );
  }

  /// Show an info dialog with app logo
  static Future<void> showInfo(
    BuildContext context,
    String message, {
    String title = 'Information',
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) async {
    if (!context.mounted) return;

    return showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: const AppLogo.dialog(),
        title: Text(title),
        message: Text(message),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: onPressed ?? () => Navigator.of(context).pop(),
          child: Text(buttonText),
        ),
      ),
    );
  }

  /// Show a success dialog with green checkmark
  static Future<void> showSuccess(
    BuildContext context,
    String message, {
    String title = 'Success',
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) async {
    if (!context.mounted) return;

    return showMacosAlertDialog(
      context: context,
      builder: (_) => MacosAlertDialog(
        appIcon: SizedBox(
          width: 64,
          height: 64,
          child: Icon(
            CupertinoIcons.check_mark_circled_solid,
            size: 64,
            color: MacosColors.systemGreenColor,
          ),
        ),
        title: Text(title),
        message: Text(message),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          onPressed: onPressed ?? () => Navigator.of(context).pop(),
          child: Text(buttonText),
        ),
      ),
    );
  }

  /// Show a URL launch error dialog
  static Future<void> showUrlError(BuildContext context, String url) async {
    return showError(context, 'Could not launch $url', title: 'Link Error');
  }

  /// Show a network/service error dialog
  static Future<void> showServiceError(
    BuildContext context,
    String operation, {
    String? details,
  }) async {
    final message = details != null
        ? 'Failed to $operation: $details'
        : 'Failed to $operation. Please try again.';

    return showError(context, message);
  }
}
