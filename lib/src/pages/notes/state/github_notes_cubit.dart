import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinboard_wizard/src/database/notes_database.dart';
import 'package:pinboard_wizard/src/notes/models/sync_result.dart';
import 'package:pinboard_wizard/src/notes/services/file_service.dart';
import 'package:pinboard_wizard/src/notes/services/network_service.dart';
import 'package:pinboard_wizard/src/notes/services/note_sync_engine.dart';
import 'package:pinboard_wizard/src/pages/notes/state/github_notes_state.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing GitHub-backed notes state, search, and synchronization.
///
/// This cubit handles:
/// - Loading notes from local database
/// - Full-text search using FTS5
/// - Syncing with GitHub (pull/push)
/// - Managing note selection and editing state
/// - Tracking sync status and conflicts
class GitHubNotesCubit extends Cubit<GitHubNotesState> {
  GitHubNotesCubit({
    required this.database,
    required this.syncEngine,
    required this.fileService,
    required this.networkService,
  }) : super(const GitHubNotesState());

  final NotesDatabase database;
  final NoteSyncEngine syncEngine;
  final FileService fileService;
  final NetworkService networkService;

  Timer? _autoSyncTimer;

  /// Initialize the cubit and load notes
  Future<void> initialize() async {
    // Clean up any orphaned notes first
    await cleanupOrphanedNotes();
    await loadNotes();
    _startAutoSync();
  }

