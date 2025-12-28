# Database Migration Guide

This document describes how to handle database schema changes for the Notes feature.

## Current Schema Version

**Version 1** (Initial Release)

### Tables

#### `notes` Table
- `id` TEXT PRIMARY KEY
- `path` TEXT UNIQUE
- `title` TEXT NULLABLE
- `lastKnownSha` TEXT NULLABLE
- `isDirty` BOOLEAN DEFAULT FALSE
- `updatedAt` DATETIME DEFAULT CURRENT_TIMESTAMP
- `createdAt` DATETIME DEFAULT CURRENT_TIMESTAMP
- `contentPreview` TEXT NULLABLE
- `contentLength` INTEGER DEFAULT 0
- `isConflict` BOOLEAN DEFAULT FALSE
- `markedForDeletion` BOOLEAN DEFAULT FALSE

#### `notes_fts` FTS5 Virtual Table
- `rowid` INTEGER (links to notes.rowid)
- `title` TEXT
- `content` TEXT

## How to Add a Migration

### Step 1: Increment Schema Version

In `notes_database.dart`, update the schema version:

```dart
@override
int get schemaVersion => 2; // Increment from 1 to 2
```

### Step 2: Add Migration Logic

Add your migration in the `onUpgrade` callback:

```dart
onUpgrade: (Migrator m, int from, int to) async {
  // Migration from version 1 to 2
  if (from < 2) {
    // Add a new column
    await m.addColumn(notes, notes.yourNewColumn);

    // Or use raw SQL for complex changes
    await customStatement('ALTER TABLE notes ADD COLUMN new_field TEXT');
  }

  // Migration from version 2 to 3
  if (from < 3) {
    // Example: Create a new index
    await customStatement('CREATE INDEX idx_notes_title ON notes(title)');
  }
},
```

### Step 3: Handle Data Migration (if needed)

If you need to transform existing data, use `beforeOpen`:

```dart
beforeOpen: (details) async {
  await customStatement('PRAGMA foreign_keys = ON');

  if (details.hadUpgrade) {
    // Perform data transformations after schema upgrade
    // Example: Populate a new column based on existing data
    await customStatement('''
      UPDATE notes
      SET new_field = CASE
        WHEN some_condition THEN 'value1'
        ELSE 'value2'
      END
    ''');
  }
},
```

### Step 4: Update the Table Definition

Add the new column to your Drift table class:

```dart
class Notes extends Table {
  // ... existing columns ...

  TextColumn get yourNewColumn => text().nullable()(); // Add this
}
```

### Step 5: Regenerate Drift Code

Run build_runner to regenerate the database code:

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

### Step 6: Update Tests

Add tests for the migration:

```dart
test('migration from v1 to v2 should add new column', () async {
  // Test migration logic
});
```

## Migration Examples

### Example 1: Adding a Column

```dart
// Version 2: Add a 'tags' column
@override
int get schemaVersion => 2;

// In Notes table:
TextColumn get tags => text().nullable()();

// In onUpgrade:
if (from < 2) {
  await m.addColumn(notes, notes.tags);
}
```

### Example 2: Adding an Index

```dart
// Version 3: Add index for faster path lookups
@override
int get schemaVersion => 3;

// In onUpgrade:
if (from < 3) {
  await customStatement('CREATE INDEX idx_notes_path ON notes(path)');
}
```

### Example 3: Modifying FTS5 Table

**Warning:** FTS5 tables cannot be altered. You must recreate them.

```dart
// Version 4: Add tags to FTS5 search
@override
int get schemaVersion => 4;

// In onUpgrade:
if (from < 4) {
  // Drop old FTS table
  await customStatement('DROP TABLE IF EXISTS notes_fts');

  // Create new FTS table with additional column
  await customStatement('''
    CREATE VIRTUAL TABLE notes_fts USING fts5(
      title,
      content,
      tags
    )
  ''');

  // Rebuild FTS index from existing notes
  final allNotes = await select(notes).get();
  for (final note in allNotes) {
    final rowId = await customSelect(
      'SELECT rowid FROM notes WHERE id = ?',
      variables: [Variable.withString(note.id)],
      readsFrom: {notes},
    ).getSingle();

    await customStatement(
      'INSERT INTO notes_fts(rowid, title, content, tags) VALUES (?, ?, ?, ?)',
      [rowId.read<int>('rowid'), note.title ?? '', '', note.tags ?? ''],
    );
  }
}
```

