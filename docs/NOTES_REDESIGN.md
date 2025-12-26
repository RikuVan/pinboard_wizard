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
2. Generate a **Fine-Grained Personal Access Token** (recommended):
   - Repository access: Only the notes repository
   - Permissions: Contents (Read and Write), Metadata (Read-only)
   - Expiration: 180 days (token rotation recommended)
3. Store token securely via `FlutterSecureStorage`
4. Store repository details:
   - Owner (GitHub username)
   - Repository name
   - Branch (default: `main`)
   - Notes folder path (default: `notes/`)

See **Token Security Recommendations** section below for detailed setup instructions.

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
  final TokenType tokenType;    // 'classic' or 'fine_grained'
  final DateTime? tokenExpiry;  // Expiration date (for monitoring)
}

enum TokenType {
  classic,        // Classic PAT (full account access)
  fineGrained,    // Fine-grained PAT (recommended)
}
```

Store in `FlutterSecureStorage`:
- Key: `github_notes_config`
- Value: JSON with all above fields
- Token stored separately: `github_pat_token`

### Token Security Recommendations

**Use Fine-Grained Personal Access Tokens (Recommended)**

Fine-grained tokens provide better security than classic PATs:

| Feature | Classic PAT | Fine-Grained PAT |
|---------|-------------|------------------|
| Scope | All repos user has access to | Single repository only |
| Permissions | Full `repo` access | Granular (Contents: Read/Write only) |
| Expiration | Optional (can be permanent) | Required (max 1 year) |
| Revocation impact | Breaks all apps using it | Only affects this app |

**Setup Instructions for Users:**

```
1. Go to GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Click "Generate new token"
3. Configure:
   - Token name: "Pinboard Wizard Notes"
   - Expiration: 180 days (recommended)
   - Repository access: "Only select repositories" → Choose your notes repo
   - Permissions:
     * Contents: Read and write
     * Metadata: Read-only (automatically included)
4. Generate and copy token
5. Paste into Pinboard Wizard settings
```

**Token Expiry Handling:**

```dart
class GitHubAuthService {
  /// Check if token is expired or expiring soon
  bool isTokenExpiringSoon(GitHubNotesConfig config) {
    if (config.tokenExpiry == null) return false;

    final daysUntilExpiry = config.tokenExpiry!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7; // Warn 7 days before expiry
  }

  /// Detect auth errors and prompt renewal
  Future<void> handleAuthError(Response response) async {
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Token invalid or expired
      emit(SyncError(
        message: 'GitHub token expired or invalid. Please update your token in settings.',
        requiresReauth: true,
      ));

      // Disable sync until user fixes auth
      await _disableSync();
    }
  }

  /// Show proactive expiry warning
  /// Call this on app launch and before each sync
  Future<void> checkTokenExpiry() async {
    final config = await _getConfig();

    if (isTokenExpiringSoon(config)) {
      final daysLeft = config.tokenExpiry!.difference(DateTime.now()).inDays;

      emit(TokenExpiryWarning(
        message: 'Your GitHub token expires in $daysLeft day${daysLeft == 1 ? '' : 's'}. '
                 'Please renew it in Settings to avoid sync interruption.',
        daysRemaining: daysLeft,
        severity: daysLeft <= 3 ? WarningSeverity.high : WarningSeverity.medium,
      ));
    }
  }
}

enum WarningSeverity {
  low,      // 7+ days remaining
  medium,   // 3-7 days remaining
  high,     // 0-3 days remaining
}
```

**When to Check Token Expiry:**

1. **On app launch** - Check immediately when app starts
2. **Before each sync** - Verify token is still valid
3. **In settings UI** - Show expiry date prominently
4. **Daily background check** - If app supports background tasks

**UI Integration Examples:**

```dart
// 1. App Launch Check
class NotesApp extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    _checkTokenOnStartup();
  }

  Future<void> _checkTokenOnStartup() async {
    await context.read<NotesCubit>().checkTokenExpiry();
  }
}

// 2. Settings Screen - Show Expiry Status
class GitHubSettingsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesCubit, NotesState>(
      builder: (context, state) {
        final config = state.githubConfig;
        final expiryDate = config?.tokenExpiry;

        if (expiryDate == null) {
          return Text('Token expiry: Not set',
              style: TextStyle(color: Colors.grey));
        }

        final daysLeft = expiryDate.difference(DateTime.now()).inDays;
        final color = daysLeft <= 3 ? Colors.red :
                     daysLeft <= 7 ? Colors.orange :
                     Colors.green;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Token expires: ${_formatDate(expiryDate)}'),
            Text('Days remaining: $daysLeft',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            if (daysLeft <= 7)
              PushButton(
                child: Text('Renew Token Now'),
                onPressed: () => _showTokenRenewalDialog(context),
              ),
          ],
        );
      },
    );
  }
}

// 3. Persistent Banner Warning
class TokenExpiryBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesCubit, NotesState>(
      builder: (context, state) {
        final warning = state.tokenExpiryWarning;
        if (warning == null) return SizedBox.shrink();

        return MacosBanner(
          icon: Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: warning.severity == WarningSeverity.high
                ? Colors.red
                : Colors.orange,
          ),
          message: warning.message,
          action: PushButton(
            child: Text('Update Token'),
            onPressed: () => Navigator.pushNamed(context, '/settings/github'),
          ),
          onDismiss: () => context.read<NotesCubit>().dismissTokenWarning(),
        );
      },
    );
  }
}

