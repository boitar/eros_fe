import 'dart:async';
import 'dart:io';

import 'package:eros_fe/common/controller/gallerycache_controller.dart';
import 'package:eros_fe/common/controller/recent_reading_store.dart';
import 'package:eros_fe/common/service/desktop_reading_source.dart';
import 'package:eros_fe/common/service/desktop_ui_preferences.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/controller/view_state.dart';
import 'package:eros_fe/pages/image_view/view/view_page.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:eros_fe/widget/desktop_recent_reading.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends EhSettingService {
  @override
  // Tests use isolated defaults instead of loading a persisted profile.
  // ignore: must_call_super
  void onInit() {}
}

class _Cache extends GetxController implements GalleryCacheController {
  @override
  GalleryProvider? getGalleryProviderCache(String? gid) => GalleryProvider(
    gid: gid,
    englishTitle: 'Neutral reading fixture',
    token: 'fixture',
  );
  @override
  Future<void> setIndex(
    String gid,
    int index, {
    bool saveToStore = false,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> mount(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    GetCupertinoApp(
      locale: const Locale('en'),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: CupertinoPageScaffold(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 300, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
  });
  tearDown(() async {
    await RecentReadingStore.instance.clear();
    Get.reset();
  });

  testWidgets(
    'menu arrow keys select once, Escape restores the invoking focus',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var selected = '';
      await mount(
        tester,
        Builder(
          builder: (context) => DesktopControl(
            label: 'Display',
            focusNode: focus,
            autofocus: true,
            onPressed: () => showDesktopGalleryMenu(
              context,
              position: const Offset(20, 40),
              title: 'Current group · A',
              entries: [
                for (final value in ['List', 'Grid', 'Waterfall'])
                  DesktopMenuEntry(
                    label: value,
                    selected: value == 'List',
                    icon: CupertinoIcons.square_grid_2x2,
                    onSelected: () => selected += value,
                  ),
              ],
            ),
            child: const Text('Display'),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Current group · A'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 'Grid');
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopGalleryMenu), findsNothing);
      expect(selected, 'Grid');
      expect(focus.hasFocus, isTrue);
    },
  );

  testWidgets(
    'recent entries prevent duplicate opens and retain history when empty',
    (tester) async {
      final store = RecentReadingStore(read: () => null, write: (_) async {});
      var histories = 0;
      var opens = 0;
      final pending = Completer<bool>();
      await mount(
        tester,
        DesktopRecentReading(
          store: store,
          onHistory: () => histories++,
          openEntry: (_) {
            opens++;
            return pending.future;
          },
        ),
      );
      await tester.tap(find.text('View all history'));
      expect(histories, 1);
      store.record(
        store.ticket('gid:1'),
        const RecentReadingEntry(
          id: 'gid:1',
          gid: '1',
          title: 'A work',
          time: 1,
          index: 0,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A work'));
      await tester.pump();
      await tester.tap(find.text('A work'));
      expect(opens, 1);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to open'), findsOneWidget);
      await store.clear();
      await tester.pumpAndSettle();
      expect(find.text('A work'), findsNothing);
      expect(find.text('View all history'), findsOneWidget);
    },
  );

  testWidgets(
    'reader records only decoded current pages and invalidates pending clear events',
    (tester) async {
      Get.put<GalleryCacheController>(_Cache());
      final store = RecentReadingStore(read: () => null, write: (_) async {});
      await store.clear();
      ViewExtState reader() => ViewExtState(
        readingStore: store,
        repository: ViewRepository(
          gid: '123',
          loadType: LoadFrom.download,
          files: ['/fixture/1.png', '/fixture/2.png'],
        ),
      );
      final state = reader();
      state.recordPresentedPage();
      await tester.pump();
      expect(store.recent, isEmpty, reason: 'not decoded');
      state.loadCompleMap[2] = true;
      state.recordPresentedPage();
      await tester.pump();
      expect(store.recent, isEmpty, reason: 'prefetch is not presentation');
      state.loadCompleMap[1] = true;
      state.recordPresentedPage();
      await store.clear();
      await tester.pump();
      expect(
        store.recent,
        isEmpty,
        reason: 'clear invalidates deferred presentation',
      );
      state.currentItemIndex = 1;
      await tester.pump();
      expect(
        store.recent.single.index,
        1,
        reason: 'new visible page is new reading',
      );
      state.dispose();
      await store.clear();
      final reopened = reader();
      reopened.loadCompleMap[1] = true;
      reopened.recordPresentedPage();
      await tester.pump();
      expect(store.recent.single.index, 0);
      reopened.dispose();
      await tester.pump(const Duration(seconds: 3));
    },
  );

  test('desktop preference reset survives restart', () async {
    String? persisted;
    final first = DesktopUiPreferences(
      read: () => null,
      write: (v) async => persisted = v,
    );
    first.load();
    first.showSidebar(false);
    first.toggleSection('recent');
    first.setSplitRatio(null);
    await first.pendingWrites;
    final second = DesktopUiPreferences(read: () => persisted);
    second.load();
    expect(second.sidebarVisible, isFalse);
    expect(second.isExpanded('recent'), isFalse);
    expect(second.splitRatio, isNull);
    expect(second.legacyProportion, isNull);
  });

  test('download source enumerates real images in natural order', () async {
    final directory = await Directory('tmpfile').createTemp('recent-source-');
    try {
      for (final name in ['10.jpg', '2.PNG', '1.webp', 'readme.txt']) {
        await File('${directory.path}/$name').writeAsString('fixture');
      }
      final images = await DesktopReadingSource.directoryImages(directory.path);
      expect(images.map((p) => p.split('/').last), [
        '1.webp',
        '2.PNG',
        '10.jpg',
      ]);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
