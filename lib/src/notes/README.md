# Notes Sync Engine - Developer Guide

## Overview

This directory contains the implementation of the GitHub-backed notes sync engine for Pinboard Wizard. The system allows users to edit markdown notes locally and sync them with a private GitHub repository.

## Architecture

```
┌─────────────────────────────────────────┐
│  UI Layer (Future Phase 5)              │
├─────────────────────────────────────────┤
│  NoteSyncEngine (Orchestration)         │
│  ├─ Pull (Download from GitHub)         │
│  ├─ Push (Upload to GitHub)             │
│  └─ Conflict Detection & Handling       │
├─────────────────────────────────────────┤
│  Supporting Services                    │
│  ├─ FileService (Local I/O)             │
│  ├─ NetworkService (Connectivity)       │
│  └─ NoteFilenameService (Naming)        │
├─────────────────────────────────────────┤
│  NotesDatabase (Drift/SQLite)           │
│  ├─ Notes table (Metadata)              │
│  └─ notes_fts (Full-text search)        │
├─────────────────────────────────────────┤
│  GitHubClient (API Wrapper)             │
│  └─ GitHub REST API v3                  │
└─────────────────────────────────────────┘
```

## Directory Structure

```
lib/src/notes/
├── models/
│   └── sync_result.dart          # Sync operation results
└── services/
    ├── file_service.dart         # Local file system operations
    ├── network_service.dart      # Connectivity checking
    ├── note_filename_service.dart # Safe filename generation
    └── note_sync_engine.dart     # Core sync orchestration

lib/src/database/
└── notes_database.dart           # Drift database with FTS5 search

lib/src/github/
├── github_client.dart            # GitHub REST API wrapper
├── github_auth_service.dart      # Token management
└── models/
    └── github_notes_config.dart  # Repository configuration
```

## Key Concepts

### 1. Source of Truth

- **GitHub Repository:** The authoritative source for note content
- **Local Files:** Working copies stored in app documents directory
- **Drift Database:** Metadata index for search and sync state tracking

### 2. Sync Flow

**Pull (Download):**
1. Check network connectivity
2. Fetch file list from GitHub via Trees API
3. For each remote file:
   - New file → Download and insert
   - Unchanged (SHA match) → Skip
   - Changed + local clean → Update local
   - Changed + local dirty → **CONFLICT**
4. Handle remote deletions

**Push (Upload):**
1. Get dirty notes from database
2. For each dirty note:
   - No SHA → Create on GitHub
   - Has SHA → Update with conflict detection
3. Handle notes marked for deletion
4. Update database with new SHAs

### 3. Conflict Handling

**When a conflict is detected:**
1. Remote file is downloaded to `[name]-conflict-[timestamp].md`
2. Both notes are marked with `isConflict: true`
3. User manually resolves by:
   - Choosing one version
   - Merging content manually
   - Deleting the conflict file

**Zero data loss:** Both versions are preserved.

### 4. Offline Support

- Notes can be edited offline
- `isDirty` flag tracks local changes
- Sync automatically retries when online
- Graceful degradation (no errors when offline)

## Usage Examples

### Basic Sync

```dart
import 'package:pinboard_wizard/src/service_locator.dart';

// Get sync engine from service locator
final syncEngine = locator.get<NoteSyncEngine>();

// Perform full sync (pull then push)
final result = await syncEngine.sync();

// Handle results
if (result.isFullSuccess) {
  showToast('✅ All notes synced');
} else if (result.conflicts.isNotEmpty) {
  showConflictDialog(result.conflicts);
} else if (!result.isOnline) {
  showToast('📵 Offline - changes saved locally');
}
```

### Pull Only

```dart
// Download updates without uploading local changes
final result = await syncEngine.pull();
```

### Push Only

```dart
// Upload local changes without downloading first
// (Not recommended - may cause conflicts)
final result = await syncEngine.push();
```

### Creating a New Note

```dart
final db = locator.get<NotesDatabase>();
final fileService = locator.get<FileService>();
final filenameService = locator.get<NoteFilenameService>();

// Generate safe filename
final filename = filenameService.generateFilename('My Flutter Tips');
// Returns: my-flutter-tips-1234567890.md

// Create local file
final repoPath = 'notes/$filename';
final localPath = fileService.getLocalPath(repoPath);
await fileService.writeFile(localPath, '# My Flutter Tips\n\nContent here...');

// Insert into database (marked as dirty)
await db.insertNote(
  NotesCompanion.insert(
    id: Uuid().v4(),
    path: repoPath,
    title: Value('My Flutter Tips'),
    isDirty: const Value(true), // Will be uploaded on next sync
  ),
);

// Sync to upload to GitHub
await syncEngine.sync();
```

### Editing an Existing Note

```dart
final db = locator.get<NotesDatabase>();
final fileService = locator.get<FileService>();

// Get note from database
final note = await db.getNoteByPath('notes/my-note.md');

// Update local file
final localPath = fileService.getLocalPath(note.path);
final content = await fileService.readFile(localPath);
final updatedContent = content + '\n\nNew paragraph';
await fileService.writeFile(localPath, updatedContent);

// Mark as dirty in database
await db.markNoteDirty(note.id, isDirty: true);

// Sync to upload changes
await syncEngine.sync();
```