// 4. Toolbar Status Indicator
class NotesToolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ToolBar(
      title: Text('Notes'),
      trailing: BlocBuilder<NotesCubit, NotesState>(
        builder: (context, state) {
          final warning = state.tokenExpiryWarning;
          if (warning == null) return SizedBox.shrink();

          return ToolBarIconButton(
            icon: MacosIcon(
              CupertinoIcons.exclamationmark_circle,
              color: warning.severity == WarningSeverity.high
                  ? Colors.red
                  : Colors.orange,
            ),
            label: 'Token expiring soon',
            onPressed: () => _showTokenWarningDialog(context, warning),
          );
        },
      ),
    );
  }
}
```

**Security Best Practices:**

1. ✅ **Never log tokens** - Exclude from logs, error messages, analytics
2. ✅ **Secure storage only** - Use `FlutterSecureStorage`, never `SharedPreferences`
3. ✅ **Set expiration** - 180-day tokens force regular rotation
4. ✅ **Minimal permissions** - Contents (read/write) only, no admin/workflow access
5. ✅ **Single repo scope** - Fine-grained tokens limit blast radius if compromised
6. ✅ **Proactive warnings** - Alert user 7 days before token expires

## First-Time Setup Flow

When user launches the app without GitHub configuration:

**Step 1: Welcome Screen**
```
┌─────────────────────────────────┐
│  Welcome to Notes               │
│                                 │
│  Sync your markdown notes       │
│  with GitHub                    │
│                                 │
│  [Setup GitHub Sync]            │
└─────────────────────────────────┘
```

**Step 2: Configuration Form**

User enters:
- GitHub username/owner (e.g., `johndoe`)
- Repository name (e.g., `personal-notes`)
- Personal access token (paste from GitHub)
- Branch (default: `main`)
- Notes folder path (default: `notes/`)

**Step 3: Validation**

```dart
Future<bool> validateGitHubConfig(GitHubNotesConfig config) async {
  try {
    // 1. Test API connection
    final response = await http.get(
      Uri.parse('https://api.github.com/user'),
      headers: {'Authorization': 'Bearer ${config.patToken}'},
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthException('Invalid token or insufficient permissions');
    }

    // 2. Verify repository exists and is accessible
    final repoResponse = await http.get(
      Uri.parse('https://api.github.com/repos/${config.owner}/${config.repo}'),
      headers: {'Authorization': 'Bearer ${config.patToken}'},
    );

    if (repoResponse.statusCode == 404) {
      throw RepositoryNotFoundException('Repository not found or not accessible');
    }

    // 3. Check token permissions
    final scopes = repoResponse.headers['x-oauth-scopes'] ?? '';
    if (!scopes.contains('repo') && !scopes.contains('contents')) {
      throw PermissionException('Token needs Contents (read/write) permission');
    }

    return true;

  } catch (e) {
    // Show error to user with specific guidance
    rethrow;
  }
}
```

**Step 4: Initial Sync**

After successful validation:
1. Save config to `FlutterSecureStorage`
2. Perform initial pull from GitHub
3. Download any existing notes (if repository has notes)
4. Build local Drift index
5. Navigate to notes list

**Step 5: Ready to Use**

```
┌─────────────────────────────────┐
│  Notes          [+ New] [Sync]  │
├─────────────────────────────────┤
│  ✓ Welcome Note (from GitHub)   │
│  ✓ Getting Started               │
│                                 │
│  [Synced with GitHub ✓]         │
└─────────────────────────────────┘
```

**Error Handling:**

| Error | User Message | Action |
|-------|--------------|--------|
| Invalid token | "Token is invalid. Please check and try again." | Stay on form |
| Repo not found | "Repository not found. Check owner and name." | Stay on form |
| No permissions | "Token needs Contents (read/write) permission." | Link to token docs |
| Network error | "Cannot connect to GitHub. Check internet." | Retry option |

## Data Model

### Local Drift Table: `notes_metadata`

Stores indexing and sync state, **not** the actual content.

```dart
class Notes extends Table {
  TextColumn get id => text()();
  // UUID v4, generated using Uuid().v4() from uuid package

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

  BoolColumn get markedForDeletion =>
      boolean().withDefault(const Constant(false))();
  // True if note should be deleted from GitHub on next sync

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

  2. List all markdown files using Git Trees API (optimized)
     See "Performance Optimization: Efficient Sync" section for details
     → Get latest commit and tree SHA
     → Fetch entire tree recursively in ONE API call
     → Filter for *.md files in notesPath

     This approach is 93% faster than traditional /contents API

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

         Sub-case 2a: Local has unsaved edits (CONFLICT)
         if local.isDirty:
           → CONFLICT DETECTED (both local and remote changed)
           → Generate conflict filename for local version:
             conflictPath = generateConflictFilename(file.path, deviceId)
           → Write local content to conflict file
           → Upload conflict file to GitHub
           → Download remote content
           → Overwrite local file with remote version
           → Update Drift for original:
             { lastKnownSha=file.sha, isDirty=false, updatedAt=now }
           → Insert conflict file in Drift:
             { path=conflictPath, isConflict=true }
           → Emit conflict notification to UI

         Sub-case 2b: No local edits (safe to overwrite)
         else:
           → Download file content
           → Overwrite local file
           → Update Drift:
             { lastKnownSha=file.sha, isDirty=false, updatedAt=now }

     Case 3: No change
       else:
         → Skip (local matches remote)

