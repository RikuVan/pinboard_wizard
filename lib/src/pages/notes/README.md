# GitHub Notes UI - Developer Guide

## Overview

The GitHub Notes UI is a complete, offline-first notes application with markdown editing, full-text search, and automatic synchronization to GitHub. It replaces the old Pinboard notes implementation with a modern, feature-rich interface.

---

## Architecture

### State Management

The UI uses **BLoC pattern** with `GitHubNotesCubit` managing all state:

```dart
GitHubNotesCubit(
  database: NotesDatabase(),      // Local SQLite storage
  syncEngine: NoteSyncEngine(),   // Sync orchestration
  fileService: FileService(),     // File system operations
  networkService: NetworkService(), // Online/offline detection
)
```

### Data Flow

```
User Action → Cubit → Service Layer → Database/FileSystem/GitHub
                  ↓
            State Update
                  ↓
            UI Rebuild
```

---

## Components

### Main Page

**`GitHubNotesPage`** - The primary UI container:
- Split view: Note list (35%) | Detail view (65%)
- Toolbar: Create, Sync, Online status, Search
- Footer: Note count, sync status, last sync time

### State Management

**`GitHubNotesCubit`** - Manages all business logic:
- `loadNotes()` - Load from database
- `search(String query)` - FTS5 full-text search
- `selectNote(Note note)` - Load note content
- `createNote()` - Create new note
- `saveNote(String content)` - Save changes
- `deleteNote(String id)` - Delete note
- `sync()` - Manual sync trigger
- `resolveConflict*()` - Conflict resolution

**`GitHubNotesState`** - Immutable state model:
```dart
class GitHubNotesState {
  final GitHubNotesStatus status;
  final List<Note> notes;           // All notes
  final List<Note> filteredNotes;   // Search results
  final Note? selectedNote;
  final String? noteContent;
  final bool isSyncing;
  final bool isOnline;
  final SyncResult? syncResult;
  // ... more fields
}
```

### Widgets

1. **`MarkdownEditor`** - Full-featured markdown editor
   - Toolbar: Bold, Italic, Headings, Links, Lists, Code
   - Auto-growing text area
   - Save/Cancel with change tracking

2. **`GitHubNoteTile`** - List item for notes
   - Title, preview, timestamp
   - Sync status icon (✓, ⏰, ⚠️, 🗑️)
   - Selection highlighting

3. **`ConflictResolutionDialog`** - Conflict handling
   - Side-by-side file comparison
   - Three resolution options
   - Confirmation dialogs

4. **`NewNoteDialog`** - Note creation
   - Title input (required)
   - Content input (optional)
   - Validation

---

## Usage

### Basic Integration

```dart
import 'package:pinboard_wizard/src/pages/notes/github_notes_page.dart';
import 'package:pinboard_wizard/src/service_locator.dart';

// In your navigation:
MaterialPageRoute(
  builder: (_) => const GitHubNotesPage(),
)
```

The page handles all setup internally using the service locator.

### Service Locator Setup

All required services should be registered:

```dart
locator
  ..registerLazySingleton<NotesDatabase>(() => NotesDatabase())
  ..registerLazySingleton<NetworkService>(() => NetworkService())
  ..registerLazySingleton<NoteFilenameService>(() => NoteFilenameService())
  ..registerLazySingleton<FileService>(() => FileService(notesDir))
  ..registerFactoryAsync<GitHubClient>(() async {
    // Create GitHub client with credentials
  })
  ..registerFactory<NoteSyncEngine>(() => NoteSyncEngine(/* deps */));
```

### Manual Cubit Usage

For custom UI implementations:

```dart
final cubit = GitHubNotesCubit(
  database: locator.get<NotesDatabase>(),
  syncEngine: locator.get<NoteSyncEngine>(),
  fileService: locator.get<FileService>(),
  networkService: locator.get<NetworkService>(),
);

// Initialize
await cubit.initialize();

// Listen to state
cubit.stream.listen((state) {
  if (state.hasError) {
    print('Error: ${state.errorMessage}');
  }
  if (state.syncResult != null) {
    print('Sync: ${state.syncResult!.userMessage}');
  }
});

// Operations
await cubit.search('flutter');
await cubit.createNote(title: 'My Note', content: '# Hello');
await cubit.sync();

// Clean up
await cubit.close();
```

