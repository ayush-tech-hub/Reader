import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// A quick-reference Markdown cheat sheet.
///
/// Rendered using [MarkdownBody] so the preview looks exactly as it
/// would in the app's own Markdown editor.
class MarkdownCheatsheetScreen extends StatelessWidget {
  const MarkdownCheatsheetScreen({super.key});

  static const _md = r'''
# Markdown Cheat Sheet

## Headings

```
# Heading 1
## Heading 2
### Heading 3
```

## Emphasis

| Syntax | Result |
|--------|--------|
| `**bold**` | **bold** |
| `_italic_` | _italic_ |
| `~~strikethrough~~` | ~~strikethrough~~ |
| `` `inline code` `` | `inline code` |

## Lists

**Unordered:**
```
- Item one
- Item two
  - Nested item
```

**Ordered:**
```
1. First
2. Second
3. Third
```

## Links & Images

```
[Link text](https://example.com)
![Alt text](image.png)
```

## Blockquote

```
> This is a blockquote.
> It can span multiple lines.
```

> This is a blockquote.

## Code Block

````
```dart
void main() {
  print('Hello, world!');
}
```
````

## Horizontal Rule

```
---
```

---

## Table

```
| Column 1 | Column 2 |
|----------|----------|
| Cell A   | Cell B   |
```

| Column 1 | Column 2 |
|----------|----------|
| Cell A   | Cell B   |

## Task List

```
- [x] Done
- [ ] Not done
```

## Inline HTML

```html
<br>  <strong>bold</strong>  <em>italic</em>
```

## Escape Special Characters

Prefix any Markdown character with `\` to display it literally:
`\* \_ \# \[ \]`
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Markdown Reference')),
      body: Markdown(
        data: _md,
        selectable: true,
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}
