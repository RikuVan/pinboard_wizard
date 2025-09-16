import 'package:equatable/equatable.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';

enum BookmarksStatus {
  initial,
  loading,
  loaded,
  error,
  loadingMore,
  searching,
  loadingAllBookmarks,
}

class BookmarksState extends Equatable {
  const BookmarksState({
    this.status = BookmarksStatus.initial,
    this.bookmarks = const [],
    this.allBookmarks = const [],
    this.filteredBookmarks = const [],
    this.errorMessage,
    this.isSearching = false,
    this.searchAll = false,
    this.allBookmarksLoaded = false,
    this.hasMoreData = true,
    this.currentOffset = 0,
    this.searchQuery = '',
    this.availableTags = const [],
    this.selectedTags = const [],
  });

  final BookmarksStatus status;
  final List<Post> bookmarks;
  final List<Post> allBookmarks;
  final List<Post> filteredBookmarks;
  final String? errorMessage;
  final bool isSearching;
  final bool searchAll;
  final bool allBookmarksLoaded;
  final bool hasMoreData;
  final int currentOffset;
  final String searchQuery;
  final List<String> availableTags;
  final List<String> selectedTags;

  BookmarksState copyWith({
    BookmarksStatus? status,
    List<Post>? bookmarks,
    List<Post>? allBookmarks,
    List<Post>? filteredBookmarks,
    String? errorMessage,
    bool? isSearching,
    bool? searchAll,
    bool? allBookmarksLoaded,
    bool? hasMoreData,
    int? currentOffset,
    String? searchQuery,
    List<String>? availableTags,
    List<String>? selectedTags,
  }) {
    return BookmarksState(
      status: status ?? this.status,
      bookmarks: bookmarks ?? this.bookmarks,
      allBookmarks: allBookmarks ?? this.allBookmarks,
      filteredBookmarks: filteredBookmarks ?? this.filteredBookmarks,
      errorMessage: errorMessage ?? this.errorMessage,
      isSearching: isSearching ?? this.isSearching,
      searchAll: searchAll ?? this.searchAll,
      allBookmarksLoaded: allBookmarksLoaded ?? this.allBookmarksLoaded,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      currentOffset: currentOffset ?? this.currentOffset,
      searchQuery: searchQuery ?? this.searchQuery,
      availableTags: availableTags ?? this.availableTags,
      selectedTags: selectedTags ?? this.selectedTags,
    );
  }

  // Convenience getters
  bool get isLoading => status == BookmarksStatus.loading;
  bool get isLoadingMore => status == BookmarksStatus.loadingMore;
  bool get isLoadingAllBookmarks =>
      status == BookmarksStatus.loadingAllBookmarks;
  bool get hasError => status == BookmarksStatus.error;
  bool get isEmpty => bookmarks.isEmpty && status != BookmarksStatus.loading;

  List<Post> get displayBookmarks {
    List<Post> baseBookmarks;
    if (isSearching) {
      baseBookmarks = filteredBookmarks;
    } else {
      baseBookmarks = bookmarks;
    }

    // Apply tag filtering
    if (selectedTags.isNotEmpty) {
      return baseBookmarks.where((bookmark) {
        return selectedTags.every(
          (selectedTag) => bookmark.hasTag(selectedTag),
        );
      }).toList();
    }

    return baseBookmarks;
  }

  bool get hasTagsSelected => selectedTags.isNotEmpty;

  @override
  List<Object?> get props => [
    status,
    bookmarks,
    allBookmarks,
    filteredBookmarks,
    errorMessage,
    isSearching,
    searchAll,
    allBookmarksLoaded,
    hasMoreData,
    currentOffset,
    searchQuery,
    availableTags,
    selectedTags,
  ];
}
