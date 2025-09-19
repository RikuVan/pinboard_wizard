import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinboard_wizard/src/pages/pinned/state/pinned_state.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';

class PinnedCubit extends Cubit<PinnedState> {
  PinnedCubit({required PinboardService pinboardService})
    : _pinboardService = pinboardService,
      super(const PinnedState());

  final PinboardService _pinboardService;

  /// Safe emit that checks if cubit is closed
  void safeEmit(PinnedState newState) {
    if (!isClosed) {
      emit(newState);
    }
  }

  /// Load all pinned bookmarks (bookmarks with 'pin' tag)
  Future<void> loadPinnedBookmarks() async {
    if (isClosed) return;
    safeEmit(state.copyWith(status: PinnedStatus.loading, errorMessage: null));

    try {
      // Use API tag filtering to get only bookmarks with 'pin' tag
      final pinnedBookmarks = await _pinboardService.getAllBookmarks(
        tag: 'pin',
      );

      if (isClosed) return;
      safeEmit(
        state.copyWith(
          status: PinnedStatus.loaded,
          pinnedBookmarks: pinnedBookmarks,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      safeEmit(
        state.copyWith(
          status: PinnedStatus.error,
          errorMessage: 'Error loading pinned bookmarks: $e',
        ),
      );
    }
  }

  /// Refresh pinned bookmarks
  Future<void> refresh() async {
    if (isClosed) return;
    safeEmit(state.copyWith(status: PinnedStatus.refreshing));
    await loadPinnedBookmarks();
  }

  /// Remove pin from a bookmark
  Future<void> unpinBookmark(Post bookmark) async {
    try {
      // Create a copy of the bookmark without the 'pin' tag
      final currentTags = bookmark.tagList;
      final updatedTags = currentTags
          .where((tag) => tag.toLowerCase() != 'pin')
          .toList();
      final updatedBookmark = bookmark.copyWith(tags: updatedTags.join(' '));

      await _pinboardService.updateBookmark(updatedBookmark);

      // Refresh to update the list
      await refresh();
    } catch (e) {
      safeEmit(
        state.copyWith(
          status: PinnedStatus.error,
          errorMessage: 'Failed to unpin bookmark: $e',
        ),
      );
    }
  }

  /// Update an existing pinned bookmark
  Future<void> updateBookmark(Post bookmark) async {
    try {
      await _pinboardService.updateBookmark(bookmark);
      await refresh();
    } catch (e) {
      safeEmit(
        state.copyWith(
          status: PinnedStatus.error,
          errorMessage: 'Failed to update bookmark: $e',
        ),
      );
    }
  }

  /// Delete a pinned bookmark
  Future<void> deleteBookmark(String url) async {
    try {
      await _pinboardService.deleteBookmark(url);
      await refresh();
    } catch (e) {
      safeEmit(
        state.copyWith(
          status: PinnedStatus.error,
          errorMessage: 'Failed to delete bookmark: $e',
        ),
      );
    }
  }
}
