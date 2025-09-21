import 'package:equatable/equatable.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';

enum PinnedStatus { loading, loaded, error, refreshing }

class PinnedBookmarkGroup extends Equatable {
  final String categoryName;
  final List<Post> bookmarks;

  const PinnedBookmarkGroup({
    required this.categoryName,
    required this.bookmarks,
  });

  @override
  List<Object?> get props => [categoryName, bookmarks];

  @override
  bool get stringify => true;
}

class PinnedState extends Equatable {
  final PinnedStatus status;
  final List<Post> pinnedBookmarks;
  final String? errorMessage;

  const PinnedState({
    this.status = PinnedStatus.loading,
    this.pinnedBookmarks = const [],
    this.errorMessage,
  });

  bool get isLoading => status == PinnedStatus.loading;
  bool get isLoaded => status == PinnedStatus.loaded;
  bool get hasError => status == PinnedStatus.error;
  bool get isRefreshing => status == PinnedStatus.refreshing;
  bool get isEmpty => pinnedBookmarks.isEmpty;

  /// Group pinned bookmarks by category
  List<PinnedBookmarkGroup> get groupedBookmarks {
    final Map<String, List<Post>> groups = {};

    for (final bookmark in pinnedBookmarks) {
      final category = bookmark.pinCategory ?? 'General';
      groups.putIfAbsent(category, () => []).add(bookmark);
    }

    // Sort groups: General first, then alphabetically
    final sortedEntries = groups.entries.toList();
    sortedEntries.sort((a, b) {
      if (a.key == 'General') return -1;
      if (b.key == 'General') return 1;
      return a.key.compareTo(b.key);
    });

    return sortedEntries
        .map(
          (entry) => PinnedBookmarkGroup(
            categoryName: entry.key,
            bookmarks: entry.value,
          ),
        )
        .toList();
  }

  PinnedState copyWith({
    PinnedStatus? status,
    List<Post>? pinnedBookmarks,
    String? errorMessage,
  }) {
    return PinnedState(
      status: status ?? this.status,
      pinnedBookmarks: pinnedBookmarks ?? this.pinnedBookmarks,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, pinnedBookmarks, errorMessage];

  @override
  bool get stringify => true;
}