  4. Handle remote deletions
     → See Phase 5: Note Deletion for detailed logic
     → If note deleted remotely but isDirty locally: preserve local copy, warn user
     → If note deleted remotely and not isDirty: safe to delete locally

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

### Phase 1.5: Note Creation

**Goal:** Create new note locally and queue for initial sync to GitHub

```
createNewNote(title):
  1. Generate unique ID
     id = Uuid().v4()

  2. Generate sanitized filename
     filename = filenameService.generateFilename(title)
     path = "{notesPath}/{filename}"
     Example: "notes/flutter-state-management-1703598234567.md"

  3. Create initial markdown content
     content = "# {title}\n\n"
     (User can edit immediately after creation)

  4. Write to local file system
     fileService.writeFile(localPath, content)

  5. Insert in Drift
     db.insertNote(
       id: id,
       path: path,
       title: title,
       lastKnownSha: null,     ← Not yet on GitHub
       isDirty: true,           ← Needs initial sync
       createdAt: now(),
       updatedAt: now()
     )

  6. Update FTS5 index
     db.updateFtsIndex(id, title, content)

  7. Queue for background sync
     sync.syncNotes()
     → Will upload to GitHub during next push phase

  ✓ Note created locally, ready for editing
  ✓ Will sync to GitHub automatically
```

**User Flow:**
1. User clicks "New Note" button
2. Enters title in dialog
3. Note appears immediately in list (marked as `isDirty`)
4. User can start editing right away
5. Background sync uploads to GitHub within 2 seconds

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

**Triggers:**
1. During **pull**: `remote.sha != note.lastKnownSha` AND `note.isDirty == true` (both local and remote changed)
2. During **push**: `remote.sha != note.lastKnownSha` (remote changed since last pull)

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

T3: Device B (Mac Mini) (was offline)
  Pull: lastKnownSha = abc123  ← hasn't synced yet
  Edit "flutter-state.md"
  isDirty = true

T4: Device B comes online, pushes
  Fetch remote metadata
  GitHub SHA = def456 (Device A just uploaded)
  Device B lastKnownSha = abc123 (hasn't pulled latest)

  → CONFLICT DETECTED
  → Create "flutter-state.conflict-macmini-2025-03-11T...md"
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

**Conflict Resolution UI Workflow**

When conflicts occur, users see both files in their notes list and can resolve them manually.

**UI Display:**

```
Notes List:
──────────────────────────────────────────────────
⚡ flutter-state.md                    [CONFLICT]
   Original version from Device A

📝 flutter-state.conflict-macmini-...md
   Your version from Device B (Mac Mini)
```

**Resolution Options:**

1. **Keep Original (Discard Your Changes)**
   - User reviews original file
   - Deletes conflict file
   - Syncs deletion to GitHub

2. **Keep Your Version (Replace Original)**
   - User opens conflict file
   - Copies content
   - Pastes into original file
   - Deletes conflict file
   - Syncs changes

3. **Manual Merge (Combine Both)**
   - User opens both files side-by-side
   - Manually merges content
   - Saves to original file
   - Deletes conflict file
   - Syncs merged result

**Implementation:**

```dart
class ConflictResolutionDialog extends StatelessWidget {
  final Note originalNote;
  final Note conflictNote;

  @override
  Widget build(BuildContext context) {
    return MacosAlertDialog(
      appIcon: Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.orange),
      title: Text('Conflict Detected'),
      message: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The note "${originalNote.title}" has conflicting changes.'),
          SizedBox(height: 16),
          Text('Original: ${originalNote.path}'),
          Text('Your version: ${conflictNote.path}'),
          SizedBox(height: 16),
          Text('How would you like to resolve this?'),
        ],
      ),
      primaryButton: PushButton(
        child: Text('View Both Files'),
        onPressed: () {
          Navigator.pop(context);
          _openSideBySideView(originalNote, conflictNote);
        },
      ),
      secondaryButton: PushButton(
        child: Text('Keep Original'),
        onPressed: () async {
          await context.read<NotesCubit>().deleteNote(conflictNote.id);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openSideBySideView(Note original, Note conflict) {
    // Open both notes in split view for manual merging
  }
}
```

**Best Practices for Users:**

1. **Act promptly**: Resolve conflicts as soon as they appear
2. **Review carefully**: Check both versions before deciding
3. **Use version control**: GitHub keeps history, mistakes are recoverable
4. **Sync regularly**: Reduces likelihood of conflicts

### Phase 5: Note Deletion

**Goal:** Handle note deletion locally and remotely with conflict safety

#### Local Deletion (User Deletes in App)

```
deleteNote(noteId):
  1. Get note from Drift
     note = db.getNoteById(noteId)

  2. Check online status
     if online:
       Step A: Delete from GitHub
       ─────────────────────────
       github.deleteFile(
         path: note.path,
         sha: note.lastKnownSha,
         message: "Delete note: {title}"
       )

       Handle errors:
       - 404 (already deleted) → Continue, that's fine
       - 409 (SHA mismatch) → Remote changed, show conflict warning
       - Network error → Queue for deletion on next sync

     else:
       Step B: Queue for deletion
       ─────────────────────────
       db.markForDeletion(noteId)
       → On next sync, delete from GitHub

  3. Delete local file
     fileService.deleteFile(note.path)

  4. Remove from Drift
     db.deleteNote(noteId)

  ✓ Note removed locally and remotely (or queued)
```

#### Remote Deletion (File Deleted on GitHub)

Handled during pull phase:

```
_handleRemoteDeletions(remotePaths):
  1. Get all local notes
     localNotes = db.getAllNotes()

  2. For each local note:
     if note.path NOT IN remotePaths:
       → File was deleted on remote

       Case A: User has local edits (isDirty = true)
       if note.isDirty:
         → CONFLICT: Deleted remotely but edited locally
         → Keep local file (preserve user's work)
         → Show warning toast:
           "Note '{title}' was deleted remotely but you have unsaved changes.
            Your version is kept locally."
         → Mark note as unsynced

       Case B: No local edits (isDirty = false)
       else:
         → Safe to delete
         → Delete local file
         → Remove from Drift
         → Emit deletion event to UI
```

**Edge Cases:**

| Scenario | Behavior |
|----------|----------|
| Delete while offline | Queue deletion, sync when online |
| Delete + edit on different devices | Keep edited version, warn user |
| Delete conflict file manually | Normal deletion flow |
| Delete then recreate with same name | Treated as new note (new UUID) |

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

### Service Layer: NoteFilenameService

Handles filename generation and title extraction with proper sanitization.

```dart
class NoteFilenameService {
  /// Generate safe, unique filename from user-provided title
  String generateFilename(String title) {
    // 1. Lowercase for consistency
    var filename = title.toLowerCase();

    // 2. Replace spaces with hyphens
    filename = filename.replaceAll(RegExp(r'\s+'), '-');

    // 3. Remove special characters (keep only alphanumeric and hyphens)
    //    Prevents path traversal, filesystem issues, git problems
    filename = filename.replaceAll(RegExp(r'[^a-z0-9-]'), '');

    // 4. Remove multiple consecutive hyphens
    filename = filename.replaceAll(RegExp(r'-+'), '-');

    // 5. Trim hyphens from start/end
    filename = filename.replaceAll(RegExp(r'^-|-$'), '');

    // 6. Limit length (GitHub max is 255 chars, keep reasonable)
    if (filename.length > 50) {
      filename = filename.substring(0, 50);
    }

    // 7. Handle empty result
    if (filename.isEmpty) {
      filename = 'untitled';
    }

    // 8. Add timestamp for uniqueness (prevents collisions)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    filename = '$filename-$timestamp';

    return '$filename.md';
  }

  /// Extract title from markdown content
  /// Priority: H1 heading > filename (cleaned)
  String extractTitle(String markdown, String filename) {
    // Try to find first H1 heading (# Title)
    final h1Match = RegExp(r'^#\s+(.+)$', multiLine: true)
        .firstMatch(markdown);

    if (h1Match != null) {
      return h1Match.group(1)!.trim();
    }

    // Fallback: use filename (remove extension and timestamp)
    return path.basenameWithoutExtension(filename)
        .replaceAll(RegExp(r'-\d{13}$'), '')  // Remove timestamp
        .replaceAll('-', ' ')                  // Hyphens to spaces
        .trim();
  }

  /// Validate filename doesn't conflict with system files
  bool isValidFilename(String filename) {
    // Reject system/hidden files
    if (filename.startsWith('.')) return false;

    // Reject reserved names (cross-platform safety)
    final reserved = ['con', 'prn', 'aux', 'nul', 'com1', 'lpt1'];
    final base = path.basenameWithoutExtension(filename).toLowerCase();
    if (reserved.contains(base)) return false;

    return true;
  }
}
```

**Usage Examples:**

```dart
final service = NoteFilenameService();

// Example 1: Simple title
service.generateFilename("Flutter State Management")
→ "flutter-state-management-1703598234567.md"

// Example 2: Special characters and emoji
service.generateFilename("React/Vue?! 🎯 (2024)")
→ "react-vue-2024-1703598234568.md"

// Example 3: Long title (truncated)
service.generateFilename("A Very Long Title That Exceeds The Maximum Length...")
→ "a-very-long-title-that-exceeds-the-maximum-le-1703598234569.md"

// Example 4: Empty/invalid title
service.generateFilename("")
→ "untitled-1703598234570.md"

// Example 5: Extract title from markdown
service.extractTitle("# My Note Title\n\nContent here", "my-note-1234.md")
→ "My Note Title"

service.extractTitle("Content without H1", "flutter-tips-1234.md")
→ "flutter tips"  // Derived from filename
```

**Why This Matters:**

| User Input | Without Sanitization | With Sanitization |
|------------|---------------------|-------------------|
| `My TODO List` | `My TODO List.md` | `my-todo-list-1703598234567.md` |
| `React/Vue` | `React/Vue.md` ⚠️ | `react-vue-1703598234568.md` ✓ |
| `Notes 🎯` | `Notes 🎯.md` ⚠️ | `notes-1703598234569.md` ✓ |
| `../secret` | `../secret.md` 💀 | `secret-1703598234570.md` ✓ |

- **Prevents path traversal attacks**: `../../../etc/passwd` → sanitized
- **Cross-platform compatibility**: Works on macOS, Linux, Windows
- **Git-friendly**: No special characters that break git
- **URL-safe**: Can be used in web URLs without encoding
- **Unique**: Timestamp prevents collisions

### Service Layer: NotesSync

Core sync orchestrator. Implements pull → push → conflict → deletion handling.

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

### Performance Optimization: Efficient Sync

**Problem:** Fetching metadata for every file on each sync is expensive and slow.

**Solution:** Use Git Trees API + conditional requests to minimize API calls.

#### Optimization Strategy

| Technique | Benefit | API Calls Saved |
|-----------|---------|-----------------|
| **Git Trees API** | Fetch all files in one request | 30+ calls → 1 call |
| **Conditional requests (ETags)** | Skip fetch if unchanged | 100% if no changes |
| **Batch operations** | Upload multiple notes together | 50% reduction |
| **Rate limit awareness** | Show remaining quota to user | Prevents surprises |

#### Implementation: Git Trees API

Instead of calling `/contents` for each file, use `/trees` to get all files at once:

```dart
class GitHubClient {
  String? _lastTreeSha;  // Cache for conditional requests

  /// Efficiently list all notes with one API call
  Future<List<GitHubFile>> listNotesFiles() async {
    // Step 1: Get latest commit SHA
    final commit = await _getLatestCommit();
    final treeSha = commit['tree']['sha'] as String;

    // Step 2: Check if tree changed (cached comparison)
    if (_lastTreeSha == treeSha) {
      // No changes since last sync, return empty
      return [];
    }

    // Step 3: Fetch entire tree recursively (one API call)
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/git/trees/$treeSha?recursive=1'
    );

    final response = await withRetry(() => _get(url));
    final tree = json.decode(response);

    // Step 4: Filter for markdown files in notes path
    final files = <GitHubFile>[];
    for (final entry in tree['tree']) {
      final path = entry['path'] as String;

      if (path.startsWith(_notesPath) && path.endsWith('.md')) {
        files.add(GitHubFile(
          path: path,
          sha: entry['sha'],
          size: entry['size'],
          type: entry['type'],
        ));
      }
    }

    // Cache tree SHA for next sync
    _lastTreeSha = treeSha;

    return files;
  }

  Future<Map<String, dynamic>> _getLatestCommit() async {
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/commits/$_branch'
    );

    final response = await withRetry(() => _get(url));
    return json.decode(response);
  }
}
```

**Performance Comparison:**

```
Traditional approach (contents API):
──────────────────────────────────
30 notes:
  - List directory: 1 API call
  - Get each file metadata: 30 API calls
  - Total: 31 API calls
  - Time: ~15 seconds (with network latency)

Optimized approach (trees API):
────────────────────────────────
30 notes:
  - Get latest commit: 1 API call
  - Get tree recursively: 1 API call
  - Total: 2 API calls
  - Time: ~1 second

Improvement: 93% fewer API calls, 15× faster
```

#### Conditional Requests with ETags

Use HTTP ETags to skip fetching unchanged content:

```dart
class GitHubClient {
  final Map<String, String> _etagCache = {};

  Future<String?> downloadFileIfChanged(String path) async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');

    // Add cached ETag to request
    final headers = <String, String>{
      'Authorization': 'Bearer $_token',
      'Accept': 'application/vnd.github.v3+json',
    };

    if (_etagCache.containsKey(path)) {
      headers['If-None-Match'] = _etagCache[path]!;
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 304) {
      // Not Modified - content hasn't changed
      return null;
    }

    if (response.statusCode == 200) {
      // Cache new ETag
      final etag = response.headers['etag'];
      if (etag != null) {
        _etagCache[path] = etag;
      }

      final data = json.decode(response.body);
      return utf8.decode(base64.decode(data['content']));
    }

    throw Exception('Failed to download file: ${response.statusCode}');
  }
}
```

#### Rate Limit Tracking

Show user their API usage to prevent surprises:

```dart
class GitHubClient {
  RateLimitInfo? _rateLimitInfo;

  Future<void> _updateRateLimitFromHeaders(Response response) async {
    _rateLimitInfo = RateLimitInfo(
      limit: int.parse(response.headers['x-ratelimit-limit'] ?? '5000'),
      remaining: int.parse(response.headers['x-ratelimit-remaining'] ?? '5000'),
      resetAt: DateTime.fromMillisecondsSinceEpoch(
        int.parse(response.headers['x-ratelimit-reset'] ?? '0') * 1000,
      ),
    );
  }

  RateLimitInfo? getRateLimitInfo() => _rateLimitInfo;
}

class RateLimitInfo {
  final int limit;        // 5000 for authenticated requests
  final int remaining;    // Calls left in current window
  final DateTime resetAt; // When limit resets

  RateLimitInfo({
    required this.limit,
    required this.remaining,
    required this.resetAt,
  });

  bool get isLow => remaining < 100;
  bool get isExhausted => remaining == 0;

  String get userMessage {
    if (isExhausted) {
      final wait = resetAt.difference(DateTime.now()).inMinutes;
      return 'GitHub API limit reached. Resets in $wait minutes.';
    }
    if (isLow) {
      return 'API calls remaining: $remaining/$limit';
    }
    return 'API calls remaining: $remaining/$limit';
  }
}
```

**UI Integration:**

```dart
// Show rate limit in status bar or settings
class SyncStatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesCubit, NotesState>(
      builder: (context, state) {
        final rateLimit = state.rateLimitInfo;
        if (rateLimit == null) return SizedBox.shrink();

        return Text(
          rateLimit.userMessage,
          style: TextStyle(
            color: rateLimit.isLow ? Colors.orange : Colors.grey,
          ),
        );
      },
    );
  }
}
```

**Estimated API Usage:**

```
Single sync cycle (30 notes):
────────────────────────────
Pull:
  - Get latest commit: 1 call
  - Get tree: 1 call
  - Download changed files: 2 calls (average)
  Total: 4 calls

Push (5 dirty notes):
  - Get metadata per note: 5 calls
  - Update file: 5 calls
  Total: 10 calls

Grand total: ~14 calls per sync
Sustainable: 350+ syncs per hour (well under 5000 limit)
```

### Service Layer: GitHubClient

Wraps GitHub REST API with retry logic, error handling, and performance optimizations.

```dart
class GitHubClient {
  final String _token;
  final String _owner;
  final String _repo;
  final String _branch;
  final String _notesPath;

  static const String _baseUrl = 'https://api.github.com';

  String? _lastTreeSha;  // Cache for conditional requests

  /// List files in notes folder with metadata (optimized using Git Trees API)
  /// See "Performance Optimization" section for implementation details
  Future<List<GitHubFile>> listNotesFiles() async {
    // Step 1: Get latest commit SHA
    final commit = await _getLatestCommit();
    final treeSha = commit['tree']['sha'] as String;

    // Step 2: Check if tree changed (cached comparison)
    if (_lastTreeSha == treeSha) {
      // No changes since last sync, return empty
      return [];
    }

    // Step 3: Fetch entire tree recursively (one API call)
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/git/trees/$treeSha?recursive=1'
    );

    final response = await withRetry(() => _get(url));
    final tree = json.decode(response);

    // Step 4: Filter for markdown files in notes path
    final files = <GitHubFile>[];
    for (final entry in tree['tree']) {
      final path = entry['path'] as String;

      if (path.startsWith(_notesPath) && path.endsWith('.md')) {
        files.add(GitHubFile(
          path: path,
          sha: entry['sha'],
          size: entry['size'],
          type: entry['type'],
        ));
      }
    }

    // Cache tree SHA for next sync
    _lastTreeSha = treeSha;

    return files;
  }

  Future<Map<String, dynamic>> _getLatestCommit() async {
    final url = Uri.parse(
      '$_baseUrl/repos/$_owner/$_repo/commits/$_branch'
    );

    final response = await withRetry(() => _get(url));
    return json.decode(response);
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

### Supporting Services

Helper services used throughout the sync system.

#### FileService

Handles local file system operations for markdown notes.

```dart
class FileService {
  final Directory notesDirectory;

  FileService(this.notesDirectory);

  /// Read markdown file content
  Future<String> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileNotFoundException('File not found: $path');
    }
    return await file.readAsString();
  }