### Example 4: Renaming a Column

**Note:** SQLite has limited ALTER TABLE support. Use this pattern:

```dart
// Version 5: Rename 'contentPreview' to 'excerpt'
@override
int get schemaVersion => 5;

// In onUpgrade:
if (from < 5) {
  // Create temporary table with new schema
  await customStatement('''
    CREATE TABLE notes_new (
      id TEXT PRIMARY KEY,
      path TEXT UNIQUE,
      title TEXT,
      lastKnownSha TEXT,
      isDirty INTEGER DEFAULT 0,
      updatedAt INTEGER,
      createdAt INTEGER,
      excerpt TEXT,  -- renamed from contentPreview
      contentLength INTEGER DEFAULT 0,
      isConflict INTEGER DEFAULT 0,
      markedForDeletion INTEGER DEFAULT 0
    )
  ''');

  // Copy data
  await customStatement('''
    INSERT INTO notes_new
    SELECT id, path, title, lastKnownSha, isDirty, updatedAt, createdAt,
           contentPreview, contentLength, isConflict, markedForDeletion
    FROM notes
  ''');

  // Drop old table and rename new one
  await customStatement('DROP TABLE notes');
  await customStatement('ALTER TABLE notes_new RENAME TO notes');
}
```

## Testing Migrations

### Test Template

```dart
test('migration from v1 to v2 works correctly', () async {
  // 1. Create a v1 database
  final dbV1 = NotesDatabase.test(NativeDatabase.memory());

  // 2. Insert test data with v1 schema
  await dbV1.insertNote(NotesCompanion(
    id: const Value('test-1'),
    path: const Value('notes/test.md'),
  ));

  // 3. Close v1 database
  await dbV1.close();

  // 4. Open with v2 schema (triggering migration)
  final dbV2 = NotesDatabase.test(NativeDatabase.memory());

  // 5. Verify data migrated correctly
  final note = await dbV2.getNoteById('test-1');
  expect(note, isNotNull);
  expect(note!.yourNewColumn, isNull); // New column exists

  await dbV2.close();
});
```

## Best Practices

### 1. Never Skip Version Numbers
```dart
// BAD: Jumping from 1 to 3
int get schemaVersion => 3;

// GOOD: Increment by 1
int get schemaVersion => 2;
```

### 2. Always Test Migrations
- Test migration from each previous version
- Test with real data, not just empty databases
- Test that existing data is preserved

### 3. Use Transactions for Complex Migrations
```dart
if (from < 2) {
  await transaction(() async {
    await m.addColumn(notes, notes.newColumn);
    await customStatement('UPDATE notes SET newColumn = defaultValue');
  });
}
```

### 4. Document Breaking Changes
If a migration requires app-level changes (e.g., clearing cache), document it:

```dart
// Version 6: BREAKING - Requires app to clear local files
// Reason: Changed path format from 'notes/' to 'markdown/'
if (from < 6) {
  // Migration logic...
  // NOTE: App must call FileService.clearAll() after upgrade
}
```

### 5. Preserve User Data
Always prefer additive changes over destructive ones:

```dart
// GOOD: Add new column, keep old one
await m.addColumn(notes, notes.newField);

// BAD: Drop column with user data (unless absolutely necessary)
await customStatement('ALTER TABLE notes DROP COLUMN oldField');
```

## Rollback Strategy

Drift doesn't support automatic rollback. If a migration fails:

1. The app will crash on database open
2. User must reinstall the app (loses local data) OR
3. Implement manual recovery:

```dart
onUpgrade: (Migrator m, int from, int to) async {
  try {
    // Attempt migration
    if (from < 2) {
      await m.addColumn(notes, notes.newColumn);
    }
  } catch (e) {
    // Log error for debugging
    print('Migration failed: $e');

    // Option: Reset to clean state (loses data)
    await customStatement('DROP TABLE IF EXISTS notes');
    await customStatement('DROP TABLE IF EXISTS notes_fts');
    await onCreate(m);
  }
},
```

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1 | 2025-01-13 | Initial schema: notes table + FTS5 search |

---

**When in doubt:** Test migrations with a copy of production data before releasing!
