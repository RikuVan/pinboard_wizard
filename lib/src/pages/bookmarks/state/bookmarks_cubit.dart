import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/state/bookmarks_state.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';

class BookmarksCubit extends Cubit<BookmarksState> {
  BookmarksCubit({required PinboardService pinboardService})
    : _pinboardService = pinboardService,
      super(const BookmarksState());

  final PinboardService _pinboardService;
  static const int _pageSize = 50;

  /// Load initial bookmarks
  Future<void> loadBookmarks() async {
    emit(
      state.copyWith(
        status: BookmarksStatus.loading,
        errorMessage: null,
        bookmarks: [],
        currentOffset: 0,
        hasMoreData: true,
      ),
    );

    try {
      final results = await _pinboardService.getAllBookmarks(
        start: 0,
        results: _pageSize,
      );

      emit(
        state.copyWith(
          status: BookmarksStatus.loaded,
          bookmarks: results,
          currentOffset: results.length,
          hasMoreData: results.length == _pageSize,
        ),
      );

      // Extract and update available tags
      _updateAvailableTags();
    } catch (e) {
      emit(
        state.copyWith(
          status: BookmarksStatus.error,
          errorMessage: 'Error loading bookmarks: $e',
        ),
      );
    }
  }

  /// Load more bookmarks for pagination
  Future<void> loadMoreBookmarks() async {
    if (state.isLoadingMore || !state.hasMoreData || state.searchAll) {
      return;
    }

    emit(state.copyWith(status: BookmarksStatus.loadingMore));

    try {
      final results = await _pinboardService.getAllBookmarks(
        start: state.currentOffset,
        results: _pageSize,
      );

      final updatedBookmarks = List<Post>.from(state.bookmarks)
        ..addAll(results);

      emit(
        state.copyWith(
          status: BookmarksStatus.loaded,
          bookmarks: updatedBookmarks,
          currentOffset: state.currentOffset + results.length,
          hasMoreData: results.length == _pageSize,
        ),
      );

      // Update available tags after loading more bookmarks
      _updateAvailableTags();
    } catch (e) {
      emit(
        state.copyWith(
          status: BookmarksStatus.error,
          errorMessage: 'Failed to load more bookmarks: $e',
        ),
      );
    }
  }

  /// Load all bookmarks (for search functionality)
  Future<void> loadAllBookmarks() async {
    if (state.allBookmarksLoaded || state.isLoadingAllBookmarks) {
      return;
    }

    emit(state.copyWith(status: BookmarksStatus.loadingAllBookmarks));

    try {
      final allBookmarks = await _pinboardService.getAllBookmarks(
        results: null, // No limit - get all bookmarks
      );

      emit(
        state.copyWith(
          status: BookmarksStatus.loaded,
          allBookmarks: allBookmarks,
          allBookmarksLoaded: true,
        ),
      );

      // Update available tags with all bookmarks
      _updateAvailableTags();
    } catch (e) {
      emit(
        state.copyWith(
          status: BookmarksStatus.error,
          errorMessage: 'Failed to load all bookmarks: $e',
        ),
      );
    }
  }

  /// Toggle search scope between current page and all bookmarks
  Future<void> toggleSearchScope(bool searchAll) async {
    emit(state.copyWith(searchAll: searchAll));

    // If switching to "All" and we need to load all bookmarks
    if (searchAll && !state.allBookmarksLoaded) {
      await loadAllBookmarks();
    }

    // Re-perform search with new scope if there's an active search
    if (state.searchQuery.isNotEmpty) {
      await performSearch(state.searchQuery);
    }
  }

  /// Perform search in bookmarks
  Future<void> performSearch(String query) async {
    if (query.isEmpty) {
      clearSearch();
      return;
    }

    emit(
      state.copyWith(
        isSearching: true,
        searchQuery: query,
        status: BookmarksStatus.searching,
      ),
    );

    try {
      List<Post> searchResults;

      if (state.searchAll) {
        // Load all bookmarks first if not already loaded
        if (!state.allBookmarksLoaded) {
          await loadAllBookmarks();
        }
        // Search in all loaded bookmarks
        searchResults = _filterBookmarks(state.allBookmarks, query);
      } else {
        // Search only current loaded bookmarks
        searchResults = _filterBookmarks(state.bookmarks, query);
      }

      emit(
        state.copyWith(
          status: BookmarksStatus.loaded,
          filteredBookmarks: searchResults,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BookmarksStatus.error,
          errorMessage: 'Failed to search bookmarks: $e',
        ),
      );
    }
  }

  /// Clear search and return to normal view
  void clearSearch() {
    emit(
      state.copyWith(
        isSearching: false,
        searchQuery: '',
        filteredBookmarks: [],
        status: BookmarksStatus.loaded,
      ),
    );
  }

  /// Refresh bookmarks
  Future<void> refresh() async {
    await loadBookmarks();
  }