  /// Write markdown content to file
  Future<void> writeFile(String path, String content) async {
    final file = File(path);

    // Ensure parent directory exists
    await file.parent.create(recursive: true);

    // Write content
    await file.writeAsString(content);
  }

  /// Delete file from local filesystem
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get local path for a repository path
  String getLocalPath(String repoPath) {
    final filename = path.basename(repoPath);
    return path.join(notesDirectory.path, filename);
  }

  /// List all local markdown files
  Future<List<File>> listLocalFiles() async {
    if (!await notesDirectory.exists()) {
      await notesDirectory.create(recursive: true);
      return [];
    }

    return notesDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.md'))
        .cast<File>()
        .toList();
  }
}
```

#### NetworkService

Checks online connectivity before sync operations.

```dart
class NetworkService {
  /// Check if device has internet connectivity
  Future<bool> isOnline() async {
    try {
      // Try to lookup GitHub's DNS
      final result = await InternetAddress.lookup('api.github.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Check connectivity with timeout
  Future<bool> isOnlineWithTimeout({Duration timeout = const Duration(seconds: 3)}) async {
    try {
      return await isOnline().timeout(timeout);
    } on TimeoutException {
      return false;
    }
  }
}
```

#### GitHubFile Model

Represents a file in the GitHub repository.

```dart
class GitHubFile {
  final String path;          // "notes/flutter-state.md"
  final String sha;           // GitHub blob SHA
  final int size;             // File size in bytes
  final String type;          // "file" or "dir"
  final String? content;      // Base64 encoded content (only in full responses)

  GitHubFile({
    required this.path,
    required this.sha,
    required this.size,
    required this.type,
    this.content,
  });

  factory GitHubFile.fromJson(Map<String, dynamic> json) {
    return GitHubFile(
      path: json['path'] as String,
      sha: json['sha'] as String,
      size: json['size'] as int,
      type: json['type'] as String,
      content: json['content'] as String?,
    );
  }

  /// Decode base64 content to UTF-8 string
  String? get decodedContent {
    if (content == null) return null;
    return utf8.decode(base64.decode(content!));
  }
}
```

### Sync Result Handling: Partial Failures

**Problem:** When syncing multiple notes, some may succeed while others fail. Users need clear visibility into what happened.

#### SyncResult Model

```dart
class SyncResult {
  final List<Note> succeeded;
  final List<SyncFailure> failed;
  final List<Note> conflicts;
  final bool isOnline;
  final DateTime timestamp;

  SyncResult({
    required this.succeeded,
    required this.failed,
    required this.conflicts,
    required this.isOnline,
    required this.timestamp,
  });

  bool get isFullSuccess => failed.isEmpty && conflicts.isEmpty;
  bool get isPartialSuccess => succeeded.isNotEmpty && (failed.isNotEmpty || conflicts.isNotEmpty);
  bool get isFullFailure => succeeded.isEmpty && (failed.isNotEmpty || conflicts.isNotEmpty);

  String get userMessage {
    if (!isOnline) {
      return 'Offline - sync pending';
    }
    if (isFullSuccess) {
      return 'Synced ${succeeded.length} note${succeeded.length == 1 ? '' : 's'}';
    }
    if (isPartialSuccess) {
      final parts = <String>[];
      if (succeeded.isNotEmpty) parts.add('${succeeded.length} synced');
      if (failed.isNotEmpty) parts.add('${failed.length} pending');
      if (conflicts.isNotEmpty) parts.add('${conflicts.length} conflict${conflicts.length == 1 ? '' : 's'}');
      return parts.join(', ');
    }
    if (isFullFailure) {
      return 'Sync failed: ${failed.first.error}';
    }
    return 'Unknown sync status';
  }

  ToastSeverity get severity {
    if (isFullSuccess) return ToastSeverity.success;
    if (isPartialSuccess) return ToastSeverity.warning;
    return ToastSeverity.error;
  }
}

class SyncFailure {
  final Note note;
  final String error;
  final SyncFailureType type;
  final DateTime timestamp;

  SyncFailure({
    required this.note,
    required this.error,
    required this.type,
    required this.timestamp,
  });

  String get userMessage {
    switch (type) {
      case SyncFailureType.network:
        return 'Network error - will retry';
      case SyncFailureType.conflict:
        return 'Conflict detected';
      case SyncFailureType.auth:
        return 'Authentication failed';
      case SyncFailureType.rateLimit:
        return 'Rate limited - retry later';
      case SyncFailureType.validation:
        return 'Invalid content';
      case SyncFailureType.unknown:
        return error;
    }
  }
}

enum SyncFailureType {
  network,      // Timeout, connection lost, DNS failure
  conflict,     // SHA mismatch, concurrent edit
  auth,         // 401/403, token expired
  rateLimit,    // 429, exceeded API quota
  validation,   // 422, invalid data
  unknown,      // Unexpected error
}

enum ToastSeverity {
  success,      // Green
  warning,      // Yellow/Orange
  error,        // Red
  info,         // Blue
}
```

#### Implementation in NotesSync

```dart
Future<SyncResult> pushDirtyNotes() async {
  final dirtyNotes = await _db.getDirtyNotes();
  final succeeded = <Note>[];
  final failed = <SyncFailure>[];
  final conflicts = <Note>[];

  for (final note in dirtyNotes) {
    try {
      // Attempt to push single note
      await _pushSingleNote(note);
      succeeded.add(note);

    } on ConflictException catch (e) {
      // Handle conflict (create conflict file)
      await _handleConflict(note);
      conflicts.add(note);

    } on NetworkException catch (e) {
      // Network error - keep as dirty, will retry
      failed.add(SyncFailure(
        note: note,
        error: e.message,
        type: SyncFailureType.network,
        timestamp: DateTime.now(),
      ));

    } on AuthException catch (e) {
      // Auth error - stop sync, disable until fixed
      failed.add(SyncFailure(
        note: note,
        error: 'Token expired or invalid',
        type: SyncFailureType.auth,
        timestamp: DateTime.now(),
      ));
      break; // Stop processing, auth broken

    } on RateLimitException catch (e) {
      // Rate limited - stop and retry later
      failed.add(SyncFailure(
        note: note,
        error: 'API rate limit exceeded',
        type: SyncFailureType.rateLimit,
        timestamp: DateTime.now(),
      ));
      break; // Stop processing, wait for reset

    } on ValidationException catch (e) {
      // Validation error - skip this note, continue with others
      failed.add(SyncFailure(
        note: note,
        error: e.message,
        type: SyncFailureType.validation,
        timestamp: DateTime.now(),
      ));

    } catch (e) {
      // Unknown error
      failed.add(SyncFailure(
        note: note,
        error: e.toString(),
        type: SyncFailureType.unknown,
        timestamp: DateTime.now(),
      ));
    }
  }

  return SyncResult(
    succeeded: succeeded,
    failed: failed,
    conflicts: conflicts,
    isOnline: await _network.isOnline(),
    timestamp: DateTime.now(),
  );
}
```

#### UI Feedback

**Toast Notifications:**

```dart
class NotesListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<NotesCubit, NotesState>(
      listener: (context, state) {
        if (state.syncResult != null) {
          final result = state.syncResult!;

          // Show appropriate toast based on result
          showMacosToast(
            context,
            result.userMessage,
            severity: result.severity,
          );
        }
      },
      child: _buildNotesList(context),
    );
  }
}
```

**Per-Note Status Indicators:**

```dart
class NoteListItem extends StatelessWidget {
  final Note note;
  final SyncResult? lastSyncResult;

