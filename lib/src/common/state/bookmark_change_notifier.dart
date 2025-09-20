import 'package:flutter/foundation.dart';

/// Global notifier for bookmark changes
/// This allows different parts of the app to be notified when bookmarks are added,
/// updated, or deleted from anywhere in the app (like keyboard shortcuts or menu items)
class BookmarkChangeNotifier extends ChangeNotifier {
  static final BookmarkChangeNotifier _instance =
      BookmarkChangeNotifier._internal();

  factory BookmarkChangeNotifier() {
    return _instance;
  }

  BookmarkChangeNotifier._internal();

  /// Notify listeners that a bookmark has been added
  void notifyBookmarkAdded(String url) {
    notifyListeners();
  }

  /// Notify listeners that a bookmark has been updated
  void notifyBookmarkUpdated(String url) {
    notifyListeners();
  }

  /// Notify listeners that a bookmark has been deleted
  void notifyBookmarkDeleted(String url) {
    notifyListeners();
  }

  /// Notify listeners that bookmarks have changed (generic)
  void notifyBookmarksChanged() {
    notifyListeners();
  }
}

/// Global instance for easy access
final bookmarkChangeNotifier = BookmarkChangeNotifier();
