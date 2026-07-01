import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DocNote {
  DocNote({
    required this.documentPath,
    required this.page,
    required this.text,
    required this.updatedAt,
  });

  final String documentPath;
  final int page;
  String text;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'documentPath': documentPath,
        'page': page,
        'text': text,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory DocNote.fromJson(Map<String, dynamic> json) => DocNote(
        documentPath: json['documentPath'] as String,
        page: json['page'] as int,
        text: json['text'] as String,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          json['updatedAt'] as int,
        ),
      );
}

/// Stores per-page reading notes as a JSON list in SharedPreferences.
class NotesService {
  static const _key = 'reading_notes_v1';

  Future<List<DocNote>> getNotesForDocument(String documentPath) async {
    final all = await _load();
    return all.where((n) => n.documentPath == documentPath).toList()
      ..sort((a, b) => a.page.compareTo(b.page));
  }

  Future<List<DocNote>> getAllNotes() async {
    final all = await _load();
    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
  }

  Future<DocNote?> getNoteForPage(String documentPath, int page) async {
    final all = await _load();
    try {
      return all.firstWhere(
        (n) => n.documentPath == documentPath && n.page == page,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveNote({
    required String documentPath,
    required int page,
    required String text,
  }) async {
    final all = await _load();
    final idx = all.indexWhere(
      (n) => n.documentPath == documentPath && n.page == page,
    );
    final note = DocNote(
      documentPath: documentPath,
      page: page,
      text: text,
      updatedAt: DateTime.now(),
    );
    if (idx >= 0) {
      all[idx] = note;
    } else {
      all.add(note);
    }
    await _save(all);
  }

  Future<void> deleteNote(String documentPath, int page) async {
    final all = await _load();
    all.removeWhere((n) => n.documentPath == documentPath && n.page == page);
    await _save(all);
  }

  Future<List<DocNote>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => DocNote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<DocNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(notes.map((n) => n.toJson()).toList()));
  }
}
