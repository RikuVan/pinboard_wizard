import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pinboard_wizard/src/pages/notes/state/notes_cubit.dart';
import 'package:pinboard_wizard/src/pages/notes/state/notes_state.dart';
import 'package:pinboard_wizard/src/pinboard/models/note.dart';
import 'package:pinboard_wizard/src/pinboard/models/notes_response.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_client.dart';

class MockPinboardService extends Mock implements PinboardService {
  @override
  Future<List<Note>> getAllNotes() => super.noSuchMethod(
    Invocation.method(#getAllNotes, []),
    returnValue: Future.value(<Note>[]),
  );

  @override
  Future<NoteDetailResponse> getNote(String noteId) => super.noSuchMethod(
    Invocation.method(#getNote, [noteId]),
    returnValue: Future.value(_createNoteDetailResponse()),
  );

  @override
  Future<List<Note>> searchNotes(String query) => super.noSuchMethod(
    Invocation.method(#searchNotes, [query]),
    returnValue: Future.value(<Note>[]),
  );
}

// Test data creation helpers
Note _createNote({
  String? id,
  String? hash,
  String? title,
  int? length,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Note(
    id: id ?? 'note_1',
    hash: hash ?? 'abcdef123456',
    title: title ?? 'Test Note',
    length: length ?? 100,
    createdAt: createdAt ?? DateTime(2023, 1, 1),
    updatedAt: updatedAt ?? DateTime(2023, 1, 2),
  );
}

List<Note> _createNoteList({int count = 3}) {
  return List.generate(count, (index) {
    return Note(
      id: 'note_${index + 1}',
      hash: 'hash${index}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Test Note ${index + 1}',
      length: 50 + (index * 25),
      createdAt: DateTime(2023, 1, index + 1),
      updatedAt: DateTime(2023, 1, index + 2),
    );
  });
}

NoteDetailResponse _createNoteDetailResponse({
  String? id,
  String? title,
  String? hash,
  int? length,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? text,
}) {
  return NoteDetailResponse(
    id: id ?? 'note_1',
    title: title ?? 'Test Note',
    hash: hash ?? 'abcdef123456',
    length: length ?? 100,
    createdAt: createdAt ?? DateTime(2023, 1, 1),
    updatedAt: updatedAt ?? DateTime(2023, 1, 2),
    text: text ?? 'This is the content of the test note.',
  );
}

List<Note> _createSearchTestNotes() {
  return [
    _createNote(
      id: 'search_1',
      title: 'Flutter Development Notes',
      length: 200,
    ),
    _createNote(id: 'search_2', title: 'React Components Guide', length: 150),
    _createNote(id: 'search_3', title: 'Database Design Patterns', length: 300),
    _createNote(id: 'search_4', title: 'Flutter Widget Testing', length: 180),
  ];
}

void main() {
  group('NotesCubit', () {
    late MockPinboardService mockPinboardService;
    late NotesCubit cubit;

    final testNote = _createNote();
    final testNoteDetail = _createNoteDetailResponse();
    final testNotesList = _createNoteList(count: 3);

    setUp(() {
      mockPinboardService = MockPinboardService();
      cubit = NotesCubit(pinboardService: mockPinboardService);
    });

    tearDown(() {
      cubit.close();
    });

    group('initial state', () {
      test('should have correct initial state', () {
        expect(cubit.state, equals(const NotesState()));
        expect(cubit.state.status, equals(NotesStatus.initial));
        expect(cubit.state.notes, isEmpty);
        expect(cubit.state.filteredNotes, isEmpty);
        expect(cubit.state.selectedNote, isNull);
        expect(cubit.state.selectedNoteDetail, isNull);
        expect(cubit.state.errorMessage, isNull);
        expect(cubit.state.isSearching, isFalse);
        expect(cubit.state.searchQuery, isEmpty);
      });

      test('convenience getters work correctly', () {
        expect(cubit.state.isLoading, isFalse);
        expect(cubit.state.hasError, isFalse);
        expect(cubit.state.isEmpty, isTrue);
        expect(cubit.state.displayNotes, isEmpty);
      });
    });

    group('loadNotes', () {
      blocTest<NotesCubit, NotesState>(
        'emits loading then loaded when successful',
        build: () {
          when(
            mockPinboardService.getAllNotes(),
          ).thenAnswer((_) async => testNotesList);
          return cubit;
        },
        act: (cubit) => cubit.loadNotes(),
        expect: () => [
          isA<NotesState>().having(
            (s) => s.status,
            'status',
            NotesStatus.loading,
          ),
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.loaded)
              .having((s) => s.notes, 'notes', hasLength(3))
              .having((s) => s.errorMessage, 'errorMessage', isNull),
        ],
        verify: (_) {
          verify(mockPinboardService.getAllNotes()).called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'emits loading then error when PinboardException is thrown',
        build: () {
          when(
            mockPinboardService.getAllNotes(),
          ).thenThrow(PinboardException('API error'));
          return cubit;
        },
        act: (cubit) => cubit.loadNotes(),
        expect: () => [
          isA<NotesState>().having(
            (s) => s.status,
            'status',
            NotesStatus.loading,
          ),
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', 'API error'),
        ],
        verify: (_) {
          verify(mockPinboardService.getAllNotes()).called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'emits loading then error when generic exception is thrown',
        build: () {
          when(
            mockPinboardService.getAllNotes(),
          ).thenThrow(Exception('Network error'));
          return cubit;
        },
        act: (cubit) => cubit.loadNotes(),
        expect: () => [
          isA<NotesState>().having(
            (s) => s.status,
            'status',
            NotesStatus.loading,
          ),
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.error)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Failed to load notes'),
              ),
        ],
        verify: (_) {
          verify(mockPinboardService.getAllNotes()).called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'maintains existing error state when loading fails',
        build: () {
          when(
            mockPinboardService.getAllNotes(),
          ).thenThrow(Exception('Network error'));
          return cubit;
        },
        seed: () => const NotesState(
          status: NotesStatus.error,
          errorMessage: 'Previous error',
        ),
        act: (cubit) => cubit.loadNotes(),
        expect: () => [
          isA<NotesState>().having(
            (s) => s.status,
            'status',
            NotesStatus.loading,
          ),
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.error)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Failed to load notes'),
              ),
        ],
      );
    });

    group('selectNote', () {
      blocTest<NotesCubit, NotesState>(
        'selects note and loads detail when successful',
        build: () {
          when(
            mockPinboardService.getNote(testNote.id),
          ).thenAnswer((_) async => testNoteDetail);
          return cubit;
        },
        act: (cubit) => cubit.selectNote(testNote),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.selectedNote, 'selectedNote', testNote)
              .having(
                (s) => s.selectedNoteDetail,
                'selectedNoteDetail',
                isNull,
              ),
          isA<NotesState>()
              .having((s) => s.selectedNote, 'selectedNote', testNote)
              .having(
                (s) => s.selectedNoteDetail,
                'selectedNoteDetail',
                testNoteDetail,
              ),
        ],
        verify: (_) {
          verify(mockPinboardService.getNote(testNote.id)).called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'selects note but fails to load detail when PinboardException is thrown',
        build: () {
          when(
            mockPinboardService.getNote(testNote.id),
          ).thenThrow(PinboardException('Note not found'));
          return cubit;
        },
        act: (cubit) => cubit.selectNote(testNote),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.selectedNote, 'selectedNote', testNote)
              .having(
                (s) => s.selectedNoteDetail,
                'selectedNoteDetail',
                isNull,
              ),
          isA<NotesState>()
              .having((s) => s.selectedNote, 'selectedNote', testNote)
              .having((s) => s.selectedNoteDetail, 'selectedNoteDetail', isNull)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                'Failed to load note details: Note not found',
              ),
        ],
        verify: (_) {
          verify(mockPinboardService.getNote(testNote.id)).called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'selects note but fails to load detail when generic exception is thrown',
        build: () {
          when(
            mockPinboardService.getNote(testNote.id),
          ).thenThrow(Exception('Network error'));
          return cubit;
        },
        act: (cubit) => cubit.selectNote(testNote),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.selectedNote, 'selectedNote', testNote)
              .having(
                (s) => s.selectedNoteDetail,
                'selectedNoteDetail',
                isNull,
              ),
          isA<NotesState>()
              .having((s) => s.selectedNote, 'selectedNote', testNote)
              .having((s) => s.selectedNoteDetail, 'selectedNoteDetail', isNull)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Failed to load note details'),
              ),
        ],
        verify: (_) {
          verify(mockPinboardService.getNote(testNote.id)).called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'replaces previous selection when selecting new note',
        build: () {
          when(
            mockPinboardService.getNote(testNote.id),
          ).thenAnswer((_) async => testNoteDetail);
          return cubit;
        },
        seed: () => NotesState(
          selectedNote: _createNote(id: 'old_note'),
          selectedNoteDetail: _createNoteDetailResponse(id: 'old_note'),
        ),
        act: (cubit) => cubit.selectNote(testNote),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.selectedNote, 'selectedNote', testNote)
              .having(
                (s) => s.selectedNoteDetail,
                'selectedNoteDetail',
                _createNoteDetailResponse(id: 'old_note'),
              ),
          isA<NotesState>()
              .having((s) => s.selectedNote, 'selectedNote', testNote)
              .having(
                (s) => s.selectedNoteDetail,
                'selectedNoteDetail',
                testNoteDetail,
              ),
        ],
      );
    });

    group('clearSelection', () {
      blocTest<NotesCubit, NotesState>(
        'clears selected note and detail',
        build: () => cubit,
        seed: () => NotesState(
          selectedNote: testNote,
          selectedNoteDetail: testNoteDetail,
        ),
        act: (cubit) => cubit.clearSelection(),
        expect: () => [],
      );

      blocTest<NotesCubit, NotesState>(
        'emits state even when no selection exists',
        build: () => cubit,
        act: (cubit) => cubit.clearSelection(),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.selectedNote, 'selectedNote', isNull)
              .having(
                (s) => s.selectedNoteDetail,
                'selectedNoteDetail',
                isNull,
              ),
        ],
      );
    });

    group('performSearch', () {
      final searchTestNotes = _createSearchTestNotes();
      final filteredNotes = searchTestNotes
          .where((note) => note.title.toLowerCase().contains('flutter'))
          .toList();

      blocTest<NotesCubit, NotesState>(
        'performs search and updates filtered notes when successful',
        build: () {
          when(
            mockPinboardService.searchNotes('flutter'),
          ).thenAnswer((_) async => filteredNotes);
          return cubit;
        },
        act: (cubit) => cubit.performSearch('flutter'),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.searching)
              .having((s) => s.searchQuery, 'searchQuery', 'flutter')
              .having((s) => s.isSearching, 'isSearching', true),
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.loaded)
              .having((s) => s.filteredNotes, 'filteredNotes', hasLength(2))
              .having((s) => s.isSearching, 'isSearching', true),
        ],
        verify: (_) {
          verify(mockPinboardService.searchNotes('flutter')).called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'clears search when empty query is provided',
        build: () => cubit,
        seed: () => NotesState(
          isSearching: true,
          searchQuery: 'flutter',
          filteredNotes: <Note>[
            Note(
              id: 'test',
              hash: 'hash',
              title: 'Test',
              length: 100,
              createdAt: DateTime(2023, 1, 1),
              updatedAt: DateTime(2023, 1, 1),
            ),
          ],
        ),
        act: (cubit) => cubit.performSearch(''),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.isSearching, 'isSearching', false)
              .having((s) => s.searchQuery, 'searchQuery', '')
              .having((s) => s.filteredNotes, 'filteredNotes', isEmpty)
              .having((s) => s.status, 'status', NotesStatus.loaded),
        ],
      );

      blocTest<NotesCubit, NotesState>(
        'emits error when PinboardException is thrown during search',
        build: () {
          when(
            mockPinboardService.searchNotes('error'),
          ).thenThrow(PinboardException('Search failed'));
          return cubit;
        },
        act: (cubit) => cubit.performSearch('error'),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.searching)
              .having((s) => s.searchQuery, 'searchQuery', 'error')
              .having((s) => s.isSearching, 'isSearching', true),
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', 'Search failed'),
        ],
        verify: (_) {
          verify(mockPinboardService.searchNotes('error')).called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'emits error when generic exception is thrown during search',
        build: () {
          when(
            mockPinboardService.searchNotes('error'),
          ).thenThrow(Exception('Network error'));
          return cubit;
        },
        act: (cubit) => cubit.performSearch('error'),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.searching)
              .having((s) => s.searchQuery, 'searchQuery', 'error')
              .having((s) => s.isSearching, 'isSearching', true),
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.error)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Search failed'),
              ),
        ],
        verify: (_) {
          verify(mockPinboardService.searchNotes('error')).called(1);
        },
      );

      blocTest<NotesCubit, NotesState>(
        'treats whitespace-only query as search term',
        build: () {
          when(
            mockPinboardService.searchNotes('   '),
          ).thenAnswer((_) async => <Note>[]);
          return cubit;
        },
        seed: () => NotesState(
          isSearching: true,
          searchQuery: 'flutter',
          filteredNotes: <Note>[
            Note(
              id: 'test',
              hash: 'hash',
              title: 'Test',
              length: 100,
              createdAt: DateTime(2023, 1, 1),
              updatedAt: DateTime(2023, 1, 1),
            ),
          ],
        ),
        act: (cubit) => cubit.performSearch('   '),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.searching)
              .having((s) => s.searchQuery, 'searchQuery', '   ')
              .having((s) => s.isSearching, 'isSearching', true),
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.loaded)
              .having((s) => s.filteredNotes, 'filteredNotes', isEmpty)
              .having((s) => s.isSearching, 'isSearching', true),
        ],
        verify: (_) {
          verify(mockPinboardService.searchNotes('   ')).called(1);
        },
      );
    });

    group('clearSearch', () {
      blocTest<NotesCubit, NotesState>(
        'clears search state and returns to loaded status',
        build: () => cubit,
        seed: () => NotesState(
          status: NotesStatus.searching,
          isSearching: true,
          searchQuery: 'flutter',
          filteredNotes: <Note>[],
        ),
        act: (cubit) => cubit.clearSearch(),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.isSearching, 'isSearching', false)
              .having((s) => s.searchQuery, 'searchQuery', '')
              .having((s) => s.filteredNotes, 'filteredNotes', isEmpty)
              .having((s) => s.status, 'status', NotesStatus.loaded),
        ],
      );

      blocTest<NotesCubit, NotesState>(
        'does not emit when not searching',
        build: () => cubit,
        seed: () => const NotesState(
          status: NotesStatus.loaded,
          isSearching: false,
          searchQuery: '',
          filteredNotes: [],
        ),
        act: (cubit) => cubit.clearSearch(),
        expect: () => [],
      );
    });

    group('refresh', () {
      blocTest<NotesCubit, NotesState>(
        'calls loadNotes when refresh is called',
        build: () {
          when(
            mockPinboardService.getAllNotes(),
          ).thenAnswer((_) async => testNotesList);
          return cubit;
        },
        act: (cubit) => cubit.refresh(),
        expect: () => [
          isA<NotesState>().having(
            (s) => s.status,
            'status',
            NotesStatus.loading,
          ),
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.loaded)
              .having((s) => s.notes, 'notes', hasLength(3)),
        ],
        verify: (_) {
          verify(mockPinboardService.getAllNotes()).called(1);
        },
      );
    });

    group('getFooterText', () {
      test('returns single note text when only one note exists', () {
        cubit.emit(NotesState(notes: [testNote]));
        expect(cubit.footerText, equals('1 note'));
      });

      test('returns multiple notes count when multiple notes exist', () {
        cubit.emit(NotesState(notes: testNotesList));
        expect(cubit.footerText, equals('3 notes'));
      });

      test('returns zero notes when no notes exist', () {
        cubit.emit(const NotesState(notes: []));
        expect(cubit.footerText, equals('0 notes'));
      });

      test('returns filtered count when searching with results', () {
        cubit.emit(
          NotesState(
            notes: testNotesList,
            filteredNotes: [testNote],
            isSearching: true,
          ),
        );
        expect(cubit.footerText, equals('1 of 3 notes'));
      });

      test('returns no results text when searching with no results', () {
        cubit.emit(
          NotesState(
            notes: testNotesList,
            filteredNotes: [],
            isSearching: true,
          ),
        );
        expect(cubit.footerText, equals('0 of 3 notes'));
      });

      test('returns correct text when searching with multiple results', () {
        cubit.emit(
          NotesState(
            notes: testNotesList,
            filteredNotes: [
              testNote,
              _createNote(id: 'note2'),
            ],
            isSearching: true,
          ),
        );
        expect(cubit.footerText, equals('2 of 3 notes'));
      });
    });

    group('displayNotes getter', () {
      test('returns all notes when not searching', () {
        cubit.emit(NotesState(notes: testNotesList));
        expect(cubit.state.displayNotes, equals(testNotesList));
      });

      test('returns filtered notes when searching', () {
        final filteredNotes = [testNote];
        cubit.emit(
          NotesState(
            notes: testNotesList,
            filteredNotes: <Note>[testNote],
            isSearching: true,
          ),
        );
        expect(cubit.state.displayNotes, equals(filteredNotes));
      });

      test('returns empty list when searching with no results', () {
        cubit.emit(
          NotesState(
            notes: testNotesList,
            filteredNotes: [],
            isSearching: true,
          ),
        );
        expect(cubit.state.displayNotes, isEmpty);
      });
    });

    group('convenience getters', () {
      test('isLoading returns true when status is loading', () {
        cubit.emit(const NotesState(status: NotesStatus.loading));
        expect(cubit.state.isLoading, isTrue);
      });

      test('isLoading returns false when status is not loading', () {
        cubit.emit(const NotesState(status: NotesStatus.loaded));
        expect(cubit.state.isLoading, isFalse);
      });

      test('hasError returns true when status is error', () {
        cubit.emit(const NotesState(status: NotesStatus.error));
        expect(cubit.state.hasError, isTrue);
      });

      test('hasError returns false when status is not error', () {
        cubit.emit(const NotesState(status: NotesStatus.loaded));
        expect(cubit.state.hasError, isFalse);
      });

      test('isEmpty returns true when notes are empty and not loading', () {
        cubit.emit(const NotesState(status: NotesStatus.loaded, notes: []));
        expect(cubit.state.isEmpty, isTrue);
      });

      test('isEmpty returns false when notes are not empty', () {
        cubit.emit(
          NotesState(status: NotesStatus.loaded, notes: testNotesList),
        );
        expect(cubit.state.isEmpty, isFalse);
      });

      test('isEmpty returns false when loading', () {
        cubit.emit(const NotesState(status: NotesStatus.loading, notes: []));
        expect(cubit.state.isEmpty, isFalse);
      });
    });

    group('state transitions', () {
      blocTest<NotesCubit, NotesState>(
        'maintains search state during note selection',
        build: () {
          when(
            mockPinboardService.getNote(testNote.id),
          ).thenAnswer((_) async => testNoteDetail);
          return cubit;
        },
        seed: () => NotesState(
          isSearching: true,
          searchQuery: 'flutter',
          filteredNotes: [testNote],
        ),
        act: (cubit) => cubit.selectNote(testNote),
        expect: () => [
          isA<NotesState>()
              .having((s) => s.selectedNote, 'selectedNote', testNote)
              .having((s) => s.isSearching, 'isSearching', true)
              .having((s) => s.searchQuery, 'searchQuery', 'flutter'),
          isA<NotesState>()
              .having(
                (s) => s.selectedNoteDetail,
                'selectedNoteDetail',
                testNoteDetail,
              )
              .having((s) => s.isSearching, 'isSearching', true)
              .having((s) => s.searchQuery, 'searchQuery', 'flutter'),
        ],
      );

      blocTest<NotesCubit, NotesState>(
        'clears error message on successful load after error',
        build: () {
          when(
            mockPinboardService.getAllNotes(),
          ).thenAnswer((_) async => testNotesList);
          return cubit;
        },
        seed: () => const NotesState(
          status: NotesStatus.error,
          errorMessage: 'Previous error',
        ),
        act: (cubit) => cubit.loadNotes(),
        expect: () => [
          isA<NotesState>().having(
            (s) => s.status,
            'status',
            NotesStatus.loading,
          ),
          isA<NotesState>()
              .having((s) => s.status, 'status', NotesStatus.loaded)
              .having((s) => s.notes, 'notes', hasLength(3)),
        ],
      );
    });
  });
}
