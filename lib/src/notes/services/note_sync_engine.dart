import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:pinboard_wizard/src/database/notes_database.dart';
import 'package:pinboard_wizard/src/github/github_client.dart';
import 'package:pinboard_wizard/src/github/models/github_file.dart';
import 'package:pinboard_wizard/src/notes/models/sync_result.dart';
import 'package:pinboard_wizard/src/notes/services/file_service.dart';
import 'package:pinboard_wizard/src/notes/services/network_service.dart';
import 'package:pinboard_wizard/src/notes/services/note_filename_service.dart';
import 'package:uuid/uuid.dart';

/// Core sync engine that orchestrates bidirectional sync between local notes
/// and GitHub repository.
///
/// Responsibilities:
/// - Pull changes from GitHub (download new/updated files)
/// - Push local changes to GitHub (upload dirty notes)
/// - Detect and handle conflicts (SHA mismatch)
/// - Manage offline queue (retry failed operations)
/// - Coordinate all services (file, network, database, GitHub)
///
/// Sync Strategy:
/// 1. Check network connectivity
/// 2. Pull remote changes first (to detect conflicts early)
/// 3. Push local dirty notes
/// 4. Handle conflicts by creating conflict files
/// 5. Return detailed sync result
///
/// Example:
/// ```dart
/// final engine = NoteSyncEngine(
///   database: notesDb,
///   githubClient: client,
///   fileService: fileService,
///   networkService: networkService,
///   filenameService: filenameService,
/// );
///
/// final result = await engine.sync();
/// if (result.isFullSuccess) {
///   print('All notes synced!');
/// } else if (result.conflicts.isNotEmpty) {
///   print('Conflicts detected: ${result.conflicts.length}');
/// }
/// ```
class NoteSyncEngine {
  final NotesDatabase database;
  final GitHubClient githubClient;
  final FileService fileService;
  final NetworkService networkService;
  final NoteFilenameService filenameService;
  final Uuid _uuid = const Uuid();

  NoteSyncEngine({
    required this.database,
    required this.githubClient,
    required this.fileService,
    required this.networkService,
    required this.filenameService,
  });

