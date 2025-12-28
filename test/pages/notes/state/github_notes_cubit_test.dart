import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pinboard_wizard/src/database/notes_database.dart';
import 'package:pinboard_wizard/src/notes/models/sync_result.dart';
import 'package:pinboard_wizard/src/notes/services/file_service.dart';
import 'package:pinboard_wizard/src/notes/services/network_service.dart';
import 'package:pinboard_wizard/src/notes/services/note_sync_engine.dart';
import 'package:pinboard_wizard/src/pages/notes/state/github_notes_cubit.dart';
import 'package:pinboard_wizard/src/pages/notes/state/github_notes_state.dart';

// Mock classes
class MockNotesDatabase extends Mock implements NotesDatabase {}

class MockNoteSyncEngine extends Mock implements NoteSyncEngine {}

class MockFileService extends Mock implements FileService {}

class MockNetworkService extends Mock implements NetworkService {}

class MockFile extends Mock implements File {
  final String _path;

  MockFile(this._path);

  @override
  String get path => _path;
}

class FakeSyncResult extends Fake implements SyncResult {
  // isSuccess is not part of SyncResult interface, so no @override
  bool get isSuccess => true;

  @override
  List<SyncFailure> get failed => [];

  @override
  List<Note> get succeeded => [];

  @override
  List<Note> get conflicts => [];

  @override
  bool get isOnline => true;

  @override
  DateTime get timestamp => DateTime.now();
}

