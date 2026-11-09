import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/block_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/pages/item/gallery_item_flow.dart';
import 'package:eros_fe/pages/item/gallery_item_flow_large.dart';
import 'package:eros_fe/pages/item/gallery_item_grid.dart';
import 'package:eros_fe/pages/item/gallery_item_simple.dart';
import 'package:eros_fe/pages/tab/view/list/tab_base.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/widget/desktop_card_chrome.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'support/waterfall_fixture.dart';

const _modes = <ListModeEnum>[
  ListModeEnum.list,
  ListModeEnum.simpleList,
  ListModeEnum.grid,
  ListModeEnum.gridTags,
  ListModeEnum.waterfall,
  ListModeEnum.waterfallLarge,
];

GalleryProvider _gallery(String gid) => GalleryProvider(
  gid: gid,
  token: 'offline',
  url: 'https://example.test/g/$gid/offline/',
  englishTitle: 'Offline gallery $gid',
  category: 'Manga',
  imgUrl: '',
  imgWidth: 200,
  imgHeight: 280,
  filecount: '20',
  rating: 3,
  ratingFallBack: 3,
  colorRating: 'ir',
  simpleTags: const [],
);

class _Layout extends LayoutServices {
  @override
  // The test does not load persisted layout data.
  // ignore: must_call_super
  void onInit() {}
}

class _Blocks extends BlockController {
  @override
  // The test does not load persisted blocking rules.
  // ignore: must_call_super
  void onInit() {}
}

class _ListHost {
  _ListHost(this.mode, this.galleries, {this.platform = TargetPlatform.macOS});

  final ListModeEnum mode;
  final TargetPlatform platform;
  List<GalleryProvider> galleries;
  late StateSetter rebuild;
  String? clipboard;
  final toasts = <String>[];

