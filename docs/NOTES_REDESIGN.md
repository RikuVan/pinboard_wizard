# Notes Redesign: GitHub-Backed Markdown Notes

## Overview

This document describes the redesigned notes system for Pinboard Wizard. The system transitions from the Pinboard API's basic note storage to a **private GitHub repository** as the backend, enabling:

- **Local editing** with full markdown support
- **Multi-device sync** using GitHub as a version control layer
- **Conflict detection** via SHA-based versioning
- **Offline-first** editing and sync on reconnect
- **Search & indexing** via local Drift database
- **Privacy** through a dedicated private GitHub repository

## Core Design Principles

| Principle | Rationale |
|-----------|-----------|
| **Private GitHub repo is source of truth** | Encrypted at rest, version controlled, portable |
| **Markdown files only** | Human-readable, future-proof, git-friendly |
| **GitHub REST API for sync** | No git client required, simpler implementation |
| **SHA-based versioning** | Detects conflicts without CRDT complexity |
| **Drift for indexing only** | Fast search + metadata, not authoritative |
| **Offline-first editing** | UX never blocked by network |
| **Deterministic conflict handling** | Automatic conflict files, zero data loss |

## Architecture Layers

```
┌─────────────────────────────────────────┐
│  Flutter UI (Editor, List, Search)      │
├─────────────────────────────────────────┤
│  Notes Cubit (State Management)         │
├─────────────────────────────────────────┤
│  Sync Engine (Pull/Push/Conflict)       │
├─────────────────────────────────────────┤
│  GitHub REST Client (API Wrapper)       │
├─────────────────────────────────────────┤
│  Drift Database (Index + Metadata)      │
├─────────────────────────────────────────┤
│  File System (Local Markdown Files)     │
├─────────────────────────────────────────┤
│  Network & GitHub Private Repo          │
└─────────────────────────────────────────┘
```

## Setup Requirements

### Private GitHub Repository

1. Create a private repository on GitHub (e.g., `personal-notes`)
2. Generate a **Personal Access Token (PAT)** with:
   - `repo` scope (full control of private repositories)
   - No expiration recommended for personal use
3. Store token securely in macOS Keychain via `FlutterSecureStorage`
4. Store repository details:
   - Owner (GitHub username)
   - Repository name
   - Branch (default: `main`)
   - Notes folder path (default: `notes/`)

### Configuration Storage

GitHub credentials and config stored in secure storage:

```dart
class GitHubNotesConfig {
  final String owner;           // GitHub username
  final String repo;            // Repository name (e.g., "personal-notes")
  final String branch;          // Branch to sync from (default: "main")
  final String notesPath;       // Repo path to notes folder (default: "notes/")
  final String deviceId;        // Unique device identifier
  final String? patToken;       // Personal Access Token (secure storage)
  final bool isConfigured;      // Is setup complete?
}
```

Store in `FlutterSecureStorage`:
- Key: `github_notes_config`
- Value: JSON with all above fields
- Token stored separately: `github_pat_token`

## Data Model

### Local Drift Table: `notes_metadata`

Stores indexing and sync state, **not** the actual content.

```dart
class Notes extends Table {
  TextColumn get id => text()();
  // UUID, primary key

  TextColumn get path => text().unique()();
  // Repo path: "notes/flutter-state.md"

  TextColumn get title => text().nullable()();
  // Parsed from markdown H1 or filename

  TextColumn get lastKnownSha => text().nullable()();
  // GitHub file SHA at last successful sync
  // CRITICAL: Used to detect conflicts

  BoolColumn get isDirty =>
      boolean().withDefault(const Constant(false))();
  // True if edited locally since last pull

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  // Last local edit time

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  // When note was first discovered

  // Search metadata (not authoritative)
  TextColumn get contentPreview => text().nullable()();
  // First 300 characters for preview

  IntColumn get contentLength => integer().withDefault(const Constant(0))();
  // Cached content length

  BoolColumn get isConflict =>
      boolean().withDefault(const Constant(false))();
  // True if this is a conflict file

  @override
  Set<Column> get primaryKey => {id};
}
```

### Local File Structure

```
<app-documents>/notes/
├── flutter-state.md          (synced markdown files)
├── dart-async.md
├── git-workflow.md
└── .sync-metadata             (optional local cache of last sync)
```

