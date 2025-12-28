import 'package:path/path.dart' as path;

/// Service for handling note filename generation and title extraction.
///
/// Provides methods to:
/// - Generate safe, unique filenames from user-provided titles
/// - Extract titles from markdown content
/// - Validate filenames for cross-platform compatibility
class NoteFilenameService {
  /// Generate safe, unique filename from user-provided title
  ///
  /// Process:
  /// 1. Lowercase for consistency
  /// 2. Replace spaces with hyphens
  /// 3. Remove special characters (keep only alphanumeric and hyphens)
  /// 4. Remove multiple consecutive hyphens
  /// 5. Trim hyphens from start/end
  /// 6. Limit length to 50 characters
  /// 7. Handle empty result (use 'untitled')
  /// 8. Add timestamp for uniqueness
  ///
  /// Example:
  /// ```dart
  /// final service = NoteFilenameService();
  /// final filename = service.generateFilename('My Flutter Tips!');
  /// // Returns: my-flutter-tips-1234567890123.md
  /// ```
  String generateFilename(String title) {
    // 1. Lowercase for consistency
    var filename = title.toLowerCase();

    // 2. Replace spaces with hyphens
    filename = filename.replaceAll(RegExp(r'\s+'), '-');

    // 3. Remove special characters (keep only alphanumeric and hyphens)
    //    Prevents path traversal, filesystem issues, git problems
    filename = filename.replaceAll(RegExp(r'[^a-z0-9-]'), '');

    // 4. Remove multiple consecutive hyphens
    filename = filename.replaceAll(RegExp(r'-+'), '-');

    // 5. Trim hyphens from start/end
    filename = filename.replaceAll(RegExp(r'^-|-$'), '');

    // 6. Limit length (GitHub max is 255 chars, keep reasonable)
    if (filename.length > 50) {
      filename = filename.substring(0, 50);
    }

    // 7. Handle empty result
    if (filename.isEmpty) {
      filename = 'untitled';
    }

    // 8. Add timestamp for uniqueness (prevents collisions)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    filename = '$filename-$timestamp';

    return '$filename.md';
  }

  /// Extract title from markdown content
  ///
  /// Priority:
  /// 1. First H1 heading (# Title)
  /// 2. Filename (cleaned up)
  ///
  /// Example:
  /// ```dart
  /// final service = NoteFilenameService();
  /// final markdown = '# My Note\n\nSome content...';
  /// final title = service.extractTitle(markdown, 'my-note-1234.md');
  /// // Returns: My Note
  /// ```
  String extractTitle(String markdown, String filename) {
    // Try to find first H1 heading (# Title)
    final h1Match = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(markdown);

    if (h1Match != null) {
      return h1Match.group(1)!.trim();
    }

    // Fallback: use filename (remove extension and timestamp)
    return path
        .basenameWithoutExtension(filename)
        .replaceAll(RegExp(r'-\d{13}$'), '') // Remove timestamp
        .replaceAll('-', ' ') // Hyphens to spaces
        .trim();
  }

  /// Validate filename doesn't conflict with system files
  ///
  /// Checks:
  /// - Not a hidden file (starts with .)
  /// - Not a reserved system name (cross-platform)
  ///
  /// Example:
  /// ```dart
  /// final service = NoteFilenameService();
  /// service.isValidFilename('my-note.md'); // true
  /// service.isValidFilename('.hidden.md'); // false
  /// service.isValidFilename('con.md'); // false (Windows reserved)
  /// ```
  bool isValidFilename(String filename) {
    // Reject system/hidden files
    if (filename.startsWith('.')) return false;

    // Reject reserved names (cross-platform safety)
    final reserved = ['con', 'prn', 'aux', 'nul', 'com1', 'lpt1'];
    final base = path.basenameWithoutExtension(filename).toLowerCase();
    if (reserved.contains(base)) return false;

    return true;
  }

  /// Check if a filename has a valid markdown extension
  bool hasMarkdownExtension(String filename) {
    return filename.endsWith('.md') || filename.endsWith('.markdown');
  }

  /// Sanitize a filename that may have been manually created
  ///
  /// Similar to [generateFilename] but without adding a timestamp,
  /// useful for validating/cleaning existing filenames.
  String sanitizeFilename(String filename) {
    var sanitized = filename.toLowerCase();

    // Remove extension if present
    if (sanitized.endsWith('.md')) {
      sanitized = sanitized.substring(0, sanitized.length - 3);
    } else if (sanitized.endsWith('.markdown')) {
      sanitized = sanitized.substring(0, sanitized.length - 9);
    }

    // Replace spaces with hyphens
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), '-');

    // Remove special characters
    sanitized = sanitized.replaceAll(RegExp(r'[^a-z0-9-]'), '');

    // Remove multiple consecutive hyphens
    sanitized = sanitized.replaceAll(RegExp(r'-+'), '-');

    // Trim hyphens from start/end
    sanitized = sanitized.replaceAll(RegExp(r'^-|-$'), '');

    // Handle empty result
    if (sanitized.isEmpty) {
      sanitized = 'untitled';
    }

    return '$sanitized.md';
  }
}
