import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';

/// Inline form for creating a new note.
///
/// Shows in the detail pane instead of a dialog for better UX.
class NewNoteForm extends StatefulWidget {
  const NewNoteForm({
    super.key,
    required this.onCreate,
    required this.onCancel,
  });

  /// Callback when note is created
  final void Function(String title, String content) onCreate;

  /// Callback when creation is cancelled
  final VoidCallback onCancel;

  @override
  State<NewNoteForm> createState() => _NewNoteFormState();
}

class _NewNoteFormState extends State<NewNoteForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_validateForm);
    // Auto-focus title field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_validateForm);
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _validateForm() {
    final canCreate = _titleController.text.trim().isNotEmpty;
    if (canCreate != _canCreate) {
      setState(() {
        _canCreate = canCreate;
      });
    }
  }

  void _handleCreate() {
    if (!_canCreate) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Default content with H1 if empty
    final noteContent = content.isEmpty ? '# $title\n\n' : content;

    widget.onCreate(title, noteContent);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.appBrightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                CupertinoIcons.doc_text_fill,
                size: 24,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 12),
              Text('Create New Note', style: context.appTypography.title2),
            ],
          ),
          const SizedBox(height: 24),

          // Title field
          Text('Title', style: context.appTypography.headline),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            placeholder: 'Enter note title...',
            maxLines: 1,
            onSubmitted: (_) => _canCreate ? _handleCreate() : null,
          ),
          const SizedBox(height: 24),

          // Content field
          Text('Content (Optional)', style: context.appTypography.headline),
          const SizedBox(height: 8),
          Text(
            'You can leave this empty and add content after creation',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),

          // Expandable content area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3C3C3C)
                      : const Color(0xFFD1D1D6),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: CupertinoTextField(
                controller: _contentController,
                placeholder: 'Start writing your note...',
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(),
                style: TextStyle(
                  fontFamily: 'SF Mono',
                  fontSize: 13,
                  height: 1.6,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0A84FF).withValues(alpha: 0.1)
                  : CupertinoColors.systemBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF0A84FF).withValues(alpha: 0.3)
                    : CupertinoColors.systemBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.info_circle_fill,
                  size: 16,
                  color: isDark
                      ? const Color(0xFF0A84FF)
                      : CupertinoColors.systemBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The note will be saved locally and synced to GitHub on next sync',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                size: AppButtonSize.large,
                secondary: true,
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              AppButton(
                size: AppButtonSize.large,
                onPressed: _canCreate ? _handleCreate : null,
                child: const Text('Create Note'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
