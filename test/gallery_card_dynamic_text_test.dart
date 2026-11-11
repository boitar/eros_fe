import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/simple_tag.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/gallery_card_title.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/pages/item/gallery_item_flow_large.dart';
import 'package:eros_fe/pages/item/gallery_item_grid.dart';
import 'package:eros_fe/pages/item/gallery_item_simple.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

void main() {
  Logger.level = Level.off;
  final settings = _Settings();
  final theme = _Theme();
  setUp(() {
    settings.fullTitle.value = false;
    settings.immersive.value = false;
    settings.fixed.value = true;
    settings.limit.value = 2;
    theme.dark.value = false;
    Get.put<EhSettingService>(settings);
    Get.put<ThemeService>(theme);
    Get.put<LayoutServices>(_Layout());
    Get.put<FavController>(_Favorites());
    Get.put<HistoryController>(_History());
    Get.put<TabHomeController>(_Tabs());
  });
  tearDown(Get.reset);
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('production card fits width=$width scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        theme.dark.value = scale > 1;
        const gallery = GalleryProvider(
          gid: 'offline-card',
          englishTitle: 'Neutral illustration collection with a long title',
          category: 'Manga',
          imgUrl: '',
          imgWidth: 400,
          imgHeight: 600,
          filecount: '48',
          postTime: '2026-10-15',
          simpleTags: [
            SimpleTag(text: 'full color'),
            SimpleTag(text: 'long neutral illustration label'),
          ],
        );
        Get.put<GalleryItemController>(
          GalleryItemController(galleryProvider: gallery),
          tag: gallery.gid,
        );
        await tester.pumpWidget(
          GetCupertinoApp(
            theme: CupertinoThemeData(textTheme: ehTextTheme),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const CupertinoPageScaffold(
              child: SingleChildScrollView(
                child: GalleryItemWidget(
                  tabTag: 'offline-card',
                  galleryProvider: gallery,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final height = tester.getSize(find.byType(GalleryItemWidget)).height;
        expect(height, scale == 1 ? 216 : greaterThan(216));
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  const raw = '[Circle] Roman Title | Readable Title [Chinese]';
  for (final mode in [
    'list',
    'list-two-tags',
    'adaptive',
    'small',
    'small-tags',
    'grid',
    'grid-tags',
    'waterfall',
    'immersive',
  ]) {
    testWidgets('full title toggles immediately in $mode', (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      settings.fixed.value = mode != 'adaptive';
      settings.immersive.value = mode == 'immersive';
      settings.limit.value = mode == 'list-two-tags' ? -1 : 2;
      final gallery = GalleryProvider(
        gid: 'full-title-$mode',
        englishTitle: raw,
        imgUrl: '',
        imgWidth: 200,
        imgHeight: 300,
        filecount: '20',
        postTime: '2026-11-11',
        category: 'Manga',
        // The small card is the tightest one; give it the real uploader and
        // tags so the fixed height is exercised at its true content height.
        uploader: mode.startsWith('small') ? 'uploader name' : null,
        simpleTags: mode == 'list-two-tags'
            ? List.generate(8, (i) => SimpleTag(text: 'tag $i'))
            : mode == 'small-tags'
            ? const [SimpleTag(text: 'full color'), SimpleTag(text: 'x')]
            : const [],
      );
      Get.put<GalleryItemController>(
        GalleryItemController(galleryProvider: gallery),
        tag: gallery.gid,
      );
      final Widget card = switch (mode) {
        'list' ||
        'list-two-tags' ||
        'adaptive' => GalleryItemWidget(galleryProvider: gallery, tabTag: mode),
        'small' || 'small-tags' => GalleryItemSimpleWidget(
          galleryProvider: gallery,
          tabTag: mode,
          showTag: mode == 'small-tags',
        ),
        'grid' => SizedBox(
          height: 375,
          child: GalleryItemGrid(galleryProvider: gallery, tabTag: mode),
        ),
        'grid-tags' => GalleryItemGrid(
          galleryProvider: gallery,
          tabTag: mode,
          showTags: true,
        ),
        _ => GalleryItemFlowLarge(galleryProvider: gallery, tabTag: mode),
      };
      await tester.pumpWidget(
        GetCupertinoApp(
          theme: CupertinoThemeData(textTheme: ehTextTheme),
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: SizedBox(
                width: mode == 'grid' || mode == 'grid-tags' ? 200 : 390,
                child: card,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final legacy = tester.widget<Text>(find.text(raw));
      final oldStyle = legacy.style;
      expect(
        legacy.maxLines,
        ['list', 'adaptive'].contains(mode)
            ? 4
            : mode == 'list-two-tags'
            ? 3
            : 2,
      );
      final beforeHeight = tester.getSize(find.byType(GalleryCardTitle)).height;
      final beforeCardHeight = tester.getSize(find.byWidget(card)).height;
      settings.fullTitle.value = true;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text(raw), findsNothing);
      final a = tester.widget<Text>(
        find.byKey(const ValueKey('card-title-primary')),
      );
      final b = tester.widget<Text>(
        find.byKey(const ValueKey('card-title-secondary')),
      );
      // At the default text scale every layout with N >= 3 shows the prefix.
      final p = tester.widget<Text>(
        find.byKey(const ValueKey('card-title-prefix')),
      );
      expect(p.maxLines, 1);
      expect(p.data, '[Circle]');
      expect(
        a.maxLines,
        ['list', 'adaptive', 'waterfall', 'immersive'].contains(mode) ? 2 : 1,
      );
      expect(b.maxLines, greaterThanOrEqualTo(1));
      expect(b.data, 'Readable Title [Chinese]');
      expect(a.textSpan!.toPlainText(), 'Roman Title');
      expect(a.textSpan!.style!.fontSize, oldStyle!.fontSize);
      // The spoken label always keeps the prefix, even when the two-line
      // fallback drops it from the card.
      const spoken = '[Circle] Roman Title\nReadable Title [Chinese]';
      final titleSemantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(GalleryCardTitle),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == spoken,
          ),
        ),
      );
      expect(titleSemantics.excludeSemantics, isTrue);
      // Tappable cards merge the title and metadata into one semantics node.
      // Keep P + A + newline + B together, once, and without a pipe.
      final label = tester
          .getSemantics(find.byType(GalleryCardTitle))
          .getSemanticsData()
          .label;
      expect(label, contains(spoken));
      expect(spoken.allMatches(label), hasLength(1));
      expect(label, isNot(contains('|')));
      if (mode == 'waterfall' || mode == 'immersive') {
        expect(b.style!.fontWeight, FontWeight.w500);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('card-title-prefix')))
              .style!
              .fontWeight,
          FontWeight.w500,
        );
      }
      if (mode == 'immersive') {
        expect(b.style!.color, const Color(0xB3FFFFFF));
      }
      if (mode == 'list' || mode.startsWith('small')) {
        expect(tester.takeException(), isNull);
      }
      if ([
        'list',
        'list-two-tags',
        'small',
        'small-tags',
        'immersive',
      ].contains(mode)) {
        expect(tester.getSize(find.byWidget(card)).height, beforeCardHeight);
      }
      settings.fullTitle.value = false;
      await tester.pump();
      expect(tester.widget<Text>(find.text(raw)).style, oldStyle);
      expect(
        tester.getSize(find.byType(GalleryCardTitle)).height,
        beforeHeight,
      );
      expect(find.byKey(const ValueKey('card-title-prefix')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final tags in [false, true]) {
    for (final scale in [1.0, 1.1, 1.11]) {
      testWidgets('small title budget tags=$tags scale=$scale', (tester) async {
        settings.fullTitle.value = true;
        await tester.pumpWidget(
          GetCupertinoApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Center(
              child: SizedBox(
                width: 200,
                child: GalleryCardTitle(
                  legacy: const Text(
                    raw,
                    maxLines: 2,
                    style: TextStyle(fontSize: 13.5),
                  ),
                  small: true,
                  showTags: tags,
                ),
              ),
            ),
          ),
        );
        // Spec C2: three lines until the text scale passes 1.1 (1.0 when the
        // card shows tags), then two lines without the prefix.
        final fallback = scale > (tags ? 1.0 : 1.1);
        expect(
          find.byKey(const ValueKey('card-title-prefix')),
          fallback ? findsNothing : findsOneWidget,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('card-title-primary')))
              .maxLines,
          1,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('card-title-secondary')))
              .maxLines,
          1,
        );
      });
    }
  }

  testWidgets('short primary returns unused lines to alternate title', (
    tester,
  ) async {
    settings.fullTitle.value = true;
    await tester.pumpWidget(
      const GetCupertinoApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: GalleryCardTitle(
              legacy: Text(
                '[Circle] A | Long alternate title [Chinese]',
                style: TextStyle(fontSize: 14),
              ),
              lines: 4,
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('card-title-primary')))
          .maxLines,
      2,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('card-title-secondary')))
          .maxLines,
      2,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('card-title-secondary')))
          .data,
      'Long alternate title [Chinese]',
    );
  });

  testWidgets('single title suffix stays in primary with the whole budget', (
    tester,
  ) async {
    settings.fullTitle.value = true;
    await tester.pumpWidget(
      const GetCupertinoApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: GalleryCardTitle(
              legacy: Text('Single [Chinese]', style: TextStyle(fontSize: 14)),
              lines: 3,
            ),
          ),
        ),
      ),
    );
    final primary = tester.widget<Text>(
      find.byKey(const ValueKey('card-title-primary')),
    );
    expect(primary.maxLines, 3);
    expect(primary.textSpan!.toPlainText(), 'Single [Chinese]');
    expect(find.byKey(const ValueKey('card-title-prefix')), findsNothing);
    expect(find.byKey(const ValueKey('card-title-secondary')), findsNothing);
  });

  testWidgets('disabled full title returns the original Text widget', (
    tester,
  ) async {
    const legacy = Text(
      raw,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.left,
      style: TextStyle(fontSize: 12),
    );
    await tester.pumpWidget(
      const GetCupertinoApp(
        home: Center(child: GalleryCardTitle(legacy: legacy)),
      ),
    );
    expect(tester.widget<Text>(find.text(raw)), same(legacy));
    expect(find.byType(LayoutBuilder), findsNothing);
  });

  for (final prefix in [false, true]) {
    for (final secondary in [false, true]) {
      testWidgets(
        'waterfall keeps two primary lines prefix=$prefix secondary=$secondary',
        (tester) async {
          settings.fullTitle.value = true;
          final title =
              '${prefix ? '[Circle] ' : ''}Roman Title'
              '${secondary ? ' | Readable Title' : ''} [Chinese]';
          await tester.pumpWidget(
            GetCupertinoApp(
              home: Center(
                child: SizedBox(
                  width: 100,
                  child: GalleryCardTitle(
                    legacy: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    waterfall: true,
                  ),
                ),
              ),
            ),
          );
          final a = tester.widget<Text>(
            find.byKey(const ValueKey('card-title-primary')),
          );
          expect(a.maxLines, 2);
          expect(
            a.textSpan!.toPlainText(),
            secondary ? 'Roman Title' : 'Roman Title [Chinese]',
          );
          expect(
            find.byKey(const ValueKey('card-title-prefix')),
            prefix ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('card-title-secondary')),
            secondary ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('long primary leaves exactly one line for the alternate title', (
    tester,
  ) async {
    settings.fullTitle.value = true;
    await tester.pumpWidget(
      GetCupertinoApp(
        home: Center(
          child: SizedBox(
            width: 100,
            child: GalleryCardTitle(
              legacy: Text(
                '[Circle] ${'Long primary title ' * 10}| Alternate [Chinese]',
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
              lines: 4,
            ),
          ),
        ),
      ),
    );
    final a = tester.widget<Text>(
      find.byKey(const ValueKey('card-title-primary')),
    );
    final b = tester.widget<Text>(
      find.byKey(const ValueKey('card-title-secondary')),
    );
    expect(a.maxLines, 2);
    expect(b.maxLines, 1);
    final p = find.byKey(const ValueKey('card-title-prefix'));
    final primary = find.byKey(const ValueKey('card-title-primary'));
    final secondary = find.byKey(const ValueKey('card-title-secondary'));
    expect(
      tester.getSize(primary).height,
      closeTo(tester.getSize(secondary).height * 2, 0.01),
    );
    expect(tester.getBottomLeft(p), tester.getTopLeft(primary));
    expect(tester.getBottomLeft(primary), tester.getTopLeft(secondary));
    expect(tester.takeException(), isNull);
  });

  for (final immersive in [false, true]) {
    testWidgets('waterfall title scaling immersive=$immersive', (tester) async {
      settings.fullTitle.value = true;
      settings.immersive.value = immersive;
      const gallery = GalleryProvider(
        gid: 'scaled-waterfall',
        englishTitle: raw,
        imgUrl: '',
        imgWidth: 200,
        imgHeight: 300,
        filecount: '20',
        category: 'Manga',
        simpleTags: [],
      );
      Get.put<GalleryItemController>(
        GalleryItemController(galleryProvider: gallery),
        tag: gallery.gid,
      );
      await tester.pumpWidget(
        GetCupertinoApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: SizedBox(
                width: 200,
                child: GalleryItemFlowLarge(
                  galleryProvider: gallery,
                  tabTag: 'scaled-waterfall',
                ),
              ),
            ),
          ),
        ),
      );
      final context = tester.element(
        find.byKey(const ValueKey('card-title-primary')),
      );
      expect(
        MediaQuery.textScalerOf(context).scale(14),
        closeTo(14 * (immersive ? 1.35 : 2), 0.001),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _Settings extends GetxService implements EhSettingService {
  final fixed = true.obs;
  final limit = 2.obs;
  final translation = false.obs;
  final blur = false.obs;
  @override
  bool get fixedHeightOfListItems => fixed.value;
  @override
  int get listViewTagLimit => limit.value;
  @override
  bool get isTagTranslate => translation.value;
  @override
  bool get isPureDarkTheme => false;
  final fullTitle = false.obs;
  @override
  bool get fullTitleInGalleryPage => fullTitle.value;
  @override
  set fullTitleInGalleryPage(bool value) => fullTitle.value = value;
  @override
  bool get blurringOfCoverBackground => blur.value;
  @override
  bool get debugMode => false;
  final immersive = false.obs;
  @override
  bool get immersiveLargeCards => immersive.value;
  @override
  final isGalleryImgBlur = false.obs;
  @override
  final vibrate = false.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class _Theme extends GetxService implements ThemeService {
  final dark = false.obs;
  @override
  ThemesModeEnum get themeModel =>
      dark.value ? ThemesModeEnum.darkMode : ThemesModeEnum.lightMode;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class _Layout extends LayoutServices {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Favorites extends GetxController implements FavController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class _History extends GetxController implements HistoryController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class _Tabs extends GetxController implements TabHomeController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}
