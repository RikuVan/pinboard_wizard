import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';

class EditBookmarkDialog extends StatefulWidget {
  final Post bookmark;

  const EditBookmarkDialog({super.key, required this.bookmark});

  @override
  State<EditBookmarkDialog> createState() => _EditBookmarkDialogState();
}

class _EditBookmarkDialogState extends State<EditBookmarkDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;

  late bool _isPrivate;
  late bool _markAsToRead;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing bookmark data
    _urlController = TextEditingController(text: widget.bookmark.href);
    _titleController = TextEditingController(text: widget.bookmark.description);
    _descriptionController = TextEditingController(
      text: widget.bookmark.extended,
    );
    _tagsController = TextEditingController(text: widget.bookmark.tags);

    // Initialize boolean values
    _isPrivate = !widget.bookmark.shared;
    _markAsToRead = widget.bookmark.toread;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MacosSheet(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 800,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      CupertinoIcons.pencil,
                      size: 24,
                      color: MacosColors.controlAccentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Bookmark',
                    style: MacosTheme.of(context).typography.largeTitle,
                  ),
                  const Spacer(),
                  MacosIconButton(
                    icon: const MacosIcon(CupertinoIcons.xmark),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form content in scrollable area
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _urlController,
                          label: 'URL',
                          placeholder: 'https://example.com',
                          isRequired: true,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _titleController,
                          label: 'Title',
                          placeholder: 'Bookmark title',
                          isRequired: true,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          placeholder: 'Optional description',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _tagsController,
                          label: 'Tags',
                          placeholder: 'tag1 tag2 tag3',
                          helperText: 'Separate tags with spaces',
                        ),
                        const SizedBox(height: 24),
                        _buildSwitchOptions(),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PushButton(
                    controlSize: ControlSize.large,
                    secondary: true,
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  PushButton(
                    controlSize: ControlSize.large,
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: _isSubmitting
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: ProgressCircle(),
                              ),
                              const SizedBox(width: 8),
                              const Text('Updating...'),
                            ],
                          )
                        : const Text('Update Bookmark'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    bool isRequired = false,
    int maxLines = 1,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: MacosTheme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  color: MacosColors.systemRedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        MacosTextField(
          controller: controller,
          placeholder: placeholder,
          maxLines: maxLines,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 12,
              color: MacosTheme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSwitchOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Options',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: MacosTheme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSwitch(
                value: _isPrivate,
                label: 'Private bookmark',
                onChanged: (value) => setState(() => _isPrivate = value),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildSwitch(
                value: _markAsToRead,
                label: 'Mark as "to read"',
                onChanged: (value) => setState(() => _markAsToRead = value),
              ),
            ),
            const SizedBox(width: 20),
            // Empty space to match add dialog layout
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildSwitch({
    required bool value,
    required String label,
    required void Function(bool) onChanged,
  }) {
    return Row(
      children: [
        MacosSwitch(value: value, onChanged: onChanged),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: MacosTheme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.87)
                  : Colors.black.withValues(alpha: 0.87),
            ),
          ),
        ),
      ],
    );
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'URL is required';
    }

    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  List<String> _parseTags(String tagsText) {
    return tagsText
        .trim()
        .split(RegExp(r'\s+'))
        .where((tag) => tag.isNotEmpty)
        .map((tag) => tag.toLowerCase())
        .toSet()
        .toList();
  }

  Future<void> _handleSubmit() async {
    // Validate manually since MacosTextField doesn't support validator
    if (_urlController.text.trim().isEmpty ||
        _titleController.text.trim().isEmpty) {
      _showErrorDialog('Please fill in all required fields');
      return;
    }

    if (_validateUrl(_urlController.text) != null) {
      _showErrorDialog('Please enter a valid URL');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Create updated bookmark with new values
      final updatedBookmark = widget.bookmark.copyWith(
        href: _urlController.text.trim(),
        description: _titleController.text.trim(),
        extended: _descriptionController.text.trim().isEmpty
            ? ''
            : _descriptionController.text.trim(),
        tags: _parseTags(_tagsController.text).join(' '),
        shared: !_isPrivate,
        toread: _markAsToRead,
      );

      Navigator.of(context).pop(updatedBookmark);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (context.mounted) {
        _showErrorDialog('Failed to prepare bookmark data: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showMacosAlertDialog(
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
        title: const Text('Error'),
        message: Text(message),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