  Widget _buildSyncStatusIcon() {
    // Check if this note has sync status
    if (lastSyncResult == null) {
      return SizedBox.shrink();
    }

    // Check if note failed
    final failure = lastSyncResult!.failed
        .firstWhereOrNull((f) => f.note.id == note.id);
    if (failure != null) {
      return Tooltip(
        message: failure.userMessage,
        child: Icon(
          CupertinoIcons.exclamationmark_triangle,
          color: Colors.orange,
          size: 16,
        ),
      );
    }

    // Check if note has conflict
    if (lastSyncResult!.conflicts.any((n) => n.id == note.id)) {
      return Tooltip(
        message: 'Conflict detected',
        child: Icon(
          CupertinoIcons.bolt,
          color: Colors.red,
          size: 16,
        ),
      );
    }

    // Check if note is dirty (pending sync)
    if (note.isDirty) {
      return Tooltip(
        message: 'Sync pending',
        child: Icon(
          CupertinoIcons.clock,
          color: Colors.grey,
          size: 16,
        ),
      );
    }

    // Successfully synced
    return Tooltip(
      message: 'Synced',
      child: Icon(
        CupertinoIcons.checkmark_circle,
        color: Colors.green,
        size: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(note.title ?? 'Untitled')),
        _buildSyncStatusIcon(),
      ],
    );
  }
}
```

**Visual Status Examples:**

```
Notes List:
────────────────────────────────────────
✓ Flutter State Management         [synced]
✓ Dart Async Programming            [synced]
⚠️ Git Workflow                     [sync pending]
⚡ React Hooks                      [conflict]
✓ Docker Setup                      [synced]
⏰ TypeScript Tips                  [syncing...]
```

**Detailed Sync Report (Optional):**

```dart
class SyncReportDialog extends StatelessWidget {
  final SyncResult result;

