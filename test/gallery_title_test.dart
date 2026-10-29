import 'package:eros_fe/utils/gallery_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits every conventional part', () {
    final parts = GalleryTitleParts.parse(
        '(C104) [Lantern House (Mori Yuki)] A Very Long Title (Original) '
        '[Chinese] [Digital]');
    expect(parts.event, 'C104');
    expect(parts.circle, 'Lantern House');
    expect(parts.artist, 'Mori Yuki');
    expect(parts.title, 'A Very Long Title');
    expect(parts.parody, 'Original');
    expect(parts.language, 'Chinese');
    expect(parts.extras, ['Digital']);
    expect(parts.byline, 'Lantern House · Mori Yuki');
  });

  test('a single bracket before the title is the artist', () {
    final parts = GalleryTitleParts.parse('[Paper Moon] Evening Notes Vol.3');
    expect(parts.circle, isEmpty);
    expect(parts.artist, 'Paper Moon');
    expect(parts.title, 'Evening Notes Vol.3');
    expect(parts.byline, 'Paper Moon');
  });

  test('a plain title has no byline', () {
    final parts = GalleryTitleParts.parse('Quiet Harbour');
    expect(parts.title, 'Quiet Harbour');
    expect(parts.byline, isEmpty);
    expect(parts.language, isEmpty);
  });

  test('recognises CJK language markers and keeps other suffixes', () {
    final parts =
        GalleryTitleParts.parse('(COMIC1☆24) [サークル] タイトル [中国翻訳] [無修正]');
    expect(parts.event, 'COMIC1☆24');
    expect(parts.artist, 'サークル');
    expect(parts.title, 'タイトル');
    expect(parts.language, '中国翻訳');
    expect(parts.extras, ['無修正']);
  });

  test('brackets inside the title stay in the title', () {
    final parts = GalleryTitleParts.parse('[A] Title (Part 2) Remaster');
    expect(parts.title, 'Title (Part 2) Remaster');
    expect(parts.parody, isEmpty);
  });

  test('nested brackets are matched as one group', () {
    final parts =
        GalleryTitleParts.parse('[Circle (Artist)] Title (Series (Season 2))');
    expect(parts.title, 'Title');
    expect(parts.parody, 'Series (Season 2)');
  });

  test('keeps the first half of a bilingual title', () {
    expect(GalleryTitleParts.parse('[X] English Title | 日本語タイトル').title,
        'English Title');
  });

  test('never returns an empty title', () {
    expect(GalleryTitleParts.parse('[Artist]').title, '[Artist]');
    expect(GalleryTitleParts.parse('(Only Event)').title, '(Only Event)');
    expect(GalleryTitleParts.parse('').title, '');
    expect(GalleryTitleParts.parse('  Unclosed [bracket').title,
        'Unclosed [bracket');
  });
}
