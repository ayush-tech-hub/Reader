import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key});

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _Quote {
  const _Quote(this.text, this.author, this.category);
  final String text;
  final String author;
  final String category;
}

const _quotes = [
  _Quote('A reader lives a thousand lives before he dies. The man who never reads lives only one.', 'George R.R. Martin', 'Reading'),
  _Quote('Not all those who wander are lost.', 'J.R.R. Tolkien', 'Adventure'),
  _Quote('The more that you read, the more things you will know. The more that you learn, the more places you\'ll go.', 'Dr. Seuss', 'Reading'),
  _Quote('I have always imagined that Paradise will be a kind of library.', 'Jorge Luis Borges', 'Books'),
  _Quote('Books are a uniquely portable magic.', 'Stephen King', 'Books'),
  _Quote('So many books, so little time.', 'Frank Zappa', 'Reading'),
  _Quote('A book is a dream that you hold in your hands.', 'Neil Gaiman', 'Books'),
  _Quote('One must always be careful of books, and what is inside them, for words have the power to change us.', 'Cassandra Clare', 'Books'),
  _Quote('The reading of all good books is like a conversation with the finest minds of past centuries.', 'René Descartes', 'Reading'),
  _Quote('If you only read the books that everyone else is reading, you can only think what everyone else is thinking.', 'Haruki Murakami', 'Wisdom'),
  _Quote('Sleep is good, death is better; but of course, the best thing would to have never been born at all.', 'Heinrich Heine', 'Life'),
  _Quote('There is no friend as loyal as a book.', 'Ernest Hemingway', 'Books'),
  _Quote('Good friends, good books, and a sleepy conscience: this is the ideal life.', 'Mark Twain', 'Life'),
  _Quote('Classic — a book which people praise and don\'t read.', 'Mark Twain', 'Humor'),
  _Quote('Be careful about reading health books. You may die of a misprint.', 'Mark Twain', 'Humor'),
  _Quote('The books that the world calls immoral are books that show the world its own shame.', 'Oscar Wilde', 'Wisdom'),
  _Quote('I cannot live without books.', 'Thomas Jefferson', 'Books'),
  _Quote('No two persons ever read the same book.', 'Edmund Wilson', 'Reading'),
  _Quote('One must read everything, then one has the material to know the relative worth of things.', 'Friedrich Nietzsche', 'Wisdom'),
  _Quote('Reading is to the mind what exercise is to the body.', 'Joseph Addison', 'Reading'),
  _Quote('I took a speed reading course and read War and Peace in twenty minutes. It involves Russia.', 'Woody Allen', 'Humor'),
  _Quote('We read to know we are not alone.', 'C.S. Lewis', 'Reading'),
  _Quote('Outside of a dog, a book is man\'s best friend. Inside of a dog it\'s too dark to read.', 'Groucho Marx', 'Humor'),
  _Quote('The world belongs to those who read.', 'Rick Holland', 'Reading'),
  _Quote('Today a reader, tomorrow a leader.', 'Margaret Fuller', 'Motivation'),
  _Quote('Reading gives us someplace to go when we have to stay where we are.', 'Mason Cooley', 'Reading'),
  _Quote('A capacity and taste for reading gives access to whatever has already been discovered by others.', 'Abraham Lincoln', 'Wisdom'),
  _Quote('Think before you speak. Read before you think.', 'Fran Lebowitz', 'Wisdom'),
  _Quote('I find television very educational. Every time someone turns it on, I go in the other room and read a book.', 'Groucho Marx', 'Humor'),
  _Quote('Once you learn to read, you will be forever free.', 'Frederick Douglass', 'Motivation'),
  _Quote('The person who deserves most pity is a lonesome one on a rainy day who doesn\'t know how to read.', 'Benjamin Franklin', 'Reading'),
  _Quote('Literature adds to reality, it does not simply describe it.', 'C.S. Lewis', 'Literature'),
  _Quote('Every book you pick up has its own lesson or lessons, and quite often the bad books have more to teach than the good ones.', 'Stephen King', 'Writing'),
  _Quote('If you want to be a writer, you must do two things above all others: read a lot and write a lot.', 'Stephen King', 'Writing'),
  _Quote('The best stories don\'t come from \'good vs. evil\' but \'good vs. good\'.', 'Leo Tolstoy', 'Writing'),
  _Quote('Words are our most inexhaustible source of magic.', 'J.K. Rowling', 'Writing'),
  _Quote('It does not do to dwell on dreams and forget to live.', 'J.K. Rowling', 'Life'),
  _Quote('We are all stories, in the end. Just make it a good one, eh?', 'Doctor Who', 'Life'),
  _Quote('A room without books is like a body without a soul.', 'Marcus Tullius Cicero', 'Books'),
  _Quote('Some books are so familiar that reading them is like being home again.', 'Louisa May Alcott', 'Books'),
  _Quote('Literature is the most agreeable way of ignoring life.', 'Fernando Pessoa', 'Literature'),
  _Quote('The unread story is not a story; it is little black marks on wood pulp.', 'Ursula K. Le Guin', 'Books'),
  _Quote('A great book should leave you with many experiences, and slightly exhausted at the end.', 'William Styron', 'Literature'),
  _Quote('Until I feared I would lose it, I never loved to read. One does not love breathing.', 'Harper Lee', 'Reading'),
  _Quote('Not all readers are leaders, but all leaders are readers.', 'Harry S Truman', 'Motivation'),
  _Quote('Books are mirrors: we only see in them what we already have inside us.', 'Carlos Ruiz Zafón', 'Books'),
  _Quote('There is nothing better than a friend, unless it is a friend with chocolate.', 'Linda Grayson', 'Humor'),
  _Quote('I do believe something very magical can happen when you read a good book.', 'J.K. Rowling', 'Reading'),
  _Quote('A word after a word after a word is power.', 'Margaret Atwood', 'Writing'),
  _Quote('Write what should not be forgotten.', 'Isabel Allende', 'Writing'),
  _Quote('Fiction is the lie through which we tell the truth.', 'Albert Camus', 'Literature'),
];

