/// The title sections used by the detail page when the full-title setting is
/// enabled.
///
/// `(Event) [Circle (Artist)] Primary | Secondary (Parody) [Language]`
/// becomes four sections while keeping bracketed pipes inside their group.
class GalleryTitleDisplay {
  const GalleryTitleDisplay({
    required this.prefix,
    required this.primary,
    required this.secondary,
    required this.suffix,
  });

  /// Splits [raw] without changing [GalleryTitleParts.parse]'s behavior.
  ///
  /// Leading and trailing bracket groups are kept as display sections. The
  /// first pipe outside any bracket group separates the two title sections;
  /// later pipes remain in [secondary].
  factory GalleryTitleDisplay.split(String raw) {
    final all = raw.trim();
    if (all.isEmpty) {
      return const GalleryTitleDisplay(
        prefix: '',
        primary: '',
        secondary: null,
        suffix: '',
      );
    }

    var rest = all;
    var prefix = '';
    while (rest.isNotEmpty) {
      final group = GalleryTitleParts._leadingGroup(rest, _pairs);
      if (group == null) {
        break;
      }
      prefix += rest.substring(0, group.length);
      rest = rest.substring(group.length);
      final spacing = rest.length - rest.trimLeft().length;
      prefix += rest.substring(0, spacing);
      rest = rest.substring(spacing);
    }

    var suffix = '';
    while (rest.isNotEmpty) {
      final trimmed = rest.trimRight();
      final group = GalleryTitleParts._trailingGroup(trimmed, _pairs);
      if (group == null) {
        break;
      }
      final groupStart = trimmed.length - group.length;
      final beforeGroup = trimmed.substring(0, groupStart);
      final base = beforeGroup.trimRight();
      final spacing = beforeGroup.substring(base.length);
      suffix = '$spacing${trimmed.substring(groupStart)}$suffix';
      rest = base;
    }

    // A title made only of bracket groups should remain readable as a title,
    // rather than being split into display-only sections.
    if (rest.isEmpty) {
      return GalleryTitleDisplay(
        prefix: '',
        primary: all,
        secondary: null,
        suffix: '',
      );
    }

    rest = rest.trim();
    final pipe = _firstPipeOutsideGroups(rest);
    if (pipe >= 0) {
      final primary = rest.substring(0, pipe).trim();
      final secondary = rest.substring(pipe + 1).trim();
      if (primary.isNotEmpty && secondary.isNotEmpty) {
        return GalleryTitleDisplay(
          prefix: prefix,
          primary: primary,
          secondary: secondary,
          suffix: suffix,
        );
      }
    }

    return GalleryTitleDisplay(
      prefix: prefix,
      primary: rest,
      secondary: null,
      suffix: suffix,
    );
  }

  final String prefix;
  final String primary;
  final String? secondary;
  final String suffix;

  static const Map<String, String> _pairs = <String, String>{
    '(': ')',
    '[': ']',
    '{': '}',
    '（': '）',
    '【': '】',
    '［': '］',
    '｛': '｝',
  };

  bool get hasSecondary => secondary != null;

  /// The complete title spoken by accessibility services, without the pipe.
  String get accessibilityLabel {
    final first = '$prefix$primary'.trim();
    if (secondary == null) {
      return '$prefix$primary$suffix'.trim();
    }
    final second = '$secondary$suffix'.trim();
    return <String>[
      if (first.isNotEmpty) first,
      if (second.isNotEmpty) second,
    ].join('\n');
  }

  static int _firstPipeOutsideGroups(String text) {
    final stack = <String>[];
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      final close = _pairs[char];
      if (close != null) {
        stack.add(close);
      } else if (_pairs.containsValue(char)) {
        if (stack.isEmpty || stack.removeLast() != char) {
          return -1;
        }
      } else if (char == '|' && stack.isEmpty) {
        return i;
      }
    }
    if (stack.isNotEmpty) {
      return -1;
    }
    return -1;
  }
}

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

  static _Group? _leadingGroup(
    String text, [
    Map<String, String>? pairs,
  ]) {
    final open = text[0];
    if (pairs == null) {
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

    final bracketPairs = pairs;
    final close = bracketPairs[open];
    if (close == null) {
      return null;
    }
    final stack = <String>[close];
    for (var i = 1; i < text.length; i++) {
      final char = text[i];
      final nestedClose = bracketPairs[char];
      if (nestedClose != null) {
        stack.add(nestedClose);
      } else if (bracketPairs.containsValue(char)) {
        if (stack.isEmpty || stack.removeLast() != char) {
          return null;
        }
        if (stack.isEmpty) {
          return _Group(open, text.substring(1, i), i + 1);
        }
      }
    }
    return null;
  }

  static _Group? _trailingGroup(
    String text, [
    Map<String, String>? pairs,
  ]) {
    final close = text[text.length - 1];
    if (pairs == null) {
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

    final bracketPairs = pairs;
    final openingForClose = <String, String>{
      for (final pair in bracketPairs.entries) pair.value: pair.key,
    };
    final open = openingForClose[close];
    if (open == null) {
      return null;
    }
    final stack = <String>[];
    for (var i = text.length - 1; i >= 0; i--) {
      final char = text[i];
      final nestedOpen = openingForClose[char];
      if (nestedOpen != null) {
        stack.add(nestedOpen);
      } else if (bracketPairs.containsKey(char)) {
        if (stack.isEmpty || stack.removeLast() != char) {
          return null;
        }
        if (stack.isEmpty) {
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