---

## Features

### Search

Full-text search powered by SQLite FTS5:

```dart
// Real-time search
cubit.search('my search query');

// Clear search
cubit.clearSearch();

// Access results
final results = state.displayNotes; // filtered or all notes
```

Search matches across:
- Note titles
- Full note content
- Results ranked by relevance

### Sync

Manual and automatic synchronization:

```dart
// Manual sync
await cubit.sync();

// Auto-sync runs every 5 minutes when online
// Controlled by internal timer in cubit
```

Sync flow:
1. **Pull**: Download changed files from GitHub
2. **Push**: Upload dirty (modified) notes
3. **Conflicts**: Detect and create conflict files
4. **Result**: Update UI with success/failure/conflicts

### Conflict Resolution

Conflicts occur when both local and remote versions changed:

```dart
// Detect conflicts
if (state.hasConflicts) {
  final conflicts = state.conflictNotes;
}

// Resolution options:
await cubit.resolveConflictKeepOriginal(conflictNote);
await cubit.resolveConflictKeepYours(originalNote, conflictNote);
// Or: User manually merges and deletes conflict file
```

Conflict file naming:
```
Original: flutter-state.md
Conflict: flutter-state.conflict-macbook-2024-12-28T14-30-45Z.md
```

### Offline Support

Works fully offline, queues changes:

```dart
// Check online status
if (state.isOnline) {
  // Connected
} else {
  // Offline - changes queued
}

// Dirty notes count
final pending = state.dirtyNotesCount;
```

---

## State Lifecycle

### Initialization

```dart
// On page load
cubit.initialize()
  ├── loadNotes()           // Load from database
  └── _startAutoSync()      // Start 5-minute timer
```

### User Actions

```dart
// Create note
cubit.createNote(title: 'Title', content: 'Content')
  ├── Generate filename
  ├── Write to file system
  ├── Insert into database (marked dirty)
  └── Emit updated state

// Edit note
cubit.selectNote(note)      // Load content
cubit.startEditing()        // Enable editor
cubit.saveNote(content)     // Write file, mark dirty
  └── Reload notes

// Delete note
cubit.deleteNote(noteId)
  ├── Mark for deletion in DB
  ├── Delete local file
  └── Will be deleted from GitHub on next sync
```

### Sync Cycle

```dart
cubit.sync()
  ├── Check network
  ├── Pull from GitHub
  │   ├── Fetch remote file list
  │   ├── Download changed files
  │   └── Update database
  ├── Push dirty notes
  │   ├── Upload each to GitHub
  │   ├── Handle conflicts
  │   └── Mark as clean
  └── Emit SyncResult
```

---

## Error Handling

### User-Facing Errors

Errors are surfaced in state:

```dart
if (state.hasError) {
  showDialog(
    message: state.errorMessage,
    actions: [
      'Retry' -> cubit.loadNotes(),
      'Cancel' -> Navigator.pop(),
    ],
  );
}
```

### Sync Errors

Partial failures are supported:

```dart
final result = state.syncResult;
if (result?.isPartialSuccess ?? false) {
  // Some notes synced, some failed
  print('Succeeded: ${result.succeeded.length}');
  print('Failed: ${result.failed.length}');
  print('Conflicts: ${result.conflicts.length}');
}
```

Error types:
- `SyncFailureType.network` - Retryable network issues
- `SyncFailureType.conflict` - SHA mismatch, needs resolution
- `SyncFailureType.auth` - Invalid credentials
- `SyncFailureType.rateLimit` - GitHub API rate limit
- `SyncFailureType.validation` - Invalid data
- `SyncFailureType.unknown` - Other errors

---

## Customization

### UI Theming

The UI uses the Liquid Glass facade (`lib/src/ui/`) and respects system theme:

```dart
final isDark = context.isDarkMode;
```

