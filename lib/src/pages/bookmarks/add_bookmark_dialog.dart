import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/ai/ai_bookmark_service.dart';
import 'package:pinboard_wizard/src/ai/ai_settings_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';

class AddBookmarkDialog extends StatefulWidget {
  const AddBookmarkDialog({super.key});

  @override
  State<AddBookmarkDialog> createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<AddBookmarkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _isPrivate = true;
  bool _markAsToRead = true;
  bool _replaceExisting = false;
  bool _isSubmitting = false;
  bool _isAnalyzing = false;
  String? _aiError;
  Timer? _clipboardTimer;
  bool _userClearedForm = false;
  String? _lastClipboardUrl;

  late final AiBookmarkService _aiBookmarkService;
  late final AiSettingsService _aiSettingsService;

  @override
  void initState() {
    super.initState();
    _aiBookmarkService = locator.get<AiBookmarkService>();
    _aiSettingsService = locator.get<AiSettingsService>();
    _tryLoadClipboardUrl();
    _startClipboardMonitoring();
  }

  @override
  void dispose() {
    // Stop clipboard monitoring
    _clipboardTimer?.cancel();

    // Clear all data before disposing
    _urlController.clear();
    _titleController.clear();
    _descriptionController.clear();
    _tagsController.clear();

    // Reset state
    _isPrivate = true;
    _markAsToRead = true;
    _replaceExisting = false;
    _isSubmitting = false;
    _isAnalyzing = false;
    _aiError = null;

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
                      CupertinoIcons.bookmark_fill,
                      size: 24,
                      color: MacosColors.controlAccentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Bookmark',
                    style: MacosTheme.of(context).typography.largeTitle,
                  ),
                  const Spacer(),
                  MacosIconButton(
                    icon: const MacosIcon(CupertinoIcons.xmark),
                    onPressed: () => _handleClose(),
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
                        _buildUrlField(),
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
                children: [
                  PushButton(
                    controlSize: ControlSize.large,
                    secondary: true,
                    onPressed: _isSubmitting ? null : _handleClear,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MacosIcon(CupertinoIcons.clear),
                        const SizedBox(width: 6),
                        const Text('Clear'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      PushButton(
                        controlSize: ControlSize.large,
                        secondary: true,
                        onPressed: _isSubmitting ? null : _handleClose,
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
                                  const Text('Adding...'),
                                ],
                              )
                            : const Text('Add Bookmark'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'URL',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: MacosTheme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
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
        Row(
          children: [
            Expanded(
              child: MacosTextField(
                controller: _urlController,
                placeholder: 'https://example.com',
                onChanged: (_) {
                  setState(() {
                    _aiError = null; // Clear error when URL changes
                    _userClearedForm =
                        false; // Reset clear flag when user types
                  });
                },
              ),
            ),
            if (_aiSettingsService.isEnabled) ...[
              const SizedBox(width: 12),
              PushButton(
                controlSize: ControlSize.regular,
                onPressed: _canUseAiMagic ? _handleAiAnalysis : null,
                child: _isAnalyzing
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: ProgressCircle(),
                          ),
                          const SizedBox(width: 8),
                          const Text('Analyzing...'),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            size: 16,
                            color: _canUseAiMagic
                                ? MacosColors.controlAccentColor
                                : MacosTheme.of(context).brightness ==
                                      Brightness.dark
                                ? Colors.white38
                                : Colors.black38,
                          ),
                          const SizedBox(width: 6),
                          const Text('Complete with AI'),
                        ],
                      ),
              ),
            ],
          ],
        ),
        if (_aiError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MacosColors.systemRedColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: MacosColors.systemRedColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 16,
                  color: MacosColors.systemRedColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _aiError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: MacosColors.systemRedColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
            Expanded(
              child: _buildSwitch(
                value: _replaceExisting,
                label: 'Replace if exists',
                onChanged: (value) => setState(() => _replaceExisting = value),
              ),
            ),
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
      final bookmarkData = {
        'url': _urlController.text.trim(),
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'tags': _parseTags(_tagsController.text),
        'shared': !_isPrivate,
        'toRead': _markAsToRead,
        'replace': _replaceExisting,
      };

      // Clear clipboard after successful save to prevent reuse
      await Clipboard.setData(const ClipboardData(text: ''));

      Navigator.of(context).pop(bookmarkData);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (context.mounted) {
        _showErrorDialog('Failed to prepare bookmark data: $e');
      }
    }
  }

  bool get _canUseAiMagic {
    if (!_aiSettingsService.isEnabled || _isAnalyzing || _isSubmitting) {
      return false;
    }

    if (!_aiSettingsService.openaiSettings.hasApiKey) {
      return false;
    }

    final url = _urlController.text.trim();
    return url.isNotEmpty && _aiBookmarkService.isValidUrl(url);
  }

  Future<void> _handleAiAnalysis() async {
    final url = _urlController.text.trim();
    if (!_aiBookmarkService.isValidUrl(url)) {
      setState(() {
        _aiError = 'Please enter a valid URL first';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _aiError = null;
    });

    try {
      final suggestions = await _aiBookmarkService.analyzeUrl(url);

      setState(() {
        _isAnalyzing = false;

        // Fill in the fields with AI suggestions
        if (suggestions.hasTitle) {
          _titleController.text = suggestions.title!;
        }
        if (suggestions.hasDescription) {
          _descriptionController.text = suggestions.description!;
        }
        if (suggestions.hasTags) {
          _tagsController.text = suggestions.tags.join(' ');
        }
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _aiError = e.toString().replaceFirst('AiBookmarkException: ', '');
      });
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

  Future<void> _tryLoadClipboardUrl() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
        final text = clipboardData.text!.trim();
        final uri = Uri.tryParse(text);
        if (uri != null && uri.hasScheme && uri.scheme.startsWith('http')) {
          _urlController.text = text;
          // Try to generate a title from the URL
          if (uri.host.isNotEmpty) {
            _titleController.text = uri.host
                .replaceAll('www.', '')
                .split('.')
                .first;
          }
        }
        // Set the last clipboard URL to prevent monitoring from re-filling
        _lastClipboardUrl = text;
      }
    } catch (e) {
      // Ignore clipboard errors
    }
  }

  void _handleClear() {
    setState(() {
      _urlController.clear();
      _titleController.clear();
      _descriptionController.clear();
      _tagsController.clear();
      _isPrivate = true;
      _markAsToRead = true;
      _replaceExisting = false;
      _aiError = null;
      _userClearedForm = true;
    });
  }

  void _handleClose() {
    Navigator.of(context).pop();
  }

  void _startClipboardMonitoring() {
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkClipboardForNewUrl();
    });
  }

  Future<void> _checkClipboardForNewUrl() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
        final text = clipboardData.text!.trim();
        final uri = Uri.tryParse(text);
        final currentUrl = _urlController.text.trim();

        // Only update if clipboard content actually changed
        if (text != _lastClipboardUrl) {
          _lastClipboardUrl = text;

          // Only update if it's a valid URL, different from current URL, and user hasn't manually cleared
          if (uri != null &&
              uri.hasScheme &&
              uri.scheme.startsWith('http') &&
              text != currentUrl &&
              !_userClearedForm) {
            setState(() {
              _urlController.text = text;
              // Generate a title from the URL if title is empty or was auto-generated
              if (_titleController.text.isEmpty ||
                  _titleController.text ==
                      uri.host.replaceAll('www.', '').split('.').first) {
                if (uri.host.isNotEmpty) {
                  _titleController.text = uri.host
                      .replaceAll('www.', '')
                      .split('.')
                      .first;
                }
              }
              // Clear AI error when URL changes
              _aiError = null;
            });
          }
        }
      }
    } catch (e) {
      // Ignore clipboard errors during monitoring
    }
  }
}
