import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/widget/desktop_card_chrome.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _History extends GetxController implements HistoryController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Desktop action test unexpectedly accessed history');
}

class _Layout extends LayoutServices {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}

/// Real cards paint and take hits; an empty box would not.
class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF202020),
    child: SizedBox(height: 160, width: double.infinity),
  );
}

void main() {
  final toasts = <String>[];
  String? clipboard;

  GalleryItemController register(GalleryProvider provider) {
    final item = GalleryItemController(galleryProvider: provider);
    Get.put<GalleryItemController>(item, tag: provider.gid);
    return item;
  }

  Future<void> pump(
    WidgetTester tester, {
    required List<GalleryProvider> galleries,
    TargetPlatform host = TargetPlatform.macOS,
    double width = 900,
  }) async {
    Get.testMode = true;
    PlatformCapabilities.debugHostPlatformOverride = host;
    DesktopGalleryActions.debugToast = toasts.add;
    favoriteStates.setAccount('desktop-actions');
    Get.put<HistoryController>(_History());
    Get.put<LayoutServices>(_Layout()).layoutMode = LayoutMode.large;
    galleries.forEach(register);
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      PlatformCapabilities.debugHostPlatformOverride = null;
      DesktopGalleryActions.debugToast = null;
      DesktopGalleryActions.hoveredGid.value = null;
      toasts.clear();
      clipboard = null;
      tester.view.reset();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
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
        // Like the desktop window's title bar: the navigator starts lower
        // than the window.
        builder: (context, child) =>
            Padding(padding: const EdgeInsets.only(top: 30), child: child),
        home: const CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: Column(
                children: <Widget>[
                  DesktopCardChrome(gid: '1', child: _Card()),
                  DesktopCardChrome(gid: '2', child: _Card()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder card(String gid) => find.byKey(ValueKey('desktop-card-$gid'));

  double quickOpacity(WidgetTester tester, String gid) => tester
      .widget<AnimatedOpacity>(find.byKey(ValueKey('desktop-quick-$gid')))
      .opacity;

  Future<TestGesture> hover(WidgetTester tester, Offset at) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(800, 650));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(at);
    await tester.pumpAndSettle();
    return mouse;
  }

  Future<void> rightClick(WidgetTester tester, Offset at) async {
    final click = await tester.startGesture(
      at,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await click.up();
    await tester.pumpAndSettle();
  }

  List<String> menuLabels(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('desktop-gallery-menu')),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? '')
      .toList();

  testWidgets('hovering a card shows its quick actions and marks it', (
    tester,
  ) async {
    await pump(
      tester,
      galleries: <GalleryProvider>[
        const GalleryProvider(gid: '1', token: 'aaaaaaaaaa'),
        const GalleryProvider(gid: '2', token: 'bbbbbbbbbb'),
      ],
    );
    expect(quickOpacity(tester, '1'), 0);

    final mouse = await hover(tester, tester.getCenter(card('1')));
    expect(quickOpacity(tester, '1'), 1);
    expect(quickOpacity(tester, '2'), 0);
    expect(DesktopGalleryActions.hoveredGid.value, '1');
    Finder inCard(String key) =>
        find.descendant(of: card('1'), matching: find.byKey(ValueKey(key)));
    final l10n = L10n.current;
    expect(inCard('desktop-quick-${l10n.read}'), findsOneWidget);
    expect(inCard('desktop-quick-${l10n.add_to_favorites}'), findsOneWidget);
    expect(inCard('desktop-quick-${l10n.download}'), findsOneWidget);

    await mouse.moveTo(tester.getCenter(card('2')));
    await tester.pumpAndSettle();
    expect(quickOpacity(tester, '1'), 0);
    expect(DesktopGalleryActions.hoveredGid.value, '2');

    await mouse.moveTo(const Offset(800, 650));
    await tester.pumpAndSettle();
    expect(DesktopGalleryActions.hoveredGid.value, isNull);
  });

  testWidgets('a right click opens the gallery menu; copy link uses it', (
    tester,
  ) async {
    await pump(
      tester,
      galleries: <GalleryProvider>[
        const GalleryProvider(
          gid: '1',
          token: 'aaaaaaaaaa',
          url: 'https://e-hentai.org/g/1/aaaaaaaaaa/',
          uploader: 'someone',
        ),
        const GalleryProvider(gid: '2', token: 'bbbbbbbbbb', favcat: '3'),
      ],
    );

    final click = tester.getCenter(card('1'));
    await rightClick(tester, click);
    // The menu opens at the pointer, below the window's title bar too.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('desktop-gallery-menu'))),
      click,
    );
    final l10n = L10n.current;
    expect(menuLabels(tester), <String>[
      l10n.read,
      '⌘',
      l10n.add_to_favorites,
      l10n.download,
      '⌘D',
      l10n.copy_link,
      '⇧⌘C',
      '${l10n.filter_by_uploader} · someone',
    ]);

    await tester.tap(find.byKey(ValueKey('desktop-menu-${l10n.copy_link}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-gallery-menu')), findsNothing);
    expect(clipboard, 'https://e-hentai.org/g/1/aaaaaaaaaa/');
    expect(toasts, <String>[l10n.copied_to_clipboard]);

    // A favorite offers moving and removing it; no uploader, no filter.
    await rightClick(tester, tester.getCenter(card('2')));
    final labels = menuLabels(tester);
    expect(labels, contains(l10n.change_to_favorites));
    expect(labels, contains(l10n.remove_from_favorites));
    expect(labels, isNot(contains(l10n.add_to_favorites)));
    expect(labels.where((l) => l.startsWith(l10n.filter_by_uploader)), isEmpty);

    // Clicking outside dismisses it without acting.
    await tester.tapAt(const Offset(800, 650));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-gallery-menu')), findsNothing);
  });

  testWidgets('the menu stays inside the window near its edge', (tester) async {
    await pump(
      tester,
      host: TargetPlatform.windows,
      width: 400,
      galleries: <GalleryProvider>[
        const GalleryProvider(gid: '1', token: 'aaaaaaaaaa'),
        const GalleryProvider(gid: '2', token: 'bbbbbbbbbb'),
      ],
    );

    await rightClick(
      tester,
      tester.getBottomRight(card('2')) - const Offset(4, 4),
    );
    final menu = tester.getRect(
      find.byKey(const ValueKey('desktop-gallery-menu')),
    );
    expect(menu.left, greaterThanOrEqualTo(8));
    expect(menu.right, lessThanOrEqualTo(392));
    expect(menu.bottom, lessThanOrEqualTo(692));
    // Windows labels its shortcuts with Ctrl.
    expect(menuLabels(tester), contains('Ctrl+Shift+C'));
  });

  testWidgets('shortcuts act on the hovered card, else the detail gallery', (
    tester,
  ) async {
    await pump(
      tester,
      galleries: <GalleryProvider>[
        const GalleryProvider(
          gid: '1',
          token: 'aaaaaaaaaa',
          url: 'https://e-hentai.org/g/1/aaaaaaaaaa/',
        ),
        const GalleryProvider(
          gid: '2',
          token: 'bbbbbbbbbb',
          url: 'https://e-hentai.org/g/2/bbbbbbbbbb/',
        ),
      ],
    );
    final context = tester.element(card('1'));

    KeyDownEvent copyEvent() => const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyC,
      logicalKey: LogicalKeyboardKey.keyC,
      timeStamp: Duration.zero,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);

    // Nothing hovered or open: not handled.
    expect(
      DesktopGalleryActions.handleShortcut(
        context,
        copyEvent(),
        detailGid: null,
      ),
      isFalse,
    );

    expect(
      DesktopGalleryActions.handleShortcut(
        context,
        copyEvent(),
        detailGid: '2',
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(clipboard, contains('/g/2/bbbbbbbbbb/'));

    await hover(tester, tester.getCenter(card('1')));
    expect(
      DesktopGalleryActions.handleShortcut(
        context,
        copyEvent(),
        detailGid: '2',
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(clipboard, contains('/g/1/aaaaaaaaaa/'));

    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    // Plain C is no shortcut.
    expect(
      DesktopGalleryActions.handleShortcut(
        context,
        copyEvent(),
        detailGid: '2',
      ),
      isFalse,
    );
  });

  testWidgets('touch platforms get no quick actions or menu', (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
    await tester.pumpWidget(
      const DesktopCardChrome(
        gid: '1',
        child: SizedBox(key: ValueKey('card')),
      ),
    );
    expect(find.byType(DesktopQuickActions), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });
}