  /// Helper method to filter bookmarks based on query
  List<Post> _filterBookmarks(List<Post> bookmarks, String query) {
    final queryLower = query.toLowerCase();
    return bookmarks.where((bookmark) {
      final titleMatch = bookmark.description.toLowerCase().contains(
        queryLower,
      );
      final descMatch = bookmark.extended.toLowerCase().contains(queryLower);
      final tagMatch = bookmark.tags.toLowerCase().contains(queryLower);
      final urlMatch = bookmark.href.toLowerCase().contains(queryLower);
      return titleMatch || descMatch || tagMatch || urlMatch;
    }).toList();
  }

  /// Check if should load more bookmarks (for scroll listener)
  bool shouldLoadMore() {
    return !state.isLoadingMore &&
        state.hasMoreData &&
        !state.searchAll &&
        !state.isSearching;
  }

  /// Get secondary footer text
  String? getSecondaryFooterText() {
    if (state.allBookmarksLoaded && !state.searchAll) {
      return 'Total: ${state.allBookmarks.length} bookmarks';
    }
    return null;
  }

  /// Extract all unique tags from bookmarks
  void _updateAvailableTags() {
    final Set<String> tagSet = <String>{};

    // Get tags from current bookmarks or all bookmarks if loaded
    final List<Post> sourceBookmarks = state.allBookmarksLoaded
        ? state.allBookmarks
        : state.bookmarks;

    for (final bookmark in sourceBookmarks) {
      // Normalize tags to lowercase for consistent handling
      for (final tag in bookmark.tagList) {
        tagSet.add(tag.toLowerCase());
      }
    }

    final List<String> sortedTags = tagSet.toList()..sort();

    emit(state.copyWith(availableTags: sortedTags));
  }

  /// Toggle a tag in the selected tags list
  void toggleTag(String tag) {
    final String normalizedTag = tag.toLowerCase();
    final List<String> newSelectedTags = List<String>.from(state.selectedTags);

    if (newSelectedTags.contains(normalizedTag)) {
      newSelectedTags.remove(normalizedTag);
    } else {
      newSelectedTags.add(normalizedTag);
    }

    emit(state.copyWith(selectedTags: newSelectedTags));
  }

  /// Clear all selected tags
  void clearSelectedTags() {
    emit(state.copyWith(selectedTags: []));
  }

  /// Add a tag to selected tags
  void addTag(String tag) {
    final String normalizedTag = tag.toLowerCase();
    if (!state.selectedTags.contains(normalizedTag)) {
      final List<String> newSelectedTags = List<String>.from(state.selectedTags)
        ..add(normalizedTag);
      emit(state.copyWith(selectedTags: newSelectedTags));
    }
  }

  /// Remove a tag from selected tags
  void removeTag(String tag) {
    final String normalizedTag = tag.toLowerCase();
    final List<String> newSelectedTags = List<String>.from(state.selectedTags)
      ..remove(normalizedTag);
    emit(state.copyWith(selectedTags: newSelectedTags));
  }

  /// Get footer text for display including tag filtering info
  String getFooterText() {
    String baseText;
    if (state.isSearching) {
      baseText =
          'Found ${state.filteredBookmarks.length} results${state.searchAll ? ' in all bookmarks' : ' in current page'}';
    } else if (state.searchAll) {
      baseText =
          'Showing all ${state.allBookmarksLoaded ? state.allBookmarks.length : state.bookmarks.length} bookmarks';
    } else {
      baseText = '${state.bookmarks.length} bookmarks loaded';
    }

    if (state.hasTagsSelected) {
      final displayedCount = state.displayBookmarks.length;
      baseText += ' • $displayedCount after filtering';
    }

    return baseText;
  }

  /// Add a new bookmark
  Future<void> addBookmark({
    required String url,
    required String title,
    String? description,
    List<String>? tags,
    bool shared = true,
    bool toRead = false,
    bool replace = false,
  }) async {
    try {
      await _pinboardService.addBookmark(
        url: url,
        title: title,
        description: description,
        tags: tags,
        shared: shared,
        toRead: toRead,
        replace: replace,
      );

      // Refresh bookmarks to show the new one
      await refresh();
    } catch (e) {
      emit(
        state.copyWith(
          status: BookmarksStatus.error,
          errorMessage: 'Failed to add bookmark: $e',
        ),
      );
    }
  }

  /// Update an existing bookmark
  Future<void> updateBookmark(Post bookmark) async {
    try {
      await _pinboardService.updateBookmark(bookmark);

      // Refresh bookmarks to show the updated one
      await refresh();
    } catch (e) {
      emit(
        state.copyWith(
          status: BookmarksStatus.error,
          errorMessage: 'Failed to update bookmark: $e',
        ),
      );
    }
  }

  /// Delete a bookmark
  Future<void> deleteBookmark(String url) async {
    try {
      await _pinboardService.deleteBookmark(url);

      // Refresh bookmarks to remove the deleted one
      await refresh();
    } catch (e) {
      emit(
        state.copyWith(
          status: BookmarksStatus.error,
          errorMessage: 'Failed to delete bookmark: $e',
        ),
      );
    }
  }
}