  @override
  Widget build(BuildContext context) {
    return MacosAlertDialog(
      appIcon: FlutterLogo(),
      title: Text('Sync Complete'),
      message: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.succeeded.isNotEmpty) ...[
            Text('✓ Synced: ${result.succeeded.length}',
                style: TextStyle(color: Colors.green)),
            ...result.succeeded.map((n) => Text('  • ${n.title}')),
          ],
          if (result.failed.isNotEmpty) ...[
            SizedBox(height: 8),
            Text('⚠️ Failed: ${result.failed.length}',
                style: TextStyle(color: Colors.orange)),
            ...result.failed.map((f) => Text('  • ${f.note.title}: ${f.userMessage}')),
          ],
          if (result.conflicts.isNotEmpty) ...[
            SizedBox(height: 8),
            Text('⚡ Conflicts: ${result.conflicts.length}',
                style: TextStyle(color: Colors.red)),
            ...result.conflicts.map((n) => Text('  • ${n.title}')),
          ],
        ],
      ),
      primaryButton: PushButton(
        buttonSize: ButtonSize.large,
        child: Text('OK'),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}
```

**Retry Logic:**

```dart
class NotesCubit extends Cubit<NotesState> {
  /// Retry failed notes from last sync
  Future<void> retryFailedNotes() async {
    final lastResult = state.syncResult;
    if (lastResult == null || lastResult.failed.isEmpty) return;

    emit(state.copyWith(isSyncing: true));

    // Retry only the failed notes
    final failedNoteIds = lastResult.failed.map((f) => f.note.id).toList();
    for (final noteId in failedNoteIds) {
      await _sync.pushSingleNote(noteId);
    }

    // Re-sync to get fresh status
    await refresh();
  }
}
```

**Benefits:**

- ✅ **Transparency**: User sees exactly what succeeded/failed
- ✅ **No silent failures**: All errors surfaced with clear messaging
- ✅ **Per-note status**: Visual indicators show state at a glance
- ✅ **Actionable**: User knows which notes need attention
- ✅ **Retry support**: Failed notes can be retried individually

### State Management: NotesCubit

Orchestrates UI state, sync operations, and result handling.

```dart
class NotesCubit extends Cubit<NotesState> {
  final NotesSync _sync;
  final NotesDatabase _db;
  final FileService _fileService;
  Timer? _syncTimer;
  StreamSubscription? _syncSubscription;