### Searching Notes

```dart
final db = locator.get<NotesDatabase>();

// Full-text search using FTS5
final results = await db.searchNotes('flutter widgets');

// Results are ranked by relevance, limited to 50
for (final note in results) {
  print('${note.title}: ${note.contentPreview}');
}
```

### Handling Conflicts

```dart
final result = await syncEngine.sync();

if (result.conflicts.isNotEmpty) {
  for (final note in result.conflicts) {
    print('⚠️ Conflict: ${note.path}');

    // Find the conflict file
    final conflictNote = await db.getAllNotes()
        .then((notes) => notes.firstWhere(
          (n) => n.path.contains('conflict') && n.path.contains(note.id),
        ));

    // User needs to manually resolve
    // - Compare note.path vs conflictNote.path
    // - Let user choose or merge
    // - Delete the unwanted version
    // - Mark resolved note as dirty and sync
  }
}
```

## Database Schema

### Notes Table

```sql
CREATE TABLE notes (
  id TEXT PRIMARY KEY,              -- UUID v4
  path TEXT UNIQUE NOT NULL,        -- "notes/my-note.md"
  title TEXT,                       -- Parsed from H1 or filename
  last_known_sha TEXT,              -- GitHub SHA for conflict detection
  is_dirty BOOLEAN DEFAULT 0,       -- Has local edits not synced
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  content_preview TEXT,             -- First 300 chars
  content_length INTEGER DEFAULT 0,
  is_conflict BOOLEAN DEFAULT 0,    -- Is a conflict file
  marked_for_deletion BOOLEAN DEFAULT 0
);
```

### FTS5 Virtual Table

```sql
CREATE VIRTUAL TABLE notes_fts USING fts5(
  title,
  content,
  content='notes',
  content_rowid='rowid'
);
```

## Error Handling

### Sync Failure Types

```dart
enum SyncFailureType {
  network,      // Timeout, DNS failure → Retryable
  conflict,     // SHA mismatch → Requires user action
  auth,         // 401/403 → Update token in settings
  rateLimit,    // 429 → Wait and retry
  validation,   // 422 → Fix content
  unknown,      // Unexpected error
}
```

### Retry Logic

```dart
final result = await syncEngine.sync();

// Automatic retry for transient failures
final retryableFailures = result.failed.where((f) => f.isRetryable);
if (retryableFailures.isNotEmpty) {
  // Wait and retry
  await Future.delayed(Duration(seconds: 5));
  await syncEngine.sync();
}

// Non-retryable failures require user action
final nonRetryable = result.failed.where((f) => !f.isRetryable);
for (final failure in nonRetryable) {
  showError('${failure.note.title}: ${failure.userMessage}');
}
```

## Testing

All components have comprehensive tests:

```bash
# Run all notes tests
fvm flutter test test/notes/

# Run specific service tests
fvm flutter test test/notes/services/note_sync_engine_test.dart
fvm flutter test test/notes/services/file_service_test.dart
fvm flutter test test/notes/models/sync_result_test.dart
```

## Configuration

GitHub credentials are managed by `GitHubAuthService`:

```dart
final authService = locator.get<GitHubAuthService>();

// Save credentials (done in settings UI)
await authService.saveCredentials(
  config: GitHubNotesConfig(
    owner: 'username',
    repo: 'personal-notes',
    branch: 'main',
    notesPath: 'notes/',
  ),
  token: 'ghp_xxxxxxxxxxxxx',
);

// Check authentication status
final isConfigured = authService.isAuthenticated;
```

## Performance Considerations

1. **Trees API:** Fetches all file metadata in one request (efficient)
2. **SHA Caching:** Avoids re-downloading unchanged files
3. **FTS5 Search:** Fast full-text search even with 1000+ notes
4. **Lazy Loading:** GitHubClient created only when needed
5. **Partial Sync:** Individual failures don't block other notes

## Limitations & Future Work

**Current Limitations:**
- No automatic merge for conflicts
- No background sync (manual trigger only)
- No progress callbacks during sync
- No delta sync (checks all files)

**Planned Enhancements (Phases 5-6):**
- Notes UI with list/editor/search
- Conflict resolution UI
- Background sync timer
- Sync progress notifications
- Migration from old notes system

## Debugging

Enable debug logging:

```dart
import 'package:flutter/foundation.dart';

// Sync engine prints debug logs via debugPrint()
// They appear in console when running in debug mode
```

Look for these log prefixes:
- `🔄` - Sync operations
- `⬇️` - Pull/download
- `⬆️` - Push/upload
- `⚠️` - Conflicts
- `🗑️` - Deletions
- `✅` - Success
- `❌` - Errors

## Related Documentation

- `docs/NOTES_REDESIGN.md` - Full architecture and design decisions
- `docs/NOTES_IMPLEMENTATION_PROGRESS.md` - Implementation status
- `docs/SYNC_ENGINE_COMPLETION.md` - Completion summary
- `lib/src/database/MIGRATIONS.md` - Database migration guide

## Support

For questions or issues:
1. Check test files for usage examples
2. Review design docs in `docs/`
3. Examine debug logs during sync
4. Consult GitHub API documentation for rate limits/errors
