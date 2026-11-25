import 'package:eros_fe/utils/tag_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats header and tag list artist names identically', () {
    for (final name in ['artist name', '"artist name"', '""artist name""']) {
      expect(formatSimpleSearch('artist:$name'), 'artist:"artist name\$"');
    }
  });

  test('does not wrap an already formatted search twice', () {
    expect(
      formatSimpleSearch('artist:"artist name\$"'),
      'artist:"artist name\$"',
    );
  });

  test('preserves quotes and colons inside a name', () {
    expect(
      formatSimpleSearch('artist:an "artist": name'),
      'artist:"an "artist": name\$"',
    );
  });

  test('formats group and uploader searches', () {
    expect(formatSimpleSearch('group:circle name'), 'group:"circle name\$"');
    expect(formatSimpleSearch('uploader:"user name"'), 'uploader:"user name"');
    expect(
      formatSimpleSearch('uploader:user "alias" name'),
      r'uploader:"user \"alias\" name"',
    );
  });

  test('leaves empty and unrecognised searches unchanged', () {
    for (final query in ['', 'plain search', 'unknown:"name"']) {
      expect(formatSimpleSearch(query), query);
    }
  });
}