  /// Start periodic auto-sync every 5 minutes when online
  /// TEMPORARILY DISABLED for debugging
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    // TODO: Re-enable auto-sync after fixing sync issues
    // _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
    //   final isOnline = await networkService.isOnline();
    //   if (isOnline && !state.isSyncing) {
    //     await sync();
    //   }
    // });
    debugPrint('⚠️ Auto-sync is DISABLED for debugging');
  }

  /// Load all notes from the local database
  Future<void> loadNotes() async {
    emit(state.copyWith(status: GitHubNotesStatus.loading));

    try {
      final notes = await database.getAllNotes();
      final isOnline = await networkService.isOnline();

      emit(
        state.copyWith(
          status: GitHubNotesStatus.loaded,
          notes: notes,
          isOnline: isOnline,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: GitHubNotesStatus.error, errorMessage: 'Failed to load notes: $e'),
      );
    }
  }

  /// Perform full-text search using FTS5
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }

    try {
      final results = await database.searchNotes(query);
      emit(
        state.copyWith(
          status: GitHubNotesStatus.loaded,
          searchQuery: query,
          isSearching: true,
          filteredNotes: results,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: GitHubNotesStatus.error, errorMessage: 'Search failed: $e'));
    }
  }

  /// Clear search and show all notes
  void clearSearch() {
    emit(
      state.copyWith(
        isSearching: false,
        searchQuery: '',
        filteredNotes: [],
        status: GitHubNotesStatus.loaded,
      ),
    );
  }

  /// Select a note and load its content from the file system
  Future<void> selectNote(Note note) async {
    emit(state.copyWith(selectedNote: note, noteContent: null));

    try {
      final localPath = fileService.getLocalPath(note.path);
      final content = await fileService.readFile(localPath);
      emit(state.copyWith(noteContent: content, errorMessage: null));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to load note content: $e'));
    }
  }

  /// Clear note selection
  void clearSelection() {
    emit(state.copyWith(selectedNote: null, noteContent: null, isEditing: false));
  }

  /// Start editing the selected note
  void startEditing() {
    if (state.selectedNote == null) return;
    emit(state.copyWith(isEditing: true));
  }

  /// Cancel editing without saving
  void cancelEditing() {
    emit(state.copyWith(isEditing: false));
  }

  /// Save edited note content locally and mark as dirty
  Future<void> saveNote(String content) async {
    final note = state.selectedNote;
    if (note == null) {
      debugPrint('⚠️ Cannot save: no note selected');
      return;
    }

    debugPrint('💾 Saving note: ${note.path}');
    debugPrint('   Content length: ${content.length} chars');
    emit(state.copyWith(isSaving: true));

    try {
      // Write content to file
      final localPath = fileService.getLocalPath(note.path);
      debugPrint('   Writing to: $localPath');
      await fileService.writeFile(localPath, content);
      debugPrint('   ✅ File written successfully');

      // Update database: mark as dirty, update timestamp, regenerate preview
      final preview = content.length > 300 ? '${content.substring(0, 297)}...' : content;

      debugPrint('   Updating database: isDirty=true');
      debugPrint('   Note ID: ${note.id}');
      debugPrint('   Current SHA (will remain): ${note.lastKnownSha}');
      await database.updateNoteById(
        note.id,
        NotesCompanion(
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
          contentPreview: Value(preview),
          contentLength: Value(content.length),
        ),
      );
      debugPrint('   ✅ Database updated (SHA unchanged, isDirty=true)');

      // Update FTS index for search
      debugPrint('   Updating FTS index...');
      await database.updateFtsIndex(note.id, note.title ?? '', content);
      debugPrint('   ✅ FTS index updated');

      // Reload notes to reflect changes
      debugPrint('   Reloading notes...');
      await loadNotes();

      // Re-select the note to show updated content
      final updatedNote = state.notes.firstWhere((n) => n.id == note.id);
      debugPrint('   Re-selecting note...');
      await selectNote(updatedNote);

      debugPrint('✅ Save complete');
      emit(state.copyWith(isSaving: false, isEditing: false, errorMessage: null));
    } catch (e, stackTrace) {
      debugPrint('❌ Save failed: $e');
      debugPrint('   Stack trace: $stackTrace');
      emit(state.copyWith(isSaving: false, errorMessage: 'Failed to save note: $e'));
    }
  }

  /// Start creating a new note (shows inline form)
  void startCreating() {
    emit(state.copyWith(isCreating: true, selectedNote: null, noteContent: null, isEditing: false));
  }

  /// Cancel creating a new note
  void cancelCreating() {
    emit(state.copyWith(isCreating: false));
  }

  /// Create a new note locally
  Future<void> createNote({required String title, required String content}) async {
    try {
      // Generate filename from title
      final filename = _sanitizeFilename(title);
      final path = '$filename.md';

      // Check if file already exists
      final existingNote = await database.getNoteByPath(path);
      if (existingNote != null) {
        emit(
          state.copyWith(isCreating: false, errorMessage: 'A note with this title already exists'),
        );
        return;
      }

      // Write file to local filesystem
      final localPath = fileService.getLocalPath(path);
      await fileService.writeFile(localPath, content);

      // Create database entry
      final preview = content.length > 300 ? '${content.substring(0, 297)}...' : content;
      final noteId = _generateUuid();

      await database.insertNote(
        NotesCompanion(
          id: Value(noteId),
          path: Value(path),
          title: Value(title),
          isDirty: const Value(true),
          contentPreview: Value(preview),
          contentLength: Value(content.length),
        ),
      );

      // Update FTS index for search
      await database.updateFtsIndex(noteId, title, content);

      // Reload notes and select the new note
      await loadNotes();

      final newNote = await database.getNoteByPath(path);
      if (newNote != null) {
        await selectNote(newNote);
      }

      emit(state.copyWith(isCreating: false, errorMessage: null));
    } catch (e) {
      emit(state.copyWith(isCreating: false, errorMessage: 'Failed to create note: $e'));
    }
  }

  /// Delete a note locally and mark for deletion
  Future<void> deleteNote(String noteId) async {
    try {
      final note = state.notes.firstWhere((n) => n.id == noteId);

      // Mark for deletion and clear dirty/conflict flags
      await database.updateNoteById(
        note.id,
        NotesCompanion(
          markedForDeletion: const Value(true),
          isDirty: const Value(false),
          isConflict: const Value(false),
        ),
      );

      // Delete local file
      final localPath = fileService.getLocalPath(note.path);
      await fileService.deleteFile(localPath);

      // Clear selection if this note was selected
      if (state.selectedNote?.id == noteId) {
        emit(state.copyWith(selectedNote: null, noteContent: null));
      }

      // Reload notes
      await loadNotes();
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to delete note: $e'));
    }
  }

  /// Clean up orphaned notes (notes in database without local files)
  Future<void> cleanupOrphanedNotes() async {
    try {
      final notes = await database.getAllNotes();
      var cleanedCount = 0;

      debugPrint('🧹 Checking ${notes.length} notes for orphaned files...');

      for (final note in notes) {
        final localPath = fileService.getLocalPath(note.path);
        final exists = await fileService.fileExists(localPath);

        debugPrint('  Checking: ${note.path} -> $localPath (exists: $exists)');

        if (!exists) {
          // Delete orphaned note from database
          debugPrint('  🗑️ Deleting orphaned note: ${note.path}');
          await database.deleteNoteById(note.id);
          cleanedCount++;
        }
      }

      if (cleanedCount > 0) {
        debugPrint('✅ Cleaned up $cleanedCount orphaned notes');
        await loadNotes();
      } else {
        debugPrint('✅ No orphaned notes found');
      }
    } catch (e) {
      debugPrint('❌ Failed to cleanup orphaned notes: $e');
      emit(state.copyWith(errorMessage: 'Failed to cleanup orphaned notes: $e'));
    }
  }

  /// Perform full sync: pull from GitHub, then push dirty notes
  Future<void> sync() async {
    emit(state.copyWith(isSyncing: true, syncResult: null));

    try {
      final isOnline = await networkService.isOnline();
      if (!isOnline) {
        emit(state.copyWith(isSyncing: false, isOnline: false, syncResult: SyncResult.offline()));
        return;
      }

      // Perform sync
      final result = await syncEngine.sync();

      // Reload notes to reflect sync changes
      await loadNotes();

      emit(
        state.copyWith(
          isSyncing: false,
          isOnline: true,
          syncResult: result,
          lastSyncTime: DateTime.now(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSyncing: false, errorMessage: 'Sync failed: $e'));
    }
  }

  /// Retry failed notes from last sync
  Future<void> retryFailedNotes() async {
    final lastResult = state.syncResult;
    if (lastResult == null || lastResult.failed.isEmpty) return;

    await sync(); // Retry full sync
  }

  /// Get notes with conflicts
  Future<List<Note>> getConflictNotes() async {
    try {
      return await database.getConflictNotes();
    } catch (e) {
      return [];
    }
  }

  /// Resolve conflict by keeping the original (discarding conflict file)
  Future<void> resolveConflictKeepOriginal(Note conflictNote) async {
    try {
      await deleteNote(conflictNote.id);
      emit(state.copyWith(errorMessage: null));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to resolve conflict: $e'));
    }
  }

  /// Resolve conflict by replacing original with conflict version
  Future<void> resolveConflictKeepYours(Note originalNote, Note conflictNote) async {
    try {
      // Read conflict content
      final conflictLocalPath = fileService.getLocalPath(conflictNote.path);
      final conflictContent = await fileService.readFile(conflictLocalPath);

      // Write to original
      final originalLocalPath = fileService.getLocalPath(originalNote.path);
      await fileService.writeFile(originalLocalPath, conflictContent);

      // Update original as dirty
      await database.updateNoteById(
        originalNote.id,
        NotesCompanion(isDirty: const Value(true), updatedAt: Value(DateTime.now())),
      );

      // Delete conflict file
      await deleteNote(conflictNote.id);

      // Reload
      await loadNotes();
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to resolve conflict: $e'));
    }
  }

  /// Get footer text for display
  String get footerText {
    final displayNotes = state.displayNotes;
    final totalNotes = state.notes.length;
    final dirtyCount = state.notes.where((n) => n.isDirty).length;

    if (state.isSearching) {
      return '${displayNotes.length} of $totalNotes notes';
    }

    if (dirtyCount > 0) {
      return '$totalNotes notes • $dirtyCount pending sync';
    }

    if (totalNotes == 1) {
      return '1 note';
    }

    return '$totalNotes notes';
  }

  /// Simple UUID generator (v4)
  String _generateUuid() {
    return const Uuid().v4();
  }

  /// Sanitize filename by removing invalid characters
  String _sanitizeFilename(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }

  /// Force clean up notes marked for deletion (useful for stuck deletion notes)
  Future<void> forceCleanDeletionNotes() async {
    try {
      debugPrint('🧹 Force cleaning deletion notes...');
      final deletionNotes = await database.getMarkedForDeletionNotes();

      for (final note in deletionNotes) {
        debugPrint('  🗑️ Removing stuck deletion note: ${note.path}');

        // Delete local file if it exists
        final localPath = fileService.getLocalPath(note.path);
        if (await fileService.fileExists(localPath)) {
          await fileService.deleteFile(localPath);
        }

        // Delete from database
        await database.deleteNoteById(note.id);
      }

      debugPrint('✅ Cleaned ${deletionNotes.length} deletion notes');
      await loadNotes();
    } catch (e) {
      debugPrint('❌ Failed to clean deletion notes: $e');
      emit(state.copyWith(errorMessage: 'Failed to clean deletion notes: $e'));
    }
  }

  /// Re-index all existing notes for FTS search
  /// Call this once to index notes that were created before FTS indexing was added
  Future<void> reindexAllNotes() async {
    try {
      debugPrint('🔍 Re-indexing all notes for search...');
      final notes = await database.getAllNotes();
      var indexedCount = 0;

      for (final note in notes) {
        try {
          // Read file content
          final localPath = fileService.getLocalPath(note.path);
          if (await fileService.fileExists(localPath)) {
            final content = await fileService.readFile(localPath);
            await database.updateFtsIndex(note.id, note.title ?? '', content);
            indexedCount++;
          } else {
            debugPrint('  ⚠️ Skipping ${note.path} - file not found');
          }
        } catch (e) {
          debugPrint('  ❌ Failed to index ${note.path}: $e');
        }
      }

      debugPrint('✅ Re-indexed $indexedCount of ${notes.length} notes');
    } catch (e) {
      debugPrint('❌ Failed to re-index notes: $e');
      emit(state.copyWith(errorMessage: 'Failed to re-index notes: $e'));
    }
  }

  @override
  Future<void> close() {
    _autoSyncTimer?.cancel();
    return super.close();
  }
}