  /// Perform a full bidirectional sync operation
  ///
  /// Process:
  /// 1. Check network connectivity (exit early if offline)
  /// 2. Pull remote changes from GitHub
  /// 3. Push local dirty notes to GitHub
  /// 4. Handle any conflicts detected
  /// 5. Return aggregated sync result
  ///
  /// Returns [SyncResult] with details of succeeded/failed/conflicted notes.
  Future<SyncResult> sync() async {
    debugPrint('🔄 Starting sync operation...');

    // Check network first
    final isOnline = await networkService.isOnlineWithTimeout();
    if (!isOnline) {
      debugPrint('📵 Offline - sync skipped');
      return SyncResult.offline();
    }

    final succeeded = <Note>[];
    final failed = <SyncFailure>[];
    final conflicts = <Note>[];

    try {
      // Step 1: Pull remote changes
      debugPrint('⬇️ Pulling remote changes...');
      final pullResult = await pull();
      succeeded.addAll(pullResult.succeeded);
      failed.addAll(pullResult.failed);
      conflicts.addAll(pullResult.conflicts);

      // Step 2: Push local changes
      debugPrint('⬆️ Pushing local changes...');
      final pushResult = await push();
      succeeded.addAll(pushResult.succeeded);
      failed.addAll(pushResult.failed);
      conflicts.addAll(pushResult.conflicts);

      debugPrint(
        '✅ Sync complete: ${succeeded.length} succeeded, '
        '${failed.length} failed, ${conflicts.length} conflicts',
      );

      return SyncResult(
        succeeded: succeeded,
        failed: failed,
        conflicts: conflicts,
        isOnline: true,
        timestamp: DateTime.now(),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Sync failed with error: $e');
      debugPrint('Stack trace: $stackTrace');

      return SyncResult(
        succeeded: succeeded,
        failed: [
          SyncFailure(
            note: Note(
              id: 'sync-error',
              path: '',
              title: 'Sync Error',
              lastKnownSha: null,
              isDirty: false,
              updatedAt: DateTime.now(),
              createdAt: DateTime.now(),
              contentPreview: null,
              contentLength: 0,
              isConflict: false,
              markedForDeletion: false,
            ),
            error: e.toString(),
            type: _classifyError(e),
            timestamp: DateTime.now(),
          ),
        ],
        conflicts: conflicts,
        isOnline: true,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Pull changes from GitHub repository
  ///
  /// Process:
  /// 1. List all files in GitHub notes directory
  /// 2. For each remote file:
  ///    - Check if exists in local database
  ///    - If new: download and insert
  ///    - If exists: compare SHA
  ///      - Same SHA: skip
  ///      - Different SHA + not dirty: update local
  ///      - Different SHA + dirty: CONFLICT
  /// 3. Handle deletions (files in DB but not on GitHub)
  ///
  /// Returns [SyncResult] with pull operation details.
  Future<SyncResult> pull() async {
    final succeeded = <Note>[];
    final failed = <SyncFailure>[];
    final conflicts = <Note>[];

    try {
      // List all remote files
      final remoteFiles = await githubClient.listNotesFiles();
      debugPrint('📋 Found ${remoteFiles.length} remote files');

      // Warn if no files found - likely path configuration issue
      if (remoteFiles.isEmpty) {
        debugPrint('⚠️ No markdown files found in GitHub repository!');
        debugPrint('   This usually means:');
        debugPrint(
          '   1. Your "Notes Path" setting doesn\'t match where files are in GitHub',
        );
        debugPrint(
          '   2. Files are at root level, but path is set to a subdirectory (or vice versa)',
        );
        debugPrint('   3. No .md files exist in the repository yet');
        debugPrint('   💡 Check Settings → GitHub → Notes Path configuration');
      }

      // Get all local notes for comparison
      final localNotes = await database.getAllNotes();
      final localNotesByPath = {for (var note in localNotes) note.path: note};

      // Process each remote file
      for (final remoteFile in remoteFiles) {
        try {
          final result = await _pullSingleFile(remoteFile, localNotesByPath);
          if (result.isConflict) {
            conflicts.add(result.note);
          } else if (result.isSuccess) {
            succeeded.add(result.note);
          }
        } catch (e) {
          failed.add(
            SyncFailure(
              note: Note(
                id: _uuid.v4(),
                path: remoteFile.path,
                title: filenameService.extractTitle('', remoteFile.path),
                lastKnownSha: remoteFile.sha,
                isDirty: false,
                updatedAt: DateTime.now(),
                createdAt: DateTime.now(),
                contentPreview: null,
                contentLength: 0,
                isConflict: false,
                markedForDeletion: false,
              ),
              error: e.toString(),
              type: _classifyError(e),
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      // Handle deletions: notes in DB but not on GitHub
      await _handleRemoteDeletions(remoteFiles, localNotes);

      return SyncResult(
        succeeded: succeeded,
        failed: failed,
        conflicts: conflicts,
        isOnline: true,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Pull failed: $e');
      failed.add(
        SyncFailure(
          note: Note(
            id: 'pull-error',
            path: '',
            title: 'Pull Error',
            lastKnownSha: null,
            isDirty: false,
            updatedAt: DateTime.now(),
            createdAt: DateTime.now(),
            contentPreview: null,
            contentLength: 0,
            isConflict: false,
            markedForDeletion: false,
          ),
          error: e.toString(),
          type: _classifyError(e),
          timestamp: DateTime.now(),
        ),
      );

      return SyncResult(
        succeeded: succeeded,
        failed: failed,
        conflicts: conflicts,
        isOnline: true,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Push local dirty notes to GitHub
  ///
  /// Process:
  /// 1. Get all dirty notes from database
  /// 2. For each dirty note:
  ///    - Read local file content
  ///    - Check if note exists on GitHub (has SHA)
  ///    - If new: create file on GitHub
  ///    - If exists: update file on GitHub (providing SHA for conflict check)
  ///    - If SHA mismatch: CONFLICT (should have been caught in pull)
  /// 3. Handle notes marked for deletion
  ///
  /// Returns [SyncResult] with push operation details.
  Future<SyncResult> push() async {
    final succeeded = <Note>[];
    final failed = <SyncFailure>[];
    final conflicts = <Note>[];

    try {
      // Get all notes that need to be pushed
      final dirtyNotes = await database.getDirtyNotes();
      final deletionNotes = await database.getMarkedForDeletionNotes();

      debugPrint(
        '📤 Pushing ${dirtyNotes.length} dirty notes, '
        '${deletionNotes.length} deletions',
      );

      // Push dirty notes (create or update)
      for (final note in dirtyNotes) {
        try {
          debugPrint('  📤 Pushing note: ${note.path}');
          final result = await _pushSingleNote(note);
          if (result.isConflict) {
            debugPrint('  ⚠️ Conflict detected for: ${note.path}');
            conflicts.add(result.note);
          } else if (result.isSuccess) {
            debugPrint('  ✅ Successfully pushed: ${note.path}');
            succeeded.add(result.note);
          } else {
            debugPrint(
              '  ❌ Push failed for: ${note.path} (no success or conflict)',
            );
          }
        } catch (e, stackTrace) {
          debugPrint('  ❌ Push error for ${note.path}: $e');
          debugPrint('  Stack trace: $stackTrace');

          // If file not found, delete orphaned note from database
          if (e.toString().contains('File not found')) {
            debugPrint(
              '  🗑️ Deleting orphaned note from database: ${note.path}',
            );
            try {
              await database.deleteNoteById(note.id);
            } catch (deleteError) {
              debugPrint('  ⚠️ Failed to delete orphaned note: $deleteError');
            }
          } else {
            failed.add(
              SyncFailure(
                note: note,
                error: e.toString(),
                type: _classifyError(e),
                timestamp: DateTime.now(),
              ),
            );
          }
        }
      }

      // Push deletions
      for (final note in deletionNotes) {
        try {
          debugPrint('  🗑️ Deleting note: ${note.path}');
          final result = await _deleteSingleNote(note);
          if (result.isSuccess) {
            debugPrint('  ✅ Successfully deleted: ${note.path}');
            succeeded.add(result.note);
          } else {
            debugPrint('  ❌ Deletion failed for: ${note.path}');
          }
        } catch (e, stackTrace) {
          debugPrint('  ❌ Deletion error for ${note.path}: $e');
          debugPrint('  Stack trace: $stackTrace');
          failed.add(
            SyncFailure(
              note: note,
              error: e.toString(),
              type: _classifyError(e),
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      return SyncResult(
        succeeded: succeeded,
        failed: failed,
        conflicts: conflicts,
        isOnline: true,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Push failed: $e');
      failed.add(
        SyncFailure(
          note: Note(
            id: 'push-error',
            path: '',
            title: 'Push Error',
            lastKnownSha: null,
            isDirty: false,
            updatedAt: DateTime.now(),
            createdAt: DateTime.now(),
            contentPreview: null,
            contentLength: 0,
            isConflict: false,
            markedForDeletion: false,
          ),
          error: e.toString(),
          type: _classifyError(e),
          timestamp: DateTime.now(),
        ),
      );

      return SyncResult(
        succeeded: succeeded,
        failed: failed,
        conflicts: conflicts,
        isOnline: true,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Pull a single file from GitHub
  ///
  /// Logic:
  /// - If file doesn't exist locally: download and insert
  /// - If file exists and SHA matches: skip
  /// - If file exists, SHA differs, and not dirty: update local
  /// - If file exists, SHA differs, and IS dirty: CONFLICT
  Future<_PullResult> _pullSingleFile(
    GitHubFile remoteFile,
    Map<String, Note> localNotesByPath,
  ) async {
    final localNote = localNotesByPath[remoteFile.path];

    // Case 1: New file (doesn't exist locally)
    if (localNote == null) {
      debugPrint('  ⬇️ New file: ${remoteFile.path}');
      final content = await githubClient.downloadFile(remoteFile.path);
      if (content == null) {
        throw Exception('Failed to download file: ${remoteFile.path}');
      }

      // Save to local filesystem
      final localPath = fileService.getLocalPath(remoteFile.path);
      await fileService.writeFile(localPath, content);

      // Extract title from content
      final title = filenameService.extractTitle(content, remoteFile.path);

      // Insert into database
      final noteId = _uuid.v4();
      await database.insertNote(
        NotesCompanion.insert(
          id: noteId,
          path: remoteFile.path,
          title: Value(title),
          lastKnownSha: Value(remoteFile.sha),
          isDirty: const Value(false),
          contentPreview: Value(_generatePreview(content)),
          contentLength: Value(content.length),
        ),
      );

      // Update FTS index for search
      await database.updateFtsIndex(noteId, title, content);

      final note = await database.getNoteById(noteId);
      return _PullResult(note: note!, isSuccess: true, isConflict: false);
    }

    // Case 2: File exists locally, check SHA
    debugPrint('  🔍 Comparing: ${remoteFile.path} (ID: ${localNote.id})');
    debugPrint('     Local SHA: ${localNote.lastKnownSha}');
    debugPrint('     Remote SHA: ${remoteFile.sha}');
    debugPrint('     Is dirty: ${localNote.isDirty}');
    debugPrint('     Is conflict: ${localNote.isConflict}');

    if (localNote.lastKnownSha == remoteFile.sha) {
      // No changes on remote
      if (localNote.isDirty) {
        // Local has changes, remote unchanged - skip pull, let push handle it
        debugPrint('  ⏭️ Skipping (dirty, will be pushed): ${remoteFile.path}');
      } else {
        // Both unchanged
        debugPrint('  ⏭️ Unchanged: ${remoteFile.path}');
      }
      return _PullResult(note: localNote, isSuccess: true, isConflict: false);
    }

    // Case 3: Remote changed, check if local is dirty
    if (localNote.isDirty) {
      // CONFLICT: both remote and local have changes
      debugPrint('  ⚠️ TRUE CONFLICT detected: ${remoteFile.path}');
      debugPrint(
        '     Remote changed from ${localNote.lastKnownSha} to ${remoteFile.sha}',
      );
      debugPrint('     AND local has unsaved changes');

      // Mark as conflict and clear dirty flag to prevent push attempts
      await database.updateNoteById(
        localNote.id,
        NotesCompanion(
          isConflict: const Value(true),
          isDirty: const Value(false),
        ),
      );

      // Download remote version to a conflict file
      await _createConflictFile(remoteFile, localNote);

      final updatedNote = await database.getNoteById(localNote.id);
      return _PullResult(
        note: updatedNote!,
        isSuccess: false,
        isConflict: true,
      );
    }

    // Case 4: Remote changed, local not dirty - safe to update
    debugPrint('  ⬇️ Updating: ${remoteFile.path}');
    final content = await githubClient.downloadFile(remoteFile.path);
    if (content == null) {
      throw Exception('Failed to download file: ${remoteFile.path}');
    }

    // Update local filesystem
    final localPath = fileService.getLocalPath(remoteFile.path);
    await fileService.writeFile(localPath, content);

    // Update database
    final title = filenameService.extractTitle(content, remoteFile.path);
    await database.updateNoteById(
      localNote.id,
      NotesCompanion(
        title: Value(title),
        lastKnownSha: Value(remoteFile.sha),
        isDirty: const Value(false),
        contentPreview: Value(_generatePreview(content)),
        contentLength: Value(content.length),
      ),
    );

    // Update FTS index for search
    await database.updateFtsIndex(localNote.id, title, content);

    final updatedNote = await database.getNoteById(localNote.id);
    return _PullResult(note: updatedNote!, isSuccess: true, isConflict: false);
  }

  /// Push a single dirty note to GitHub
  Future<_PushResult> _pushSingleNote(Note note) async {
    // Read local file content
    final localPath = fileService.getLocalPath(note.path);
    final content = await fileService.readFile(localPath);

    debugPrint('  📝 Pushing note ID: ${note.id}');
    String newSha;

    if (note.lastKnownSha == null || note.lastKnownSha!.isEmpty) {
      // Create new file on GitHub
      debugPrint('  ⬆️ Creating: ${note.path} (no existing SHA)');
      newSha = await githubClient.createFile(
        path: note.path,
        content: content,
        message: 'Create ${note.title}',
      );
      debugPrint('  ✅ Created with SHA: $newSha');
    } else {
      // Update existing file on GitHub
      debugPrint(
        '  ⬆️ Updating: ${note.path} (current SHA: ${note.lastKnownSha})',
      );
      try {
        newSha = await githubClient.updateFile(
          path: note.path,
          content: content,
          currentSha: note.lastKnownSha!,
          message: 'Update ${note.title}',
        );
        debugPrint('  ✅ Updated with new SHA: $newSha');
      } catch (e) {
        // Check if it's a SHA mismatch (conflict)
        if (e.toString().contains('does not match') ||
            e.toString().contains('409')) {
          debugPrint('  ⚠️ Conflict on push: ${note.path}');

          // Mark as conflict and clear dirty flag to prevent retry loops
          await database.updateNoteById(
            note.id,
            NotesCompanion(
              isConflict: const Value(true),
              isDirty: const Value(false),
            ),
          );

          final updatedNote = await database.getNoteById(note.id);
          return _PushResult(
            note: updatedNote!,
            isSuccess: false,
            isConflict: true,
          );
        }
        rethrow;
      }
    }

    // Update database: mark as clean, update SHA
    debugPrint('  💾 Saving SHA to database for note ID ${note.id}: $newSha');
    await database.updateNoteAfterSync(note.id, newSha);

    final updatedNote = await database.getNoteById(note.id);
    debugPrint(
      '  ✓ Note reloaded, SHA in DB: ${updatedNote?.lastKnownSha}, isDirty: ${updatedNote?.isDirty}',
    );
    return _PushResult(note: updatedNote!, isSuccess: true, isConflict: false);
  }

  /// Delete a single note from GitHub
  Future<_PushResult> _deleteSingleNote(Note note) async {
    if (note.lastKnownSha == null || note.lastKnownSha!.isEmpty) {
      // Note doesn't exist on GitHub, just remove from database
      debugPrint('  🗑️ Removing local-only note: ${note.path}');
      await database.deleteNoteById(note.id);
      return _PushResult(note: note, isSuccess: true, isConflict: false);
    }

    // Delete from GitHub
    debugPrint('  🗑️ Deleting from GitHub: ${note.path}');
    try {
      await githubClient.deleteFile(
        path: note.path,
        currentSha: note.lastKnownSha!,
        message: 'Delete ${note.title}',
      );
    } catch (e) {
      // Check if file doesn't exist (already deleted) - treat as success
      if (e.toString().contains('Resource not found') ||
          e.toString().contains('404')) {
        debugPrint('  ℹ️ File already deleted from GitHub: ${note.path}');
        // Continue to delete local file and database entry below
      } else if (e.toString().contains('does not match') ||
          e.toString().contains('409')) {
        // SHA mismatch (conflict)
        debugPrint('  ⚠️ Conflict on delete: ${note.path}');

        // Mark as conflict and clear deletion/dirty flags
        await database.updateNoteById(
          note.id,
          NotesCompanion(
            isConflict: const Value(true),
            markedForDeletion: const Value(false),
            isDirty: const Value(false),
          ),
        );

        final updatedNote = await database.getNoteById(note.id);
        return _PushResult(
          note: updatedNote!,
          isSuccess: false,
          isConflict: true,
        );
      } else {
        rethrow;
      }
    }

    // Delete local file and database entry
    final localPath = fileService.getLocalPath(note.path);
    await fileService.deleteFile(localPath);
    await database.deleteNoteById(note.id);

    return _PushResult(note: note, isSuccess: true, isConflict: false);
  }

  /// Handle notes that exist locally but not on GitHub (deleted remotely)
  Future<void> _handleRemoteDeletions(
    List<GitHubFile> remoteFiles,
    List<Note> localNotes,
  ) async {
    final remotePaths = remoteFiles.map((f) => f.path).toSet();

    for (final localNote in localNotes) {
      // Skip notes that are already marked as conflicts or for deletion
      if (localNote.isConflict || localNote.markedForDeletion) {
        continue;
      }

      if (!remotePaths.contains(localNote.path)) {
        // Check if this is a new note (never synced) or a deleted note
        if (localNote.lastKnownSha == null) {
          // This is a new note that hasn't been pushed yet - skip it
          // The push phase will handle uploading it
          debugPrint('  📝 New note (not yet pushed): ${localNote.path}');
          continue;
        }

        if (localNote.isDirty) {
          // Local has changes, remote deleted - this is a conflict
          debugPrint('  ⚠️ Delete conflict: ${localNote.path}');
          await database.updateNoteById(
            localNote.id,
            NotesCompanion(
              isConflict: const Value(true),
              isDirty: const Value(false),
            ),
          );
        } else {
          // Safe to delete locally
          debugPrint('  🗑️ Removing deleted note: ${localNote.path}');
          final localPath = fileService.getLocalPath(localNote.path);
          await fileService.deleteFile(localPath);
          await database.deleteNoteById(localNote.id);
        }
      }
    }
  }

  /// Create a conflict file for manual resolution
  ///
  /// Process:
  /// 1. Download remote version
  /// 2. Save as "[original]-conflict-[timestamp].md"
  /// 3. Insert as conflict note in database
  Future<void> _createConflictFile(
    GitHubFile remoteFile,
    Note localNote,
  ) async {
    final content = await githubClient.downloadFile(remoteFile.path);
    if (content == null) {
      throw Exception('Failed to download conflict file: ${remoteFile.path}');
    }

    // Generate conflict filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = remoteFile.path.replaceAll('.md', '');
    final conflictPath = '$baseName-conflict-$timestamp.md';

    // Save conflict file
    final conflictLocalPath = fileService.getLocalPath(conflictPath);
    await fileService.writeFile(conflictLocalPath, content);

    // Insert conflict note (no SHA - this is a local-only file)
    final title = filenameService.extractTitle(content, conflictPath);
    final conflictId = _uuid.v4();
    await database.insertNote(
      NotesCompanion.insert(
        id: conflictId,
        path: conflictPath,
        title: Value('CONFLICT: $title'),
        lastKnownSha: const Value(null), // Local-only, never on GitHub
        isDirty: const Value(false),
        isConflict: const Value(true),
        contentPreview: Value(_generatePreview(content)),
        contentLength: Value(content.length),
      ),
    );

    // Update FTS index for search
    await database.updateFtsIndex(conflictId, 'CONFLICT: $title', content);

    debugPrint('  📁 Created conflict file: $conflictPath');
  }

  /// Generate content preview (first 300 characters)
  String _generatePreview(String content) {
    final maxLength = 300;
    if (content.length <= maxLength) {
      return content;
    }
    return '${content.substring(0, maxLength)}...';
  }

  /// Classify error into appropriate SyncFailureType
  SyncFailureType _classifyError(Object error) {
    final errorString = error.toString().toLowerCase();

    if (error is SocketException ||
        errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection')) {
      return SyncFailureType.network;
    }

    if (errorString.contains('409') ||
        errorString.contains('conflict') ||
        errorString.contains('does not match')) {
      return SyncFailureType.conflict;
    }

    if (errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('auth')) {
      return SyncFailureType.auth;
    }

    if (errorString.contains('429') || errorString.contains('rate limit')) {
      return SyncFailureType.rateLimit;
    }

    if (errorString.contains('422') || errorString.contains('validation')) {
      return SyncFailureType.validation;
    }

    return SyncFailureType.unknown;
  }
}

/// Internal result type for pull operations
class _PullResult {
  final Note note;
  final bool isSuccess;
  final bool isConflict;

  _PullResult({
    required this.note,
    required this.isSuccess,
    required this.isConflict,
  });
}

/// Internal result type for push operations
class _PushResult {
  final Note note;
  final bool isSuccess;
  final bool isConflict;

  _PushResult({
    required this.note,
    required this.isSuccess,
    required this.isConflict,
  });
}
