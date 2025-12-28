# Enhanced Markdown Editor Features

The Pinboard Wizard notes feature includes a powerful, GitHub-flavored markdown editor with live preview capabilities.

## Key Features

### 🎨 Display Modes

The editor supports three display modes, accessible via toggle buttons in the toolbar:

- **Edit Mode**: Full-width markdown editor for focused writing
- **Split Mode**: Side-by-side editor and live preview (default)
- **Preview Mode**: Full-width rendered preview for reading

### ⌨️ Keyboard Shortcuts

Common markdown formatting can be applied using keyboard shortcuts:

| Shortcut | Action |
|----------|--------|
| `⌘B` / `Ctrl+B` | **Bold** text |
| `⌘I` / `Ctrl+I` | *Italic* text |
| `⌘K` / `Ctrl+K` | Insert link |
| `⌘E` / `Ctrl+E` | `Inline code` |
| `⌘⇧C` / `Ctrl+Shift+C` | Code block |

### 🛠️ Formatting Toolbar

The toolbar provides one-click access to all markdown formatting options:

#### Text Formatting
- **Bold** (`**text**`)
- *Italic* (`_text_`)
- ~~Strikethrough~~ (`~~text~~`)

#### Headings
- Dropdown menu for all heading levels (H1-H6)
- `# Heading 1` through `###### Heading 6`

#### Links & Images
- **Link**: `[link text](url)`
- **Image**: `![alt text](image-url)`

#### Lists
- **Bullet List**: `- item`
- **Numbered List**: `1. item`
- **Task List**: `- [ ] task` (GitHub-flavored)

#### Code
- **Inline Code**: `` `code` ``
- **Code Block**:
  ```
  ```language
  code here
  ```
  ```

#### Block Elements
- **Blockquote**: `> quote`
- **Table**: Auto-generates markdown table template
- **Horizontal Rule**: `---`

### 📝 GitHub-Flavored Markdown Support

The editor uses GitHub-flavored markdown (GFM) for maximum compatibility:

- ✅ **Tables** with alignment
- ✅ **Task lists** (checkboxes)
- ✅ **Strikethrough** text
- ✅ **Autolinks** for URLs
- ✅ **Fenced code blocks** with syntax highlighting
- ✅ **Emoji** support (`:emoji_name:`)

### 🎯 Live Preview

The preview pane renders markdown in real-time as you type, showing:

- Properly styled headings, paragraphs, and lists
- Syntax-highlighted code blocks
- Formatted tables with borders
- Styled blockquotes
- Working links (clickable)
- Rendered images
- Task list checkboxes
- Dark/light mode support

### 💾 Auto-Save & Sync

- **Character count** displayed in the footer
- **Unsaved changes** indicator
- **Save button** enabled only when changes are present
- **Auto-sync** to GitHub when saved (if credentials configured)

## Usage Tips

### Creating Headers

Use the heading dropdown or type directly:
```markdown
# Main Title
## Section Title
### Subsection
```

### Creating Links

1. Select the text you want to link
2. Click the link button or press `⌘K`
3. Replace "url" with your actual URL

### Creating Tables

1. Click the table button
2. Edit the auto-generated template:
```markdown
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |
```

### Task Lists

Perfect for TODO items:
```markdown
- [x] Completed task
- [ ] Pending task
- [ ] Another pending task
```

### Code Blocks

For syntax-highlighted code:
````markdown
```dart
void main() {
  print('Hello, World!');
}
```
````

### Blockquotes

For quotes or callouts:
```markdown
> This is a blockquote.
> It can span multiple lines.
```

## Dark Mode Support

The editor automatically adapts to your system's dark/light mode:

- **Editor**: Syntax-friendly color scheme
- **Preview**: Proper contrast for all markdown elements
- **Toolbar**: Theme-aware icons and buttons

## Best Practices

1. **Use Split Mode** for the best editing experience
2. **Preview Mode** is great for reviewing finished notes
3. **Keyboard shortcuts** speed up formatting significantly
4. **Save frequently** to ensure your work is synced to GitHub
5. **Use headers** to organize long notes for better searchability

## Limitations

- **No inline HTML**: Pure markdown only (security/simplicity)
- **Image URLs**: Must be absolute URLs or GitHub-hosted
- **No file uploads**: Images must be hosted externally
- **Local-first**: Requires GitHub sync for backup/sharing

## Examples

### Meeting Notes
```markdown
# Team Meeting - 2024-01-15

## Attendees
- Alice
- Bob
- Charlie

## Agenda
1. Project updates
2. Timeline review
3. Action items

## Action Items
- [ ] Alice: Update documentation
- [ ] Bob: Review PR #123
- [ ] Charlie: Deploy to staging

## Notes
> Important: Deadline is next Friday!

See [project board](https://github.com/org/repo/projects/1) for details.
```

### Code Documentation
````markdown
# API Integration Guide

## Authentication

First, obtain an API key:

```bash
curl -X POST https://api.example.com/auth
```

## Making Requests

Use the following pattern:

```dart
final response = await http.get(
  Uri.parse('https://api.example.com/data'),
  headers: {'Authorization': 'Bearer $token'},
);
```

## Error Handling

| Status | Meaning |
|--------|---------|
| 200    | Success |
| 401    | Unauthorized |
| 404    | Not Found |
````

---

For more markdown syntax help, see:
- [GitHub Markdown Guide](https://guides.github.com/features/mastering-markdown/)
- [CommonMark Spec](https://commonmark.org/)
