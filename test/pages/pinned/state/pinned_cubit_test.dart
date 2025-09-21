import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pinboard_wizard/src/pages/pinned/state/pinned_cubit.dart';
import 'package:pinboard_wizard/src/pages/pinned/state/pinned_state.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import '../../../test_helpers.dart';

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
  Future<void> updateBookmark(Post bookmark) => super.noSuchMethod(
    Invocation.method(#updateBookmark, [bookmark]),
    returnValue: Future.value(),
  );

  @override
  Future<void> deleteBookmark(String url) => super.noSuchMethod(
    Invocation.method(#deleteBookmark, [url]),
    returnValue: Future.value(),
  );
}

void main() {
  group('PinnedCubit', () {
    late MockPinboardService mockPinboardService;
    late PinnedCubit cubit;

    setUp(() {
      mockPinboardService = MockPinboardService();
      cubit = PinnedCubit(pinboardService: mockPinboardService);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state should be correct', () {
      expect(cubit.state, equals(const PinnedState()));
      expect(cubit.state.status, equals(PinnedStatus.loading));
      expect(cubit.state.pinnedBookmarks, isEmpty);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isLoading, isTrue);
      expect(cubit.state.isLoaded, isFalse);
      expect(cubit.state.hasError, isFalse);
      expect(cubit.state.isEmpty, isTrue);
    });

    group('loadPinnedBookmarks', () {
      blocTest<PinnedCubit, PinnedState>(
        'emits [loading, loaded] when successful with no pinned bookmarks',
        build: () {
          when(
            mockPinboardService.getAllBookmarks(),
          ).thenAnswer((_) async => []);
          return cubit;
        },
        act: (cubit) => cubit.loadPinnedBookmarks(),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.loading,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loaded,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
        ],
      );

      blocTest<PinnedCubit, PinnedState>(
        'emits [loading, loaded] when successful with pinned bookmarks',
        build: () {
          final allBookmarks = [
            PostTestData.createPost(
              href: 'https://flutter.dev',
              description: 'Flutter Docs',
              tags: 'flutter pin development',
            ),
            PostTestData.createPost(
              href: 'https://dart.dev',
              description: 'Dart Docs',
              tags: 'dart pin:work programming',
            ),
            PostTestData.createPost(
              href: 'https://example.com',
              description: 'Non-pinned',
              tags: 'example test',
            ),
          ];
          when(
            mockPinboardService.getAllBookmarks(),
          ).thenAnswer((_) async => allBookmarks);
          return cubit;
        },
        act: (cubit) => cubit.loadPinnedBookmarks(),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.loading,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          PinnedState(
            status: PinnedStatus.loaded,
            pinnedBookmarks: [
              PostTestData.createPost(
                href: 'https://flutter.dev',
                description: 'Flutter Docs',
                tags: 'flutter pin development',
              ),
              PostTestData.createPost(
                href: 'https://dart.dev',
                description: 'Dart Docs',
                tags: 'dart pin:work programming',
              ),
            ],
            errorMessage: null,
          ),
        ],
      );

      blocTest<PinnedCubit, PinnedState>(
        'emits [loading, error] when service throws exception',
        build: () {
          when(
            mockPinboardService.getAllBookmarks(),
          ).thenThrow(ExceptionTestData.createNetworkException());
          return cubit;
        },
        act: (cubit) => cubit.loadPinnedBookmarks(),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.loading,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.error,
            pinnedBookmarks: [],
            errorMessage:
                'Error loading pinned bookmarks: Exception: Network error: Failed to connect to server',
          ),
        ],
      );

      test('calls getAllBookmarks with correct parameters', () async {
        when(mockPinboardService.getAllBookmarks()).thenAnswer((_) async => []);

        await cubit.loadPinnedBookmarks();

        verify(mockPinboardService.getAllBookmarks()).called(1);
      });
    });

    group('refresh', () {
      blocTest<PinnedCubit, PinnedState>(
        'emits [refreshing, loaded] when successful',
        build: () {
          final pinnedBookmarks = [
            PostTestData.createPost(
              href: 'https://example.com',
              description: 'Test Bookmark',
              tags: 'test pin',
            ),
          ];
          when(
            mockPinboardService.getAllBookmarks(),
          ).thenAnswer((_) async => pinnedBookmarks);
          return cubit;
        },
        act: (cubit) => cubit.refresh(),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.refreshing,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loading,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          PinnedState(
            status: PinnedStatus.loaded,
            pinnedBookmarks: [
              PostTestData.createPost(
                href: 'https://example.com',
                description: 'Test Bookmark',
                tags: 'test pin',
              ),
            ],
            errorMessage: null,
          ),
        ],
      );

      blocTest<PinnedCubit, PinnedState>(
        'emits [refreshing, error] when service throws exception',
        build: () {
          when(
            mockPinboardService.getAllBookmarks(),
          ).thenThrow(ExceptionTestData.createServerException());
          return cubit;
        },
        act: (cubit) => cubit.refresh(),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.refreshing,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loading,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.error,
            pinnedBookmarks: [],
            errorMessage:
                'Error loading pinned bookmarks: Exception: Server error: Internal server error (500)',
          ),
        ],
      );
    });

    group('unpinBookmark', () {
      late Post testBookmark;
      late Post expectedUpdatedBookmark;

      setUp(() {
        testBookmark = PostTestData.createPost(
          href: 'https://example.com',
          description: 'Test Bookmark',
          tags: 'flutter pin development',
        );
        expectedUpdatedBookmark = testBookmark.copyWith(
          tags: 'flutter development',
        );
      });

      blocTest<PinnedCubit, PinnedState>(
        'successfully unpins bookmark and refreshes list',
        build: () {
          // Set up the mock for updateBookmark
          when(
            mockPinboardService.updateBookmark(expectedUpdatedBookmark),
          ).thenAnswer((_) async {});

          // Set up the mock for the refresh call (getAllBookmarks)
          when(
            mockPinboardService.getAllBookmarks(tag: 'pin'),
          ).thenAnswer((_) async => []); // Empty list after unpinning

          return cubit;
        },
        act: (cubit) => cubit.unpinBookmark(testBookmark),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.refreshing,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loading,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loaded,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
        ],
        verify: (_) {
          // Verify updateBookmark was called with bookmark without pin tag
          verify(
            mockPinboardService.updateBookmark(expectedUpdatedBookmark),
          ).called(1);
          // Verify refresh was called (getAllBookmarks)
          verify(mockPinboardService.getAllBookmarks()).called(1);
        },
      );

      blocTest<PinnedCubit, PinnedState>(
        'handles bookmark with only pin tag',
        build: () {
          final bookmarkWithOnlyPin = PostTestData.createPost(tags: 'pin');
          final expectedUpdated = bookmarkWithOnlyPin.copyWith(tags: '');

          when(
            mockPinboardService.updateBookmark(expectedUpdated),
          ).thenAnswer((_) async {});
          when(
            mockPinboardService.getAllBookmarks(),
          ).thenAnswer((_) async => []);

          return cubit;
        },
        act: (cubit) =>
            cubit.unpinBookmark(PostTestData.createPost(tags: 'pin')),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.refreshing,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loading,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loaded,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
        ],
        verify: (_) {
          final expectedUpdated = PostTestData.createPost(
            tags: 'pin',
          ).copyWith(tags: '');
          verify(mockPinboardService.updateBookmark(expectedUpdated)).called(1);
        },
      );

      blocTest<PinnedCubit, PinnedState>(
        'handles case-insensitive pin tag removal',
        build: () {
          final bookmarkWithUppercasePin = PostTestData.createPost(
            tags: 'flutter PIN development',
          );
          final expectedUpdated = bookmarkWithUppercasePin.copyWith(
            tags: 'flutter development',
          );

          when(
            mockPinboardService.updateBookmark(expectedUpdated),
          ).thenAnswer((_) async {});
          when(
            mockPinboardService.getAllBookmarks(),
          ).thenAnswer((_) async => []);

          return cubit;
        },
        act: (cubit) {
          final bookmarkWithUppercasePin = PostTestData.createPost(
            tags: 'flutter PIN development',
          );
          return cubit.unpinBookmark(bookmarkWithUppercasePin);
        },
        expect: () => [
          const PinnedState(
            status: PinnedStatus.refreshing,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loading,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loaded,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
        ],
        verify: (_) {
          final expectedUpdated = PostTestData.createPost(
            tags: 'flutter PIN development',
          ).copyWith(tags: 'flutter development');
          verify(mockPinboardService.updateBookmark(expectedUpdated)).called(1);
        },
      );

      blocTest<PinnedCubit, PinnedState>(
        'emits error when updateBookmark fails',
        build: () {
          when(
            mockPinboardService.updateBookmark(expectedUpdatedBookmark),
          ).thenThrow(ExceptionTestData.createAuthException());
          return cubit;
        },
        act: (cubit) => cubit.unpinBookmark(testBookmark),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.error,
            pinnedBookmarks: [],
            errorMessage:
                'Failed to unpin bookmark: Exception: Authentication failed: Invalid API token',
          ),
        ],
      );
    });

    group('updateBookmark', () {
      late Post testBookmark;

      setUp(() {
        testBookmark = PostTestData.createPost(
          href: 'https://example.com',
          description: 'Updated Test Bookmark',
          tags: 'flutter pin development updated',
        );
      });

      blocTest<PinnedCubit, PinnedState>(
        'successfully updates bookmark and refreshes list',
        build: () {
          when(
            mockPinboardService.updateBookmark(testBookmark),
          ).thenAnswer((_) async {});
          when(
            mockPinboardService.getAllBookmarks(),
          ).thenAnswer((_) async => [testBookmark]);
          return cubit;
        },
        act: (cubit) => cubit.updateBookmark(testBookmark),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.refreshing,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loading,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          PinnedState(
            status: PinnedStatus.loaded,
            pinnedBookmarks: [testBookmark],
            errorMessage: null,
          ),
        ],
        verify: (_) {
          verify(mockPinboardService.updateBookmark(testBookmark)).called(1);
          verify(mockPinboardService.getAllBookmarks(tag: 'pin')).called(1);
        },
      );

      blocTest<PinnedCubit, PinnedState>(
        'emits error when updateBookmark fails',
        build: () {
          when(
            mockPinboardService.updateBookmark(testBookmark),
          ).thenThrow(ExceptionTestData.createTimeoutException());
          return cubit;
        },
        act: (cubit) => cubit.updateBookmark(testBookmark),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.error,
            pinnedBookmarks: [],
            errorMessage:
                'Failed to update bookmark: Exception: Request timeout: Operation took too long',
          ),
        ],
      );
    });

    group('deleteBookmark', () {
      const testUrl = 'https://example.com';

      blocTest<PinnedCubit, PinnedState>(
        'successfully deletes bookmark and refreshes list',
        build: () {
          when(
            mockPinboardService.deleteBookmark(testUrl),
          ).thenAnswer((_) async {});
          when(
            mockPinboardService.getAllBookmarks(),
          ).thenAnswer((_) async => []);

          return cubit;
        },
        act: (cubit) => cubit.deleteBookmark(testUrl),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.refreshing,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loading,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
          const PinnedState(
            status: PinnedStatus.loaded,
            pinnedBookmarks: [],
            errorMessage: null,
          ),
        ],
        verify: (_) {
          verify(mockPinboardService.deleteBookmark(testUrl)).called(1);
          verify(mockPinboardService.getAllBookmarks(tag: 'pin')).called(1);
        },
      );

      blocTest<PinnedCubit, PinnedState>(
        'emits error when deleteBookmark fails',
        build: () {
          when(
            mockPinboardService.deleteBookmark(testUrl),
          ).thenThrow(ExceptionTestData.createNotFoundException());
          return cubit;
        },
        act: (cubit) => cubit.deleteBookmark(testUrl),
        expect: () => [
          const PinnedState(
            status: PinnedStatus.error,
            pinnedBookmarks: [],
            errorMessage:
                'Failed to delete bookmark: Exception: Not found: Resource does not exist (404)',
          ),
        ],
      );
    });

    group('state properties', () {
      test('isLoading returns correct value for each status', () {
        expect(
          const PinnedState(status: PinnedStatus.loading).isLoading,
          isTrue,
        );
        expect(
          const PinnedState(status: PinnedStatus.loaded).isLoading,
          isFalse,
        );
        expect(
          const PinnedState(status: PinnedStatus.error).isLoading,
          isFalse,
        );
        expect(
          const PinnedState(status: PinnedStatus.refreshing).isLoading,
          isFalse,
        );
      });

      test('isLoaded returns correct value for each status', () {
        expect(
          const PinnedState(status: PinnedStatus.loading).isLoaded,
          isFalse,
        );
        expect(const PinnedState(status: PinnedStatus.loaded).isLoaded, isTrue);
        expect(const PinnedState(status: PinnedStatus.error).isLoaded, isFalse);
        expect(
          const PinnedState(status: PinnedStatus.refreshing).isLoaded,
          isFalse,
        );
      });

      test('hasError returns correct value for each status', () {
        expect(
          const PinnedState(status: PinnedStatus.loading).hasError,
          isFalse,
        );
        expect(
          const PinnedState(status: PinnedStatus.loaded).hasError,
          isFalse,
        );
        expect(const PinnedState(status: PinnedStatus.error).hasError, isTrue);
        expect(
          const PinnedState(status: PinnedStatus.refreshing).hasError,
          isFalse,
        );
      });

      test('isRefreshing returns correct value for each status', () {
        expect(
          const PinnedState(status: PinnedStatus.loading).isRefreshing,
          isFalse,
        );
        expect(
          const PinnedState(status: PinnedStatus.loaded).isRefreshing,
          isFalse,
        );
        expect(
          const PinnedState(status: PinnedStatus.error).isRefreshing,
          isFalse,
        );
        expect(
          const PinnedState(status: PinnedStatus.refreshing).isRefreshing,
          isTrue,
        );
      });

      test('isEmpty returns correct value based on pinnedBookmarks', () {
        expect(const PinnedState(pinnedBookmarks: []).isEmpty, isTrue);
        expect(
          PinnedState(pinnedBookmarks: [PostTestData.createPost()]).isEmpty,
          isFalse,
        );
      });
    });

    group('copyWith', () {
      test('returns new instance with updated values', () {
        const original = PinnedState(
          status: PinnedStatus.loading,
          pinnedBookmarks: [],
          errorMessage: null,
        );

        final updated = original.copyWith(
          status: PinnedStatus.loaded,
          errorMessage: 'Test error',
        );

        expect(updated.status, equals(PinnedStatus.loaded));
        expect(updated.pinnedBookmarks, equals([]));
        expect(updated.errorMessage, equals('Test error'));

        // Original should remain unchanged
        expect(original.status, equals(PinnedStatus.loading));
        expect(original.errorMessage, isNull);
      });

      test(
        'returns new instance with same values when no parameters provided',
        () {
          const original = PinnedState(
            status: PinnedStatus.loaded,
            pinnedBookmarks: [],
            errorMessage: 'Original error',
          );

          final copy = original.copyWith();

          expect(copy.status, equals(original.status));
          expect(copy.pinnedBookmarks, equals(original.pinnedBookmarks));
          expect(copy.errorMessage, equals(original.errorMessage));
          expect(copy, equals(original));
        },
      );
    });

    group('equality and hashCode', () {
      test('two states with same values are equal', () {
        final bookmarks = [PostTestData.createPost()];

        final state1 = PinnedState(
          status: PinnedStatus.loaded,
          pinnedBookmarks: bookmarks,
          errorMessage: 'Test error',
        );

        final state2 = PinnedState(
          status: PinnedStatus.loaded,
          pinnedBookmarks: bookmarks,
          errorMessage: 'Test error',
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('two states with different values are not equal', () {
        final state1 = const PinnedState(
          status: PinnedStatus.loaded,
          pinnedBookmarks: [],
          errorMessage: 'Error 1',
        );

        final state2 = const PinnedState(
          status: PinnedStatus.error,
          pinnedBookmarks: [],
          errorMessage: 'Error 2',
        );

        expect(state1, isNot(equals(state2)));
        expect(state1.hashCode, isNot(equals(state2.hashCode)));
      });
    });

    group('integration tests', () {
      blocTest<PinnedCubit, PinnedState>(
        'full workflow: load -> unpin -> refresh shows updated list',
        build: () {
          final pinnedBookmark = PostTestData.createPost(
            href: 'https://example.com',
            description: 'Test Bookmark',
            tags: 'flutter pin development',
          );

          // First call (initial load) returns the pinned bookmark
          when(
            mockPinboardService.getAllBookmarks(tag: 'pin'),
          ).thenAnswer((_) async => [pinnedBookmark]);

          when(
            mockPinboardService.updateBookmark(
              PostTestData.createPost(
                href: 'https://example.com',
                description: 'Test Bookmark',
                tags: 'flutter development',
              ),
            ),
          ).thenAnswer((_) async {});

          return cubit;
        },
        act: (cubit) async {
          // Load initial pinned bookmarks
          await cubit.loadPinnedBookmarks();

          // Setup mock for after unpinning (should return empty list)
          when(
            mockPinboardService.getAllBookmarks(),
          ).thenAnswer((_) async => []);

          // Unpin the bookmark
          await cubit.unpinBookmark(
            PostTestData.createPost(
              href: 'https://example.com',
              description: 'Test Bookmark',
              tags: 'flutter pin development',
            ),
          );
        },
        expect: () {
          final testPost = PostTestData.createPost(
            href: 'https://example.com',
            description: 'Test Bookmark',
            tags: 'flutter pin development',
          );
          return [
            const PinnedState(
              status: PinnedStatus.loading,
              pinnedBookmarks: [],
              errorMessage: null,
            ),
            PinnedState(
              status: PinnedStatus.loaded,
              pinnedBookmarks: [testPost],
              errorMessage: null,
            ),
            PinnedState(
              status: PinnedStatus.refreshing,
              pinnedBookmarks: [testPost],
              errorMessage: null,
            ),
            PinnedState(
              status: PinnedStatus.loading,
              pinnedBookmarks: [testPost],
              errorMessage: null,
            ),
            const PinnedState(
              status: PinnedStatus.loaded,
              pinnedBookmarks: [],
              errorMessage: null,
            ),
          ];
        },
      );
    });
  });
}
