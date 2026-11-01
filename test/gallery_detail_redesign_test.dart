import 'dart:typed_data';

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/view/gallery_widget.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_hero.dart';
import 'package:eros_fe/pages/gallery/view/sliver/slivers.dart';
import 'package:eros_fe/pages/tab/view/gallery_base.dart';
import 'package:eros_fe/widget/image/eh_cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/waterfall_fixture.dart';

Widget _host(Widget child, {double scale = 1}) => CupertinoApp(
      locale: const Locale('en'),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: CupertinoPageScaffold(
        child: Center(child: SizedBox(width: 320, child: child)),
      ),
    );

/// A transparent 1×1 PNG.
final _onePixelPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  setUp(registerWaterfallFixture);
  tearDown(Get.reset);

  group('DetailTagChip', () {
    testWidgets('marks votes with an arrow after the tag', (tester) async {
      await tester.pumpWidget(_host(const Column(children: [
        DetailTagChip(text: 'liked', vote: 1),
        DetailTagChip(text: 'disliked', vote: -1),
        DetailTagChip(text: 'plain'),
      ])));
      expect(find.text('liked ↑', findRichText: true), findsOneWidget);
      expect(find.text('disliked ↓', findRichText: true), findsOneWidget);
      expect(find.text('plain', findRichText: true), findsOneWidget);
    });

    testWidgets('a watched tag wears its My Tags colours as on the site',
        (tester) async {
      const red = Color(0xFFD03030);
      const ink = Color(0xFFF1F1F1);
      Future<(Color?, Color?)> chip(Color fill, Color? text) async {
        await tester.pumpWidget(_host(DetailTagChip(
          text: 'watched',
          userColor: fill,
          userTextColor: text,
        )));
        final box = tester.widget<Container>(find.descendant(
            of: find.byType(DetailTagChip), matching: find.byType(Container)));
        final label = tester.widget<Text>(find.byType(Text));
        return (
          (box.decoration! as ShapeDecoration).color,
          label.style?.color,
        );
      }

      expect(await chip(red, ink), (red, ink));
      // Without the site's text colour, the label still reads on the fill.
      expect(await chip(red, null), (red, const Color(0xFFFFFFFF)));
      expect(await chip(const Color(0xFFFFE066), null),
          (const Color(0xFFFFE066), const Color(0xFF000000)));
      expect(tester.widget<Text>(find.byType(Text)).style?.fontWeight,
          FontWeight.w600);
    });

    testWidgets('taps and long presses reach their callbacks', (tester) async {
      var taps = 0;
      var holds = 0;
      await tester.pumpWidget(_host(DetailTagChip(
        text: 'tag',
        onPressed: () => taps++,
        onLongPress: () => holds++,
      )));
      await tester.tap(find.byType(DetailTagChip));
      await tester.longPress(find.byType(DetailTagChip));
      expect(taps, 1);
      expect(holds, 1);
    });
  });

  testWidgets('namespace column fits the widest label and grows with text',
      (tester) async {
    late double normal;
    late double large;
    const groups = [
      TagGroup(tagType: 'language', galleryTags: []),
      TagGroup(tagType: 'female', galleryTags: []),
    ];
    await tester.pumpWidget(_host(Builder(builder: (context) {
      normal = tagNamespaceColumnWidth(context, groups, translate: false);
      return const SizedBox();
    })));
    await tester.pumpWidget(_host(Builder(builder: (context) {
      large = tagNamespaceColumnWidth(context, groups, translate: false);
      return const SizedBox();
    }), scale: 2));
    expect(normal, greaterThanOrEqualTo(34));
    expect(large, greaterThan(normal));
    expect(large, lessThanOrEqualTo(120));
  });

  testWidgets('a tag group lays out at large text without overflow',
      (tester) async {
    await tester.pumpWidget(_host(
      const TagGroupItem(
        labelWidth: 60,
        tagGroupData: TagGroup(tagType: 'female', galleryTags: [
          GalleryTag(
              title: 'a very long neutral tag',
              tagTranslat: 'a very long neutral tag',
              type: 'female'),
          GalleryTag(
              title: 'short', tagTranslat: 'short', type: 'female', vote: 1),
        ]),
      ),
      scale: 2.5,
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('female'), findsOneWidget);
  });

  testWidgets('section title links to the full list', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(MiniTitle(
      title: 'Thumbnails',
      count: '186 pages',
      onTap: () => opened++,
    )));
    expect(
        find.text('186 pages · See All', findRichText: true), findsOneWidget);
    await tester.tap(find.text('Thumbnails'));
    expect(opened, 1);
  });

  testWidgets('add-tag chip opens the editor', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(AddTagChip(onPressed: () => opened++)));
    expect(find.text('+ Add tags'), findsOneWidget);
    await tester.tap(find.byType(AddTagChip));
    expect(opened, 1);
  });

  test('hero covers share one area at their real shape', () {
    Size size(int w, int h) =>
        heroCoverSize(GalleryProvider(imgWidth: w, imgHeight: h));
    // Unknown size: the usual 210:300 portrait.
    expect(heroCoverSize(null), const Size(168, 240));
    expect(size(200, 200), const Size(201, 201));
    expect(size(400, 300), const Size(232, 174));
    // Beyond 1:2 and 2:1 the cover is cropped; banners stop at 280pt wide.
    expect(size(100, 400), const Size(142, 284));
    expect(size(600, 200), const Size(280, 140));
  });

  test('the list size wins so the Hero flight lands exactly', () {
    const list = GalleryProvider(imgWidth: 200, imgHeight: 300);
    const detail = GalleryProvider(imgWidth: 250, imgHeight: 250);
    expect(heroCoverSource(list, detail), same(list));
    expect(heroCoverSource(const GalleryProvider(), detail), same(detail));
  });

  group('detail columns', () {
    AdaptiveEnvironmentSnapshot window(Size size, [Rect? fold]) =>
        AdaptiveEnvironmentSnapshot(
          size: size,
          reservedRegions: [
            if (fold != null)
              AdaptiveRegion(frame: fold, kind: AdaptiveRegionKind.division),
          ],
        );

    test('phones keep one column; wide pages get a fixed side column', () {
      expect(GalleryDetailColumns.resolve(width: 402), isNull);
      expect(GalleryDetailColumns.resolve(width: 699), isNull);
      expect(GalleryDetailColumns.resolve(width: 700),
          const GalleryDetailColumns(leading: 320, gap: 0));
      expect(GalleryDetailColumns.resolve(width: 1032),
          const GalleryDetailColumns(leading: 320, gap: 0));
    });

    test('an unfolded Duo splits the page at the fold', () {
      final duo =
          window(const Size(560, 900), const Rect.fromLTWH(272, 0, 16, 900));
      expect(GalleryDetailColumns.resolve(width: 560, environment: duo),
          const GalleryDetailColumns(leading: 272, gap: 16));
    });

    test('the fold is ignored when it cannot split the page', () {
      final duo =
          window(const Size(560, 900), const Rect.fromLTWH(272, 0, 16, 900));
      // Split panes already sit either side of the fold.
      expect(
          GalleryDetailColumns.resolve(
              width: 560, environment: duo, split: true),
          isNull);
      // A page narrower than the window is a pane, not the whole window.
      expect(
          GalleryDetailColumns.resolve(width: 400, environment: duo), isNull);
      // Panes narrower than 260pt each stay one column.
      final narrow =
          window(const Size(500, 900), const Rect.fromLTWH(242, 0, 16, 900));
      expect(GalleryDetailColumns.resolve(width: 500, environment: narrow),
          isNull);
      // A horizontal fold is tabletop, not a book.
      final tabletop =
          window(const Size(900, 700), const Rect.fromLTWH(0, 342, 900, 16));
      expect(GalleryDetailColumns.resolve(width: 900, environment: tabletop),
          const GalleryDetailColumns(leading: 320, gap: 0));
    });
  });

  group('ShownImages', () {
    testWidgets('a detail page draws the cover its list card already drew',
        (tester) async {
      const url = 'https://ehgt.org/t/00/00/shown-cover.jpg';
      await tester.pumpWidget(_host(const SizedBox(
        height: 100,
        child: ShownImage(url),
      )));
      // Nothing drawn yet: an empty box, not a spinner.
      expect(find.byType(Image), findsNothing);

      final drawn = MemoryImage(_onePixelPng);
      ShownImages.remember(url, drawn);
      await tester.pumpWidget(_host(const SizedBox(
        height: 101,
        child: ShownImage(url),
      )));
      expect(tester.widget<Image>(find.byType(Image)).image, same(drawn));
    });

    test('keeps the most recently drawn images', () {
      final first = MemoryImage(Uint8List.fromList(const <int>[1]));
      ShownImages.remember('https://ehgt.org/t/first.jpg', first);
      for (var i = 0; i < 48; i++) {
        ShownImages.remember('https://ehgt.org/t/$i.jpg',
            MemoryImage(Uint8List.fromList(<int>[i])));
      }
      expect(ShownImages.of('https://ehgt.org/t/first.jpg'), isNull);
      expect(ShownImages.of('https://ehgt.org/t/47.jpg'), isNotNull);
    });
  });

  testWidgets('an error page keeps its face while it rebuilds',
      (tester) async {
    final error = ['5', '03'].join();
    final faces = <IconData?>{};
    for (var build = 0; build < 5; build++) {
      await tester.pumpWidget(_host(GalleryErrorPage(error: error)));
      faces.add(tester.widget<FaIcon>(find.byType(FaIcon)).icon);
    }
    expect(faces, hasLength(1));
  });

  test('saturation matrix keeps grey and amplifies colour', () {
    final identity = GalleryAmbientBackdrop.saturation(1);
    expect(identity[0], closeTo(1, 1e-9));
    expect(identity[6], closeTo(1, 1e-9));
    expect(identity[12], closeTo(1, 1e-9));
    final boosted = GalleryAmbientBackdrop.saturation(1.15);
    // Rows still sum to 1, so neutral greys stay neutral.
    for (var row = 0; row < 3; row++) {
      final sum =
          boosted[row * 5] + boosted[row * 5 + 1] + boosted[row * 5 + 2];
      expect(sum, closeTo(1, 1e-9));
    }
    expect(boosted[0], greaterThan(1));
  });
}