  NotesCubit({
    required NotesSync sync,
    required NotesDatabase db,
    required FileService fileService,
  })  : _sync = sync,
        _db = db,
        _fileService = fileService,
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

  /// Get local file system path from repository path
  String _getLocalFilePath(String repoPath) {
    // Strip notes/ prefix and get local app documents path
    final filename = path.basename(repoPath);
    return path.join(_fileService.notesDirectory, filename);
  }

  @override
  Future<void> close() {
    _syncTimer?.cancel();
    _syncSubscription?.cancel();
    return super.close();
  }
}
```

### Search Architecture: FTS5 Full-Text Search

**Goal:** Fast, comprehensive search across all notes without sacrificing the file-as-source-of-truth principle.

#### Storage Strategy

The design uses **dual storage** for search optimization:

| Storage | Purpose | Content | Authoritative? |
|---------|---------|---------|----------------|
| **Local Files** | Source of truth | Full markdown content | ✅ Yes |
| **Drift `notes`** | Metadata & UI | Title, preview (300 chars), sync state | No |
| **FTS5 `notes_fts`** | Search index | Full markdown content | No |

**Key principle:** Files are canonical. Database is cache + index only.

#### FTS5 Table Schema

```dart
// Main metadata table (lightweight)
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get path => text().unique()();
  TextColumn get title => text().nullable()();
  TextColumn get lastKnownSha => text().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // UI previews (NOT indexed for search)
  TextColumn get contentPreview => text().nullable()(); // First 300 chars
  IntColumn get contentLength => integer().withDefault(const Constant(0))();
  BoolColumn get isConflict => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// FTS5 virtual table (full-text search)
