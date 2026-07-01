import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Text-based hierarchical mind map with collapsible tree.
class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _Node {
  String id;
  String text;
  List<_Node> children;
  bool collapsed;

  _Node({
    required this.id,
    required this.text,
    List<_Node>? children,
    this.collapsed = false,
  }) : children = children ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        't': text,
        'ch': children.map((c) => c.toJson()).toList(),
        'cl': collapsed,
      };

  factory _Node.fromJson(Map<String, dynamic> j) => _Node(
        id: j['id'] as String,
        text: j['t'] as String,
        children: (j['ch'] as List?)
                ?.map((c) => _Node.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        collapsed: j['cl'] as bool? ?? false,
      );
}

const _prefKey = 'mindmap_v1';

class _MindMapScreenState extends State<MindMapScreen> {
  _Node _root = _Node(id: 'root', text: 'Central Idea');
  // Track all maps by name
  List<Map<String, dynamic>> _maps = [];
  int _currentMapIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final maps = (data['maps'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final idx = data['current'] as int? ?? 0;
      if (maps.isNotEmpty) {
        setState(() {
          _maps = maps;
          _currentMapIndex = idx.clamp(0, maps.length - 1);
          _root = _Node.fromJson(
              maps[_currentMapIndex]['root'] as Map<String, dynamic>);
        });
        return;
      }
    }
    // Default map
    _maps = [
      {'name': 'My Mind Map', 'root': _root.toJson()}
    ];
  }

  Future<void> _save() async {
    _maps[_currentMapIndex] = {
      'name': _maps[_currentMapIndex]['name'],
      'root': _root.toJson(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey,
        jsonEncode({'maps': _maps, 'current': _currentMapIndex}));
  }

  String _nextId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _addChild(_Node parent) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Child Node'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Text'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              setState(() => parent.children.add(
                    _Node(id: _nextId(), text: text),
                  ));
              _save();
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editNode(_Node node, _Node? parent) {
    final ctrl = TextEditingController(text: node.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Node'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Text'),
        ),
        actions: [
          if (parent != null)
            TextButton(
              onPressed: () {
                setState(() => parent.children.remove(node));
                _save();
                Navigator.pop(ctx);
              },
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error),
              child: const Text('Delete'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              setState(() => node.text = text);
              _save();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _newMap() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Mind Map'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Map name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final newRoot = _Node(id: 'root', text: name);
              setState(() {
                _maps.add({'name': name, 'root': newRoot.toJson()});
                _currentMapIndex = _maps.length - 1;
                _root = newRoot;
              });
              _save();
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_maps.isNotEmpty
            ? (_maps[_currentMapIndex]['name'] as String)
            : 'Mind Map'),
        actions: [
          if (_maps.length > 1)
            PopupMenuButton<int>(
              icon: const Icon(Icons.map_outlined),
              onSelected: (i) {
                setState(() {
                  _currentMapIndex = i;
                  _root = _Node.fromJson(
                      _maps[i]['root'] as Map<String, dynamic>);
                });
              },
              itemBuilder: (_) => [
                for (int i = 0; i < _maps.length; i++)
                  PopupMenuItem(
                    value: i,
                    child: Text(_maps[i]['name'] as String),
                  ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New map',
            onPressed: _newMap,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: _NodeWidget(
          node: _root,
          parent: null,
          depth: 0,
          onAddChild: _addChild,
          onEdit: _editNode,
          onToggle: (n) => setState(() {
            n.collapsed = !n.collapsed;
            _save();
          }),
        ),
      ),
    );
  }
}

// ─── Node Widget ─────────────────────────────────────────────────────────────

const _depthColors = [
  Color(0xFF1976D2),
  Color(0xFF388E3C),
  Color(0xFFF57C00),
  Color(0xFF7B1FA2),
  Color(0xFFD32F2F),
  Color(0xFF0097A7),
];

class _NodeWidget extends StatelessWidget {
  const _NodeWidget({
    required this.node,
    required this.parent,
    required this.depth,
    required this.onAddChild,
    required this.onEdit,
    required this.onToggle,
  });

  final _Node node;
  final _Node? parent;
  final int depth;
  final void Function(_Node) onAddChild;
  final void Function(_Node, _Node?) onEdit;
  final void Function(_Node) onToggle;

  @override
  Widget build(BuildContext context) {
    final color = _depthColors[depth % _depthColors.length];
    final hasChildren = node.children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (depth > 0)
              Container(
                width: depth * 20.0,
                height: 1,
                color: Colors.grey.withOpacity(0.4),
              ),
            if (hasChildren)
              GestureDetector(
                onTap: () => onToggle(node),
                child: Icon(
                  node.collapsed
                      ? Icons.chevron_right
                      : Icons.expand_more,
                  size: 18,
                  color: color,
                ),
              )
            else
              const SizedBox(width: 18),
            Flexible(
              child: GestureDetector(
                onLongPress: () => onEdit(node, parent),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(depth == 0 ? 0.2 : 0.1),
                    border: Border.all(color: color.withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    node.text,
                    style: TextStyle(
                      color: color,
                      fontWeight:
                          depth == 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, size: 16, color: color),
              tooltip: 'Add child',
              onPressed: () => onAddChild(node),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (!node.collapsed && hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.children
                  .map((child) => _NodeWidget(
                        node: child,
                        parent: node,
                        depth: depth + 1,
                        onAddChild: onAddChild,
                        onEdit: onEdit,
                        onToggle: onToggle,
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
