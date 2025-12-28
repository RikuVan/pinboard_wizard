import 'dart:io';
import 'package:path/path.dart' as path;

/// Custom exception for file not found errors
class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);

  @override
  String toString() => message;
}

/// Service for handling local file system operations for markdown notes.
///
/// Provides methods for reading, writing, deleting, and listing markdown files
/// in a designated notes directory.
class FileService {
  /// The directory where notes are stored locally
  final Directory notesDirectory;

  FileService(this.notesDirectory);

  /// Read markdown file content from the given path
  ///
  /// Throws [FileNotFoundException] if the file doesn't exist.
  Future<String> readFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileNotFoundException('File not found: $filePath');
    }
    return await file.readAsString();
  }

  /// Write markdown content to the given file path
  ///
  /// Creates parent directories if they don't exist.
  Future<void> writeFile(String filePath, String content) async {
    final file = File(filePath);

    // Ensure parent directory exists
    await file.parent.create(recursive: true);

    // Write content
    await file.writeAsString(content);
  }

  /// Delete file from local filesystem
  ///
  /// Does nothing if the file doesn't exist (idempotent).
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get local file path for a repository path
  ///
  /// Converts a repository path like "notes/my-note.md" to a local
  /// filesystem path in the notes directory.
  ///
  /// Example:
  /// ```dart
  /// final localPath = service.getLocalPath('notes/flutter-tips.md');
  /// // Returns: /path/to/notes/flutter-tips.md
  /// ```
  String getLocalPath(String repoPath) {
    final filename = path.basename(repoPath);
    return path.join(notesDirectory.path, filename);
  }

  /// List all local markdown files in the notes directory
  ///
  /// Returns an empty list if the directory doesn't exist.
  /// Only returns files with .md extension.
  Future<List<File>> listLocalFiles() async {
    if (!await notesDirectory.exists()) {
      await notesDirectory.create(recursive: true);
      return [];
    }

    return notesDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.md'))
        .cast<File>()
        .toList();
  }

  /// Check if a file exists at the given path
  Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Get the size of a file in bytes
  ///
  /// Returns 0 if the file doesn't exist.
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return 0;
    }
    return await file.length();
  }

  /// Ensure the notes directory exists
  ///
  /// Creates the directory if it doesn't exist.
  Future<void> ensureDirectoryExists() async {
    if (!await notesDirectory.exists()) {
      await notesDirectory.create(recursive: true);
    }
  }
}
