# Bug Fix: New Notes Showing Conflict Error After Sync

## Issue Description

When users created a new note and immediately clicked sync, two problems occurred:

1. **Original Bug (Fixed):** The note would disappear from the app with "File not found" errors
2. **Follow-up Issue (Fixed):** The note would sync successfully but show a red conflict triangle permanently

The logs showed:

```
flutter:   ⚠️ Delete conflict: test.md
flutter:   📤 Pushing note: test.md
flutter:   ✅ Successfully pushed: test.md
```

But the note still appeared with a conflict indicator in the UI.

## Root Causes

### Bug #1: Files Written to Wrong Location

The bug was in `github_notes_cubit.dart` in three methods:

1. `createNote()` - Creating new notes
2. `saveNote()` - Saving edited notes
3. `resolveConflictKeepYours()` - Resolving conflicts

These methods were passing **relative paths** (e.g., `"test.md"`) directly to `fileService.writeFile()`, but the `FileService` expects **absolute local filesystem paths**.

### Bug #2: New Notes Marked as Conflicts

The sync engine's `_handleRemoteDeletions()` method ran during the **pull phase** and incorrectly identified new notes (that hadn't been pushed yet) as "deleted remotely", marking them as conflicts.

### Bug #3: Conflict Flag Not Cleared After Successful Sync

The `updateNoteAfterSync()` method cleared the `isDirty` flag and updated the SHA, but didn't clear the `isConflict` flag, so notes remained marked as conflicts even after successful sync.

### What Was Happening

1. **Note Creation:**

   ```dart
   // WRONG - writes to CWD/test.md (not in app documents directory)
   await fileService.writeFile("test.md", content);
   ```

   - File was written to the current working directory, not the app's documents directory
   - Database entry was created with `path: "test.md"` and `isDirty: true`

2. **Sync Operation:**
   - **Pull phase:** Remote has no "test.md" yet, local DB has "test.md"
     - Sync engine sees this as a delete conflict (local has changes, remote deleted)
     - Marks note as conflict
   - **Push phase:** Tries to push "test.md"
     - Calls `fileService.readFile(getLocalPath("test.md"))`
     - Looks in `/Users/.../Documents/test.md` (correct location)
     - File doesn't exist there (it was written to wrong location)
     - Push fails with "File not found"
     - Cleanup removes orphaned note from database

3. **Result:** Note disappears from the UI

## The Fixes

### Fix #1: Use Correct File Paths

Use `fileService.getLocalPath()` to convert repository paths to local filesystem paths before reading/writing:

### Before:

```dart
// createNote()
await fileService.writeFile(path, content);

// saveNote()
await fileService.writeFile(note.path, content);

// resolveConflictKeepYours()
final conflictContent = await fileService.readFile(conflictNote.path);
await fileService.writeFile(originalNote.path, conflictContent);
```

### After:

```dart
// createNote()
final localPath = fileService.getLocalPath(path);
await fileService.writeFile(localPath, content);

// saveNote()
final localPath = fileService.getLocalPath(note.path);
await fileService.writeFile(localPath, content);

// resolveConflictKeepYours()
final conflictLocalPath = fileService.getLocalPath(conflictNote.path);
final conflictContent = await fileService.readFile(conflictLocalPath);
final originalLocalPath = fileService.getLocalPath(originalNote.path);
await fileService.writeFile(originalLocalPath, conflictContent);
```

### Fix #2: Skip New Notes in Remote Deletion Check

Added logic to `_handleRemoteDeletions()` to distinguish between:

- **New notes** (never synced, `lastKnownSha == null`) → Skip, will be pushed later
- **Deleted notes** (previously synced, `lastKnownSha != null`) → Mark as conflict if dirty

```dart
// In note_sync_engine.dart
if (!remotePaths.contains(localNote.path)) {
  // Check if this is a new note (never synced) or a deleted note
  if (localNote.lastKnownSha == null) {
    // This is a new note that hasn't been pushed yet - skip it
    debugPrint('  📝 New note (not yet pushed): ${localNote.path}');
    continue;
  }

  if (localNote.isDirty) {
    // Local has changes, remote deleted - this is a conflict
    debugPrint('  ⚠️ Delete conflict: ${localNote.path}');
    await database.markNoteConflict(localNote.id, isConflict: true);
  }
}
```

