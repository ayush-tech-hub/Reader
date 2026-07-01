import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Convert Markdown to HTML and preview the rendered output.
class MarkdownHtmlScreen extends StatefulWidget {
  const MarkdownHtmlScreen({super.key});

  @override
  State<MarkdownHtmlScreen> createState() => _MarkdownHtmlScreenState();
}

String _mdToHtml(String md) {
  // Line-by-line transform (covers common Markdown elements).
  final lines = md.split('\n');
  final buf = StringBuffer();
  bool inCode = false;
  bool inList = false;
  bool inOrderedList = false;

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];

    // Code fence
    if (line.trim().startsWith('```')) {
      if (inCode) {
        buf.writeln('</code></pre>');
        inCode = false;
      } else {
        if (inList) { buf.writeln('</ul>'); inList = false; }
        if (inOrderedList) { buf.writeln('</ol>'); inOrderedList = false; }
        final lang = line.trim().substring(3).trim();
        buf.writeln('<pre><code${lang.isNotEmpty ? ' class="language-$lang"' : ''}>');
        inCode = true;
      }
      continue;
    }

    if (inCode) {
      buf.writeln(_escHtml(line));
      continue;
    }

    // ATX headings
    if (line.startsWith('# ')) {
      if (inList) { buf.writeln('</ul>'); inList = false; }
      if (inOrderedList) { buf.writeln('</ol>'); inOrderedList = false; }
      buf.writeln('<h1>${_inline(line.substring(2))}</h1>');
    } else if (line.startsWith('## ')) {
      if (inList) { buf.writeln('</ul>'); inList = false; }
      if (inOrderedList) { buf.writeln('</ol>'); inOrderedList = false; }
      buf.writeln('<h2>${_inline(line.substring(3))}</h2>');
    } else if (line.startsWith('### ')) {
      if (inList) { buf.writeln('</ul>'); inList = false; }
      if (inOrderedList) { buf.writeln('</ol>'); inOrderedList = false; }
      buf.writeln('<h3>${_inline(line.substring(4))}</h3>');
    } else if (line.startsWith('#### ')) {
      buf.writeln('<h4>${_inline(line.substring(5))}</h4>');
    } else if (line.startsWith('##### ')) {
      buf.writeln('<h5>${_inline(line.substring(6))}</h5>');
    } else if (line.startsWith('###### ')) {
      buf.writeln('<h6>${_inline(line.substring(7))}</h6>');
    }
    // Blockquote
    else if (line.startsWith('> ')) {
      buf.writeln('<blockquote>${_inline(line.substring(2))}</blockquote>');
    }
    // Horizontal rule
    else if (RegExp(r'^[-*_]{3,}$').hasMatch(line.trim())) {
      buf.writeln('<hr>');
    }
    // Unordered list
    else if (line.startsWith('- ') || line.startsWith('* ')) {
      if (!inList) { buf.writeln('<ul>'); inList = true; }
      if (inOrderedList) { buf.writeln('</ol>'); inOrderedList = false; }
      buf.writeln('<li>${_inline(line.substring(2))}</li>');
    }
    // Ordered list
    else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
      if (!inOrderedList) { buf.writeln('<ol>'); inOrderedList = true; }
      if (inList) { buf.writeln('</ul>'); inList = false; }
      buf.writeln('<li>${_inline(RegExp(r'^\d+\.\s').stringMatch(line) != null ? line.replaceFirst(RegExp(r'^\d+\.\s'), '') : line)}</li>');
    }
    // Empty line
    else if (line.trim().isEmpty) {
      if (inList) { buf.writeln('</ul>'); inList = false; }
      if (inOrderedList) { buf.writeln('</ol>'); inOrderedList = false; }
      buf.writeln();
    }
    // Paragraph
    else {
      if (inList) { buf.writeln('</ul>'); inList = false; }
      if (inOrderedList) { buf.writeln('</ol>'); inOrderedList = false; }
      buf.writeln('<p>${_inline(line)}</p>');
    }
  }

  if (inCode) buf.writeln('</code></pre>');
  if (inList) buf.writeln('</ul>');
  if (inOrderedList) buf.writeln('</ol>');

  return buf.toString().trim();
}

String _escHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _inline(String s) {
  // Bold
  s = s.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m[1]}</strong>');
  s = s.replaceAllMapped(
      RegExp(r'__(.+?)__'), (m) => '<strong>${m[1]}</strong>');
  // Italic
  s = s.replaceAllMapped(
      RegExp(r'\*(.+?)\*'), (m) => '<em>${m[1]}</em>');
  s = s.replaceAllMapped(
      RegExp(r'_(.+?)_'), (m) => '<em>${m[1]}</em>');
  // Strikethrough
  s = s.replaceAllMapped(
      RegExp(r'~~(.+?)~~'), (m) => '<del>${m[1]}</del>');
  // Inline code
  s = s.replaceAllMapped(
      RegExp(r'`(.+?)`'), (m) => '<code>${_escHtml(m[1]!)}</code>');
  // Links
  s = s.replaceAllMapped(
      RegExp(r'\[(.+?)\]\((.+?)\)'),
      (m) => '<a href="${m[2]}">${m[1]}</a>');
  // Images
  s = s.replaceAllMapped(
      RegExp(r'!\[(.+?)\]\((.+?)\)'),
      (m) => '<img src="${m[2]}" alt="${m[1]}">');
  return s;
}

class _MarkdownHtmlScreenState extends State<MarkdownHtmlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _ctrl = TextEditingController(text: '''# Hello, World!

This is a **Markdown** example.

## Features

- Bold text with **asterisks**
- *Italic* text
- `inline code`
- [Links](https://example.com)

### Code block

```dart
void main() {
  print("Hello!");
}
```

> Blockquote example

---

1. Ordered item one
2. Ordered item two
''');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  String get _html => _mdToHtml(_ctrl.text);

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markdown → HTML'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Markdown'),
            Tab(text: 'HTML'),
            Tab(text: 'Preview'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy HTML',
            onPressed: () => _copy(_html),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Markdown editor
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Type Markdown here…',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // HTML output
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _html,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12, height: 1.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton.icon(
                  onPressed: () => _copy(_html),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy HTML'),
                ),
              ),
            ],
          ),
          // Rendered preview
          Markdown(data: _ctrl.text, selectable: true),
        ],
      ),
    );
  }
}
