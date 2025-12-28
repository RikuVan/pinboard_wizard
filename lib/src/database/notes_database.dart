import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'notes_database.g.dart';

/// Main metadata table for notes
/// Stores sync state and metadata, NOT the actual content.
/// Files are the source of truth for content.
class Notes extends Table {
  /// UUID v4, generated using Uuid().v4() from uuid package
  TextColumn get id => text()();

  /// Repo path: "notes/flutter-state.md"
  TextColumn get path => text().unique()();

  /// Parsed from markdown H1 or filename
  TextColumn get title => text().nullable()();

  /// GitHub file SHA at last successful sync
  /// CRITICAL: Used to detect conflicts
  TextColumn get lastKnownSha => text().nullable()();

  /// True if edited locally since last pull
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  /// Last local edit time
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// When note was first discovered
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// First 300 characters for preview (not authoritative)
  TextColumn get contentPreview => text().nullable()();

  /// Cached content length
  IntColumn get contentLength => integer().withDefault(const Constant(0))();

  /// True if this is a conflict file
  BoolColumn get isConflict => boolean().withDefault(const Constant(false))();

  /// True if note should be deleted from GitHub on next sync
  BoolColumn get markedForDeletion =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift database for managing notes metadata and full-text search
/// FTS5 table is created manually in migrations
@DriftDatabase(tables: [Notes])
class NotesDatabase extends _$NotesDatabase {
  NotesDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor
  NotesDatabase.test(super.executor);

  @override
  int get schemaVersion => 1;

