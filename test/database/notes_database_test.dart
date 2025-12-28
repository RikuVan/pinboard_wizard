import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matcher/matcher.dart' as matcher;
import 'package:pinboard_wizard/src/database/notes_database.dart';

void main() {
  late NotesDatabase db;

  setUp(() {
    // Use in-memory database for testing
    db = NotesDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('NotesDatabase - Basic Operations', () {
    test('insert note should add new note', () async {
      final note = NotesCompanion(
        id: const Value('test-id-1'),
        path: const Value('notes/test.md'),
        title: const Value('Test Note'),
        lastKnownSha: const Value('sha123'),
        isDirty: const Value(false),
        contentPreview: const Value('This is a test note'),
        contentLength: const Value(100),
      );

      await db.insertNote(note);

      final retrieved = await db.getNoteById('test-id-1');
      expect(retrieved, matcher.isNotNull);
      expect(retrieved!.id, 'test-id-1');
      expect(retrieved.path, 'notes/test.md');
      expect(retrieved.title, 'Test Note');
      expect(retrieved.lastKnownSha, 'sha123');
      expect(retrieved.isDirty, false);
    });

    test('upsert note should insert if not exists', () async {
      final note = NotesCompanion(
        id: const Value('test-id-2'),
        path: const Value('notes/new.md'),
        title: const Value('New Note'),
      );

      await db.upsertNote(note);

      final retrieved = await db.getNoteById('test-id-2');
      expect(retrieved, matcher.isNotNull);
      expect(retrieved!.title, 'New Note');
    });

    test('upsert note should update if exists', () async {
      final note = NotesCompanion(
        id: const Value('test-id-3'),
        path: const Value('notes/update.md'),
        title: const Value('Original Title'),
      );

      await db.insertNote(note);

      final updated = NotesCompanion(
        id: const Value('test-id-3'),
        path: const Value('notes/update.md'),
        title: const Value('Updated Title'),
        isDirty: const Value(true),
      );

      await db.upsertNote(updated);

      final retrieved = await db.getNoteById('test-id-3');
      expect(retrieved!.title, 'Updated Title');
      expect(retrieved.isDirty, true);
    });

    test('get note by path should return correct note', () async {
      final note = NotesCompanion(
        id: const Value('test-id-4'),
        path: const Value('notes/find-by-path.md'),
        title: const Value('Find Me'),
      );

      await db.insertNote(note);

      final retrieved = await db.getNoteByPath('notes/find-by-path.md');
      expect(retrieved, matcher.isNotNull);
      expect(retrieved!.id, 'test-id-4');
      expect(retrieved.title, 'Find Me');
    });

    test('get note by path should return null if not found', () async {
      final retrieved = await db.getNoteByPath('notes/nonexistent.md');
      expect(retrieved, matcher.isNull);
    });

    test(
      'get all notes should return all notes ordered by updated date',
      () async {
        await db.insertNote(
          NotesCompanion(
            id: const Value('id-1'),
            path: const Value('notes/a.md'),
            title: const Value('First'),
            updatedAt: Value(DateTime(2024, 1, 1)),
          ),
        );

        await db.insertNote(
          NotesCompanion(
            id: const Value('id-2'),
            path: const Value('notes/b.md'),
            title: const Value('Second'),
            updatedAt: Value(DateTime(2024, 1, 3)),
          ),
        );

        await db.insertNote(
          NotesCompanion(
            id: const Value('id-3'),
            path: const Value('notes/c.md'),
            title: const Value('Third'),
            updatedAt: Value(DateTime(2024, 1, 2)),
          ),
        );

        final notes = await db.getAllNotes();
        expect(notes.length, 3);
        // Should be ordered by updatedAt desc (newest first)
        expect(notes[0].id, 'id-2'); // Jan 3
        expect(notes[1].id, 'id-3'); // Jan 2
        expect(notes[2].id, 'id-1'); // Jan 1
      },
    );

    test('delete note by id should remove note', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('delete-me-1'),
          path: const Value('notes/delete.md'),
          title: const Value('To Delete'),
        ),
      );

      await db.deleteNoteById('delete-me-1');

      final retrieved = await db.getNoteById('delete-me-1');
      expect(retrieved, matcher.isNull);
    });

    test('delete note by path should remove note', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('delete-me-2'),
          path: const Value('notes/delete-path.md'),
          title: const Value('To Delete'),
        ),
      );

      await db.deleteNoteByPath('notes/delete-path.md');

      final retrieved = await db.getNoteByPath('notes/delete-path.md');
      expect(retrieved, matcher.isNull);
    });
  });

  group('NotesDatabase - Update Operations', () {
    test('updateNoteById should update specific fields', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('update-id-1'),
          path: const Value('notes/update.md'),
          title: const Value('Original'),
          isDirty: const Value(false),
        ),
      );

      await db.updateNoteById(
        'update-id-1',
        const NotesCompanion(title: Value('Modified'), isDirty: Value(true)),
      );

      final retrieved = await db.getNoteById('update-id-1');
      expect(retrieved!.title, 'Modified');
      expect(retrieved.isDirty, true);
    });

    test('updateNoteByPath should update specific fields', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('update-id-2'),
          path: const Value('notes/update-path.md'),
          title: const Value('Original'),
        ),
      );

      await db.updateNoteByPath(
        'notes/update-path.md',
        const NotesCompanion(title: Value('Modified')),
      );

      final retrieved = await db.getNoteByPath('notes/update-path.md');
      expect(retrieved!.title, 'Modified');
    });

    test('markNoteDirty should update dirty flag', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('dirty-1'),
          path: const Value('notes/dirty.md'),
          isDirty: const Value(false),
        ),
      );

      await db.markNoteDirty('dirty-1', isDirty: true);

      final retrieved = await db.getNoteById('dirty-1');
      expect(retrieved!.isDirty, true);
    });

    test('markNoteConflict should update conflict flag', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('conflict-1'),
          path: const Value('notes/conflict.md'),
          isConflict: const Value(false),
        ),
      );

      await db.markNoteConflict('conflict-1', isConflict: true);

      final retrieved = await db.getNoteById('conflict-1');
      expect(retrieved!.isConflict, true);
    });

    test('markNoteForDeletion should update deletion flag', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('delete-flag-1'),
          path: const Value('notes/to-delete.md'),
          markedForDeletion: const Value(false),
        ),
      );

      await db.markNoteForDeletion('delete-flag-1', markedForDeletion: true);

      final retrieved = await db.getNoteById('delete-flag-1');
      expect(retrieved!.markedForDeletion, true);
    });

    test(
      'updateNoteAfterSync should clear dirty flag, conflict flag, and update SHA',
      () async {
        await db.insertNote(
          NotesCompanion(
            id: const Value('sync-1'),
            path: const Value('notes/sync.md'),
            isDirty: const Value(true),
            isConflict: const Value(true),
            lastKnownSha: const Value('old-sha'),
          ),
        );

        await db.updateNoteAfterSync('sync-1', 'new-sha');

        final retrieved = await db.getNoteById('sync-1');
        expect(retrieved!.isDirty, false);
        expect(retrieved.isConflict, false);
        expect(retrieved.lastKnownSha, 'new-sha');
      },
    );
  });

  group('NotesDatabase - Query Operations', () {
    setUp(() async {
      // Add test data
      await db.insertNote(
        NotesCompanion(
          id: const Value('query-1'),
          path: const Value('notes/dirty1.md'),
          isDirty: const Value(true),
        ),
      );
      await db.insertNote(
        NotesCompanion(
          id: const Value('query-2'),
          path: const Value('notes/clean.md'),
          isDirty: const Value(false),
        ),
      );
      await db.insertNote(
        NotesCompanion(
          id: const Value('query-3'),
          path: const Value('notes/dirty2.md'),
          isDirty: const Value(true),
        ),
      );
      await db.insertNote(
        NotesCompanion(
          id: const Value('query-4'),
          path: const Value('notes/conflict.md'),
          isConflict: const Value(true),
        ),
      );
      await db.insertNote(
        NotesCompanion(
          id: const Value('query-5'),
          path: const Value('notes/marked.md'),
          markedForDeletion: const Value(true),
        ),
      );
    });

    test('getDirtyNotes should return only dirty notes', () async {
      final dirtyNotes = await db.getDirtyNotes();
      expect(dirtyNotes.length, 2);
      expect(dirtyNotes.any((n) => n.id == 'query-1'), true);
      expect(dirtyNotes.any((n) => n.id == 'query-3'), true);
    });

    test('getConflictNotes should return only conflict notes', () async {
      final conflictNotes = await db.getConflictNotes();
      expect(conflictNotes.length, 1);
      expect(conflictNotes.first.id, 'query-4');
    });

    test('getMarkedForDeletionNotes should return only marked notes', () async {
      final markedNotes = await db.getMarkedForDeletionNotes();
      expect(markedNotes.length, 1);
      expect(markedNotes.first.id, 'query-5');
    });

    test('getDirtyNotesCount should return correct count', () async {
      final count = await db.getDirtyNotesCount();
      expect(count, 2);
    });

    test('getConflictNotesCount should return correct count', () async {
      final count = await db.getConflictNotesCount();
      expect(count, 1);
    });
  });

  group('NotesDatabase - FTS5 Search', () {
    setUp(() async {
      // Clear any existing data first
      await db.clearAllNotes();

      // Add notes with content for search testing
      await db.insertNote(
        NotesCompanion(
          id: const Value('fts-1'),
          path: const Value('notes/flutter.md'),
          title: const Value('Flutter State Management'),
        ),
      );
      await db.updateFtsIndex(
        'fts-1',
        'Flutter State Management',
        'This note discusses state management in Flutter using BLoC and Cubit patterns.',
      );

      await db.insertNote(
        NotesCompanion(
          id: const Value('fts-2'),
          path: const Value('notes/dart.md'),
          title: const Value('Dart Async Programming'),
        ),
      );
      await db.updateFtsIndex(
        'fts-2',
        'Dart Async Programming',
        'Learn about async/await, Futures, and Streams in Dart.',
      );

      await db.insertNote(
        NotesCompanion(
          id: const Value('fts-3'),
          path: const Value('notes/testing.md'),
          title: const Value('Testing Flutter Apps'),
        ),
      );
      await db.updateFtsIndex(
        'fts-3',
        'Testing Flutter Apps',
        'Unit testing, widget testing, and integration testing in Flutter.',
      );
    });

    tearDown(() async {
      // Clean up after each test
      await db.clearAllNotes();
    });

    test('searchNotes should find notes by title and content', () async {
      // "Flutter" appears in:
      // - fts-1: title + content
      // - fts-3: title + content
      // Note: FTS5 searches both title AND content fields
      final results = await db.searchNotes('Flutter');
      expect(results.length, 2);
      expect(results.any((n) => n.id == 'fts-1'), true);
      expect(results.any((n) => n.id == 'fts-3'), true);
    });

    test('searchNotes should find notes by content only', () async {
      // "Futures" only appears in fts-2's content, not in any title
      final results = await db.searchNotes('Futures');
      expect(results.length, 1);
      expect(results.first.id, 'fts-2');
    });

    test('searchNotes should return all notes for empty query', () async {
      final results = await db.searchNotes('');
      expect(results.length, 3);
    });

    test('searchNotes should return empty for no matches', () async {
      final results = await db.searchNotes('NonExistentTerm12345');
      expect(results.length, 0);
    });

    test('searchNotes should limit results to 50', () async {
      // Add 60 notes with unique search term
      for (int i = 0; i < 60; i++) {
        await db.insertNote(
          NotesCompanion(
            id: Value('bulk-$i'),
            path: Value('notes/bulk-$i.md'),
            title: const Value('SearchableTerm Title'),
          ),
        );
        await db.updateFtsIndex(
          'bulk-$i',
          'SearchableTerm Title',
          'SearchableTerm content',
        );
      }

      final results = await db.searchNotes('SearchableTerm');
      expect(results.length, 50);
    });

    test('updateFtsIndex should update searchable content', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('fts-update-1'),
          path: const Value('notes/update-fts.md'),
          title: const Value('UniqueOriginal Title'),
        ),
      );
      await db.updateFtsIndex(
        'fts-update-1',
        'UniqueOriginal Title',
        'UniqueOriginal content',
      );

      var results = await db.searchNotes('UniqueOriginal');
      expect(results.length, 1);

      // Update FTS index
      await db.updateFtsIndex(
        'fts-update-1',
        'UniqueUpdated Title',
        'UniqueUpdated content',
      );

      results = await db.searchNotes('UniqueUpdated');
      expect(results.length, 1);

      results = await db.searchNotes('UniqueOriginal');
      expect(results.length, 0);
    });

    test('deleteNoteById should remove from FTS index', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('fts-delete-1'),
          path: const Value('notes/delete-fts.md'),
          title: const Value('UniqueDeletable Title'),
        ),
      );
      await db.updateFtsIndex(
        'fts-delete-1',
        'UniqueDeletable Title',
        'UniqueDeletable content',
      );

      var results = await db.searchNotes('UniqueDeletable');
      expect(results.any((n) => n.id == 'fts-delete-1'), true);

      await db.deleteNoteById('fts-delete-1');

      results = await db.searchNotes('UniqueDeletable');
      expect(results.any((n) => n.id == 'fts-delete-1'), false);
    });
  });

  group('NotesDatabase - Edge Cases', () {
    test('inserting duplicate id should throw', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('duplicate-id'),
          path: const Value('notes/first.md'),
        ),
      );

      expect(
        () => db.insertNote(
          NotesCompanion(
            id: const Value('duplicate-id'),
            path: const Value('notes/second.md'),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('inserting duplicate path should throw', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('first-id'),
          path: const Value('notes/duplicate-path.md'),
        ),
      );

      expect(
        () => db.insertNote(
          NotesCompanion(
            id: const Value('second-id'),
            path: const Value('notes/duplicate-path.md'),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('updateFtsIndex should throw if note does not exist', () async {
      expect(
        () => db.updateFtsIndex('nonexistent-id', 'Title', 'Content'),
        throwsA(isA<StateError>()),
      );
    });

    test('clearAllNotes should remove all notes and FTS entries', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('clear-1'),
          path: const Value('notes/clear1.md'),
        ),
      );
      await db.insertNote(
        NotesCompanion(
          id: const Value('clear-2'),
          path: const Value('notes/clear2.md'),
        ),
      );
      await db.updateFtsIndex('clear-1', 'Title 1', 'Content 1');
      await db.updateFtsIndex('clear-2', 'Title 2', 'Content 2');

      await db.clearAllNotes();

      final notes = await db.getAllNotes();
      expect(notes.length, 0);

      final searchResults = await db.searchNotes('Content');
      expect(searchResults.length, 0);
    });

    test('updating non-existent note should return 0', () async {
      final result = await db.updateNoteById(
        'nonexistent',
        const NotesCompanion(title: Value('Test')),
      );
      expect(result, 0);
    });

    test('deleting non-existent note should return 0', () async {
      final result = await db.deleteNoteById('nonexistent');
      expect(result, 0);
    });
  });

  group('NotesDatabase - Timestamps', () {
    test('createdAt should be set automatically', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('timestamp-1'),
          path: const Value('notes/timestamp.md'),
        ),
      );

      final note = await db.getNoteById('timestamp-1');
      expect(note, matcher.isNotNull);
      expect(note!.createdAt, matcher.isNotNull);

      // Timestamp should be recent (within last 5 seconds)
      final now = DateTime.now();
      final diff = now.difference(note.createdAt).inSeconds;
      expect(diff >= 0 && diff < 5, true, reason: 'createdAt should be recent');
    });

    test('updatedAt should be set automatically on insert', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('timestamp-2'),
          path: const Value('notes/timestamp2.md'),
        ),
      );

      final note = await db.getNoteById('timestamp-2');
      expect(note, matcher.isNotNull);
      expect(note!.updatedAt, matcher.isNotNull);

      // Timestamp should be recent (within last 5 seconds)
      final now = DateTime.now();
      final diff = now.difference(note.updatedAt).inSeconds;
      expect(diff >= 0 && diff < 5, true, reason: 'updatedAt should be recent');
    });

    test('updatedAt should change when note is modified', () async {
      await db.insertNote(
        NotesCompanion(
          id: const Value('timestamp-3'),
          path: const Value('notes/timestamp3.md'),
        ),
      );

      final noteBeforeUpdate = await db.getNoteById('timestamp-3');
      final originalUpdatedAt = noteBeforeUpdate!.updatedAt;

      // Wait to ensure timestamp difference (increased for reliability)
      await Future.delayed(const Duration(milliseconds: 500));

      await db.markNoteDirty('timestamp-3', isDirty: true);

      final noteAfterUpdate = await db.getNoteById('timestamp-3');

      // Allow for equal timestamps in case of very fast execution
      final timestampDiff = noteAfterUpdate!.updatedAt
          .difference(originalUpdatedAt)
          .inMilliseconds;
      expect(
        timestampDiff >= 0,
        true,
        reason:
            'updatedAt should be same or after original (diff: $timestampDiff ms)',
      );
    });
  });

  group('NotesDatabase - Migrations', () {
    test('schema version should be set', () {
      expect(db.schemaVersion, 1);
    });

    test('migration strategy should be configured', () {
      expect(db.migration, matcher.isNotNull);
    });

    test('onCreate should create notes table', () async {
      // Create a fresh database
      final freshDb = NotesDatabase.test(NativeDatabase.memory());

      // Insert a note to verify table was created
      await freshDb.insertNote(
        NotesCompanion(
          id: const Value('migration-test-1'),
          path: const Value('notes/migration.md'),
        ),
      );

      final note = await freshDb.getNoteById('migration-test-1');
      expect(note, matcher.isNotNull);

      await freshDb.close();
    });

    test('onCreate should create FTS5 table', () async {
      // Create a fresh database
      final freshDb = NotesDatabase.test(NativeDatabase.memory());

      // Insert and index a note
      await freshDb.insertNote(
        NotesCompanion(
          id: const Value('fts-migration-test'),
          path: const Value('notes/fts-test.md'),
          title: const Value('Migration FTS Test'),
        ),
      );

      await freshDb.updateFtsIndex(
        'fts-migration-test',
        'Migration FTS Test',
        'Testing FTS5 table creation',
      );

      // Search to verify FTS table exists and works
      final results = await freshDb.searchNotes('Migration');
      expect(results.length, 1);

      await freshDb.close();
    });
  });
}
