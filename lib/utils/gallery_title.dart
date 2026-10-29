/// The parts of a conventionally named gallery title:
///
/// `(Event) [Circle (Artist)] Title (Parody) [Language] [Extras]`
///
/// Every part but [title] is optional; anything that does not fit the
/// convention stays in [title], so nothing a reader needs is ever dropped.
class GalleryTitleParts {
  const GalleryTitleParts({
    required this.title,
    this.event = '',
    this.circle = '',
    this.artist = '',
    this.parody = '',
    this.language = '',
    this.extras = const <String>[],
  });

  /// Splits [raw]. Brackets are only taken from the two ends of the title;
  /// a bracket in the middle belongs to the title itself.
  factory GalleryTitleParts.parse(String raw) {
    var rest = raw.trim();
    var event = '';
    var circle = '';
    var artist = '';
    var parody = '';
    var language = '';
    final extras = <String>[];

    // Leading groups: (Event) then [Circle (Artist)].
    var sawAuthor = false;
    while (rest.isNotEmpty) {
      final group = _leadingGroup(rest);
      if (group == null) {
        break;
      }
      final inner = group.inner.trim();
      if (group.open == '(' && !sawAuthor && event.isEmpty) {
        event = inner;
      } else if (group.open == '[' && !sawAuthor) {
        sawAuthor = true;
        final match = RegExp(r'^(.*?)\s*\(([^()]+)\)$').firstMatch(inner);
        if (match != null && match.group(1)!.trim().isNotEmpty) {
          circle = match.group(1)!.trim();
          artist = match.group(2)!.trim();
        } else {
          artist = inner;
        }
      } else if (inner.isNotEmpty) {
        extras.add(inner);
      }
      rest = rest.substring(group.length).trim();
    }

    // Trailing groups, read from the end: [Language] [Extras] (Parody).
    final trailing = <String>[];
    while (rest.isNotEmpty) {
      final group = _trailingGroup(rest);
      if (group == null) {
        break;
      }
      final inner = group.inner.trim();
      if (group.open == '[' && language.isEmpty && _isLanguage(inner)) {
        language = inner;
      } else if (group.open == '(' && parody.isEmpty) {
        parody = inner;
      } else if (inner.isNotEmpty) {
        trailing.insert(0, inner);
      }
      rest = rest.substring(0, rest.length - group.length).trim();
    }
    extras.addAll(trailing);

    // "English title | Japanese title": the first half reads on its own.
    var title = rest.split('|').first.trim();
    if (title.isEmpty) {
      title = rest.isNotEmpty ? rest : raw.trim();
    }

    return GalleryTitleParts(
      title: title,
      event: event,
      circle: circle,
      artist: artist,
      parody: parody,
      language: language,
      extras: List<String>.unmodifiable(extras),
    );
  }

  final String title;
  final String event;
  final String circle;
  final String artist;
  final String parody;
  final String language;
  final List<String> extras;

  /// "Circle · Artist", or whichever of the two is present.
  String get byline =>
      <String>[circle, artist].where((part) => part.isNotEmpty).join(' · ');

  static const Map<String, String> _pairs = <String, String>{
    '(': ')',
    '[': ']',
    '{': '}',
  };

  static final RegExp _languagePattern = RegExp(
    r'chinese|english|japanese|korean|spanish|french|german|russian|thai|'
    r'vietnamese|portuguese|italian|polish|indonesian|translated|'
    r'翻訳|翻译|翻譯|汉化|漢化|中国|中國|中文|英訳|英译|韓国|한국',
    caseSensitive: false,
  );

  static bool _isLanguage(String text) => _languagePattern.hasMatch(text);

  static _Group? _leadingGroup(String text) {
    final open = text[0];
    final close = _pairs[open];
    if (close == null) {
      return null;
    }
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == open) {
        depth++;
      } else if (char == close) {
        depth--;
        if (depth == 0) {
          return _Group(open, text.substring(1, i), i + 1);
        }
      }
    }
    return null;
  }

  static _Group? _trailingGroup(String text) {
    final close = text[text.length - 1];
    final open = _pairs.entries
        .where((pair) => pair.value == close)
        .map((pair) => pair.key)
        .firstOrNull;
    if (open == null) {
      return null;
    }
    var depth = 0;
    for (var i = text.length - 1; i >= 0; i--) {
      final char = text[i];
      if (char == close) {
        depth++;
      } else if (char == open) {
        depth--;
        if (depth == 0) {
          // A group spanning the whole title is the title, not a suffix.
          if (i == 0) {
            return null;
          }
          return _Group(
              open, text.substring(i + 1, text.length - 1), text.length - i);
        }
      }
    }
    return null;
  }
}

class _Group {
  const _Group(this.open, this.inner, this.length);

  final String open;
  final String inner;
  final int length;
}
