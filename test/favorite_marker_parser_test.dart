import 'package:eros_fe/common/parser/gallery_list_parser.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;

Element row(String html) =>
    parseFragment('<table><tbody>$html</tbody></table>').querySelector('tr')!;

// Compact list markup consumed by both gallery and favorite transformers.
String listHtml(String marker) => '''
<table><tbody><tr>
  <td class="gl1c glcat"><div>Manga</div></td>
  <td class="gl2c">
    <div><div><img src="https://example.com/cover.jpg"></div></div>
    <div>$marker<div class="ir" style="background-position:0px -1px">
      <div></div><div><div></div><div>20 pages</div></div>
    </div></div>
    <div><div></div><div class="ir"></div></div>
  </td>
  <td class="gl3c glname"><a href="https://e-hentai.org/g/123/abc/">
    <div class="glink">Example</div></a></td>
  <td class="gl4c glhide"><div>uploader</div><div>20 pages</div></td>
</tr></tbody></table>
''';

void main() {
  const backgrounds = [
    '0,0,0',
    '240,0,0',
    '240,160,0',
    '208,208,0',
    '0,128,0',
    '144,240,64',
    '64,176,240',
    '0,0,240',
    '80,0,128',
    '232,0,232',
  ];

  for (final entry in EHConst.favCat.entries) {
    final cat = entry.value;
    final color = entry.key;
    final expanded = color.substring(1).split('').map((c) => '$c$c').join();
    for (final css in [
      'border-color:$color;',
      ' BORDER-COLOR : #${expanded.toUpperCase()} !important',
    ]) {
      for (final favorite in [false, true]) {
        test(
            'initial ${favorite ? "favorite" : "gallery"} list category $cat $css',
            () {
          final html = listHtml(
              '<div title="我的收藏 $cat" style="$css">2026-09-13 12:00</div>');
          final result =
              favorite ? parseGalleryListOfFav(html) : parseGalleryList(html);
          final item = result.gallerys!.single;
          expect(item.favTitle, '我的收藏 $cat');
          expect(item.favcat, cat);
          expect(
              ThemeColors.favColorFor(item.favcat), ThemeColors.favColor[cat]);
        });
      }
    }
    test('initial toplist category $cat', () {
      final html = listHtml(
          '<div id="posted_123" style="background-color:rgba(${backgrounds[int.parse(cat)]},0.2)">2026-09-13 12:00</div>');
      expect(parseGalleryList(html).gallerys!.single.favcat, cat);
    });
  }

  test('legacy third-child metadata works with or without whitespace', () {
    final html = listHtml(
      '<div title="自定义收藏" style="border-color:#4bf">2026-09-13 12:00</div>',
    ).replaceFirst('<div><div><img', '<div></div><div><div><img');
    for (final response in [html, html.replaceAll(RegExp(r'>\s+<'), '><')]) {
      final item = parseGalleryList(response).gallerys!.single;
      expect(item.favTitle, '自定义收藏');
      expect(item.favcat, '6');
    }
  });

  test('posted colors support equivalent CSS encodings without guessing', () {
    for (final style in [
      'background-color:#ff0000',
      'background-color: rgb(255, 0, 0)',
      'background-color:rgba(255,0,0,.2)',
      'border-color:rgb(255,0,0)',
    ]) {
      expect(
          parseFavoriteMarker(row(
                  '<tr><td><div id="posted_123" style="$style"></div></td></tr>'))
              .favcat,
          '1');
    }
    for (final color in [
      'rgba(255,0,0,0)',
      'rgba(255,0,0,2)',
      'rgb(999,0,0)',
      '#123456'
    ]) {
      expect(
          parseFavoriteMarker(row(
                  '<tr><td><div id="posted_123" style="background-color:$color"></div></td></tr>'))
              .favcat,
          isEmpty);
    }
  });

  test('stable posted ID supports changed nesting and custom category names',
      () {
    final marker = parseFavoriteMarker(row('''
      <tr><td><section><div id="posted_123" title="language:chinese"
        style="border-color:#fa0">date</div></section></td></tr>
    '''));
    expect(marker.title, 'language:chinese');
    expect(marker.favcat, '2');
  });

  test('colored tags and arbitrary Favorites tooltips are not favorites', () {
    final marker = parseFavoriteMarker(row('''
      <tr><td class="gl3c"><div class="gt" title="language:chinese" style="border-color:#f00"></div>
      <span title="Favorites 2" style="border-color:#fa0"></span></td></tr>
    '''));
    expect(marker.isFavorited, isFalse);
    expect(marker.favcat, isEmpty);
  });

  test('favorite color takes precedence over category name and colored tags',
      () {
    final marker = parseFavoriteMarker(row('''
      <tr><td><div class="gt" title="Favorites 1" style="border-color:#f00"></div></td>
      <td><div id="posted_123" title="Favorites 7" style="border-color:#fa0"></div></td></tr>
    '''));
    expect(marker.favcat, '2');
  });

  test('unknown border does not suppress recognized posted background', () {
    final marker = parseFavoriteMarker(row('''
      <tr><td><div id="posted_123" title="自定义" style="border-color:#123456;background-color:rgba(0,0,240,0.2)"></div></td></tr>
    '''));
    expect(marker.favcat, '7');
  });

  test('unknown color is not guessed from the title', () {
    final marker = parseFavoriteMarker(row('''
      <tr><td><div id="posted_123" title="Favorites 9" style="border-color:#123456"></div></td></tr>
    '''));
    expect(marker.title, 'Favorites 9');
    expect(marker.favcat, isEmpty);
  });

  test('unfavorited list has no marker', () {
    final item = parseGalleryList(
            listHtml('<div id="posted_123">2026-09-13 12:00</div>'))
        .gallerys!
        .single;
    expect(item.favcat, isEmpty);
    expect(item.favTitle, isEmpty);
  });
}