All markdown files are the **source of truth** for content. Drift is cache + index only.

## Sync Flow

### Phase 1: Pull (Always First)

**Precondition:** Check online & GitHub auth valid

**Goal:** Ensure local state matches remote before editing

```
pullFromGitHub():
  1. Verify online
  2. List all markdown files in GitHub repo at <notesPath>
     GET /repos/{owner}/{repo}/contents/{notesPath}?ref={branch}

  3. For each file from GitHub:
     local = db.getNoteByPath(file.path)

     Case 1: New on remote
       if local == null:
         → Download file content
         → Write to local file system
         → Insert in Drift:
           { id, path, lastKnownSha, isDirty=false, updatedAt }

     Case 2: Updated on remote
       else if file.sha != local.lastKnownSha:
         → Download file content
         → Overwrite local file
         → Update Drift:
           { lastKnownSha=file.sha, isDirty=false, updatedAt=now }

     Case 3: No change
       else:
         → Skip (local matches remote)

  4. Deleted on remote?
     → Keep local file (user may have unsaved edits)
     → Mark isDirty=false in Drift
     → Show warning in UI

  5. Rebuild Drift search index

  ✓ Invariant: Local state now matches remote
  ✓ isDirty=false for all non-edited notes
```

**Error Handling:**
- Network unavailable → emit offline state, don't block
- 401/403 (auth invalid) → show setup/auth error, stop sync
- 404 (repo not found) → show config error
- 429 (rate limited) → backoff 60+ seconds
- 5xx or timeout → retry with exponential backoff

**UX:**
- Show "Syncing..." spinner in notes list
- Allow user to continue editing during sync
- Disable push until pull completes
- Show sync status in status bar

### Phase 2: Local Edit

**Goal:** Track changes without immediately syncing

```
onNoteEdited(noteId, newContent):
  1. Write markdown to local file immediately

  2. Update Drift:
     { isDirty=true, updatedAt=now() }

  3. ⚠️ DO NOT change lastKnownSha
     lastKnownSha = remote version at last pull
     (Needed to detect conflicts later)

  4. Debounce auto-save (2 second delay)

  5. Queue for background sync
```

**Auto-Save:**
- Debounce changes for 2 seconds
- Always write to local file first
- Trigger sync after debounce window

### Phase 3: Push (Safe Update with Conflict Detection)

**Precondition:** Online & pull completed

**Goal:** Upload dirty notes safely, detect conflicts early

```
pushDirtyNotes():
  1. Get all notes where isDirty=true
  2. If offline → defer, return

  3. For each dirty note:

     Step A: Fetch remote metadata
     ─────────────────────────────
     remote = github.getFileMetadata(note.path)
     GET /repos/{owner}/{repo}/contents/{note.path}?ref={branch}

     Step B: Compare versions (CONFLICT DETECTION)
     ──────────────────────────────────────────────
     if remote.sha == note.lastKnownSha:
       → Safe to update
       → Proceed to Step C

     else if remote.sha != note.lastKnownSha:
       → CONFLICT: Someone else edited this file
       → Proceed to Conflict Handling (below)

     Step C: Safe update (no conflict)
     ────────────────────────────────
     newSha = github.updateFile(
       path: note.path,
       content: readFile(note.path),
       baseSha: note.lastKnownSha,  ← validation key
       message: "Update note: {title}"
     )

     Update Drift:
       { lastKnownSha=newSha, isDirty=false, updatedAt=now }

     ✓ GitHub rejects if baseSha doesn't match (safety valve)

  4. Return sync result to UI
```

**Error Handling per Note:**
- Transient (5xx, timeout) → retry later, show "⚠️ sync pending" badge
- Conflict (sha mismatch) → create conflict file (see Phase 4)
- Auth error (401/403) → stop, show alert, disable sync
- Validation error (422) → skip, log warning
- Not found (404 file deleted) → skip, remove from Drift

### Phase 4: Conflict Handling

**Trigger:** `remote.sha != note.lastKnownSha` during push phase

**Resolution Strategy (Deterministic, Zero Data Loss):**

