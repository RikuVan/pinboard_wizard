import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/state/bookmarks_cubit.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/state/bookmarks_state.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';

class MockPinboardService extends Mock implements PinboardService {
  @override
  Future<List<Post>> getAllBookmarks({
    String? tag,
    int? start,
    int? results,
    DateTime? fromdt,
    DateTime? todt,
    int? meta,
  }) => super.noSuchMethod(
    Invocation.method(#getAllBookmarks, [], {
      #tag: tag,
      #start: start,
      #results: results,
      #fromdt: fromdt,
      #todt: todt,
      #meta: meta,
    }),
    returnValue: Future.value(<Post>[]),
  );

  @override
  Future<void> addBookmark({
    required String url,
    required String title,
    String? description,
    List<String>? tags,
    bool shared = true,
    bool toRead = false,
    bool replace = false,
  }) => super.noSuchMethod(
    Invocation.method(#addBookmark, [], {
      #url: url,
      #title: title,
      #description: description,
      #tags: tags,
      #shared: shared,
      #toRead: toRead,
      #replace: replace,
    }),
    returnValue: Future<void>.value(),
  );

  @override
  Future<void> updateBookmark(Post bookmark) => super.noSuchMethod(
    Invocation.method(#updateBookmark, [bookmark]),
    returnValue: Future<void>.value(),
  );

  @override
  Future<void> deleteBookmark(String url) => super.noSuchMethod(
    Invocation.method(#deleteBookmark, [url]),
    returnValue: Future<void>.value(),
  );
}

void main() {
  group('BookmarksCubit', () {
    late MockPinboardService mockPinboardService;
    late BookmarksCubit cubit;

    final testPost = Post(
      href: 'https://example.com',
      description: 'Test Bookmark',
      extended: 'Test description',
      meta: 'meta',
      hash: 'hash123',
      time: DateTime(2023, 1, 1),
      shared: true,
      toread: false,
      tags: 'flutter dart',
    );

    setUp(() {
      mockPinboardService = MockPinboardService();
      cubit = BookmarksCubit(pinboardService: mockPinboardService);
    });

    tearDown(() {
      cubit.close();
    });

    group('initial state', () {
      test('should have correct initial state', () {
        expect(cubit.state, equals(const BookmarksState()));
        expect(cubit.state.status, equals(BookmarksStatus.initial));
        expect(cubit.state.bookmarks, isEmpty);
        expect(cubit.state.errorMessage, isNull);
        expect(cubit.state.isSearching, isFalse);
        expect(cubit.state.searchAll, isFalse);
        expect(cubit.state.hasMoreData, isTrue);
        expect(cubit.state.currentOffset, equals(0));
        expect(cubit.state.showUnreadOnly, isFalse);
      });

      test('convenience getters work correctly', () {
        expect(cubit.state.isLoading, isFalse);
        expect(cubit.state.isLoadingMore, isFalse);
        expect(cubit.state.hasError, isFalse);
        expect(cubit.state.isEmpty, isTrue);
        expect(cubit.state.displayBookmarks, isEmpty);
      });
    });

    group('loadBookmarks', () {
      blocTest<BookmarksCubit, BookmarksState>(
        'emits loading then loaded when successful',
        build: () {
          when(
            mockPinboardService.getAllBookmarks(start: 0, results: 50),
          ).thenAnswer((_) async => [testPost]);
          return cubit;
        },
        act: (cubit) => cubit.loadBookmarks(),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.status,
            'status',
            BookmarksStatus.loading,
          ),
          isA<BookmarksState>()
              .having((s) => s.status, 'status', BookmarksStatus.loaded)
              .having((s) => s.bookmarks, 'bookmarks', hasLength(1)),
          isA<BookmarksState>()
              .having((s) => s.status, 'status', BookmarksStatus.loaded)
              .having((s) => s.availableTags, 'availableTags', isNotEmpty),
        ],
        verify: (_) {
          verify(
            mockPinboardService.getAllBookmarks(start: 0, results: 50),
          ).called(1);
        },
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'emits loading then error when service throws exception',
        build: () {
          when(
            mockPinboardService.getAllBookmarks(start: 0, results: 50),
          ).thenThrow(Exception('Network error'));
          return cubit;
        },
        act: (cubit) => cubit.loadBookmarks(),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.status,
            'status',
            BookmarksStatus.loading,
          ),
          isA<BookmarksState>()
              .having((s) => s.status, 'status', BookmarksStatus.error)
              .having(
                (s) => s.errorMessage,
                'errorMessage',
                contains('Network error'),
              ),
        ],
      );
    });

    group('loadMoreBookmarks', () {
      blocTest<BookmarksCubit, BookmarksState>(
        'loads more bookmarks when conditions are met',
        build: () {
          when(
            mockPinboardService.getAllBookmarks(start: 1, results: 50),
          ).thenAnswer(
            (_) async => [testPost.copyWith(href: 'https://example2.com')],
          );
          return cubit;
        },
        seed: () => BookmarksState(
          status: BookmarksStatus.loaded,
          bookmarks: [testPost],
          currentOffset: 1,
          hasMoreData: true,
        ),
        act: (cubit) => cubit.loadMoreBookmarks(),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.status,
            'status',
            BookmarksStatus.loadingMore,
          ),
          isA<BookmarksState>()
              .having((s) => s.status, 'status', BookmarksStatus.loaded)
              .having((s) => s.bookmarks, 'bookmarks', hasLength(2)),
          isA<BookmarksState>()
              .having((s) => s.status, 'status', BookmarksStatus.loaded)
              .having((s) => s.availableTags, 'availableTags', isNotEmpty),
        ],
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'does not load when already loading more',
        build: () => cubit,
        seed: () => const BookmarksState(
          status: BookmarksStatus.loadingMore,
          hasMoreData: true,
        ),
        act: (cubit) => cubit.loadMoreBookmarks(),
        expect: () => [],
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'does not load when no more data',
        build: () => cubit,
        seed: () => const BookmarksState(
          status: BookmarksStatus.loaded,
          hasMoreData: false,
        ),
        act: (cubit) => cubit.loadMoreBookmarks(),
        expect: () => [],
      );
    });

    group('performSearch', () {
      blocTest<BookmarksCubit, BookmarksState>(
        'clears search when query is empty',
        build: () => cubit,
        seed: () => const BookmarksState(
          isSearching: true,
          searchQuery: 'old query',
          filteredBookmarks: [],
        ),
        act: (cubit) => cubit.performSearch(''),
        expect: () => [
          isA<BookmarksState>()
              .having((s) => s.isSearching, 'isSearching', false)
              .having((s) => s.searchQuery, 'searchQuery', '')
              .having((s) => s.status, 'status', BookmarksStatus.loaded),
        ],
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'searches in current bookmarks when searchAll is false',
        build: () => cubit,
        seed: () => BookmarksState(
          bookmarks: [
            testPost.copyWith(description: 'Flutter Tutorial'),
            testPost.copyWith(
              description: 'React Guide',
              href: 'https://react.example.com',
            ),
          ],
          status: BookmarksStatus.loaded,
        ),
        act: (cubit) => cubit.performSearch('flutter'),
        expect: () => [
          isA<BookmarksState>()
              .having((s) => s.isSearching, 'isSearching', true)
              .having((s) => s.searchQuery, 'searchQuery', 'flutter')
              .having((s) => s.status, 'status', BookmarksStatus.searching),
          isA<BookmarksState>()
              .having((s) => s.isSearching, 'isSearching', true)
              .having(
                (s) => s.filteredBookmarks,
                'filteredBookmarks',
                hasLength(2),
              )
              .having((s) => s.status, 'status', BookmarksStatus.loaded),
        ],
      );
    });

    group('clearSearch', () {
      blocTest<BookmarksCubit, BookmarksState>(
        'clears search state',
        build: () => cubit,
        seed: () => const BookmarksState(
          isSearching: true,
          searchQuery: 'test query',
          filteredBookmarks: [],
          status: BookmarksStatus.searching,
        ),
        act: (cubit) => cubit.clearSearch(),
        expect: () => [
          isA<BookmarksState>()
              .having((s) => s.isSearching, 'isSearching', false)
              .having((s) => s.searchQuery, 'searchQuery', '')
              .having((s) => s.status, 'status', BookmarksStatus.loaded),
        ],
      );
    });

    group('tag management', () {
      blocTest<BookmarksCubit, BookmarksState>(
        'toggleTag adds tag when not selected',
        build: () => cubit,
        act: (cubit) => cubit.toggleTag('flutter'),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.selectedTags,
            'selectedTags',
            contains('flutter'),
          ),
        ],
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'toggleTag removes tag when selected',
        build: () => cubit,
        seed: () => const BookmarksState(selectedTags: ['flutter', 'dart']),
        act: (cubit) => cubit.toggleTag('flutter'),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.selectedTags,
            'selectedTags',
            equals(['dart']),
          ),
        ],
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'clearSelectedTags removes all tags',
        build: () => cubit,
        seed: () => const BookmarksState(selectedTags: ['flutter', 'dart']),
        act: (cubit) => cubit.clearSelectedTags(),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.selectedTags,
            'selectedTags',
            isEmpty,
          ),
        ],
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'addTag adds new tag',
        build: () => cubit,
        seed: () => const BookmarksState(selectedTags: ['dart']),
        act: (cubit) => cubit.addTag('flutter'),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.selectedTags,
            'selectedTags',
            contains('flutter'),
          ),
        ],
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'addTag ignores duplicate',
        build: () => cubit,
        seed: () => const BookmarksState(selectedTags: ['flutter']),
        act: (cubit) => cubit.addTag('flutter'),
        expect: () => [],
      );
    });

    group('unread filter', () {
      blocTest<BookmarksCubit, BookmarksState>(
        'toggleUnreadFilter sets showUnreadOnly to true',
        build: () => cubit,
        act: (cubit) => cubit.toggleUnreadFilter(true),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.showUnreadOnly,
            'showUnreadOnly',
            isTrue,
          ),
        ],
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'toggleUnreadFilter sets showUnreadOnly to false',
        build: () => cubit,
        seed: () => const BookmarksState(showUnreadOnly: true),
        act: (cubit) => cubit.toggleUnreadFilter(false),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.showUnreadOnly,
            'showUnreadOnly',
            isFalse,
          ),
        ],
      );

      test('displayBookmarks filters unread when showUnreadOnly is true', () {
        final readBookmark = testPost.copyWith(toread: false);
        final unreadBookmark = testPost.copyWith(
          href: 'https://unread.example.com',
          toread: true,
        );

        cubit.emit(
          cubit.state.copyWith(
            bookmarks: [readBookmark, unreadBookmark],
            showUnreadOnly: true,
          ),
        );

        expect(cubit.state.displayBookmarks, hasLength(1));
        expect(cubit.state.displayBookmarks.first.toread, isTrue);
      });

      test('displayBookmarks shows all when showUnreadOnly is false', () {
        final readBookmark = testPost.copyWith(toread: false);
        final unreadBookmark = testPost.copyWith(
          href: 'https://unread.example.com',
          toread: true,
        );

        cubit.emit(
          cubit.state.copyWith(
            bookmarks: [readBookmark, unreadBookmark],
            showUnreadOnly: false,
          ),
        );

        expect(cubit.state.displayBookmarks, hasLength(2));
      });
    });

    group('shouldLoadMore', () {
      test('returns true when conditions are met', () {
        cubit.emit(
          cubit.state.copyWith(
            status: BookmarksStatus.loaded,
            hasMoreData: true,
            searchAll: false,
            isSearching: false,
          ),
        );

        expect(cubit.shouldLoadMore(), isTrue);
      });

      test('returns false when loading more', () {
        cubit.emit(cubit.state.copyWith(status: BookmarksStatus.loadingMore));
        expect(cubit.shouldLoadMore(), isFalse);
      });

      test('returns false when no more data', () {
        cubit.emit(cubit.state.copyWith(hasMoreData: false));
        expect(cubit.shouldLoadMore(), isFalse);
      });
    });

    group('footer text methods', () {
      test('getFooterText returns correct text for search results', () {
        cubit.emit(
          cubit.state.copyWith(
            isSearching: true,
            filteredBookmarks: [testPost, testPost],
            searchAll: false,
          ),
        );

        expect(cubit.footerText, equals('Found 2 results in current page'));
      });

      test('getFooterText returns loaded count when not searching', () {
        cubit.emit(
          cubit.state.copyWith(
            bookmarks: [testPost, testPost],
            isSearching: false,
            searchAll: false,
          ),
        );

        expect(cubit.footerText, equals('2 bookmarks loaded'));
      });

      test('getFooterText includes unread filter info', () {
        final readBookmark = testPost.copyWith(toread: false);
        final unreadBookmark = testPost.copyWith(
          href: 'https://unread.example.com',
          toread: true,
        );

        cubit.emit(
          cubit.state.copyWith(
            bookmarks: [readBookmark, unreadBookmark],
            isSearching: false,
            searchAll: false,
            showUnreadOnly: true,
          ),
        );

        expect(
          cubit.footerText,
          equals('2 bookmarks loaded • 1 after unread only filtering'),
        );
      });

      test('getFooterText includes combined filters info', () {
        final taggedReadBookmark = testPost.copyWith(
          toread: false,
          tags: 'flutter dart',
        );
        final taggedUnreadBookmark = testPost.copyWith(
          href: 'https://unread.example.com',
          toread: true,
          tags: 'flutter dart',
        );

        cubit.emit(
          cubit.state.copyWith(
            bookmarks: [taggedReadBookmark, taggedUnreadBookmark],
            isSearching: false,
            searchAll: false,
            showUnreadOnly: true,
            selectedTags: ['flutter'],
          ),
        );

        expect(
          cubit.footerText,
          equals(
            '2 bookmarks loaded • 1 after unread only & tag filtered filtering',
          ),
        );
      });

      test('getSecondaryFooterText returns total when all loaded', () {
        cubit.emit(
          cubit.state.copyWith(
            allBookmarksLoaded: true,
            allBookmarks: [testPost, testPost, testPost],
            searchAll: false,
          ),
        );

        expect(cubit.getSecondaryFooterText(), equals('Total: 3 bookmarks'));
      });

      test('getSecondaryFooterText returns null when not all loaded', () {
        cubit.emit(cubit.state.copyWith(allBookmarksLoaded: false));
        expect(cubit.getSecondaryFooterText(), isNull);
      });
    });

    group('CRUD operations', () {
      blocTest<BookmarksCubit, BookmarksState>(
        'addBookmark calls service and refreshes on success',
        build: () {
          when(
            mockPinboardService.addBookmark(
              url: 'https://example.com',
              title: 'Test Bookmark',
              description: 'Test description',
              tags: ['flutter', 'dart'],
              shared: true,
              toRead: false,
              replace: false,
            ),
          ).thenAnswer((_) async {});

          when(
            mockPinboardService.getAllBookmarks(start: 0, results: 50),
          ).thenAnswer((_) async => [testPost]);
          return cubit;
        },
        act: (cubit) => cubit.addBookmark(
          url: 'https://example.com',
          title: 'Test Bookmark',
          description: 'Test description',
          tags: ['flutter', 'dart'],
          shared: true,
          toRead: false,
          replace: false,
        ),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.status,
            'status',
            BookmarksStatus.loading,
          ),
          isA<BookmarksState>().having(
            (s) => s.status,
            'status',
            BookmarksStatus.loaded,
          ),
          isA<BookmarksState>()
              .having((s) => s.status, 'status', BookmarksStatus.loaded)
              .having((s) => s.availableTags, 'availableTags', isNotEmpty),
        ],
        verify: (_) {
          verify(
            mockPinboardService.addBookmark(
              url: 'https://example.com',
              title: 'Test Bookmark',
              description: 'Test description',
              tags: ['flutter', 'dart'],
              shared: true,
              toRead: false,
              replace: false,
            ),
          ).called(1);
        },
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'updateBookmark calls service and refreshes',
        build: () {
          when(
            mockPinboardService.updateBookmark(testPost),
          ).thenAnswer((_) async {});
          when(
            mockPinboardService.getAllBookmarks(start: 0, results: 50),
          ).thenAnswer((_) async => [testPost]);
          return cubit;
        },
        act: (cubit) => cubit.updateBookmark(testPost),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.status,
            'status',
            BookmarksStatus.loading,
          ),
          isA<BookmarksState>().having(
            (s) => s.status,
            'status',
            BookmarksStatus.loaded,
          ),
          isA<BookmarksState>()
              .having((s) => s.status, 'status', BookmarksStatus.loaded)
              .having((s) => s.availableTags, 'availableTags', isNotEmpty),
        ],
        verify: (_) {
          verify(mockPinboardService.updateBookmark(testPost)).called(1);
        },
      );

      blocTest<BookmarksCubit, BookmarksState>(
        'deleteBookmark calls service and refreshes',
        build: () {
          when(
            mockPinboardService.deleteBookmark('https://test.com'),
          ).thenAnswer((_) async {});
          when(
            mockPinboardService.getAllBookmarks(start: 0, results: 50),
          ).thenAnswer((_) async => []);
          return cubit;
        },
        act: (cubit) => cubit.deleteBookmark('https://test.com'),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<BookmarksState>().having(
            (s) => s.status,
            'status',
            BookmarksStatus.loading,
          ),
          isA<BookmarksState>().having(
            (s) => s.status,
            'status',
            BookmarksStatus.loaded,
          ),
        ],
        verify: (_) {
          verify(
            mockPinboardService.deleteBookmark('https://test.com'),
          ).called(1);
        },
      );
    });

    group('edge cases', () {
      test('handles large datasets', () {
        final largeList = List.generate(
          1000,
          (i) => testPost.copyWith(href: 'https://example$i.com'),
        );

        expect(
          () => cubit.emit(cubit.state.copyWith(bookmarks: largeList)),
          returnsNormally,
        );
        expect(cubit.state.bookmarks.length, equals(1000));
      });

      test('handles empty results', () {
        cubit.emit(cubit.state.copyWith(bookmarks: []));
        expect(cubit.state.isEmpty, isTrue);
        expect(cubit.state.displayBookmarks, isEmpty);
      });

      test('state consistency during multiple operations', () {
        // Initial state
        expect(cubit.state.status, equals(BookmarksStatus.initial));

        // After loading
        cubit.emit(
          cubit.state.copyWith(
            status: BookmarksStatus.loaded,
            bookmarks: [testPost],
            currentOffset: 1,
          ),
        );

        expect(cubit.state.status, equals(BookmarksStatus.loaded));
        expect(cubit.state.bookmarks.length, equals(1));
        expect(cubit.state.currentOffset, equals(1));

        // After search
        cubit.emit(
          cubit.state.copyWith(
            isSearching: true,
            searchQuery: 'test',
            filteredBookmarks: [testPost],
          ),
        );

        expect(cubit.state.isSearching, isTrue);
        expect(cubit.state.searchQuery, equals('test'));
        expect(cubit.state.filteredBookmarks.length, equals(1));
        expect(cubit.state.bookmarks.length, equals(1)); // Original preserved
      });
    });
  });
}
