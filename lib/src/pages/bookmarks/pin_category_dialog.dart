import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/common/widgets/app_logo.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';

class PinCategoryDialog extends StatefulWidget {
  final bool isCurrentlyPinned;
  final String? currentCategory;
  final List<Post> allPosts;

  const PinCategoryDialog({
    super.key,
    required this.isCurrentlyPinned,
    this.currentCategory,
    required this.allPosts,
  });

  @override
  State<PinCategoryDialog> createState() => _PinCategoryDialogState();
}

class _PinCategoryDialogState extends State<PinCategoryDialog> {
  final TextEditingController _categoryController = TextEditingController();
  bool _useCategory = false;
  List<String> _existingCategories = [];

  @override
  void initState() {
    super.initState();
    _extractExistingCategories();

    if (widget.isCurrentlyPinned && widget.currentCategory != null) {
      _useCategory = true;
      _categoryController.text = _formatCategoryForInput(
        widget.currentCategory!,
      );
    }
  }

  void _extractExistingCategories() {
    final categories = <String>{};
    for (final post in widget.allPosts) {
      if (post.isPinned && post.pinCategory != null) {
        categories.add(post.pinCategory!);
      }
    }
    _existingCategories = categories.toList()..sort();
  }

  String _formatCategoryForInput(String category) {
    return category.toLowerCase().replaceAll(' ', '-');
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MacosAlertDialog(
      appIcon: const AppLogo.dialog(),
      title: Text(widget.isCurrentlyPinned ? 'Update Pin' : 'Pin Bookmark'),
      message: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category toggle
            Row(
              children: [
                MacosCheckbox(
                  value: _useCategory,
                  onChanged: (value) => setState(() => _useCategory = value),
                ),
                const SizedBox(width: 8),
                const Text('Use category'),
              ],
            ),

            // Category input
            if (_useCategory) ...[
              const SizedBox(height: 12),
              MacosTextField(
                controller: _categoryController,
                placeholder: 'Enter category name',
                maxLines: 1,
              ),

              // Existing categories as chips
              if (_existingCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Tap to use:',
                  style: TextStyle(
                    fontSize: 11,
                    color: MacosColors.secondaryLabelColor.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: _existingCategories.take(4).map((category) {
                    return GestureDetector(
                      onTap: () => setState(() {
                        _categoryController.text = _formatCategoryForInput(
                          category,
                        );
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: MacosColors.controlAccentColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: MacosColors.controlAccentColor.withValues(
                              alpha: 0.3,
                            ),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 9,
                            color: MacosColors.controlAccentColor,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],

            // Remove option for currently pinned
            if (widget.isCurrentlyPinned) ...[
              const SizedBox(height: 16),
              Center(
                child: PushButton(
                  controlSize: ControlSize.regular,
                  color: MacosColors.systemRedColor,
                  onPressed: () => Navigator.of(context).pop('unpin'),
                  child: const Text('Remove Pin'),
                ),
              ),
            ],
          ],
        ),
      ),
      primaryButton: PushButton(
        controlSize: ControlSize.large,
        onPressed: _handlePin,
        child: Text(widget.isCurrentlyPinned ? 'Update' : 'Pin'),
      ),
      secondaryButton: PushButton(
        controlSize: ControlSize.large,
        secondary: true,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    );
  }

  void _handlePin() {
    String result;

    if (_useCategory) {
      final category = _categoryController.text.trim().toLowerCase();
      if (category.isEmpty) {
        showMacosAlertDialog(
          context: context,
          builder: (_) => MacosAlertDialog(
            appIcon: const AppLogo.dialog(),
            title: const Text('Category Required'),
            message: const Text('Please enter a category name.'),
            primaryButton: PushButton(
              controlSize: ControlSize.large,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
        return;
      }

      if (!RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch(category)) {
        showMacosAlertDialog(
          context: context,
          builder: (_) => MacosAlertDialog(
            appIcon: const AppLogo.dialog(),
            title: const Text('Invalid Category'),
            message: const Text('Use only letters, numbers, and hyphens.'),
            primaryButton: PushButton(
              controlSize: ControlSize.large,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
        return;
      }

      result = 'pin:$category';
    } else {
      result = 'pin';
    }

    Navigator.of(context).pop(result);
  }
}