```
handleConflict(note):
  1. Read local content

  2. Generate conflict filename:
     original: "flutter-state.md"
     conflict: "flutter-state.conflict-macbook-2025-03-11T14-30-45Z.md"

     Format: <name>.conflict-<deviceId>-<ISO8601>.md

  3. Upload conflict file to GitHub:
     github.createFile(
       path: conflictPath,
       content: readFile(note.path),
       message: "Conflict: sync from {deviceId}"
     )

  4. Mark original as clean but unchanged:
     db.updateNote(
       path: note.path,
       isDirty=false
       ← DO NOT change lastKnownSha
       ← Next pull will fetch remote version
     )

  5. Emit state to UI:
     Show toast: "Conflict on '{title}'. Created '{conflictName}'"
     Both files visible in notes list

  6. On next pull:
     Both original and conflict appear in list
     User can manually merge and delete conflict file
```

**Example Multi-Device Scenario:**

```
Timeline:
─────────

T1: Device A (MacBook)
  Pull: lastKnownSha = abc123
  Edit "flutter-state.md"
  isDirty = true

T2: Device A pushes
  Push → Success
  GitHub SHA now: def456
  Device A: lastKnownSha = def456, isDirty = false

T3: Device B (iPad) (was offline)
  Pull: lastKnownSha = abc123  ← hasn't synced yet
  Edit "flutter-state.md"
  isDirty = true

T4: Device B comes online, pushes
  Fetch remote metadata
  GitHub SHA = def456 (Device A just uploaded)
  Device B lastKnownSha = abc123 (hasn't pulled latest)

  → CONFLICT DETECTED
  → Create "flutter-state.conflict-ipad-2025-03-11T...md"
  → Mark original isDirty = false

T5: Device B pulls
  Download Device A's version (def456) → overwrite local
  Download conflict file
  Show both in list

Result: ✔ Zero data loss
        ✔ Deterministic
        ✔ Clear conflict visibility
        ✔ User can merge manually
```

## Implementation Details

### Required Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  drift: ^2.14.0                      # Local database
  sqlite3_flutter_libs: ^0.5.0        # SQLite support
  http: ^1.1.0                        # Already present
  flutter_secure_storage: ^10.0.0     # Already present
  uuid: ^4.0.0                        # UUID generation
  path: ^1.8.0                        # File path handling
  path_provider: ^2.1.0               # App documents directory
```

### Service Layer: NotesSync

Core sync orchestrator. Implements pull → push → conflict handling.

```dart
class NotesSync {
  final GitHubClient _github;
  final NotesDatabase _db;
  final FileService _fileService;
  final NetworkService _network;
  final String _deviceId;

  /// Main sync orchestrator
  Future<SyncResult> syncNotes() async {
    if (!await _network.isOnline()) {
      return SyncResult.offline();
    }

    try {
      // Always pull first
      await _pullFromGitHub();

      // Then push dirty notes
      await _pushDirtyNotes();

      return SyncResult.success();
    } catch (e) {
      return SyncResult.error(e.toString());
    }
  }

  Future<void> _pullFromGitHub() async { /* ... */ }
  Future<void> _pushDirtyNotes() async { /* ... */ }
  Future<void> _handleConflict(Note note) async { /* ... */ }
}
```

### Service Layer: GitHubClient

Wraps GitHub REST API with retry logic and error handling.

```dart
class GitHubClient {
  final String _token;
  final String _owner;
  final String _repo;
  final String _branch;
  final String _notesPath;

  static const String _baseUrl = 'https://api.github.com';

  /// List files in notes folder with metadata
  Future<List<GitHubFile>> listNotesFiles() async {
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/contents/$_notesPath'
      '?ref=$_branch'
    );