### Fix #3: Clear Conflict Flag After Successful Sync

Updated `updateNoteAfterSync()` to clear both `isDirty` and `isConflict`:

```dart
// In notes_database.dart
Future<void> updateNoteAfterSync(String id, String newSha) async {
  await (update(notes)..where((n) => n.id.equals(id))).write(
    NotesCompanion(
      lastKnownSha: Value(newSha),
      isDirty: const Value(false),
      isConflict: const Value(false),  // NEW: Clear conflict flag
      updatedAt: Value(DateTime.now()),
    ),
  );
}
```

## Why These Fixes Work

### `getLocalPath()` Explanation

The `FileService.getLocalPath()` method:

- Takes a repository path like `"test.md"` or `"notes/test.md"`
- Returns the full local filesystem path: `/Users/.../Documents/test.md`
- Ensures files are stored in the app's documents directory
- Uses only the basename (filename), keeping local storage flat

Example:

```dart
// Input: "test.md" or "notes/test.md"
// Output: "/Users/.../Library/Containers/.../Documents/test.md"
```

### `lastKnownSha` as Sync Indicator

- `null` or empty → Note has never been synced to GitHub (new note)
- Has value → Note exists on GitHub, SHA tracks the version

This allows the sync engine to distinguish "not yet uploaded" from "deleted on remote".

## Testing the Fixes

1. Create a new note with title "Test Note" and some content
2. Save the note
3. Click the sync button
4. Verify:
   - ✅ Note remains visible in the notes list
   - ✅ Note is successfully pushed to GitHub
   - ✅ No "File not found" errors in logs
   - ✅ No orphaned note cleanup messages
   - ✅ No red conflict triangle next to the note
   - ✅ Logs show `📝 New note (not yet pushed)` instead of `⚠️ Delete conflict`

## Files Modified

1. **`lib/src/pages/notes/state/github_notes_cubit.dart`**
   - `createNote()` method - Use `getLocalPath()` before writing
   - `saveNote()` method - Use `getLocalPath()` before writing
   - `resolveConflictKeepYours()` method - Use `getLocalPath()` for reading and writing

2. **`lib/src/notes/services/note_sync_engine.dart`**
   - `_handleRemoteDeletions()` method - Skip new notes (no `lastKnownSha`)

3. **`lib/src/database/notes_database.dart`**
   - `updateNoteAfterSync()` method - Clear `isConflict` flag

4. **`test/database/notes_database_test.dart`**
   - Updated test to verify `isConflict` is cleared after sync

## Related Code

The sync engine (`note_sync_engine.dart`) was already using `getLocalPath()` correctly:

```dart
// This was correct all along
final localPath = fileService.getLocalPath(remoteFile.path);
await fileService.writeFile(localPath, content);
```

The bug was isolated to the cubit layer, which handles user-initiated note creation and editing.

## Prevention

Going forward, always use `getLocalPath()` when working with file paths:

```dart
// ✅ CORRECT
final localPath = fileService.getLocalPath(note.path);
await fileService.writeFile(localPath, content);
await fileService.readFile(localPath);

// ❌ WRONG
await fileService.writeFile(note.path, content);
await fileService.readFile(note.path);
```

## Impact

Before these fixes:

- ❌ New notes disappeared after sync
- ❌ Notes showed permanent conflict indicators
- ❌ Confusing user experience with false errors

After these fixes:

- ✅ New notes sync correctly to GitHub
- ✅ No false conflict indicators
- ✅ Clean, reliable sync workflow
- ✅ Proper distinction between new notes and actual conflicts

## Status

✅ **All Issues Fixed** - New notes now:

1. Save to the correct local directory
2. Sync successfully to GitHub without conflicts
3. Clear conflict flags after successful sync
4. Provide accurate status indicators in the UI