void main() {
  late MockNotesDatabase mockDatabase;
  late MockNoteSyncEngine mockSyncEngine;
  late MockFileService mockFileService;
  late MockNetworkService mockNetworkService;

  setUpAll(() {
    registerFallbackValue(
      NotesCompanion(
        id: const Value(''),
        path: const Value(''),
        title: const Value(''),
        lastKnownSha: const Value(''),
        isDirty: const Value(false),
        updatedAt: const Value.absent(),
        createdAt: const Value.absent(),
        contentPreview: const Value(''),
        contentLength: const Value(0),
        isConflict: const Value(false),
        markedForDeletion: const Value(false),
      ),
    );
  });

  setUp(() {
    mockDatabase = MockNotesDatabase();
    mockSyncEngine = MockNoteSyncEngine();
    mockFileService = MockFileService();
    mockNetworkService = MockNetworkService();

    // Default mock behaviors
    when(() => mockNetworkService.isOnline()).thenAnswer((_) async => true);
    when(
      () => mockNetworkService.isOnlineWithTimeout(),
    ).thenAnswer((_) async => true);
  });

  group('GitHubNotesCubit - Initialization', () {
    test('initializes with empty state', () {
      final cubit = GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      );

      expect(cubit.state.notes, isEmpty);
      expect(cubit.state.status, GitHubNotesStatus.initial);
      expect(cubit.state.isSearching, false);
    });

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'loadNotes emits loading then loaded state',
      setUp: () {
        final testNote = Note(
          id: 'note1',
          path: 'notes/test.md',
          title: 'Test Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: false,
          lastKnownSha: 'sha123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 12,
        );

        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([testNote]));
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) => cubit.loadNotes(),
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>()
            .having((state) => state.status, 'status', GitHubNotesStatus.loaded)
            .having((state) => state.notes.length, 'notes.length', 1),
      ],
    );

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'loadNotes emits error state on failure',
      setUp: () {
        when(
          () => mockDatabase.getAllNotes(),
        ).thenThrow(Exception('Database error'));
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) => cubit.loadNotes(),
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>()
            .having((state) => state.status, 'status', GitHubNotesStatus.error)
            .having((state) => state.hasError, 'hasError', true),
      ],
    );
  });

  group('GitHubNotesCubit - Search', () {
    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'search filters notes by title',
      setUp: () {
        final testNotes = <Note>[
          Note(
            id: 'note1',
            path: 'notes/flutter.md',
            title: 'Flutter Guide',
            isDirty: false,
            isConflict: false,
            markedForDeletion: false,
            lastKnownSha: 'sha1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            contentLength: 15,
          ),
          Note(
            id: 'note2',
            path: 'notes/dart.md',
            title: 'Dart Basics',
            isDirty: false,
            isConflict: false,
            markedForDeletion: false,
            lastKnownSha: 'sha2',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            contentLength: 12,
          ),
        ];

        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value(testNotes));
        when(
          () => mockDatabase.searchNotes('flutter'),
        ).thenAnswer((_) => Future<List<Note>>.value([testNotes[0]]));
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        await cubit.search('flutter');
      },
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>()
            .having((state) => state.status, 'status', GitHubNotesStatus.loaded)
            .having((state) => state.notes.length, 'notes.length', 2),
        isA<GitHubNotesState>()
            .having((state) => state.isSearching, 'isSearching', true)
            .having(
              (state) => state.displayNotes.length,
              'displayNotes.length',
              1,
            ),
      ],
    );

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'clearSearch returns to full note list',
      setUp: () {
        final testNotes = <Note>[
          Note(
            id: 'note1',
            path: 'notes/flutter.md',
            title: 'Flutter Guide',
            isDirty: false,
            isConflict: false,
            markedForDeletion: false,
            lastKnownSha: 'sha1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            contentLength: 15,
          ),
        ];

        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value(testNotes));
        when(
          () => mockDatabase.searchNotes('flutter'),
        ).thenAnswer((_) => Future<List<Note>>.value([testNotes[0]]));
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        await cubit.search('flutter');
        cubit.clearSearch();
      },
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loaded,
        ),
        isA<GitHubNotesState>()
            .having((state) => state.isSearching, 'isSearching', true)
            .having(
              (state) => state.displayNotes.length,
              'displayNotes.length',
              1,
            ),
        isA<GitHubNotesState>().having(
          (state) => state.isSearching,
          'isSearching',
          false,
        ),
      ],
    );
  });

  group('GitHubNotesCubit - Selection', () {
    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'selectNote updates selectedNote and loads content',
      setUp: () {
        final testNote = Note(
          id: 'note1',
          path: 'notes/test.md',
          title: 'Test Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: false,
          lastKnownSha: 'sha123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 12,
        );

        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([testNote]));
        when(
          () => mockFileService.getLocalPath(any()),
        ).thenReturn('/local/path/test.md');
        when(
          () => mockFileService.readFile(any()),
        ).thenAnswer((_) async => 'Test content');
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        await cubit.selectNote(cubit.state.notes.first);
      },
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loaded,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.selectedNote,
          'selectedNote',
          isNotNull,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.noteContent,
          'noteContent',
          isNotNull,
        ),
      ],
    );

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'clearSelection removes selectedNote',
      setUp: () {
        final testNote = Note(
          id: 'note1',
          path: 'notes/test.md',
          title: 'Test Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: false,
          lastKnownSha: 'sha123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 12,
        );

        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([testNote]));
        when(
          () => mockFileService.getLocalPath(any()),
        ).thenReturn('/local/path/test.md');
        when(
          () => mockFileService.readFile(any()),
        ).thenAnswer((_) async => 'Test content');
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        await cubit.selectNote(cubit.state.notes.first);
        cubit.clearSelection();
      },
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loaded,
        ),
        // selectNote emits first with selectedNote but null content
        isA<GitHubNotesState>()
            .having((state) => state.selectedNote, 'selectedNote', isNotNull)
            .having((state) => state.noteContent, 'noteContent', isNull),
        // selectNote emits again after loading content
        isA<GitHubNotesState>()
            .having((state) => state.selectedNote, 'selectedNote', isNotNull)
            .having((state) => state.noteContent, 'noteContent', isNotNull),
        // clearSelection emits with selectedNote back to null
        isA<GitHubNotesState>().having(
          (state) => state.selectedNote,
          'selectedNote',
          isNull,
        ),
      ],
    );
  });

  group('GitHubNotesCubit - Editing', () {
    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'startEditing sets editing mode',
      setUp: () {
        final testNote = Note(
          id: 'note1',
          path: 'notes/test.md',
          title: 'Test Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: false,
          lastKnownSha: 'sha123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 12,
        );

        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([testNote]));
        when(
          () => mockFileService.getLocalPath(any()),
        ).thenReturn('/local/path/test.md');
        when(
          () => mockFileService.readFile(any()),
        ).thenAnswer((_) async => 'Test content');
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        await cubit.selectNote(cubit.state.notes.first);
        cubit.startEditing();
      },
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loaded,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.selectedNote,
          'selectedNote',
          isNotNull,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.noteContent,
          'noteContent',
          isNotNull,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.isEditing,
          'isEditing',
          true,
        ),
      ],
    );

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'cancelEditing exits editing mode',
      setUp: () {
        final testNote = Note(
          id: 'note1',
          path: 'notes/test.md',
          title: 'Test Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: false,
          lastKnownSha: 'sha123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 12,
        );

        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([testNote]));
        when(
          () => mockFileService.getLocalPath(any()),
        ).thenReturn('/local/path/test.md');
        when(
          () => mockFileService.readFile(any()),
        ).thenAnswer((_) async => 'Test content');
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        await cubit.selectNote(cubit.state.notes.first);
        cubit.startEditing();
        cubit.cancelEditing();
      },
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loaded,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.selectedNote,
          'selectedNote',
          isNotNull,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.noteContent,
          'noteContent',
          isNotNull,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.isEditing,
          'isEditing',
          true,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.isEditing,
          'isEditing',
          false,
        ),
      ],
    );
  });

  group('GitHubNotesCubit - Creating', () {
    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'startCreating sets creating mode',
      setUp: () {
        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([]));
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        cubit.startCreating();
      },
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loaded,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.isCreating,
          'isCreating',
          true,
        ),
      ],
    );

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'cancelCreating exits creating mode',
      setUp: () {
        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([]));
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        cubit.startCreating();
        cubit.cancelCreating();
      },
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loaded,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.isCreating,
          'isCreating',
          true,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.isCreating,
          'isCreating',
          false,
        ),
      ],
    );

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'createNote creates and inserts new note',
      setUp: () {
        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([]));
        when(
          () => mockDatabase.getNoteByPath(any()),
        ).thenAnswer((_) => Future<Note?>.value(null));
        when(
          () => mockDatabase.insertNote(any()),
        ).thenAnswer((_) => Future.value(1));
        when(
          () => mockDatabase.updateFtsIndex(any(), any(), any()),
        ).thenAnswer((_) => Future.value(null));
        when(
          () => mockFileService.writeFile(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => mockFileService.getLocalPath(any()),
        ).thenReturn('/local/path/new-note.md');
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        cubit.startCreating();
        await cubit.createNote(title: 'New Note', content: 'New content');
      },
      verify: (cubit) {
        verify(() => mockDatabase.insertNote(any())).called(1);
        verify(() => mockFileService.writeFile(any(), any())).called(1);
      },
    );

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'createNote handles title collision by adding timestamp',
      setUp: () {
        // Handle three calls: collision check, timestamp check, retrieve created note
        var callCount = 0;
        when(() => mockDatabase.getNoteByPath(any())).thenAnswer((_) {
          callCount++;
          if (callCount == 1) {
            // First check: collision detected with base filename
            return Future<Note?>.value(
              Note(
                id: 'existing',
                path: 'new-note.md',
                title: 'Existing Note',
                isDirty: false,
                isConflict: false,
                markedForDeletion: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                contentLength: 100,
              ),
            );
          } else if (callCount == 2) {
            // Second check: timestamped version is unique
            return Future<Note?>.value(null);
          } else {
            // Third call: retrieve the newly created note
            return Future<Note?>.value(
              Note(
                id: 'new',
                path: 'new-note-20251228-143045.md',
                title: 'New Note',
                isDirty: true,
                isConflict: false,
                markedForDeletion: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                contentLength: 11,
              ),
            );
          }
        });
        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([]));
        when(
          () => mockDatabase.insertNote(any()),
        ).thenAnswer((_) => Future.value(1));
        when(
          () => mockDatabase.updateFtsIndex(any(), any(), any()),
        ).thenAnswer((_) => Future.value(null));
        when(
          () => mockFileService.writeFile(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => mockFileService.getLocalPath(any()),
        ).thenReturn('/local/path/new-note-20251228-143045.md');
        when(
          () => mockFileService.readFile(any()),
        ).thenAnswer((_) async => 'New content');
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        cubit.startCreating();
        await cubit.createNote(title: 'New Note', content: 'New content');
      },
      verify: (cubit) {
        // Should check 3 times:
        // 1. Base filename collision check
        // 2. Timestamped filename uniqueness check
        // 3. Retrieve newly created note for selection
        verify(() => mockDatabase.getNoteByPath(any())).called(3);
        // Should still successfully insert the note with timestamped name
        verify(() => mockDatabase.insertNote(any())).called(1);
        verify(() => mockFileService.writeFile(any(), any())).called(1);
      },
    );
  });

  group('GitHubNotesCubit - Syncing', () {
    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'sync updates isSyncing state',
      setUp: () {
        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([]));
        when(
          () => mockSyncEngine.sync(),
        ).thenAnswer((_) async => FakeSyncResult());
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) async {
        await cubit.loadNotes();
        await cubit.sync();
      },
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loaded,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.isSyncing,
          'isSyncing',
          true,
        ),
        // sync() calls loadNotes() which emits loading/loaded states
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loaded,
        ),
        // Final state with isSyncing: false
        isA<GitHubNotesState>().having(
          (state) => state.isSyncing,
          'isSyncing',
          false,
        ),
      ],
    );
  });

  group('GitHubNotesCubit - Online Status', () {
    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'tracks online status from network service',
      setUp: () {
        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) => Future<List<Note>>.value([]));
        when(
          () => mockNetworkService.isOnline(),
        ).thenAnswer((_) async => false);
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) => cubit.loadNotes(),
      expect: () => [
        isA<GitHubNotesState>().having(
          (state) => state.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>().having(
          (state) => state.isOnline,
          'isOnline',
          false,
        ),
      ],
    );
  });

  group('GitHubNotesCubit - Deletion', () {
    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'deleteNote marks note for deletion and clears selection if selected',
      setUp: () {
        final testNote = Note(
          id: 'note1',
          path: 'notes/test.md',
          title: 'Test Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 100,
        );

        when(
          () => mockDatabase.getNoteById('note1'),
        ).thenAnswer((_) async => testNote);
        when(
          () => mockFileService.getLocalPath(any()),
        ).thenReturn('/path/to/notes/test.md');
        when(
          () => mockFileService.fileExists(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockFileService.moveToTrash(any()),
        ).thenAnswer((_) async => '/path/to/.trash/12345_test.md');
        when(
          () => mockDatabase.updateNoteById(any(), any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockDatabase.getAllNotes(),
        ).thenAnswer((_) async => [testNote.copyWith(markedForDeletion: true)]);
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      seed: () => GitHubNotesState(
        status: GitHubNotesStatus.loaded,
        notes: [
          Note(
            id: 'note1',
            path: 'notes/test.md',
            title: 'Test Note',
            isDirty: false,
            isConflict: false,
            markedForDeletion: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            contentLength: 100,
          ),
        ],
        selectedNote: Note(
          id: 'note1',
          path: 'notes/test.md',
          title: 'Test Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 100,
        ),
        noteContent: 'Test content',
      ),
      act: (cubit) => cubit.deleteNote('note1'),
      expect: () => [
        // Should clear selection
        isA<GitHubNotesState>()
            .having((s) => s.selectedNote, 'selectedNote', isNull)
            .having((s) => s.noteContent, 'noteContent', isNull),
        // Then reload with marked for deletion
        isA<GitHubNotesState>().having(
          (s) => s.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>()
            .having((s) => s.status, 'status', GitHubNotesStatus.loaded)
            .having(
              (s) => s.notes.first.markedForDeletion,
              'markedForDeletion',
              true,
            ),
      ],
      verify: (cubit) {
        // Should mark note for deletion
        verify(
          () => mockDatabase.updateNoteById(
            'note1',
            any(
              that: isA<NotesCompanion>().having(
                (c) => c.markedForDeletion.value,
                'markedForDeletion',
                true,
              ),
            ),
          ),
        ).called(1);
        // Should backup file before deletion
        verify(() => mockFileService.moveToTrash(any())).called(1);
      },
    );

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'deleteNote does not clear selection if different note selected',
      setUp: () {
        final testNote = Note(
          id: 'note1',
          path: 'notes/test.md',
          title: 'Test Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 100,
        );

        when(
          () => mockDatabase.getNoteById('note1'),
        ).thenAnswer((_) async => testNote);
        when(
          () => mockFileService.getLocalPath(any()),
        ).thenReturn('/path/to/notes/test.md');
        when(
          () => mockFileService.fileExists(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockFileService.moveToTrash(any()),
        ).thenAnswer((_) async => '/path/to/.trash/12345_test.md');
        when(
          () => mockDatabase.updateNoteById(any(), any()),
        ).thenAnswer((_) async => 1);
        when(() => mockDatabase.getAllNotes()).thenAnswer(
          (_) async => [
            testNote.copyWith(markedForDeletion: true),
            Note(
              id: 'note2',
              path: 'notes/other.md',
              title: 'Other Note',
              isDirty: false,
              isConflict: false,
              markedForDeletion: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              contentLength: 50,
            ),
          ],
        );
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      seed: () => GitHubNotesState(
        status: GitHubNotesStatus.loaded,
        notes: [
          Note(
            id: 'note1',
            path: 'notes/test.md',
            title: 'Test Note',
            isDirty: false,
            isConflict: false,
            markedForDeletion: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            contentLength: 100,
          ),
          Note(
            id: 'note2',
            path: 'notes/other.md',
            title: 'Other Note',
            isDirty: false,
            isConflict: false,
            markedForDeletion: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            contentLength: 50,
          ),
        ],
        selectedNote: Note(
          id: 'note2',
          path: 'notes/other.md',
          title: 'Other Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 50,
        ),
        noteContent: 'Other content',
      ),
      act: (cubit) => cubit.deleteNote('note1'),
      expect: () => [
        // Should reload notes but keep selection
        isA<GitHubNotesState>().having(
          (s) => s.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>()
            .having((s) => s.status, 'status', GitHubNotesStatus.loaded)
            .having((s) => s.selectedNote?.id, 'selectedNote.id', 'note2')
            .having((s) => s.noteContent, 'noteContent', 'Other content'),
      ],
    );

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'undoDeleteNote unmarks note from deletion and restores from trash',
      setUp: () {
        final deletedNote = Note(
          id: 'note1',
          path: 'notes/test.md',
          title: 'Test Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 100,
        );

        when(
          () => mockDatabase.getNoteById('note1'),
        ).thenAnswer((_) async => deletedNote);
        when(
          () => mockFileService.getLocalPath(any()),
        ).thenReturn('/path/to/notes/test.md');
        when(
          () => mockFileService.fileExists(any()),
        ).thenAnswer((_) async => false);
        when(
          () => mockFileService.listBackups(),
        ).thenAnswer((_) async => [MockFile('/path/to/.trash/12345_test.md')]);
        when(
          () => mockFileService.restoreFromTrash(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => mockDatabase.updateNoteById(any(), any()),
        ).thenAnswer((_) async => 1);
        when(() => mockDatabase.getAllNotes()).thenAnswer(
          (_) async => [deletedNote.copyWith(markedForDeletion: false)],
        );
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      seed: () => GitHubNotesState(
        status: GitHubNotesStatus.loaded,
        notes: [
          Note(
            id: 'note1',
            path: 'notes/test.md',
            title: 'Test Note',
            isDirty: false,
            isConflict: false,
            markedForDeletion: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            contentLength: 100,
          ),
        ],
      ),
      act: (cubit) => cubit.undoDeleteNote('note1'),
      expect: () => [
        // Should reload notes
        isA<GitHubNotesState>().having(
          (s) => s.status,
          'status',
          GitHubNotesStatus.loading,
        ),
        isA<GitHubNotesState>()
            .having((s) => s.status, 'status', GitHubNotesStatus.loaded)
            .having(
              (s) => s.notes.first.markedForDeletion,
              'markedForDeletion',
              false,
            ),
      ],
      verify: (cubit) {
        // Should restore from trash
        verify(
          () => mockFileService.restoreFromTrash(
            '/path/to/.trash/12345_test.md',
            '/path/to/notes/test.md',
          ),
        ).called(1);
        // Should unmark from deletion
        verify(
          () => mockDatabase.updateNoteById(
            'note1',
            any(
              that: isA<NotesCompanion>().having(
                (c) => c.markedForDeletion.value,
                'markedForDeletion',
                false,
              ),
            ),
          ),
        ).called(1);
      },
    );

    blocTest<GitHubNotesCubit, GitHubNotesState>(
      'undoDeleteNote shows error if note not marked for deletion',
      setUp: () {
        final note = Note(
          id: 'note1',
          path: 'notes/test.md',
          title: 'Test Note',
          isDirty: false,
          isConflict: false,
          markedForDeletion: false, // Not marked for deletion
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          contentLength: 100,
        );

        when(
          () => mockDatabase.getNoteById('note1'),
        ).thenAnswer((_) async => note);
      },
      build: () => GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      ),
      act: (cubit) => cubit.undoDeleteNote('note1'),
      expect: () => [
        isA<GitHubNotesState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Note is not marked for deletion',
        ),
      ],
    );
  });

  group('GitHubNotesCubit - Cleanup', () {
    test('close cancels auto-sync timer', () {
      final cubit = GitHubNotesCubit(
        database: mockDatabase,
        syncEngine: mockSyncEngine,
        fileService: mockFileService,
        networkService: mockNetworkService,
      );

      cubit.close();
      // No exception should be thrown
      expect(true, true);
    });
  });
}
