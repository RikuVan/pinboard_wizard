import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinboard_wizard/src/database/notes_database.dart';
import 'package:pinboard_wizard/src/github/github_client.dart';
import 'package:pinboard_wizard/src/github/models/github_file.dart';
import 'package:pinboard_wizard/src/notes/models/sync_result.dart';
import 'package:pinboard_wizard/src/notes/services/file_service.dart';
import 'package:pinboard_wizard/src/notes/services/network_service.dart';
import 'package:pinboard_wizard/src/notes/services/note_filename_service.dart';
import 'package:pinboard_wizard/src/notes/services/note_sync_engine.dart';

// Mock classes
class MockGitHubClient extends Mock implements GitHubClient {}

class MockNetworkService extends Mock implements NetworkService {}

class MockFileService extends Mock implements FileService {}

void main() {
  late NotesDatabase database;
  late MockGitHubClient mockGitHubClient;
  late MockNetworkService mockNetworkService;
  late MockFileService mockFileService;
  late NoteFilenameService filenameService;
  late NoteSyncEngine syncEngine;

  setUp(() {
    // Create in-memory database for testing
    database = NotesDatabase.test(NativeDatabase.memory());

    // Create mocks
    mockGitHubClient = MockGitHubClient();
    mockNetworkService = MockNetworkService();
    mockFileService = MockFileService();
    filenameService = NoteFilenameService();

    // Create sync engine
    syncEngine = NoteSyncEngine(
      database: database,
      githubClient: mockGitHubClient,
      fileService: mockFileService,
      networkService: mockNetworkService,
      filenameService: filenameService,
    );

    // Register fallback values for mocktail
    registerFallbackValue(NotesCompanion.insert(id: '', path: ''));
  });

  tearDown(() async {
    await database.close();
  });

  group('NoteSyncEngine - sync()', () {
    test('returns offline result when network is unavailable', () async {
      // Arrange
      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => false);

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.isOnline, false);
      expect(result.succeeded, isEmpty);
      expect(result.failed, isEmpty);
      expect(result.conflicts, isEmpty);
      verifyNever(() => mockGitHubClient.listNotesFiles());
    });

    test('performs pull and push when online', () async {
      // Arrange
      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => true);
      when(() => mockGitHubClient.listNotesFiles()).thenAnswer((_) async => []);

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.isOnline, true);
      verify(() => mockGitHubClient.listNotesFiles()).called(1);
    });

    test('aggregates results from pull and push', () async {
      // Arrange
      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => true);

      // Setup pull to return a new file
      final remoteFile = GitHubFile(
        path: 'notes/test.md',
        sha: 'abc123',
        size: 100,
        type: 'file',
      );
      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenAnswer((_) async => [remoteFile]);
      when(
        () => mockGitHubClient.downloadFile('notes/test.md'),
      ).thenAnswer((_) async => '# Test Note\n\nContent');
      when(
        () => mockFileService.getLocalPath('notes/test.md'),
      ).thenReturn('/local/test.md');
      when(
        () => mockFileService.writeFile('/local/test.md', any()),
      ).thenAnswer((_) async {});

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.isOnline, true);
      expect(result.succeeded.length, 1);
      expect(result.succeeded.first.path, 'notes/test.md');
    });

    test('handles sync errors gracefully', () async {
      // Arrange
      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => true);
      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenThrow(Exception('Network error'));

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.isOnline, true);
      expect(result.failed.length, 1);
      expect(result.failed.first.error, contains('Network error'));
    });
  });

  group('NoteSyncEngine - pull()', () {
    test('downloads and inserts new remote files', () async {
      // Arrange
      final remoteFile = GitHubFile(
        path: 'notes/new-note.md',
        sha: 'sha123',
        size: 100,
        type: 'file',
      );

      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenAnswer((_) async => [remoteFile]);
      when(
        () => mockGitHubClient.downloadFile('notes/new-note.md'),
      ).thenAnswer((_) async => '# New Note\n\nThis is a new note.');
      when(
        () => mockFileService.getLocalPath('notes/new-note.md'),
      ).thenReturn('/local/new-note.md');
      when(
        () => mockFileService.writeFile('/local/new-note.md', any()),
      ).thenAnswer((_) async {});

      // Act
      final result = await syncEngine.pull();

      // Assert
      expect(result.succeeded.length, 1);
      expect(result.succeeded.first.path, 'notes/new-note.md');
      expect(result.succeeded.first.title, 'New Note');
      expect(result.succeeded.first.lastKnownSha, 'sha123');
      expect(result.succeeded.first.isDirty, false);

      // Verify file was written
      verify(
        () => mockFileService.writeFile(
          '/local/new-note.md',
          '# New Note\n\nThis is a new note.',
        ),
      ).called(1);
    });

    test('skips files with matching SHA', () async {
      // Arrange - insert existing note
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/existing.md',
          title: Value('Existing Note'),
          lastKnownSha: Value('same-sha'),
          isDirty: Value(false),
        ),
      );

      final remoteFile = GitHubFile(
        path: 'notes/existing.md',
        sha: 'same-sha',
        size: 100,
        type: 'file',
      );

      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenAnswer((_) async => [remoteFile]);

      // Act
      final result = await syncEngine.pull();

      // Assert
      expect(result.succeeded.length, 1);
      expect(result.succeeded.first.path, 'notes/existing.md');

      // Verify file was NOT downloaded
      verifyNever(() => mockGitHubClient.downloadFile(any()));
      verifyNever(() => mockFileService.writeFile(any(), any()));
    });

    test('updates local file when remote changed and not dirty', () async {
      // Arrange - insert existing note
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/updated.md',
          title: Value('Old Title'),
          lastKnownSha: Value('old-sha'),
          isDirty: Value(false),
        ),
      );

      final remoteFile = GitHubFile(
        path: 'notes/updated.md',
        sha: 'new-sha',
        size: 150,
        type: 'file',
      );

      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenAnswer((_) async => [remoteFile]);
      when(
        () => mockGitHubClient.downloadFile('notes/updated.md'),
      ).thenAnswer((_) async => '# Updated Title\n\nUpdated content.');
      when(
        () => mockFileService.getLocalPath('notes/updated.md'),
      ).thenReturn('/local/updated.md');
      when(
        () => mockFileService.writeFile('/local/updated.md', any()),
      ).thenAnswer((_) async {});

      // Act
      final result = await syncEngine.pull();

      // Assert
      expect(result.succeeded.length, 1);
      expect(result.succeeded.first.path, 'notes/updated.md');
      expect(result.succeeded.first.title, 'Updated Title');
      expect(result.succeeded.first.lastKnownSha, 'new-sha');
      expect(result.succeeded.first.isDirty, false);

      // Verify file was updated
      verify(
        () => mockFileService.writeFile(
          '/local/updated.md',
          '# Updated Title\n\nUpdated content.',
        ),
      ).called(1);
    });

    test('detects conflict when both remote and local changed', () async {
      // Arrange - insert dirty note
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/conflict.md',
          title: Value('Conflict Note'),
          lastKnownSha: Value('old-sha'),
          isDirty: Value(true),
        ),
      );

      final remoteFile = GitHubFile(
        path: 'notes/conflict.md',
        sha: 'new-sha',
        size: 200,
        type: 'file',
      );

      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenAnswer((_) async => [remoteFile]);
      when(
        () => mockGitHubClient.downloadFile('notes/conflict.md'),
      ).thenAnswer((_) async => '# Conflict Note Remote\n\nRemote version.');
      when(
        () => mockFileService.getLocalPath(any()),
      ).thenReturn('/local/conflict.md');
      when(
        () => mockFileService.writeFile(any(), any()),
      ).thenAnswer((_) async {});

      // Act
      final result = await syncEngine.pull();

      // Assert
      expect(result.conflicts.length, 1);
      expect(result.conflicts.first.path, 'notes/conflict.md');
      expect(result.conflicts.first.isConflict, true);

      // Verify conflict file was created
      verify(
        () => mockFileService.writeFile(
          any(),
          '# Conflict Note Remote\n\nRemote version.',
        ),
      ).called(1);
    });

    test('deletes local notes that were deleted remotely', () async {
      // Arrange - insert note that doesn't exist on remote
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/deleted.md',
          title: Value('Deleted Note'),
          lastKnownSha: Value('sha'),
          isDirty: Value(false),
        ),
      );

      when(() => mockGitHubClient.listNotesFiles()).thenAnswer((_) async => []);
      when(
        () => mockFileService.getLocalPath('notes/deleted.md'),
      ).thenReturn('/local/deleted.md');
      when(
        () => mockFileService.deleteFile('/local/deleted.md'),
      ).thenAnswer((_) async {});

      // Act
      final result = await syncEngine.pull();

      // Assert
      expect(result.succeeded, isEmpty);

      // Verify note was deleted
      final notes = await database.getAllNotes();
      expect(notes, isEmpty);
      verify(() => mockFileService.deleteFile('/local/deleted.md')).called(1);
    });

    test('marks conflict when local dirty note was deleted remotely', () async {
      // Arrange - insert dirty note that doesn't exist on remote
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/dirty-deleted.md',
          title: Value('Dirty Deleted Note'),
          lastKnownSha: Value('sha'),
          isDirty: Value(true),
        ),
      );

      when(() => mockGitHubClient.listNotesFiles()).thenAnswer((_) async => []);

      // Act
      final result = await syncEngine.pull();

      // Assert
      expect(result.succeeded, isEmpty);

      // Verify note is marked as conflict, not deleted
      final notes = await database.getAllNotes();
      expect(notes.length, 1);
      expect(notes.first.isConflict, true);
    });

    test('handles download failures gracefully', () async {
      // Arrange
      final remoteFile = GitHubFile(
        path: 'notes/fail.md',
        sha: 'sha123',
        size: 100,
        type: 'file',
      );

      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenAnswer((_) async => [remoteFile]);
      when(
        () => mockGitHubClient.downloadFile('notes/fail.md'),
      ).thenThrow(Exception('Download failed'));

      // Act
      final result = await syncEngine.pull();

      // Assert
      expect(result.failed.length, 1);
      expect(result.failed.first.error, contains('Download failed'));
      expect(result.failed.first.note.path, 'notes/fail.md');
    });
  });

  group('NoteSyncEngine - push()', () {
    test('creates new file on GitHub for note without SHA', () async {
      // Arrange - insert dirty note without SHA
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/new.md',
          title: Value('New Note'),
          isDirty: Value(true),
        ),
      );

      when(
        () => mockFileService.getLocalPath('notes/new.md'),
      ).thenReturn('/local/new.md');
      when(
        () => mockFileService.readFile('/local/new.md'),
      ).thenAnswer((_) async => '# New Note\n\nContent');
      when(
        () => mockGitHubClient.createFile(
          path: 'notes/new.md',
          content: '# New Note\n\nContent',
          message: 'Create New Note',
        ),
      ).thenAnswer((_) async => 'created-sha');

      // Act
      final result = await syncEngine.push();

      // Assert
      expect(result.succeeded.length, 1);
      expect(result.succeeded.first.path, 'notes/new.md');
      expect(result.succeeded.first.lastKnownSha, 'created-sha');
      expect(result.succeeded.first.isDirty, false);

      // Verify create was called
      verify(
        () => mockGitHubClient.createFile(
          path: 'notes/new.md',
          content: '# New Note\n\nContent',
          message: 'Create New Note',
        ),
      ).called(1);
    });

    test('updates existing file on GitHub for note with SHA', () async {
      // Arrange - insert dirty note with SHA
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/existing.md',
          title: Value('Existing Note'),
          lastKnownSha: Value('old-sha'),
          isDirty: Value(true),
        ),
      );

      when(
        () => mockFileService.getLocalPath('notes/existing.md'),
      ).thenReturn('/local/existing.md');
      when(
        () => mockFileService.readFile('/local/existing.md'),
      ).thenAnswer((_) async => '# Existing Note\n\nUpdated content');
      when(
        () => mockGitHubClient.updateFile(
          path: 'notes/existing.md',
          content: '# Existing Note\n\nUpdated content',
          currentSha: 'old-sha',
          message: 'Update Existing Note',
        ),
      ).thenAnswer((_) async => 'new-sha');

      // Act
      final result = await syncEngine.push();

      // Assert
      expect(result.succeeded.length, 1);
      expect(result.succeeded.first.path, 'notes/existing.md');
      expect(result.succeeded.first.lastKnownSha, 'new-sha');
      expect(result.succeeded.first.isDirty, false);

      // Verify update was called
      verify(
        () => mockGitHubClient.updateFile(
          path: 'notes/existing.md',
          content: '# Existing Note\n\nUpdated content',
          currentSha: 'old-sha',
          message: 'Update Existing Note',
        ),
      ).called(1);
    });

    test('detects conflict on SHA mismatch during update', () async {
      // Arrange - insert dirty note with SHA
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/conflict.md',
          title: Value('Conflict Note'),
          lastKnownSha: Value('old-sha'),
          isDirty: Value(true),
        ),
      );

      when(
        () => mockFileService.getLocalPath('notes/conflict.md'),
      ).thenReturn('/local/conflict.md');
      when(
        () => mockFileService.readFile('/local/conflict.md'),
      ).thenAnswer((_) async => '# Conflict Note\n\nContent');
      when(
        () => mockGitHubClient.updateFile(
          path: 'notes/conflict.md',
          content: '# Conflict Note\n\nContent',
          currentSha: 'old-sha',
          message: 'Update Conflict Note',
        ),
      ).thenThrow(Exception('SHA does not match'));

      // Act
      final result = await syncEngine.push();

      // Assert
      expect(result.conflicts.length, 1);
      expect(result.conflicts.first.path, 'notes/conflict.md');
      expect(result.conflicts.first.isConflict, true);
    });

    test('deletes file from GitHub when marked for deletion', () async {
      // Arrange - insert note marked for deletion
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/delete.md',
          title: Value('Delete Note'),
          lastKnownSha: Value('sha'),
          markedForDeletion: Value(true),
        ),
      );

      when(
        () => mockGitHubClient.deleteFile(
          path: 'notes/delete.md',
          currentSha: 'sha',
          message: 'Delete Delete Note',
        ),
      ).thenAnswer((_) async => 'delete-sha');
      when(
        () => mockFileService.getLocalPath('notes/delete.md'),
      ).thenReturn('/local/delete.md');
      when(
        () => mockFileService.deleteFile('/local/delete.md'),
      ).thenAnswer((_) async {});

      // Act
      final result = await syncEngine.push();

      // Assert
      expect(result.succeeded.length, 1);

      // Verify note was deleted from database
      final notes = await database.getAllNotes();
      expect(notes, isEmpty);

      // Verify delete was called
      verify(
        () => mockGitHubClient.deleteFile(
          path: 'notes/delete.md',
          currentSha: 'sha',
          message: 'Delete Delete Note',
        ),
      ).called(1);
      verify(() => mockFileService.deleteFile('/local/delete.md')).called(1);
    });

    test(
      'removes local-only note marked for deletion without GitHub call',
      () async {
        // Arrange - insert note without SHA marked for deletion
        await database.insertNote(
          NotesCompanion.insert(
            id: 'note1',
            path: 'notes/local-only.md',
            title: Value('Local Only'),
            markedForDeletion: Value(true),
          ),
        );

        // Act
        final result = await syncEngine.push();

        // Assert
        expect(result.succeeded.length, 1);

        // Verify note was deleted from database
        final notes = await database.getAllNotes();
        expect(notes, isEmpty);

        // Verify GitHub delete was NOT called
        verifyNever(
          () => mockGitHubClient.deleteFile(
            path: any(named: 'path'),
            currentSha: any(named: 'currentSha'),
            message: any(named: 'message'),
          ),
        );
      },
    );

    test('handles push errors gracefully', () async {
      // Arrange - insert dirty note
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/error.md',
          title: Value('Error Note'),
          isDirty: Value(true),
        ),
      );

      when(
        () => mockFileService.getLocalPath('notes/error.md'),
      ).thenReturn('/local/error.md');
      when(
        () => mockFileService.readFile('/local/error.md'),
      ).thenThrow(FileNotFoundException('File not found'));

      // Act
      final result = await syncEngine.push();

      // Assert - orphaned notes are deleted from database, not added to failed list
      expect(result.failed.length, 0);

      // Verify the orphaned note was deleted from the database
      final deletedNote = await database.getNoteById('note1');
      expect(deletedNote, isNull);
    });

    test(
      'skips notes that are not dirty and not marked for deletion',
      () async {
        // Arrange - insert clean note
        await database.insertNote(
          NotesCompanion.insert(
            id: 'note1',
            path: 'notes/clean.md',
            title: Value('Clean Note'),
            lastKnownSha: Value('sha'),
            isDirty: Value(false),
          ),
        );

        // Act
        final result = await syncEngine.push();

        // Assert
        expect(result.succeeded, isEmpty);
        expect(result.failed, isEmpty);
        expect(result.conflicts, isEmpty);

        // Verify no GitHub calls
        verifyNever(
          () => mockGitHubClient.createFile(
            path: any(named: 'path'),
            content: any(named: 'content'),
            message: any(named: 'message'),
          ),
        );
        verifyNever(
          () => mockGitHubClient.updateFile(
            path: any(named: 'path'),
            content: any(named: 'content'),
            currentSha: any(named: 'currentSha'),
            message: any(named: 'message'),
          ),
        );
      },
    );
  });

  group('NoteSyncEngine - error classification', () {
    test('classifies network errors correctly', () async {
      // Arrange
      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => true);
      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenThrow(SocketException('Connection refused'));

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.failed.length, 1);
      expect(result.failed.first.type, SyncFailureType.network);
    });

    test('classifies auth errors correctly', () async {
      // Arrange
      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => true);
      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenThrow(Exception('401 Unauthorized'));

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.failed.length, 1);
      expect(result.failed.first.type, SyncFailureType.auth);
    });

    test('classifies rate limit errors correctly', () async {
      // Arrange
      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => true);
      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenThrow(Exception('429 Rate limit exceeded'));

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.failed.length, 1);
      expect(result.failed.first.type, SyncFailureType.rateLimit);
    });

    test('classifies conflict errors correctly', () async {
      // Arrange
      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => true);
      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenThrow(Exception('409 Conflict'));

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.failed.length, 1);
      expect(result.failed.first.type, SyncFailureType.conflict);
    });

    test('classifies validation errors correctly', () async {
      // Arrange
      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => true);
      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenThrow(Exception('422 Validation failed'));

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.failed.length, 1);
      expect(result.failed.first.type, SyncFailureType.validation);
    });

    test('classifies unknown errors correctly', () async {
      // Arrange
      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => true);
      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenThrow(Exception('Something went wrong'));

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.failed.length, 1);
      expect(result.failed.first.type, SyncFailureType.unknown);
    });
  });

  group('NoteSyncEngine - integration scenarios', () {
    test('handles multiple files with mixed outcomes', () async {
      // Arrange - multiple local notes
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note1',
          path: 'notes/dirty.md',
          title: Value('Dirty Note'),
          lastKnownSha: Value('sha1'),
          isDirty: Value(true),
        ),
      );
      await database.insertNote(
        NotesCompanion.insert(
          id: 'note2',
          path: 'notes/clean.md',
          title: Value('Clean Note'),
          lastKnownSha: Value('sha2'),
          isDirty: Value(false),
        ),
      );

      // Remote has a new file and updated version of dirty note
      final remoteFiles = [
        GitHubFile(
          path: 'notes/new.md',
          sha: 'new-sha',
          size: 100,
          type: 'file',
        ),
        GitHubFile(
          path: 'notes/clean.md',
          sha: 'sha2',
          size: 100,
          type: 'file',
        ),
      ];

      when(
        () => mockNetworkService.isOnlineWithTimeout(),
      ).thenAnswer((_) async => true);
      when(
        () => mockGitHubClient.listNotesFiles(),
      ).thenAnswer((_) async => remoteFiles);
      when(
        () => mockGitHubClient.downloadFile('notes/new.md'),
      ).thenAnswer((_) async => '# New\n\nContent');
      when(
        () => mockFileService.getLocalPath(any()),
      ).thenReturn('/local/file.md');
      when(
        () => mockFileService.writeFile(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockFileService.readFile('/local/file.md'),
      ).thenAnswer((_) async => '# Content');
      when(
        () => mockGitHubClient.updateFile(
          path: 'notes/dirty.md',
          content: any(named: 'content'),
          currentSha: 'sha1',
          message: any(named: 'message'),
        ),
      ).thenAnswer((_) async => 'new-sha1');

      // Act
      final result = await syncEngine.sync();

      // Assert
      expect(result.isOnline, true);
      expect(
        result.succeeded.length,
        greaterThanOrEqualTo(2),
      ); // New file + pushed dirty file
    });
  });
}
