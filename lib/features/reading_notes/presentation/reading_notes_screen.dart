import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/notes_service.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _notesServiceProvider = Provider<NotesService>((_) => NotesService());

final _allNotesProvider = FutureProvider<List<DocNote>>((ref) async {
  return ref.watch(_notesServiceProvider).getAllNotes();
});

// ── Notes overview screen ─────────────────────────────────────────────────────

class ReadingNotesScreen extends ConsumerWidget {
  const ReadingNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_allNotesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reading Notes')),
      body: async.when(
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Text(
                'No notes yet.\nOpen a document and add notes per page.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline),
              ),
            );
          }

          final grouped = <String, List<DocNote>>{};
          for (final n in notes) {
            grouped.putIfAbsent(n.documentPath, () => []).add(n);
          }
          final docs = grouped.keys.toList();

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final docPath = docs[i];
              final docNotes = grouped[docPath]!;
              return _DocGroup(
                docPath: docPath,
                notes: docNotes,
                service: ref.read(_notesServiceProvider),
                onChanged: () => ref.invalidate(_allNotesProvider),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DocGroup extends StatelessWidget {
  const _DocGroup({
    required this.docPath,
    required this.notes,
    required this.service,
    required this.onChanged,
  });

  final String docPath;
  final List<DocNote> notes;
  final NotesService service;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(Icons.picture_as_pdf, color: scheme.primary),
          title: Text(
            p.basenameWithoutExtension(docPath),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: scheme.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            '${notes.length} note${notes.length != 1 ? 's' : ''}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
        ),
        for (final note in notes)
          Dismissible(
            key: ValueKey('${note.documentPath}-${note.page}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: scheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: Icon(Icons.delete_outline, color: scheme.onError),
            ),
            onDismissed: (_) async {
              await service.deleteNote(note.documentPath, note.page);
              onChanged();
            },
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: InkWell(
                onTap: () => _editNote(context, note),
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: note.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'p.${note.page}',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _relative(note.updatedAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        note.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const Divider(),
      ],
    );
  }

  void _editNote(BuildContext context, DocNote note) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NoteEditor(note: note, service: service, onSaved: onChanged),
    );
  }

  static String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }
}

// ── Per-document note editor (bottom sheet) ──────────────────────────────────

class NoteEditorSheet extends StatelessWidget {
  const NoteEditorSheet({
    super.key,
    required this.documentPath,
    required this.page,
  });

  final String documentPath;
  final int page;

  static Future<void> show(
    BuildContext context, {
    required String documentPath,
    required int page,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => NoteEditorSheet(
        documentPath: documentPath,
        page: page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _NoteEditorLoader(documentPath: documentPath, page: page);
  }
}

class _NoteEditorLoader extends StatefulWidget {
  const _NoteEditorLoader({
    required this.documentPath,
    required this.page,
  });

  final String documentPath;
  final int page;

  @override
  State<_NoteEditorLoader> createState() => _NoteEditorLoaderState();
}

class _NoteEditorLoaderState extends State<_NoteEditorLoader> {
  final _service = NotesService();
  final _ctrl = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _service.getNoteForPage(widget.documentPath, widget.page).then((note) {
      if (mounted) {
        _ctrl.text = note?.text ?? '';
        setState(() => _loaded = true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return _NoteEditorForm(
      documentPath: widget.documentPath,
      page: widget.page,
      controller: _ctrl,
      service: _service,
      onSaved: () {},
    );
  }
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({
    required this.note,
    required this.service,
    required this.onSaved,
  });

  final DocNote note;
  final NotesService service;
  final VoidCallback onSaved;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _ctrl = TextEditingController(text: widget.note.text);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _NoteEditorForm(
      documentPath: widget.note.documentPath,
      page: widget.note.page,
      controller: _ctrl,
      service: widget.service,
      onSaved: widget.onSaved,
    );
  }
}

class _NoteEditorForm extends StatelessWidget {
  const _NoteEditorForm({
    required this.documentPath,
    required this.page,
    required this.controller,
    required this.service,
    required this.onSaved,
  });

  final String documentPath;
  final int page;
  final TextEditingController controller;
  final NotesService service;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Note — Page $page',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    await service.deleteNote(documentPath, page);
                  } else {
                    await service.saveNote(
                      documentPath: documentPath,
                      page: page,
                      text: text,
                    );
                  }
                  onSaved();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 6,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write your note here…',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
