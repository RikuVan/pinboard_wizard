import 'dart:io';
import 'package:path/path.dart' as path;

/// Custom exception for file not found errors
class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);

  @override
  String toString() => message;
}

/// Custom exception for security-related path errors
class PathSecurityException implements Exception {
  final String message;
  PathSecurityException(this.message);

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
  /// filesystem path in the notes directory, preserving the directory structure.
  ///
  /// Security: Validates the path to prevent directory traversal attacks.
  /// Throws [PathSecurityException] if the path is unsafe.
  ///
  /// Example:
  /// ```dart
  /// final localPath = service.getLocalPath('notes/folder/flutter-tips.md');
  /// // Returns: /path/to/notes/folder/flutter-tips.md
  /// ```
  String getLocalPath(String repoPath) {
    // Check for null bytes BEFORE normalization (directory traversal attack vector)
    if (repoPath.contains('\x00')) {
      throw PathSecurityException(
        'Null byte in path: potential security attack',
      );
    }

    // Check for empty path components BEFORE normalization
    if (repoPath.contains('//') ||
        repoPath.startsWith('/') ||
        repoPath.endsWith('/')) {
      throw PathSecurityException(
        'Invalid path format: empty components or leading/trailing slashes in $repoPath',
      );
    }

    // Normalize the path to handle different separators and resolve . and ..
    final normalized = path.normalize(repoPath);

    // Security checks AFTER normalization
    if (normalized.contains('..')) {
      throw PathSecurityException(
        'Path traversal detected: $repoPath contains ".."',
      );
    }

    if (path.isAbsolute(normalized)) {
      throw PathSecurityException('Absolute paths not allowed: $repoPath');
    }

    // Split path into components and validate each
    final parts = path.split(normalized);
    for (final part in parts) {
      if (part.isEmpty || part == '.' || part == '..') {
        throw PathSecurityException(
          'Invalid path component: $part in $repoPath',
        );
      }
    }

    // Build the local path preserving directory structure
    // This handles paths like "notes/folder1/folder2/file.md"
    return path.join(notesDirectory.path, normalized);
  }

  /// List all local markdown files in the notes directory
  ///
  /// Recursively scans all subdirectories to find markdown files.
  /// Returns an empty list if the directory doesn't exist.
  /// Only returns files with .md extension.
  Future<List<File>> listLocalFiles() async {
    if (!await notesDirectory.exists()) {
      await notesDirectory.create(recursive: true);
      return [];
    }

    return notesDirectory
        .list(recursive: true) // Now recursive to handle subdirectories
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

  /// Get the path to the trash/backup directory
  Directory get _trashDirectory =>
      Directory(path.join(notesDirectory.path, '.trash'));

  /// Move a file to trash as a backup before deletion
  ///
  /// Returns the backup file path for potential recovery.
  /// The file is moved to .trash/{timestamp}_{filename}
  Future<String> moveToTrash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileNotFoundException('Cannot backup non-existent file: $filePath');
    }

    // Ensure trash directory exists
    if (!await _trashDirectory.exists()) {
      await _trashDirectory.create(recursive: true);
    }

    // Create unique backup filename with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = path.basename(filePath);
    final backupPath = path.join(
      _trashDirectory.path,
      '${timestamp}_$filename',
    );

    // Move file to trash
    await file.rename(backupPath);

    return backupPath;
  }

  /// Restore a file from trash back to its original location
  ///
  /// Used for undo operations or when deletion needs to be rolled back.
  Future<void> restoreFromTrash(String backupPath, String originalPath) async {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw FileNotFoundException('Backup file not found: $backupPath');
    }

    // Ensure parent directory of original path exists
    final originalFile = File(originalPath);
    await originalFile.parent.create(recursive: true);

    // Move file back to original location
    await backupFile.rename(originalPath);
  }

  /// Permanently delete a backup file from trash
  Future<void> deleteBackup(String backupPath) async {
    final file = File(backupPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clean up old backups from trash
  ///
  /// Deletes backups older than [retentionDays] days.
  /// Default is 30 days.
  Future<int> cleanupOldBackups({int retentionDays = 30}) async {
    if (!await _trashDirectory.exists()) {
      return 0;
    }

    final cutoffTime = DateTime.now().subtract(Duration(days: retentionDays));
    final cutoffMillis = cutoffTime.millisecondsSinceEpoch;
    int deletedCount = 0;

    await for (final entity in _trashDirectory.list()) {
      if (entity is File) {
        // Extract timestamp from filename (format: {timestamp}_{filename})
        final filename = path.basename(entity.path);
        final parts = filename.split('_');
        if (parts.isNotEmpty) {
          final timestamp = int.tryParse(parts[0]);
          if (timestamp != null && timestamp < cutoffMillis) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
    }

    return deletedCount;
  }

  /// List all backup files in trash
  Future<List<File>> listBackups() async {
    if (!await _trashDirectory.exists()) {
      return [];
    }

    return _trashDirectory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
  }
}