    final response = await withRetry(() => _get(url));
    return _parseFileList(response);
  }

  /// Get single file metadata (SHA, size, etc.)
  Future<GitHubFile> getFileMetadata(String path) async {
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/contents/$path?ref=$_branch'
    );

    final response = await withRetry(() => _get(url));
    return GitHubFile.fromJson(json.decode(response));
  }

  /// Download file content
  Future<String> downloadFile(String path) async {
    final metadata = await getFileMetadata(path);
    return utf8.decode(base64.decode(metadata.content));
  }

  /// Update file with SHA validation
  Future<String> updateFile({
    required String path,
    required String content,
    required String baseSha,
    String message = 'Update note',
  }) async {
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/contents/$path'
    );

    final body = {
      'message': message,
      'content': base64.encode(utf8.encode(content)),
      'sha': baseSha,
      'branch': _branch,
    };

    final response = await withRetry(
      () => _put(url, body),
    );

    final result = json.decode(response);
    return result['commit']['tree']['sha'] as String;
  }

  /// Create new file
  Future<String> createFile({
    required String path,
    required String content,
    String message = 'Create note',
  }) async {
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/contents/$path'
    );

    final body = {
      'message': message,
      'content': base64.encode(utf8.encode(content)),
      'branch': _branch,
    };

    final response = await withRetry(
      () => _put(url, body),
    );

    final result = json.decode(response);
    return result['commit']['tree']['sha'] as String;
  }

  /// Retry wrapper for transient errors
  Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 5,
  }) async {
    Duration delay = const Duration(seconds: 1);
    final maxDelay = const Duration(seconds: 30);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxAttempts) rethrow;

        if (!_isTransient(e)) rethrow;

        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).toInt(),
        ).clamp(delay, maxDelay);
      }
    }

    throw Exception('Sync failed after $maxAttempts attempts');
  }

  bool _isTransient(dynamic error) {
    if (error is HttpException) {
      final statusCode = error.statusCode;
      return statusCode == 502 || statusCode == 503 || statusCode == 504;
    }
    return error is SocketException || error is TimeoutException;
  }
}
```

### State Management: NotesCubit

Orchestrates UI state and sync operations.

```dart
class NotesCubit extends Cubit<NotesState> {
  final NotesSync _sync;
  final NotesDatabase _db;
  Timer? _syncTimer;
  StreamSubscription? _syncSubscription;

  NotesCubit({
    required NotesSync sync,
    required NotesDatabase db,
  })  : _sync = sync,
        _db = db,
        super(const NotesState());

  /// Load all notes and pull from GitHub
  Future<void> loadNotes() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _sync.syncNotes();
      final notes = await _db.getAllNotes();
      emit(state.copyWith(
        notes: notes,
        isLoading: false,
        hasError: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        hasError: true,
        errorMessage: e.toString(),
        isLoading: false,
      ));
    }
  }

  /// Manual refresh (pull + push)
  Future<void> refresh() async {
    await loadNotes();
  }

  /// Edit note and queue for sync
  Future<void> editNote(String noteId, String content) async {
    try {
      // Write to file immediately
      final note = await _db.getNoteById(noteId);
      final filePath = _getLocalFilePath(note.path);
      await _fileService.writeFile(filePath, content);

      // Mark dirty
      await _db.updateNote(noteId, isDirty: true);

      // Debounced sync
      _syncTimer?.cancel();
      _syncTimer = Timer(const Duration(seconds: 2), () {
        _sync.syncNotes();
      });

      emit(state.copyWith(hasPendingSync: true));
    } catch (e) {
      emit(state.copyWith(
        hasError: true,
        errorMessage: 'Failed to edit note: $e',
      ));
    }
  }

  /// Select a note for detail view
  void selectNote(Note note) {
    emit(state.copyWith(selectedNote: note));
  }

  /// Search notes
  Future<void> performSearch(String query) async {
    if (query.isEmpty) {
      emit(state.copyWith(searchResults: [], isSearching: false));
      return;
    }

    emit(state.copyWith(isSearching: true));
    try {
      final results = await _db.searchNotes(query);
      emit(state.copyWith(searchResults: results));
    } catch (e) {
      emit(state.copyWith(hasError: true));
    }
  }

  void clearSearch() {
    emit(state.copyWith(searchResults: [], isSearching: false));
  }

  @override
  Future<void> close() {
    _syncTimer?.cancel();
    _syncSubscription?.cancel();
    return super.close();
  }
}
```

### Drift Database Service

Manages local metadata storage and search.

```dart
@DriftDatabase(tables: [Notes])
class NotesDatabase extends _$NotesDatabase {
  NotesDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  /// Get all notes
  Future<List<Note>> getAllNotes() async {
    return select(notes).get();
  }

  /// Get by path
  Future<Note?> getNoteByPath(String path) async {
    return (select(notes)..where((n) => n.path.equals(path)))
        .getSingleOrNull();
  }