class _QuoteScreenState extends State<QuoteScreen> {
  static const _favsKey = 'favourite_quotes_v1';
  final _rng = Random();
  _Quote? _current;
  Set<String> _favourites = {};
  bool _loaded = false;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _loadFavourites().then((_) => _newQuote());
  }

  Future<void> _loadFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favsKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _favourites = list.map((e) => e as String).toSet();
      } catch (_) {}
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _favsKey, jsonEncode(_favourites.toList()));
  }

  void _newQuote() {
    final pool = _filter == null
        ? _quotes
        : _quotes.where((q) => q.category == _filter).toList();
    if (pool.isEmpty) return;
    setState(() => _current = pool[_rng.nextInt(pool.length)]);
  }

  bool get _isFav => _current != null && _favourites.contains(_current!.text);

  void _toggleFav() {
    if (_current == null) return;
    setState(() {
      if (_isFav) {
        _favourites.remove(_current!.text);
      } else {
        _favourites.add(_current!.text);
      }
    });
    _saveFavourites();
  }

  List<String> get _categories =>
      _quotes.map((q) => q.category).toSet().toList()..sort();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Quotes'),
        actions: [
          if (_favourites.isNotEmpty)
            Badge(
              label: Text('${_favourites.length}'),
              child: IconButton(
                icon: const Icon(Icons.favorite_border),
                tooltip: 'Favourites',
                onPressed: () => _showFavourites(context),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) {
                    setState(() => _filter = null);
                    _newQuote();
                  },
                ),
                for (final cat in _categories)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: _filter == cat,
                      onSelected: (_) {
                        setState(() => _filter = cat);
                        _newQuote();
                      },
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: _current == null
                ? const Center(child: CircularProgressIndicator())
                : GestureDetector(
                    onHorizontalDragEnd: (d) {
                      if (d.velocity.pixelsPerSecond.dx.abs() > 200) {
                        _newQuote();
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.format_quote,
                              size: 48,
                              color: scheme.primary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            '"${_current!.text}"',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '— ${_current!.author}',
                            style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(_current!.category),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border,
                      color: _isFav ? Colors.red : null),
                  tooltip: _isFav ? 'Unfavourite' : 'Favourite',
                  onPressed: _toggleFav,
                ),
                FilledButton.icon(
                  onPressed: _newQuote,
                  icon: const Icon(Icons.refresh),
                  label: const Text('New Quote'),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy',
                  onPressed: _current == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(
                              text:
                                  '"${_current!.text}"\n— ${_current!.author}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Quote copied!')),
                          );
                        },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Swipe left/right for a new quote',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showFavourites(BuildContext context) {
    final favQuotes =
        _quotes.where((q) => _favourites.contains(q.text)).toList();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: favQuotes.length,
        itemBuilder: (_, i) {
          final q = favQuotes[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('"${q.text}"',
                  style: const TextStyle(fontSize: 13, height: 1.4)),
              subtitle: Text('— ${q.author}'),
              trailing: IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red, size: 18),
                onPressed: () {
                  setState(() => _favourites.remove(q.text));
                  _saveFavourites();
                  Navigator.pop(ctx);
                  if (_favourites.isNotEmpty) _showFavourites(context);
                },
              ),
              onTap: () {
                setState(() => _current = q);
                Navigator.pop(ctx);
              },
            ),
          );
        },
      ),
    );
  }
}
