import 'package:flutter/widgets.dart';

/// Plugin architecture: a [DocumentPlugin] teaches the app to open a new
/// document type. Built-in readers (Markdown, EPUB, comics) register
/// through the same interface third parties would use — nothing in the
/// file browser is hardcoded to them.
abstract interface class DocumentPlugin {
  /// Unique id, e.g. 'opendocs.markdown'.
  String get id;

  /// Lower-case extensions (with dot) this plugin opens.
  Set<String> get extensions;

  /// Builds the viewer for [path].
  Widget buildViewer(BuildContext context, String path);
}

/// App-wide registry. Register in main() / plugin packages; the file
/// browser asks [forPath] when it encounters an unknown extension.
class PluginRegistry {
  PluginRegistry._();

  static final PluginRegistry instance = PluginRegistry._();

  final List<DocumentPlugin> _plugins = [];

  void register(DocumentPlugin plugin) {
    _plugins.removeWhere((p) => p.id == plugin.id);
    _plugins.add(plugin);
  }

  List<DocumentPlugin> get plugins => List.unmodifiable(_plugins);

  DocumentPlugin? forPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = path.substring(dot).toLowerCase();
    for (final plugin in _plugins) {
      if (plugin.extensions.contains(ext)) return plugin;
    }
    return null;
  }
}