  Future<void> pump(WidgetTester tester, {String? detailGid}) async {
    Logger.level = Level.off;
    registerWaterfallFixture();
    PlatformCapabilities.debugHostPlatformOverride = platform;
    Get.find<EhSettingService>().listMode.value = mode;
    Get.put<BlockController>(_Blocks());
    final layout = Get.put<LayoutServices>(_Layout())
      ..layoutMode = LayoutMode.large;
    final stack = layout.tabNavigation.select('desktop-gallery-list');
    if (detailGid != null) {
      DesktopCardChrome.debugGidForTag = (tag) => tag;
      stack.detailObserver.didPush(
        PageRouteBuilder<void>(
          settings: RouteSettings(
            name: EHRoutes.galleryPage,
            arguments: ControllerTagSnapshot(galleryTag: detailGid),
          ),
          pageBuilder: (_, _, _) => const SizedBox(),
        ),
        null,
      );
    }
    DesktopGalleryActions.debugToast = toasts.add;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(900, 700);
    addTearDown(() {
      tester.view.reset();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      DesktopCardChrome.debugGidForTag = null;
      DesktopGalleryActions.debugToast = null;
      DesktopGalleryActions.hoveredGid.value = null;
      PlatformCapabilities.debugHostPlatformOverride = null;
      Get.reset();
    });
    await tester.pumpWidget(
      GetCupertinoApp(
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: L10n.delegate.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return CupertinoPageScaffold(
              child: CustomScrollView(
                slivers: <Widget>[
                  getGallerySliverList(galleries, 'desktop-fixture'),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> replace(WidgetTester tester, String gid) async {
    rebuild(() => galleries = <GalleryProvider>[_gallery(gid)]);
    await tester.pumpAndSettle();
  }
}

// flutter_list_view omits even painted children from its onstage traversal.
// Include them in lookups and verify that the card is actually hit-testable.
Finder _key(String value) =>
    find.byKey(ValueKey<String>(value), skipOffstage: false);

Finder _card(String gid) => _key('desktop-card-$gid');

Future<TestGesture> _hover(WidgetTester tester, String gid) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(880, 680));
  await mouse.moveTo(tester.getCenter(_card(gid)));
  await tester.pumpAndSettle();
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<void> _copyShortcut(
  WidgetTester tester,
  String gid, {
  TargetPlatform platform = TargetPlatform.macOS,
}) async {
  final modifier = platform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  final handled = DesktopGalleryActions.handleShortcut(
    tester.element(_card(gid)),
    const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyC,
      logicalKey: LogicalKeyboardKey.keyC,
      timeStamp: Duration.zero,
    ),
    detailGid: 'different-detail',
  );
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
  expect(handled, isTrue);
}

void main() {
  for (final mode in _modes) {
    testWidgets('${mode.name} real list exposes desktop actions', (
      tester,
    ) async {
      final host = _ListHost(mode, <GalleryProvider>[_gallery('selected')]);
      await host.pump(tester, detailGid: 'selected');
      final card = _card('selected');
      expect(card, findsOneWidget);
      expect(card.hitTestable(), findsOneWidget);
      expect(_key('desktop-card-ring-selected'), findsOneWidget);
      final expectedCard = switch (mode) {
        ListModeEnum.list => find.byType(
          GalleryItemWidget,
          skipOffstage: false,
        ),
        ListModeEnum.simpleList => find.byType(
          GalleryItemSimpleWidget,
          skipOffstage: false,
        ),
        ListModeEnum.grid || ListModeEnum.gridTags => find.byType(
          GalleryItemGrid,
          skipOffstage: false,
        ),
        ListModeEnum.waterfall => find.byType(
          GalleryItemFlow,
          skipOffstage: false,
        ),
        ListModeEnum.waterfallLarge => find.byType(
          GalleryItemFlowLarge,
          skipOffstage: false,
        ),
        _ => throw StateError('Unexpected list mode'),
      };
      expect(
        find.descendant(of: card, matching: expectedCard, skipOffstage: false),
        findsOneWidget,
      );
      if (mode == ListModeEnum.grid || mode == ListModeEnum.gridTags) {
        expect(
          tester.widget<GalleryItemGrid>(expectedCard).showTags,
          mode == ListModeEnum.gridTags,
        );
      }

      await _hover(tester, 'selected');
      expect(DesktopGalleryActions.hoveredGid.value, 'selected');
      expect(
        tester.widget<AnimatedOpacity>(_key('desktop-quick-selected')).opacity,
        1,
      );
      final l10n = L10n.current;
      for (final label in <String>[
        l10n.read,
        l10n.add_to_favorites,
        l10n.download,
      ]) {
        expect(
          find.descendant(
            of: card,
            matching: _key('desktop-quick-$label'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      }

      await _copyShortcut(tester, 'selected');
      expect(host.clipboard, 'https://example.test/g/selected/offline/');

      final click = await tester.startGesture(
        tester.getCenter(card),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await click.up();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-gallery-menu')),
        findsOneWidget,
      );
      expect(find.text(l10n.copy_link), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('desktop-menu-${l10n.copy_link}')));
      await tester.pumpAndSettle();
      expect(host.clipboard, 'https://example.test/g/selected/offline/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      '${mode.name} replaces a hovered gallery without moving mouse',
      (tester) async {
        final host = _ListHost(mode, <GalleryProvider>[_gallery('before')]);
        await host.pump(tester);
        await _hover(tester, 'before');
        expect(DesktopGalleryActions.hoveredGid.value, 'before');

        await host.replace(tester, 'after');
        expect(_card('before').hitTestable(), findsNothing);
        expect(_card('after').hitTestable(), findsOneWidget);
        expect(DesktopGalleryActions.hoveredGid.value, 'after');
        expect(
          tester.widget<AnimatedOpacity>(_key('desktop-quick-after')).opacity,
          1,
        );
        await _copyShortcut(tester, 'after');
        expect(host.clipboard, 'https://example.test/g/after/offline/');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final mode in [ListModeEnum.waterfall, ListModeEnum.waterfallLarge]) {
    testWidgets('${mode.name} supports Windows mouse and keyboard', (
      tester,
    ) async {
      final host = _ListHost(mode, <GalleryProvider>[
        _gallery('before'),
      ], platform: TargetPlatform.windows);
      await host.pump(tester, detailGid: 'before');
      expect(_key('desktop-card-ring-before'), findsOneWidget);
      await _hover(tester, 'before');
      expect(DesktopGalleryActions.hoveredGid.value, 'before');
      expect(
        tester.widget<AnimatedOpacity>(_key('desktop-quick-before')).opacity,
        1,
      );
      await host.replace(tester, 'after');
      expect(DesktopGalleryActions.hoveredGid.value, 'after');
      await _copyShortcut(tester, 'after', platform: TargetPlatform.windows);
      expect(host.clipboard, 'https://example.test/g/after/offline/');

      final click = await tester.startGesture(
        tester.getCenter(_card('after')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await click.up();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-gallery-menu')),
        findsOneWidget,
      );
      expect(find.text('Ctrl+Shift+C'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('an unkeyed reused card transfers its hover to the new gid', (
    tester,
  ) async {
    final host = _ListHost(ListModeEnum.list, <GalleryProvider>[
      _gallery('old'),
    ]);
    await host.pump(tester);
    Get.put<GalleryItemController>(
      GalleryItemController(galleryProvider: _gallery('new')),
      tag: 'new',
    );
    var gid = 'old';
    late StateSetter rebuild;
    await tester.pumpWidget(
      GetCupertinoApp(
        locale: const Locale('en'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: L10n.delegate.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Center(
              child: SizedBox(
                width: 300,
                height: 160,
                child: DesktopCardChrome(
                  gid: gid,
                  child: const ColoredBox(color: CupertinoColors.systemGrey),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _hover(tester, 'old');
    rebuild(() => gid = 'new');
    await tester.pumpAndSettle();
    expect(DesktopGalleryActions.hoveredGid.value, 'new');
    await _copyShortcut(tester, 'new');
    expect(host.clipboard, 'https://example.test/g/new/offline/');

    // Updating or disposing a card must not clear another card's ownership.
    DesktopGalleryActions.hoveredGid.value = 'another-card';
    rebuild(() => gid = 'old');
    await tester.pumpAndSettle();
    expect(DesktopGalleryActions.hoveredGid.value, 'another-card');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(DesktopGalleryActions.hoveredGid.value, 'another-card');
  });
}
