# GitHub Notes Path Configuration

## Overview

The **Notes Path** setting in GitHub configuration determines where your markdown notes are stored within your repository. This guide explains the different options and when to use each.

## Configuration Options

### Option 1: Root Level (Empty Path)

**Setting**: Leave the "Notes Path" field empty or enter `/`

```
Notes Path: (empty)
```

**Repository Structure**:
```
your-repo/
├── note-1.md
├── note-2.md
└── note-3.md
```

**Use this when**:
- Your repository is dedicated to notes only
- You want notes at the root level
- You're using a simple, flat structure

**Example**: If your GitHub repo `personal-notes` only contains markdown files, use an empty path.

---

### Option 2: Subdirectory

**Setting**: Enter a directory path (with or without trailing slash)

```
Notes Path: notes/
```
or
```
Notes Path: documents/personal/
```

**Repository Structure**:
```
your-repo/
├── README.md
├── .gitignore
└── notes/
    ├── note-1.md
    ├── note-2.md
    └── note-3.md
```

**Use this when**:
- Your repository contains other files besides notes
- You want to organize notes in a specific folder
- You're sharing the repo with other tools/projects

**Example**: If your repo contains code, docs, and notes, use `notes/` to keep them separate.

---

## Path Syntax

### Valid Paths

✅ `notes/` - Subdirectory named "notes"
✅ `documents/` - Subdirectory named "documents"
✅ `personal/journal/` - Nested subdirectories
✅ (empty) - Root level

### Invalid Paths

❌ `/notes/` - Leading slash (will be treated as root)
❌ `notes` - Missing trailing slash (will be auto-corrected to `notes/`)
❌ `../notes/` - Parent directory references

## How It Works

The app uses this path to:

1. **List Files**: Only show markdown files (`.md`, `.markdown`) in the specified path
2. **Create Notes**: New notes are saved to this path
3. **Sync**: Only files in this path are synced

### Path Filtering Logic

- **Empty/Root path**: Only files at root level (no subdirectories)
- **Specified path**: Only files starting with that path prefix

Example with `notes/` path:
```
✅ notes/example.md         - Included
✅ notes/work/project.md    - Included
❌ README.md                - Excluded
❌ docs/guide.md            - Excluded
```

## Troubleshooting

### Problem: "Found 0 markdown files"

**Symptoms**: Sync logs show `Found 0 markdown files in "notes/"` but you have files in GitHub.

**Solution**: Check if your files are actually in the configured path.

1. Check your GitHub repo structure
2. Verify where your `.md` files are located
3. Update the "Notes Path" setting to match

**Example**:
- If files are at root: Set path to empty
- If files are in `docs/`: Set path to `docs/`
- If files are in `my-notes/`: Set path to `my-notes/`

---

### Problem: Sync Not Working

**Checklist**:
1. ✅ Personal Access Token is valid
2. ✅ Repository owner/name is correct
3. ✅ Branch name is correct (usually `main` or `master`)
4. ✅ **Notes Path matches your repo structure**
5. ✅ Token has `Contents` read/write permission

---

### Problem: Files Not Appearing in List

**Possible Causes**:
- Files are in wrong directory
- Files don't have `.md` or `.markdown` extension
- Path configuration doesn't match repo structure

**Debug Steps**:
1. Go to Settings → GitHub
2. Check the "Notes Path" field
3. Visit your GitHub repo in browser
4. Compare the path in settings with actual file locations
5. Update path if they don't match

---

## Migration Guide

### Moving from Root to Subdirectory

If you started with files at root and want to organize them:

1. In GitHub, create a new folder (e.g., `notes/`)
2. Move your `.md` files into that folder
3. In Pinboard Wizard Settings → GitHub:
   - Update "Notes Path" to `notes/`
   - Click "Save and Validate"
4. Click "Sync Now" to reload the file list

### Moving from Subdirectory to Root

If you want to simplify and move files to root:

1. In GitHub, move files from `notes/` to repository root
2. In Pinboard Wizard Settings → GitHub:
   - Clear the "Notes Path" field (leave it empty)
   - Click "Save and Validate"
3. Click "Sync Now" to reload the file list

---

## Best Practices

### ✅ Recommended

- **Use a subdirectory** if your repo has mixed content
- **Use root level** if your repo is notes-only
- **Keep it simple** - avoid deep nesting
- **Be consistent** - decide on a structure and stick to it

### ❌ Avoid

- Changing paths frequently (causes re-downloads)
- Using special characters in path names
- Mixing notes across multiple directories
- Using paths with spaces

---

## Examples

### Example 1: Dedicated Notes Repo

**Repo**: `github.com/username/notes`

**Content**: Only markdown notes

**Configuration**:
```
Owner: username
Repo: notes
Branch: main
Notes Path: (empty)
```

---

### Example 2: Project Repo with Notes

**Repo**: `github.com/username/my-project`

**Content**: Code, documentation, and personal notes

**Configuration**:
```
Owner: username
Repo: my-project
Branch: main
Notes Path: personal-notes/
```

**Structure**:
```
my-project/
├── src/
├── docs/
├── README.md
└── personal-notes/
    ├── ideas.md
    └── tasks.md
```

---

### Example 3: Nested Organization

**Repo**: `github.com/username/knowledge-base`

**Content**: Organized knowledge management

**Configuration**:
```
Owner: username
Repo: knowledge-base
Branch: main
Notes Path: work/daily-notes/
```

**Structure**:
```
knowledge-base/
├── personal/
├── work/
│   ├── daily-notes/
│   │   ├── 2024-01-15.md
│   │   └── 2024-01-16.md
│   └── projects/
└── learning/
```

---

## Summary

| Scenario | Notes Path Setting | Result |
|----------|-------------------|--------|
| Notes-only repo | (empty) | Files at root level |
| Mixed content repo | `notes/` | Files in notes/ folder |
| Organized structure | `work/journal/` | Files in work/journal/ |

**Key Point**: The "Notes Path" must match where your `.md` files actually exist in your GitHub repository.

---

## Need Help?

If you're still having issues:

1. Check the sync logs (displayed during sync operations)
2. Verify your repository structure in GitHub web interface
3. Ensure the path setting exactly matches your folder structure
4. Try an empty path first if you're unsure

The app will show you exactly how many files it found in the logs, which helps diagnose path issues.