@UseRowClass(NoteFts)
class NotesFts extends Table {
  IntColumn get rowid => integer()();  // Links to Notes.id
  TextColumn get title => text()();
  TextColumn get content => text()();  // Full markdown content

  @override
  String get tableName => 'notes_fts';

  @override
  Set<Column> get primaryKey => {rowid};

  @override
  List<String> get customConstraints => [
    'USING fts5(title, content, content=notes, content_rowid=id)',
  ];
}
```

#### Workflow: Keeping FTS5 Synchronized

**When note is created/edited/pulled:**

```dart
Future<void> syncNoteToDatabase(String noteId, String notePath) async {
  // 1. Read from file (source of truth)
  final markdownContent = await _fileService.readFile(notePath);

  // 2. Extract metadata
  final title = _filenameService.extractTitle(markdownContent, notePath);
  final preview = markdownContent.substring(0, min(300, markdownContent.length));

  // 3. Update metadata table
  await _db.into(_db.notes).insertOnConflictUpdate(
    NotesCompanion(
      id: Value(noteId),
      path: Value(notePath),
      title: Value(title),
      contentPreview: Value(preview),
      contentLength: Value(markdownContent.length),
      updatedAt: Value(DateTime.now()),
    ),
  );

  // 4. Update FTS5 index with full content
  await _db.customStatement(
    '''
    INSERT INTO notes_fts(rowid, title, content)
    VALUES (?, ?, ?)
    ON CONFLICT(rowid) DO UPDATE SET
      title = excluded.title,
      content = excluded.content
    ''',
    [noteId, title, markdownContent],
  );
}
```

**When displaying notes list:**

```dart
// Use metadata table (fast, no FTS query)
Future<List<Note>> getAllNotes() async {
  return select(notes).get();
  // Shows: title, contentPreview, updatedAt, isDirty
}
```

**When searching:**

```dart
// Use FTS5 (searches full content)
Future<List<Note>> searchNotes(String query) async {
  return customSelect(
    '''
    SELECT n.* FROM notes n
    JOIN notes_fts fts ON fts.rowid = n.id
    WHERE notes_fts MATCH ?
    ORDER BY rank
    LIMIT 50
    ''',
    variables: [Variable.withString(query)],
    readsFrom: {notes},
  ).map((row) => notes.map(row.data)).get();
}
```

**When opening editor:**

```dart
// Always read from file (not database)
Future<String> loadNoteForEditing(String noteId) async {
  final note = await _db.getNoteById(noteId);
  return await _fileService.readFile(note.path);
  // Never read from FTS or metadata table
}
```

#### Why This Approach Works

**Storage Cost:**
```
Example: 1000 notes, 5KB average per note
─────────────────────────────────────────
Files:         1000 × 5KB = 5 MB
Metadata DB:   1000 × 500B = 0.5 MB  (titles, paths, SHAs)
FTS5 Index:    1000 × 5KB = 5 MB     (full content indexed)
─────────────────────────────────────────
Total:         ~10.5 MB (negligible on modern systems)
```

**Benefits:**
- ✅ **Comprehensive search**: Finds matches anywhere in note, not just first 300 chars
- ✅ **Files remain canonical**: Editor always reads from file
- ✅ **Fast UI**: List view uses lightweight metadata, doesn't hit FTS
- ✅ **Ranked results**: FTS5 provides relevance scoring
- ✅ **Simple sync**: Update FTS whenever file changes

**Alternative Approaches (Not Recommended):**

| Approach | Trade-off |
|----------|-----------|
| Index preview only (300 chars) | ⚠️ Misses matches in long notes |
| Store full content in metadata table | ⚠️ Duplicates storage without search benefits |
| No indexing, scan files on search | 💀 Extremely slow with many notes |
| Lazy/on-demand indexing | ⚠️ First search is slow, complex logic |

### Drift Database Service

Manages local metadata storage and FTS5 search index.

```dart
@DriftDatabase(tables: [Notes, NotesFts])
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

  /// Full text search using FTS5
  /// See "Search Architecture: FTS5 Full-Text Search" section for implementation
  Future<List<Note>> searchNotes(String query) async {
    return customSelect(
      '''
      SELECT n.* FROM notes n
      JOIN notes_fts fts ON fts.rowid = n.id
      WHERE notes_fts MATCH ?
      ORDER BY rank
      LIMIT 50
      ''',
      variables: [Variable.withString(query)],
      readsFrom: {notes},
    ).map((row) => notes.map(row.data)).get();
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
- Pull 30 files: ~2 API calls (1 commit + 1 tree)
- Push 5 files: ~10 calls (1 metadata check + 1 update per file)
- Download 2 changed files: ~2 calls
- Total: ~14 calls per sync
- Sustainable: 350+ syncs per hour (well under 5000 limit)

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