  /// Get by ID
  Future<Note?> getNoteById(String id) async {
    return (select(notes)..where((n) => n.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get dirty notes (need sync)
  Future<List<Note>> getDirtyNotes() async {
    return (select(notes)..where((n) => n.isDirty.equals(true)))
        .get();
  }

  /// Get conflict files
  Future<List<Note>> getConflictNotes() async {
    return (select(notes)..where((n) => n.isConflict.equals(true)))
        .get();
  }

  /// Insert note
  Future<void> insertNote(NotesCompanion note) async {
    await into(notes).insert(note);
  }

  /// Update note
  Future<void> updateNote(
    String id, {
    String? path,
    String? title,
    String? lastKnownSha,
    bool? isDirty,
    String? contentPreview,
    int? contentLength,
  }) async {
    await (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        path: path != null ? Value(path) : const Value.absent(),
        title: title != null ? Value(title) : const Value.absent(),
        lastKnownSha:
            lastKnownSha != null ? Value(lastKnownSha) : const Value.absent(),
        isDirty: isDirty != null ? Value(isDirty) : const Value.absent(),
        contentPreview: contentPreview != null
            ? Value(contentPreview)
            : const Value.absent(),
        contentLength:
            contentLength != null ? Value(contentLength) : const Value.absent(),
      ),
    );
  }

  /// Full text search
  Future<List<Note>> searchNotes(String query) async {
    return (select(notes)
          ..where((n) =>
              n.title.like('%$query%') |
              n.contentPreview.like('%$query%')))
        .get();
  }
}
```

## Offline-First Behavior

**Editing always works, sync is best-effort:**

```
User edits notes:
  ✓ Write to local file immediately
  ✓ Update Drift (isDirty = true)
  ✗ Network not required

User pushes (manually or auto):
  if offline:
    → Queue for sync
    → Show "⚠️ Sync pending" indicator
    → Don't block UI

  if online:
    → Execute pull → push
    → Show result in toast

App resumed:
  → Check if pending sync
  → Execute now if online
  → Show status
```

## Rate Limiting

GitHub REST API: 5,000 requests/hour (60k with enterprise)

**Strategy:**
- Batch file lists (1 request for 30+ files)
- Cache metadata between syncs
- Show user if rate limit hit (show wait time)
- Exponential backoff on 429

**Estimated Usage:**
- Pull 30 files: ~1 API call
- Push 5 files: ~10 calls (1 metadata check + 1 update per file)
- Total: ~20-30 calls per sync
- Sustainable: 100+ syncs per hour without issue

## What This Design Intentionally Avoids

- ❌ CRDTs (overkill for solo user)
- ❌ Real-time collaboration (Pinboard Wizard is single-user)
- ❌ Automatic merge algorithms (conflicts rare, manual merge is clear)
- ❌ Full git client (adds complexity, GitHub REST is sufficient)
- ❌ Drift as authoritative storage (files are source of truth)

## Future Enhancements

1. **Tagging:** Add `tags` column to Drift, search by tag
2. **Markdown preview:** Render markdown in detail view
3. **Sync indicators:** Show per-note sync status
4. **Batch operations:** Delete multiple, bulk export
5. **Sync history:** View file revisions on GitHub
6. **Encryption:** Add optional client-side encryption
7. **Mobile sync:** Extend to iOS via same GitHub backend

## Migration Strategy

1. **Phase 1:** Implement new GitHub-backed system alongside existing Pinboard notes
2. **Phase 2:** One-time migration: Export Pinboard notes to markdown, upload to GitHub
3. **Phase 3:** Deprecate Pinboard notes UI, keep for backward compat
4. **Phase 4:** Optional: Clean up old Pinboard notes code

## Testing Strategy

### Unit Tests
- Sync engine logic (pull, push, conflict handling)
- GitHub client API calls
- File operations
- Drift queries

### Integration Tests
- Full sync flow (pull → edit → push)
- Conflict detection and handling
- Multi-device scenario simulation
- Offline/online transitions

### Manual Testing
- Create/edit/delete notes
- Sync with GitHub
- Trigger conflicts (manual edit on GitHub)
- Network failures and recovery
