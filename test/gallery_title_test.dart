import 'dart:convert';

import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/models/eh_config.dart';
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

  group('full title display split', () {
    test('keeps leading and trailing bracket groups around two sections', () {
      final parts = GalleryTitleDisplay.split(
        '(C104) [Circle (Artist)] Roman Title | Readable Title '
        '(Original) [Chinese]',
      );
      expect(parts.prefix.trim(), '(C104) [Circle (Artist)]');
      expect(parts.primary, 'Roman Title');
      expect(parts.secondary, 'Readable Title');
      expect(parts.suffix.trim(), '(Original) [Chinese]');
      expect(parts.accessibilityLabel,
          '(C104) [Circle (Artist)] Roman Title\nReadable Title (Original) [Chinese]');
    });

    test('does not split a pipe inside brackets', () {
      final parts = GalleryTitleDisplay.split(
          '[Circle] Title [Tag | Inner] | Alternate');
      expect(parts.prefix.trim(), '[Circle]');
      expect(parts.primary, 'Title [Tag | Inner]');
      expect(parts.secondary, 'Alternate');
    });

    test('splits an ASCII pipe without surrounding spaces', () {
      final parts = GalleryTitleDisplay.split('English|日本語');
      expect(parts.primary, 'English');
      expect(parts.secondary, '日本語');
    });

    test('keeps a pipe inside full-width brackets', () {
      final parts =
          GalleryTitleDisplay.split('（Event | Circle） Title | 日本語');
      expect(parts.prefix.trim(), '（Event | Circle）');
      expect(parts.primary, 'Title');
      expect(parts.secondary, '日本語');
    });

    test('does not split a malformed bracket group', () {
      final parts = GalleryTitleDisplay.split('Title [broken) | Alt');
      expect(parts.primary, 'Title [broken) | Alt');
      expect(parts.secondary, isNull);
      expect(parts.accessibilityLabel, 'Title [broken) | Alt');
    });

    test('keeps the full-width vertical bar as title text', () {
      final parts = GalleryTitleDisplay.split('（イベント）タイトル ｜ 日本語');
      expect(parts.primary, 'タイトル ｜ 日本語');
      expect(parts.secondary, isNull);
      expect(parts.accessibilityLabel, '（イベント）タイトル ｜ 日本語');
    });

    test('keeps a single title and its trailing language group', () {
      final parts =
          GalleryTitleDisplay.split('[Circle] Single Title [Chinese]');
      expect(parts.primary, 'Single Title');
      expect(parts.secondary, isNull);
      expect(parts.suffix.trim(), '[Chinese]');
    });

    test('keeps later pipes in the second section', () {
      final parts = GalleryTitleDisplay.split('First | Second | Third');
      expect(parts.primary, 'First');
      expect(parts.secondary, 'Second | Third');
    });

    test('does not split when either section is empty', () {
      expect(GalleryTitleDisplay.split('Title |').secondary, isNull);
      expect(GalleryTitleDisplay.split('| Title').secondary, isNull);
      expect(GalleryTitleDisplay.split('Title |').primary, 'Title |');
    });

    test('handles empty and bracket-only titles', () {
      expect(GalleryTitleDisplay.split('').primary, isEmpty);
      final parts = GalleryTitleDisplay.split('(Only Event) [Artist]');
      expect(parts.prefix, isEmpty);
      expect(parts.primary, '(Only Event) [Artist]');
      expect(parts.secondary, isNull);
      expect(parts.suffix, isEmpty);
    });

    test('keeps a Japanese-only title with full-width groups', () {
      const raw =
          '（コミティア150） [青空工房 (Artist)] 月の裏側で待ってるから '
          '(オリジナル) [DL版]';
      final parts = GalleryTitleDisplay.split(raw);
      expect(parts.primary, '月の裏側で待ってるから');
      expect(parts.secondary, isNull);
      expect(parts.accessibilityLabel, raw);
    });
  });

  test('full title setting survives config persistence operations', () {
    final config = EhConfig.fromJson(const <String, dynamic>{
      'favoritesOrder': '',
      'listMode': '',
      'catFilter': 0,
      'maxHistory': 100,
      'viewModel': '',
      'fullTitleInGalleryPage': true,
    });
    final restored = EhConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>);

    expect(config.fullTitleInGalleryPage, isTrue);
    expect(restored.fullTitleInGalleryPage, isTrue);
    expect(restored, config);
    expect(restored.hashCode, config.hashCode);
    expect(config.clone(), config);
    expect(config.copyWith(fullTitleInGalleryPage: false.oN)
        .fullTitleInGalleryPage, isFalse);
  });

  test('legacy profiles default the full title switch to off', () {
    final legacy = EhConfig.fromJson(const <String, dynamic>{
      'favoritesOrder': '',
      'listMode': '',
      'catFilter': 0,
      'maxHistory': 100,
      'viewModel': '',
    });
    expect(legacy.fullTitleInGalleryPage, isNull);
    expect(kDefEhConfig.fullTitleInGalleryPage, isFalse);
  });
}
