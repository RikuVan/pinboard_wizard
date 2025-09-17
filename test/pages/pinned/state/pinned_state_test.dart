import 'package:flutter_test/flutter_test.dart';
import 'package:pinboard_wizard/src/pages/pinned/state/pinned_state.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import '../../../test_helpers.dart';

void main() {
  group('PinnedState', () {
    group('constructor', () {
      test('creates instance with default values', () {
        const state = PinnedState();

        expect(state.status, equals(PinnedStatus.loading));
        expect(state.pinnedBookmarks, equals([]));
        expect(state.errorMessage, isNull);
      });

      test('creates instance with provided values', () {
        final bookmarks = [PostTestData.createPost()];
        const errorMessage = 'Test error';

        final state = PinnedState(
          status: PinnedStatus.error,
          pinnedBookmarks: bookmarks,
          errorMessage: errorMessage,
        );

        expect(state.status, equals(PinnedStatus.error));
        expect(state.pinnedBookmarks, equals(bookmarks));
        expect(state.errorMessage, equals(errorMessage));
      });
    });

    group('getters', () {
      test('isLoading returns true only for loading status', () {
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

      test('isLoaded returns true only for loaded status', () {
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

      test('hasError returns true only for error status', () {
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

      test('isRefreshing returns true only for refreshing status', () {
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

      test('isEmpty returns true when pinnedBookmarks is empty', () {
        expect(const PinnedState(pinnedBookmarks: []).isEmpty, isTrue);

        final bookmarks = [PostTestData.createPost()];
        expect(PinnedState(pinnedBookmarks: bookmarks).isEmpty, isFalse);
      });

      test(
        'isEmpty returns true when pinnedBookmarks is default empty list',
        () {
          expect(const PinnedState().isEmpty, isTrue);
        },
      );
    });

    group('copyWith', () {
      late PinnedState originalState;
      late List<Post> testBookmarks;

      setUp(() {
        testBookmarks = [
          PostTestData.createPost(description: 'Test 1'),
          PostTestData.createPost(description: 'Test 2'),
        ];
        originalState = PinnedState(
          status: PinnedStatus.loaded,
          pinnedBookmarks: testBookmarks,
          errorMessage: 'Original error',
        );
      });

      test('returns new instance with updated status', () {
        final newState = originalState.copyWith(status: PinnedStatus.error);

        expect(newState.status, equals(PinnedStatus.error));
        expect(newState.pinnedBookmarks, equals(originalState.pinnedBookmarks));
        expect(newState.errorMessage, equals(originalState.errorMessage));
        expect(newState, isNot(same(originalState)));
      });

      test('returns new instance with updated pinnedBookmarks', () {
        final newBookmarks = [PostTestData.createPost(description: 'New Test')];
        final newState = originalState.copyWith(pinnedBookmarks: newBookmarks);

        expect(newState.status, equals(originalState.status));
        expect(newState.pinnedBookmarks, equals(newBookmarks));
        expect(newState.errorMessage, equals(originalState.errorMessage));
        expect(newState, isNot(same(originalState)));
      });

      test('returns new instance with updated errorMessage', () {
        const newErrorMessage = 'New error message';
        final newState = originalState.copyWith(errorMessage: newErrorMessage);

        expect(newState.status, equals(originalState.status));
        expect(newState.pinnedBookmarks, equals(originalState.pinnedBookmarks));
        expect(newState.errorMessage, equals(newErrorMessage));
        expect(newState, isNot(same(originalState)));
      });

      test('returns new instance with multiple updated values', () {
        final newBookmarks = [
          PostTestData.createPost(description: 'Multiple Update'),
        ];
        const newErrorMessage = 'Multiple error';

        final newState = originalState.copyWith(
          status: PinnedStatus.refreshing,
          pinnedBookmarks: newBookmarks,
          errorMessage: newErrorMessage,
        );

        expect(newState.status, equals(PinnedStatus.refreshing));
        expect(newState.pinnedBookmarks, equals(newBookmarks));
        expect(newState.errorMessage, equals(newErrorMessage));
        expect(newState, isNot(same(originalState)));
      });

      test(
        'returns new instance with same values when no parameters provided',
        () {
          final newState = originalState.copyWith();

          expect(newState.status, equals(originalState.status));
          expect(
            newState.pinnedBookmarks,
            equals(originalState.pinnedBookmarks),
          );
          expect(newState.errorMessage, equals(originalState.errorMessage));
          expect(newState, equals(originalState));
          expect(newState, isNot(same(originalState)));
        },
      );

      test('preserves errorMessage when not explicitly changed', () {
        final stateWithError = const PinnedState(errorMessage: 'Some error');
        final newState = stateWithError.copyWith();

        expect(newState.errorMessage, equals('Some error'));
        expect(newState.status, equals(stateWithError.status));
        expect(
          newState.pinnedBookmarks,
          equals(stateWithError.pinnedBookmarks),
        );
      });

      test('can set pinnedBookmarks to empty list', () {
        final stateWithBookmarks = PinnedState(pinnedBookmarks: testBookmarks);
        final newState = stateWithBookmarks.copyWith(pinnedBookmarks: []);

        expect(newState.pinnedBookmarks, equals([]));
        expect(newState.isEmpty, isTrue);
        expect(newState.status, equals(stateWithBookmarks.status));
        expect(newState.errorMessage, equals(stateWithBookmarks.errorMessage));
      });
    });

    group('equality', () {
      test('two states with same values are equal', () {
        final bookmarks1 = [
          PostTestData.createPost(description: 'Test 1'),
          PostTestData.createPost(description: 'Test 2'),
        ];
        final bookmarks2 = [
          PostTestData.createPost(description: 'Test 1'),
          PostTestData.createPost(description: 'Test 2'),
        ];

        final state1 = PinnedState(
          status: PinnedStatus.loaded,
          pinnedBookmarks: bookmarks1,
          errorMessage: 'Test error',
        );

        final state2 = PinnedState(
          status: PinnedStatus.loaded,
          pinnedBookmarks: bookmarks2,
          errorMessage: 'Test error',
        );

        expect(state1, equals(state2));
      });

      test('two states with different status are not equal', () {
        const state1 = PinnedState(status: PinnedStatus.loading);
        const state2 = PinnedState(status: PinnedStatus.loaded);

        expect(state1, isNot(equals(state2)));
      });

      test('two states with different pinnedBookmarks are not equal', () {
        final bookmarks1 = [PostTestData.createPost(description: 'Test 1')];
        final bookmarks2 = [PostTestData.createPost(description: 'Test 2')];

        final state1 = PinnedState(pinnedBookmarks: bookmarks1);
        final state2 = PinnedState(pinnedBookmarks: bookmarks2);

        expect(state1, isNot(equals(state2)));
      });

      test('two states with different errorMessage are not equal', () {
        const state1 = PinnedState(errorMessage: 'Error 1');
        const state2 = PinnedState(errorMessage: 'Error 2');

        expect(state1, isNot(equals(state2)));
      });

      test(
        'state with null errorMessage is not equal to state with non-null errorMessage',
        () {
          const state1 = PinnedState(errorMessage: null);
          const state2 = PinnedState(errorMessage: 'Error');

          expect(state1, isNot(equals(state2)));
        },
      );

      test('two states with empty bookmarks lists are equal', () {
        const state1 = PinnedState(pinnedBookmarks: []);
        const state2 = PinnedState(pinnedBookmarks: []);

        expect(state1, equals(state2));
      });
    });

    group('hashCode', () {
      test('states with same values have same hashCode', () {
        final bookmarks = [PostTestData.createPost()];

        final state1 = PinnedState(
          status: PinnedStatus.loaded,
          pinnedBookmarks: bookmarks,
          errorMessage: 'Test',
        );

        final state2 = PinnedState(
          status: PinnedStatus.loaded,
          pinnedBookmarks: bookmarks,
          errorMessage: 'Test',
        );

        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('states with different values have different hashCodes', () {
        const state1 = PinnedState(status: PinnedStatus.loading);
        const state2 = PinnedState(status: PinnedStatus.loaded);

        expect(state1.hashCode, isNot(equals(state2.hashCode)));
      });
    });

    group('toString', () {
      test('returns string representation of state', () {
        final bookmarks = [
          PostTestData.createPost(description: 'Test Bookmark'),
        ];
        final state = PinnedState(
          status: PinnedStatus.loaded,
          pinnedBookmarks: bookmarks,
          errorMessage: 'Test error',
        );

        final stringRep = state.toString();

        expect(stringRep, contains('PinnedState'));
        expect(stringRep, contains('PinnedStatus.loaded'));
        expect(stringRep, contains('Test error'));
        expect(stringRep, isA<String>());
      });

      test('handles null errorMessage in toString', () {
        const state = PinnedState(
          status: PinnedStatus.loading,
          errorMessage: null,
        );

        final stringRep = state.toString();

        expect(stringRep, contains('PinnedState'));
        expect(stringRep, contains('PinnedStatus.loading'));
        expect(() => stringRep, returnsNormally);
      });

      test('handles empty bookmarks list in toString', () {
        const state = PinnedState(pinnedBookmarks: []);

        final stringRep = state.toString();

        expect(stringRep, contains('PinnedState'));
        expect(() => stringRep, returnsNormally);
      });
    });

    group('props', () {
      test('includes all properties in props list', () {
        final bookmarks = [PostTestData.createPost()];
        final state = PinnedState(
          status: PinnedStatus.error,
          pinnedBookmarks: bookmarks,
          errorMessage: 'Test error',
        );

        expect(state.props, contains(PinnedStatus.error));
        expect(state.props, contains(bookmarks));
        expect(state.props, contains('Test error'));
        expect(state.props.length, equals(3));
      });

      test('props list changes when state values change', () {
        const state1 = PinnedState(status: PinnedStatus.loading);
        const state2 = PinnedState(status: PinnedStatus.loaded);

        expect(state1.props, isNot(equals(state2.props)));
      });
    });

    group('edge cases', () {
      test('handles very large bookmarks list', () {
        final largeBookmarksList = PostTestData.createLargePostList(
          count: 1000,
        );
        final state = PinnedState(
          status: PinnedStatus.loaded,
          pinnedBookmarks: largeBookmarksList,
        );

        expect(state.pinnedBookmarks.length, equals(1000));
        expect(state.isEmpty, isFalse);
        expect(state.isLoaded, isTrue);
      });

      test('handles very long error message', () {
        final longErrorMessage = 'Error: ${'Very long error message. ' * 100}';
        final state = PinnedState(errorMessage: longErrorMessage);

        expect(state.errorMessage, equals(longErrorMessage));
        expect(state.hasError, isFalse); // Status is still loading by default
      });

      test('maintains immutability', () {
        final testBookmark = PostTestData.createPost(description: 'Original');
        final originalBookmarks = [testBookmark];
        final state = PinnedState(pinnedBookmarks: originalBookmarks);

        // The state should maintain its own reference to the list
        expect(state.pinnedBookmarks.length, equals(1));
        expect(state.pinnedBookmarks.first.description, equals('Original'));

        // Create a new state with different bookmarks to verify independence
        final newBookmarks = [PostTestData.createPost(description: 'New')];
        final newState = state.copyWith(pinnedBookmarks: newBookmarks);

        expect(state.pinnedBookmarks.length, equals(1));
        expect(state.pinnedBookmarks.first.description, equals('Original'));
        expect(newState.pinnedBookmarks.length, equals(1));
        expect(newState.pinnedBookmarks.first.description, equals('New'));
      });
    });
  });
}