  /// Get all notes ordered by updated date (newest first)
  Future<List<Note>> getAllNotes() async {
    return (select(
      notes,
    )..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])).get();
  }

  /// Get a note by its path
  Future<Note?> getNoteByPath(String path) async {
    return (select(notes)..where((n) => n.path.equals(path))).getSingleOrNull();
  }

  /// Get a note by its ID
  Future<Note?> getNoteById(String id) async {
    return (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  /// Get all dirty notes (need sync)
  /// Excludes notes marked for deletion or in conflict state
  Future<List<Note>> getDirtyNotes() async {
    return (select(notes)
          ..where((n) => n.isDirty.equals(true))
          ..where((n) => n.markedForDeletion.equals(false))
          ..where((n) => n.isConflict.equals(false)))
        .get();
  }

  /// Get all conflict notes
  Future<List<Note>> getConflictNotes() async {
    return (select(notes)..where((n) => n.isConflict.equals(true))).get();
  }

  /// Get notes marked for deletion (excluding conflicts)
  Future<List<Note>> getMarkedForDeletionNotes() async {
    return (select(notes)
          ..where((n) => n.markedForDeletion.equals(true))
          ..where((n) => n.isConflict.equals(false)))
        .get();
  }

  /// Insert a new note
  Future<int> insertNote(NotesCompanion note) async {
    return await into(notes).insert(note);
  }

  /// Insert or update a note
  Future<void> upsertNote(NotesCompanion note) async {
    await into(notes).insertOnConflictUpdate(note);
  }

  /// Update a note by ID
  Future<int> updateNoteById(String id, NotesCompanion companion) async {
    return await (update(
      notes,
    )..where((n) => n.id.equals(id))).write(companion);
  }

  /// Update a note by path
  Future<int> updateNoteByPath(String path, NotesCompanion companion) async {
    return await (update(
      notes,
    )..where((n) => n.path.equals(path))).write(companion);
  }

  /// Mark a note as dirty (needs sync)
  Future<void> markNoteDirty(String id, {required bool isDirty}) async {
    await (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(isDirty: Value(isDirty), updatedAt: Value(DateTime.now())),
    );
  }

  /// Mark a note as conflict
  Future<void> markNoteConflict(String id, {required bool isConflict}) async {
    await (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(isConflict: Value(isConflict)),
    );
  }

  /// Mark a note for deletion
  Future<void> markNoteForDeletion(
    String id, {
    required bool markedForDeletion,
  }) async {
    await (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(markedForDeletion: Value(markedForDeletion)),
    );
  }

  /// Update note metadata after sync
  Future<void> updateNoteAfterSync(String id, String newSha) async {
    debugPrint('  💾 updateNoteAfterSync: id=$id, newSha=$newSha');
    await (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        lastKnownSha: Value(newSha),
        isDirty: const Value(false),
        isConflict: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Verify it was saved
    final updated = await getNoteById(id);
    debugPrint('  ✓ Verified saved SHA: ${updated?.lastKnownSha}');
  }

  /// Delete a note by ID
  Future<int> deleteNoteById(String id) async {
    // Get the rowid first for FTS deletion
    final rowIdResult = await customSelect(
      'SELECT rowid FROM notes WHERE id = ?',
      variables: [Variable.withString(id)],
      readsFrom: {notes},
    ).getSingleOrNull();

    // Delete from FTS5 index first if note existed
    if (rowIdResult != null) {
      final rowId = rowIdResult.read<int>('rowid');
      await customStatement('DELETE FROM notes_fts WHERE rowid = ?', [rowId]);
    }

    // Delete from notes table
    final result = await (delete(notes)..where((n) => n.id.equals(id))).go();

    return result;
  }

  /// Delete a note by path
  Future<int> deleteNoteByPath(String path) async {
    // Get the rowid first for FTS deletion
    final rowIdResult = await customSelect(
      'SELECT rowid FROM notes WHERE path = ?',
      variables: [Variable.withString(path)],
      readsFrom: {notes},
    ).getSingleOrNull();

    // Delete from FTS5 index first if note existed
    if (rowIdResult != null) {
      final rowId = rowIdResult.read<int>('rowid');
      await customStatement('DELETE FROM notes_fts WHERE rowid = ?', [rowId]);
    }

    // Delete from notes table
    final result = await (delete(
      notes,
    )..where((n) => n.path.equals(path))).go();

    return result;
  }

  /// Update FTS5 index for a note
  /// Call this whenever note content changes
  Future<void> updateFtsIndex(String id, String title, String content) async {
    // First, get the rowid for this note
    final note = await getNoteById(id);
    if (note == null) {
      throw StateError('Cannot update FTS index: note not found with id $id');
    }

    // SQLite rowid is 1-based and auto-increments, but we need to get it from the note
    final rowIdResult = await customSelect(
      'SELECT rowid FROM notes WHERE id = ?',
      variables: [Variable.withString(id)],
      readsFrom: {notes},
    ).getSingleOrNull();

    if (rowIdResult == null) {
      throw StateError('Cannot find rowid for note $id');
    }

    final rowId = rowIdResult.read<int>('rowid');

    // Check if entry exists in FTS
    final existsResult = await customSelect(
      'SELECT rowid FROM notes_fts WHERE rowid = ?',
      variables: [Variable.withInt(rowId)],
    ).getSingleOrNull();

    if (existsResult != null) {
      // Delete old entry
      await customStatement('DELETE FROM notes_fts WHERE rowid = ?', [rowId]);
    }

    // Insert new entry
    await customStatement(
      'INSERT INTO notes_fts(rowid, title, content) VALUES (?, ?, ?)',
      [rowId, title, content],
    );
  }

  /// Full-text search using FTS5
  /// Returns ranked results limited to 50
  Future<List<Note>> searchNotes(String query) async {
    if (query.trim().isEmpty) {
      return getAllNotes();
    }

    // Query FTS5 table first to get matching rowids, then join with notes
    final results = await customSelect(
      '''
      SELECT notes.* FROM notes_fts
      INNER JOIN notes ON notes_fts.rowid = notes.rowid
      WHERE notes_fts MATCH ?
      ORDER BY notes_fts.rank
      LIMIT 50
      ''',
      variables: [Variable.withString(query)],
      readsFrom: {notes},
    ).get();

    // Map the results to Note objects
    return results.map((row) => notes.map(row.data)).toList();
  }

  /// Get count of dirty notes
  Future<int> getDirtyNotesCount() async {
    final result =
        await (selectOnly(notes)
              ..addColumns([notes.id.count()])
              ..where(notes.isDirty.equals(true)))
            .getSingle();
    return result.read(notes.id.count()) ?? 0;
  }

  /// Get count of conflict notes
  Future<int> getConflictNotesCount() async {
    final result =
        await (selectOnly(notes)
              ..addColumns([notes.id.count()])
              ..where(notes.isConflict.equals(true)))
            .getSingle();
    return result.read(notes.id.count()) ?? 0;
  }

  /// Clear all notes (for testing or reset)
  Future<void> clearAllNotes() async {
    // Clear FTS5 table
    await customStatement('DELETE FROM notes_fts');
    await delete(notes).go();
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      // Create regular tables
      await m.createAll();

      // Create FTS5 virtual table manually (without content table linkage)
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
          title,
          content
        )
      ''');
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Handle migrations between schema versions
      // Example future migrations:
      // if (from < 2) {
      //   // Migration from version 1 to 2
      //   await m.addColumn(notes, notes.someNewColumn);
      // }
      // if (from < 3) {
      //   // Migration from version 2 to 3
      //   await customStatement('ALTER TABLE notes ADD COLUMN another_column TEXT');
      // }
    },
    beforeOpen: (details) async {
      // Enable foreign keys
      await customStatement('PRAGMA foreign_keys = ON');

      // Perform any data migrations after schema changes
      // This runs on every database open, so keep it lightweight
      // Example:
      // if (details.wasCreated) {
      //   // Database just created, no migration needed
      // } else if (details.hadUpgrade) {
      //   // Database was upgraded, perform data migration if needed
      // }
    },
  );
}

/// Open database connection with proper SQLite setup for FTS5
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'notes.db'));

    // Make sure sqlite3 is initialized for FTS5 support
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Also work around limitations on macOS
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