All colors, fonts, and spacing use theme values.

### Auto-Sync Frequency

Currently hardcoded to 5 minutes. To change:

```dart
// In GitHubNotesCubit._startAutoSync()
_autoSyncTimer = Timer.periodic(
  const Duration(minutes: 5), // Change this
  (_) async { /* ... */ },
);
```

### Split View Ratio

Adjust in `GitHubNotesPage`:

```dart
ResizableSplitView(
  initialRatio: 0.35,  // 35% list, 65% detail
  minLeftWidth: 250,
  minRightWidth: 400,
  // ...
)
```

---

## Testing

### Unit Tests

Test cubit state transitions:

```dart
test('search updates filtered notes', () async {
  final cubit = GitHubNotesCubit(/* mocked deps */);

  await cubit.search('flutter');

  expect(cubit.state.isSearching, true);
  expect(cubit.state.searchQuery, 'flutter');
  expect(cubit.state.filteredNotes.isNotEmpty, true);
});
```

### Integration Tests

Test full workflows:

```dart
testWidgets('create, edit, sync workflow', (tester) async {
  await tester.pumpWidget(const GitHubNotesPage());

  // Create note
  await tester.tap(find.text('New Note'));
  await tester.enterText(find.byType(TextField), 'Test Note');
  await tester.tap(find.text('Create'));

  // Edit note
  await tester.tap(find.text('Test Note'));
  await tester.tap(find.text('Edit'));
  await tester.enterText(find.byType(MarkdownEditor), 'Content');
  await tester.tap(find.text('Save'));

  // Sync
  await tester.tap(find.text('Sync'));
  await tester.pump();

  // Verify
  expect(find.text('Synced'), findsOneWidget);
});
```

---

## Performance Tips

1. **Lazy Loading**: Content loaded only when note is selected
2. **Search Indexing**: FTS5 index updated only on content change
3. **Debouncing**: Search queries should be debounced in UI
4. **Pagination**: Consider adding for large note collections (>1000)
5. **Caching**: Note list cached in state, file reads on-demand

---

## Migration from Old Notes

To migrate from Pinboard API notes:

```dart
// 1. Fetch old notes
final oldNotes = await pinboardService.getAllNotes();

// 2. Create in new system
for (final oldNote in oldNotes) {
  await cubit.createNote(
    title: oldNote.title ?? 'Untitled',
    content: oldNote.text ?? '',
  );
}

// 3. Sync to GitHub
await cubit.sync();
```

---

## Troubleshooting

### Notes Not Syncing

1. Check GitHub credentials in Settings
2. Verify network connectivity (`state.isOnline`)
3. Check for dirty notes (`state.dirtyNotesCount`)
4. Review sync result (`state.syncResult`)

### Search Not Working

1. Verify FTS5 index is populated (`database.updateFtsIndex()`)
2. Check search query syntax
3. Ensure notes have content

### Conflicts Not Resolving

1. Check conflict file exists in filesystem
2. Verify original note path matches
3. Review database state (`note.isConflict`)

---

## Best Practices

1. **Always Close Cubit**: Call `cubit.close()` in `dispose()`
2. **Handle Offline**: Check `isOnline` before network operations
3. **Validate Input**: Check for empty titles, duplicate paths
4. **Show Feedback**: Use sync results for user notifications
5. **Preserve Data**: Never delete without confirmation

---

## Future Enhancements

Planned for Phase 6:
- [ ] Markdown preview mode
- [ ] Side-by-side conflict diff
- [ ] Note templates
- [ ] Export/import functionality
- [ ] Background sync notifications
- [ ] Token expiry warnings
- [ ] Performance optimizations (pagination, lazy loading)

---

## References

- [Notes Redesign Doc](../../docs/NOTES_REDESIGN.md)
- [Implementation Progress](../../docs/NOTES_IMPLEMENTATION_PROGRESS.md)
- [UI Completion Summary](../../docs/NOTES_UI_COMPLETION.md)
- [Sync Engine Completion](../../docs/SYNC_ENGINE_COMPLETION.md)
