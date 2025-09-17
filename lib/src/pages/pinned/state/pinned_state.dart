import 'package:equatable/equatable.dart';
import 'package:pinboard_wizard/src/pinboard/models/post.dart';

enum PinnedStatus { loading, loaded, error, refreshing }

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
