/// Search field scope for E-Hentai `favorites.php` queries.
///
/// E-Hentai retired the legacy `sn=on` / `st=on` / `sf=on` checkboxes on
/// `favorites.php` and now scopes searches via qualifier prefixes directly
/// inside `f_search`:
/// - `all`: unqualified query (titles + tags)
/// - `title`: `title:` qualifier
/// - `tag`: `tag:` qualifier (preserving explicit namespace prefixes)
/// - `note`: `favnote:` qualifier
enum FavSearchScope {
  all,
  title,
  tag,
  note,
}

final RegExp _queryTokenPattern = RegExp(
  r'([+-]?)([a-zA-Z]+:)?(?:"([^"]*)"|(\S+))',
);

/// Formats [rawQuery] with the live E-Hentai `favorites.php` qualifier prefix
/// for [scope].
String buildFavoriteSearchQuery(String rawQuery, FavSearchScope scope) {
  final trimmed = rawQuery.trim();
  if (trimmed.isEmpty || scope == FavSearchScope.all) {
    return trimmed;
  }
  final qualifier = switch (scope) {
    FavSearchScope.all => '',
    FavSearchScope.title => 'title:',
    FavSearchScope.tag => 'tag:',
    FavSearchScope.note => 'favnote:',
  };

  final buffer = StringBuffer();
  for (final match in _queryTokenPattern.allMatches(trimmed)) {
    final sign = match.group(1) ?? '';
    final existingPrefix = match.group(2) ?? '';
    final quoted = match.group(3);
    final bare = match.group(4);
    if (quoted != null) {
      final inner = quoted.trim();
      if (inner.isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      final prefix = existingPrefix.isNotEmpty ? existingPrefix : qualifier;
      buffer.write('$sign$prefix"$inner"');
    } else if (bare != null) {
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      final prefix = existingPrefix.isNotEmpty ? existingPrefix : qualifier;
      buffer.write('$sign$prefix$bare');
    }
  }
  return buffer.toString();
}

/// Extracts user-visible search terms for highlighting in titles and notes,
/// stripping qualifier prefixes, quotes, and excluded `-term` tokens.
List<String> extractFavoriteHighlightTerms(String rawQuery) {
  final trimmed = rawQuery.trim();
  if (trimmed.isEmpty) {
    return const <String>[];
  }
  final terms = <String>[];
  for (final match in _queryTokenPattern.allMatches(trimmed)) {
    final sign = match.group(1) ?? '';
    if (sign == '-') {
      continue;
    }
    var term = (match.group(3) ?? match.group(4) ?? '').trim();
    if (term.isEmpty) {
      continue;
    }
    term = term.replaceAll('"', '').replaceAll(r'$', '').trim();
    if (term.isNotEmpty && !terms.contains(term)) {
      terms.add(term);
    }
  }
  terms.sort((a, b) => b.length.compareTo(a.length));
  return terms;
}
