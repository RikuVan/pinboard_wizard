# Keyboard Shortcuts

This document describes the keyboard shortcuts available in Pinboard Wizard.

## Available Shortcuts

### File Operations

- **⌘+B** - New Bookmark
  - Opens the Add Bookmark dialog
  - Works from anywhere in the application
  - Also available via File > New Bookmark in the menu bar
  - Automatically saves the bookmark when the dialog is closed with data

### Navigation

- **⌘+1** - Switch to Pinned page
- **⌘+2** - Switch to Bookmarks page
- **⌘+3** - Switch to Notes page
- **⌘+4** - Switch to Settings page
- **⌘+R** - Refresh current page
  - Currently refreshes the Bookmarks page when active
  - Future updates may add refresh functionality to other pages

## Implementation Details

The keyboard shortcuts system is implemented using Flutter's `Shortcuts` and `Actions` widgets, which provide a robust way to handle keyboard input across the entire application.

### Architecture

- **Intent Classes** (`lib/src/common/widgets/keyboard_shortcuts.dart`)
  - `NewBookmarkIntent` - Intent for creating a new bookmark

- **KeyboardShortcuts Widget** - Wraps the main application content to provide global shortcut handling

- **Menu Integration** - Keyboard shortcuts are also exposed in the macOS menu bar with their corresponding key combinations displayed

### Adding New Shortcuts

To add a new keyboard shortcut:

1. Create a new Intent class in `lib/src/common/widgets/keyboard_shortcuts.dart`
2. Add the shortcut mapping to the `Shortcuts` widget
3. Add the corresponding action to the `Actions` widget
4. If the action needs to interact with the main app state, add a callback parameter to `KeyboardShortcuts`
5. Optionally add a menu item in `main.dart` for discoverability

Example:

```dart
// 1. Define the intent
class MyNewIntent extends Intent {
  const MyNewIntent();
}

// 2. Add to shortcuts map
LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyX): const MyNewIntent(),

// 3. Add to actions map
MyNewIntent: CallbackAction<MyNewIntent>(
  onInvoke: (intent) {
    // Handle the action or call a callback
    onMyAction?.call();
    return null;
  },
),

// 4. Add callback parameter to KeyboardShortcuts widget
final VoidCallback? onMyAction;
```

## Platform Considerations

- Uses `LogicalKeyboardKey.meta` for the ⌘ (Command) key on macOS
- The `Focus` widget with `autofocus: true` ensures shortcuts work immediately when the app launches
- Integrates with macOS menu system to show keyboard shortcuts in menus
- Uses `FocusScope` to maintain focus after modal dialogs close

## Implementation Details

### Bookmark Saving

The keyboard shortcut system creates its own `BookmarksCubit` instance to save bookmarks independently of the BookmarksPage. This ensures that:

- Bookmarks can be saved from anywhere in the app
- The shortcut doesn't depend on being on the Bookmarks page
- Resources are properly cleaned up after saving

### Focus Management

To ensure shortcuts continue working after modal dialogs:

- The main app is wrapped in a `FocusScope` with `autofocus: true`
- The `KeyboardShortcuts` widget uses `Focus` with `canRequestFocus: true`
- Context validation is performed before showing dialogs

### Troubleshooting

If keyboard shortcuts stop working:

1. Check the debug console for messages starting with "🔥 Keyboard shortcut:" or "🔥 Menu item:"
2. Ensure the app has focus after closing dialogs
3. Try clicking somewhere in the app to restore focus
4. Check if the shortcut is being triggered but failing to save (error messages will appear in debug output)

### Menu Item Integration

The File > New Bookmark menu item uses a global `NavigatorKey` to access the correct navigation context, as menu callbacks run outside the normal widget tree context. This ensures that both the keyboard shortcut and menu item work consistently.

Navigation shortcuts (⌘+1-4) use callback functions passed from the main app to update the page index state. The View menu displays these shortcuts for discoverability.

### Bookmark Change Notification System

The keyboard shortcuts and menu items use a global notification system to keep the BookmarksPage synchronized when bookmarks are added from outside the normal flow:

- `BookmarkChangeNotifier` (`lib/src/common/state/bookmark_change_notifier.dart`) - A singleton that notifies listeners when bookmarks change
- The BookmarksPage subscribes to these notifications and automatically refreshes its list

This ensures that when you create a bookmark via keyboard shortcut or menu item while viewing the bookmarks page, the new bookmark appears immediately without manual refresh.

### Common Dialogs System

Error and confirmation dialogs throughout the app use a centralized system:

- `CommonDialogs` (`lib/src/common/widgets/dialogs.dart`) - Static methods for showing consistent dialogs
- Provides `showError()`, `showConfirmation()`, `showDeleteConfirmation()`, and other common dialog types
- Eliminates duplicate dialog code and ensures consistent UI/UX
