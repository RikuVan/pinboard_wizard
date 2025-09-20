import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/add_bookmark_dialog.dart';
import 'package:pinboard_wizard/src/pages/bookmarks/state/bookmarks_cubit.dart';
import 'package:pinboard_wizard/src/pinboard/pinboard_service.dart';
import 'package:pinboard_wizard/src/service_locator.dart';
import 'package:pinboard_wizard/src/common/state/bookmark_change_notifier.dart';
import 'package:pinboard_wizard/src/common/widgets/dialogs.dart';

// Intent classes for keyboard shortcuts
class NewBookmarkIntent extends Intent {
  const NewBookmarkIntent();
}

class NavigateToPinnedIntent extends Intent {
  const NavigateToPinnedIntent();
}

class NavigateToBookmarksIntent extends Intent {
  const NavigateToBookmarksIntent();
}

class NavigateToNotesIntent extends Intent {
  const NavigateToNotesIntent();
}

class NavigateToSettingsIntent extends Intent {
  const NavigateToSettingsIntent();
}

class RefreshPageIntent extends Intent {
  const RefreshPageIntent();
}

// Global function to show the add bookmark dialog
Future<void> showAddBookmarkDialog(BuildContext context) async {
  if (!context.mounted) return;

  final result = await showMacosSheet<Map<String, dynamic>>(
    context: context,
    builder: (_) => const AddBookmarkDialog(),
  );

  if (result != null && context.mounted) {
    final success = await _addBookmark(context, result);
    if (!success && context.mounted) {
      // Show error dialog if bookmark creation failed
      await CommonDialogs.showServiceError(context, 'save bookmark');
    }
  }
}

// Helper function to add a bookmark using the cubit
Future<bool> _addBookmark(
  BuildContext context,
  Map<String, dynamic> bookmarkData,
) async {
  try {
    final bookmarksCubit = BookmarksCubit(
      pinboardService: locator.get<PinboardService>(),
    );

    await bookmarksCubit.addBookmark(
      url: bookmarkData['url'] as String,
      title: bookmarkData['title'] as String,
      description: bookmarkData['description'] as String?,
      tags: bookmarkData['tags'] as List<String>?,
      shared: bookmarkData['shared'] as bool,
      toRead: bookmarkData['toRead'] as bool,
      replace: bookmarkData['replace'] as bool,
    );

    // Close the cubit to clean up resources
    bookmarksCubit.close();

    // Notify that a bookmark was added so other parts of the app can refresh
    bookmarkChangeNotifier.notifyBookmarkAdded(bookmarkData['url'] as String);

    return true;
  } catch (e) {
    return false;
  }
}

// Keyboard shortcuts widget wrapper
class KeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onNavigateToPinned;
  final VoidCallback? onNavigateToBookmarks;
  final VoidCallback? onNavigateToNotes;
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onRefreshPage;

  const KeyboardShortcuts({
    super.key,
    required this.child,
    this.onNavigateToPinned,
    this.onNavigateToBookmarks,
    this.onNavigateToNotes,
    this.onNavigateToSettings,
    this.onRefreshPage,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // Define ⌘+B for new bookmark
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyB):
            const NewBookmarkIntent(),
        // Navigation shortcuts
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit1):
            const NavigateToPinnedIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit2):
            const NavigateToBookmarksIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit3):
            const NavigateToNotesIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit4):
            const NavigateToSettingsIntent(),
        // Refresh shortcut
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyR):
            const RefreshPageIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewBookmarkIntent: CallbackAction<NewBookmarkIntent>(
            onInvoke: (intent) {
              showAddBookmarkDialog(context);
              return null;
            },
          ),
          NavigateToPinnedIntent: CallbackAction<NavigateToPinnedIntent>(
            onInvoke: (intent) {
              onNavigateToPinned?.call();
              return null;
            },
          ),
          NavigateToBookmarksIntent: CallbackAction<NavigateToBookmarksIntent>(
            onInvoke: (intent) {
              onNavigateToBookmarks?.call();
              return null;
            },
          ),
          NavigateToNotesIntent: CallbackAction<NavigateToNotesIntent>(
            onInvoke: (intent) {
              onNavigateToNotes?.call();
              return null;
            },
          ),
          NavigateToSettingsIntent: CallbackAction<NavigateToSettingsIntent>(
            onInvoke: (intent) {
              onNavigateToSettings?.call();
              return null;
            },
          ),
          RefreshPageIntent: CallbackAction<RefreshPageIntent>(
            onInvoke: (intent) {
              onRefreshPage?.call();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, canRequestFocus: true, child: child),
      ),
    );
  }
}
