import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:pinboard_wizard/src/ui/ui.dart';
import 'package:markdown/markdown.dart' as md;

/// Display mode for the markdown editor
enum MarkdownEditorMode {
  /// Show only the editor
  edit,

  /// Show editor and preview side-by-side
  split,

  /// Show only the preview
  preview,
}

/// An enhanced markdown editor widget with live preview support.
///
/// Features:
/// - Split-pane view (editor + preview)
/// - Toggle between edit/split/preview modes
/// - Extended markdown toolbar (headings, code blocks, quotes, images, tables, checkboxes)
/// - Keyboard shortcuts (Cmd+B, Cmd+I, Cmd+K, etc.)
/// - GitHub-flavored markdown rendering
/// - Syntax highlighting for code blocks
/// - macOS native styling
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.initialContent,
    required this.onSave,
    required this.onCancel,
    this.readOnly = false,
  });

  /// Initial markdown content to display
  final String initialContent;

  /// Callback when save button is pressed
  final void Function(String content) onSave;

  /// Callback when cancel button is pressed
  final VoidCallback onCancel;

  /// Whether the editor is read-only
  final bool readOnly;

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _hasChanges = false;
  MarkdownEditorMode _mode = MarkdownEditorMode.edit;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasChanges = _controller.text != widget.initialContent;
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  void _insertMarkdown(String prefix, {String? suffix}) {
    final selection = _controller.selection;
    final text = _controller.text;

    if (!selection.isValid) {
      return;
    }

    final selectedText = selection.textInside(text);
    final newText = '$prefix$selectedText${suffix ?? prefix}';

    _controller.text = text.replaceRange(
      selection.start,
      selection.end,
      newText,
    );

    // Update selection to highlight the text between markers
    final newStart = selection.start + prefix.length;
    final newEnd = newStart + selectedText.length;
    _controller.selection = TextSelection(
      baseOffset: newStart,
      extentOffset: newEnd,
    );
    _focusNode.requestFocus();
  }

  void _insertLink() {
    final selection = _controller.selection;
    final text = _controller.text;

    if (!selection.isValid) {
      return;
    }

    final selectedText = selection.textInside(text);
    final linkText = selectedText.isEmpty ? 'link text' : selectedText;
    final newText = '[$linkText](url)';

    _controller.text = text.replaceRange(
      selection.start,
      selection.end,
      newText,
    );

    // Select the URL part
    final urlStart = selection.start + linkText.length + 3;
    _controller.selection = TextSelection(
      baseOffset: urlStart,
      extentOffset: urlStart + 3,
    );
    _focusNode.requestFocus();
  }

  void _insertList(String prefix) {
    final selection = _controller.selection;
    final text = _controller.text;

    if (!selection.isValid) {
      return;
    }

    final lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;

    _controller.text = text.replaceRange(lineStart, lineStart, prefix);
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + prefix.length,
    );
    _focusNode.requestFocus();
  }

  void _insertCodeBlock() {
    final selection = _controller.selection;
    final text = _controller.text;

    if (!selection.isValid) {
      return;
    }

    final selectedText = selection.textInside(text);
    final newText =
        '```\n${selectedText.isEmpty ? 'code here' : selectedText}\n```';

    _controller.text = text.replaceRange(
      selection.start,
      selection.end,
      newText,
    );

    // Position cursor inside the code block
    final cursorPos = selection.start + 4;
    _controller.selection = TextSelection.collapsed(offset: cursorPos);
    _focusNode.requestFocus();
  }

  void _insertBlockquote() {
    final selection = _controller.selection;
    final text = _controller.text;

    if (!selection.isValid) {
      return;
    }

    final lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;

    _controller.text = text.replaceRange(lineStart, lineStart, '> ');
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + 2,
    );
    _focusNode.requestFocus();
  }

  void _insertTable() {
    final selection = _controller.selection;
    final text = _controller.text;

    if (!selection.isValid) {
      return;
    }

    const table = '''
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |
''';

    _controller.text = text.replaceRange(selection.start, selection.end, table);
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + table.length,
    );
    _focusNode.requestFocus();
  }

  void _insertCheckbox() {
    final selection = _controller.selection;
    final text = _controller.text;

    if (!selection.isValid) {
      return;
    }

    final lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;

    _controller.text = text.replaceRange(lineStart, lineStart, '- [ ] ');
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + 6,
    );
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isMeta =
        event.logicalKey == LogicalKeyboardKey.meta ||
        event.logicalKey == LogicalKeyboardKey.metaLeft ||
        event.logicalKey == LogicalKeyboardKey.metaRight;

    final isControl =
        event.logicalKey == LogicalKeyboardKey.control ||
        event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight;

    if (!isMeta && !isControl) {
      return KeyEventResult.ignored;
    }

    // Cmd/Ctrl + B = Bold
    if (event.logicalKey == LogicalKeyboardKey.keyB) {
      _insertMarkdown('**');
      return KeyEventResult.handled;
    }

    // Cmd/Ctrl + I = Italic
    if (event.logicalKey == LogicalKeyboardKey.keyI) {
      _insertMarkdown('_');
      return KeyEventResult.handled;
    }

    // Cmd/Ctrl + K = Link
    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      _insertLink();
      return KeyEventResult.handled;
    }

    // Cmd/Ctrl + E = Code
    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      _insertMarkdown('`');
      return KeyEventResult.handled;
    }

    // Cmd/Ctrl + Shift + C = Code block
    if (event.logicalKey == LogicalKeyboardKey.keyC &&
        (HardwareKeyboard.instance.isShiftPressed)) {
      _insertCodeBlock();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = context.appBrightness;
    final isDark = brightness == Brightness.dark;

    return Column(
      children: [
        // Toolbar
        if (!widget.readOnly) _buildToolbar(isDark),

        // Editor/Preview
        Expanded(child: _buildContentArea(isDark)),

        // Action buttons
        if (!widget.readOnly) _buildActionBar(isDark),
      ],
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFD1D1D6),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Mode toggle buttons
            _ModeToggleButtons(
              mode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
            const SizedBox(width: 16),
            const VerticalDivider(),
            const SizedBox(width: 8),

            _ToolbarButton(
              icon: CupertinoIcons.link,
              tooltip: 'Link (⌘K)',
              onPressed: _insertLink,
            ),
            const SizedBox(width: 8),

            _ToolbarButton(
              icon: CupertinoIcons.list_bullet,
              tooltip: 'Bullet List',
              onPressed: () => _insertList('- '),
            ),
            _ToolbarButton(
              icon: CupertinoIcons.list_number,
              tooltip: 'Numbered List',
              onPressed: () => _insertList('1. '),
            ),
            _ToolbarButton(
              icon: CupertinoIcons.check_mark_circled,
              tooltip: 'Task List',
              onPressed: _insertCheckbox,
            ),
            const SizedBox(width: 8),

            _ToolbarButton(
              icon: CupertinoIcons.chevron_left_slash_chevron_right,
              tooltip: 'Inline Code (⌘E)',
              onPressed: () => _insertMarkdown('`'),
            ),
            _ToolbarButton(
              icon: CupertinoIcons.square_on_square,
              tooltip: 'Code Block (⌘⇧C)',
              onPressed: _insertCodeBlock,
            ),
            _ToolbarButton(
              icon: CupertinoIcons.quote_bubble,
              tooltip: 'Blockquote',
              onPressed: _insertBlockquote,
            ),
            const SizedBox(width: 8),

            _ToolbarButton(
              icon: CupertinoIcons.table,
              tooltip: 'Table',
              onPressed: _insertTable,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        switch (_mode) {
          case MarkdownEditorMode.edit:
            return _buildEditor(isDark);
          case MarkdownEditorMode.preview:
            return _buildPreview(isDark);
          case MarkdownEditorMode.split:
            return Row(
              children: [
                Expanded(child: _buildEditor(isDark)),
                Container(
                  width: 1,
                  color: isDark
                      ? const Color(0xFF3C3C3C)
                      : const Color(0xFFD1D1D6),
                ),
                Expanded(child: _buildPreview(isDark)),
              ],
            );
        }
      },
    );
  }

  Widget _buildEditor(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: Border.all(
              color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFD1D1D6),
            ),
            borderRadius: _mode == MarkdownEditorMode.split
                ? const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  )
                : BorderRadius.circular(6),
          ),
          child: Focus(
            onKeyEvent: _handleKeyEvent,
            child: CupertinoTextField(
              controller: _controller,
              focusNode: _focusNode,
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
              readOnly: widget.readOnly,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreview(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: Border.all(
              color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFD1D1D6),
            ),
            borderRadius: _mode == MarkdownEditorMode.split
                ? const BorderRadius.only(
                    topRight: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  )
                : BorderRadius.circular(6),
          ),
          child: Markdown(
            data: _controller.text.isEmpty
                ? '*No content to preview*'
                : _controller.text,
            selectable: true,
            extensionSet: md.ExtensionSet.gitHubFlavored,
            builders: {'code': _CodeElementBuilder(isDark: isDark)},
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: isDark ? Colors.white : Colors.black,
              ),
              h1: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              h2: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              h3: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              h4: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              h5: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              h6: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              code: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 12,
                backgroundColor: isDark
                    ? const Color(0xFF2D2D2D)
                    : const Color(0xFFF5F5F5),
                color: isDark
                    ? const Color(0xFFD19A66)
                    : const Color(0xFFE45649),
              ),
              codeblockDecoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2D2D2D)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3C3C3C)
                      : const Color(0xFFD1D1D6),
                ),
              ),
              blockquote: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isDark ? Colors.white30 : Colors.black26,
                    width: 4,
                  ),
                ),
              ),
              checkbox: TextStyle(color: isDark ? Colors.white : Colors.black),
              tableHead: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              tableBody: TextStyle(color: isDark ? Colors.white : Colors.black),
              tableBorder: TableBorder.all(
                color: isDark
                    ? const Color(0xFF3C3C3C)
                    : const Color(0xFFD1D1D6),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFD1D1D6),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (_hasChanges)
                Text(
                  'Unsaved changes',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              if (_hasChanges) const SizedBox(width: 16),
              Text(
                '${_controller.text.length} characters',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
              ),
            ],
          ),
          Row(
            children: [
              AppButton(
                size: AppButtonSize.regular,
                secondary: true,
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              AppButton(
                size: AppButtonSize.regular,
                onPressed: _hasChanges
                    ? () => widget.onSave(_controller.text)
                    : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom code block builder with syntax highlighting for markdown editor
class _CodeElementBuilder extends MarkdownElementBuilder {
  final bool isDark;

  _CodeElementBuilder({required this.isDark});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';

    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      language = lg.substring(9); // Remove 'language-' prefix
    }

    return SizedBox(
      width: double.infinity,
      child: HighlightView(
        element.textContent,
        language: language,
        theme: isDark ? a11yDarkTheme : githubTheme,
        padding: const EdgeInsets.all(12),
        textStyle: const TextStyle(fontFamily: 'SF Mono', fontSize: 12),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = context.appBrightness == Brightness.dark;

    return AppTooltip(
      message: tooltip,
      child: AppIconButton(
        icon: Icon(
          icon,
          size: 16,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
        backgroundColor: Colors.transparent,
        size: 28,
        onPressed: onPressed,
      ),
    );
  }
}

class _ModeToggleButtons extends StatelessWidget {
  const _ModeToggleButtons({required this.mode, required this.onChanged});

  final MarkdownEditorMode mode;
  final ValueChanged<MarkdownEditorMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = context.appBrightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            label: 'Edit',
            isSelected: mode == MarkdownEditorMode.edit,
            onPressed: () => onChanged(MarkdownEditorMode.edit),
            isFirst: true,
          ),
          _ModeButton(
            label: 'Split',
            isSelected: mode == MarkdownEditorMode.split,
            onPressed: () => onChanged(MarkdownEditorMode.split),
          ),
          _ModeButton(
            label: 'Preview',
            isSelected: mode == MarkdownEditorMode.preview,
            onPressed: () => onChanged(MarkdownEditorMode.preview),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
    this.isFirst = false,
    this.isLast = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDark = context.appBrightness == Brightness.dark;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0A84FF) : CupertinoColors.systemBlue)
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(6) : Radius.zero,
            right: isLast ? const Radius.circular(6) : Radius.zero,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
