# Markdown Quick Reference

Quick reference guide for the Pinboard Wizard markdown editor.

## Keyboard Shortcuts

| Shortcut | Action | Result |
|----------|--------|--------|
| `⌘B` or `Ctrl+B` | Bold | `**text**` |
| `⌘I` or `Ctrl+I` | Italic | `_text_` |
| `⌘K` or `Ctrl+K` | Link | `[text](url)` |
| `⌘E` or `Ctrl+E` | Inline Code | `` `code` `` |
| `⌘⇧C` or `Ctrl+Shift+C` | Code Block | ` ```code``` ` |

## Display Modes

- **Edit**: Full-width editor for focused writing
- **Split**: Editor + live preview side-by-side *(recommended)*
- **Preview**: Full-width rendered markdown

Toggle modes using the buttons at the top-left of the toolbar.

## Text Formatting

```markdown
**bold text**
_italic text_
~~strikethrough~~
`inline code`
```

## Headings

```markdown
# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6
```

*Tip: Use the heading dropdown in the toolbar*

## Lists

### Bullet List
```markdown
- Item 1
- Item 2
  - Nested item
```

### Numbered List
```markdown
1. First item
2. Second item
3. Third item
```

### Task List
```markdown
- [x] Completed task
- [ ] Pending task
- [ ] Another task
```

## Links & Images

### Link
```markdown
[Link text](https://example.com)
```

### Image
```markdown
![Alt text](https://example.com/image.png)
```

## Code

### Inline Code
```markdown
Use `console.log()` to print
```

### Code Block
````markdown
```javascript
function hello() {
  console.log('Hello, World!');
}
```
````

*Tip: Specify language after opening backticks for syntax highlighting*

## Blockquotes

```markdown
> This is a blockquote.
> It can span multiple lines.
>
> And have multiple paragraphs.
```

## Tables

```markdown
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |
```

*Tip: Use the table button to insert a template*

### Table Alignment

```markdown
| Left | Center | Right |
|:-----|:------:|------:|
| L1   | C1     | R1    |
| L2   | C2     | R2    |
```

## Horizontal Rule

```markdown
---
```

or

```markdown
***
```

## Advanced Features

### Emoji

```markdown
:smile: :heart: :rocket:
```

### Escaping Characters

Use backslash to escape special characters:

```markdown
\* Not a bullet point
\# Not a heading
```

### Line Breaks

- **Hard break**: Two spaces at end of line
- **Paragraph**: Blank line between blocks

## Common Patterns

### Meeting Notes
```markdown
# Team Meeting - 2024-01-15

## Attendees
- Alice
- Bob

## Action Items
- [ ] Alice: Update docs
- [ ] Bob: Review PR

## Notes
> Deadline: Friday
```

### Code Documentation
````markdown
# API Guide

## Authentication

```bash
curl -X POST https://api.example.com/auth
```

## Usage

```dart
final response = await http.get(url);
```
````

### Project Planning
```markdown
# Project: New Feature

## Timeline
| Phase | Duration | Status |
|-------|----------|--------|
| Design | 1 week | ✅ Done |
| Dev | 2 weeks | 🚧 In Progress |
| Test | 1 week | ⏳ Pending |

## Tasks
- [x] Create wireframes
- [x] Get approval
- [ ] Implement backend
- [ ] Write tests
```

## Tips & Tricks

1. **Use Split Mode** for the best experience - see your changes in real-time
2. **Keyboard shortcuts** are faster than clicking toolbar buttons
3. **Headers** make notes searchable - use them liberally
4. **Task lists** are perfect for TODO items
5. **Code blocks** preserve formatting and add syntax highlighting
6. **Save often** - changes auto-sync to GitHub when saved
7. **Preview mode** is great for final review before saving

## GitHub Flavored Markdown

This editor supports **GitHub Flavored Markdown (GFM)**, which means:

- ✅ Tables with alignment
- ✅ Task lists (checkboxes)
- ✅ Strikethrough text
- ✅ Automatic URL linking
- ✅ Fenced code blocks
- ✅ Emoji codes

## What's NOT Supported

- ❌ Inline HTML (security/simplicity)
- ❌ Local file references (must use URLs)
- ❌ File uploads (images must be hosted)
- ❌ Custom CSS/styling

## Need More Help?

See the full documentation:
- [Markdown Features Guide](MARKDOWN_FEATURES.md)
- [GitHub Markdown Guide](https://guides.github.com/features/mastering-markdown/)
- [CommonMark Spec](https://commonmark.org/)

---

**Character Count**: Displayed in the editor footer
**Auto-Save**: Save button enables when you make changes
**Dark Mode**: Automatically follows system theme
