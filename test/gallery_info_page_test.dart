// ignore_for_file: must_call_super

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eros_fe/common/controller/cache_controller.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/controller/image_block_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/models/gallery_stats.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/view/gallery_info_page.dart';
import 'package:eros_fe/pages/gallery/view/gallery_stats_section.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_more_actions.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/image/eh_cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oktoast/oktoast.dart' as oktoast;

class _FakeSettings extends EhSettingService {
  @override
  void onInit() {
    vibrate.value = false;
  }

  @override
  bool get jpnTitleInGalleryPage => false;
}

class _FakeTheme extends ThemeService {
  @override
  void onInit() {}
}

class _FakeCacheController extends GetxController implements CacheController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeImageBlockController extends GetxController
    implements ImageBlockController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDownloadController extends DownloadController {
  @override
  void onInit() {}
}

class _FakeUserController extends UserController {
  @override
  void onInit() {}
}

class _FakeGalleryPageController extends GetxController
    implements GalleryPageController {
  _FakeGalleryPageController(this.gState);

  @override
  final GalleryPageState gState;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapApp({
  required Widget child,
  Locale locale = const Locale('zh', 'CN'),
  Brightness brightness = Brightness.dark,
  bool? supportsAnnounce,
}) {
  final wrappedChild = supportsAnnounce == null
      ? child
      : Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(supportsAnnounce: supportsAnnounce),
            child: child,
          ),
        );
  return oktoast.OKToast(
    child: GetCupertinoApp(
      locale: locale,
      theme: ehTheme.palette.themeData(
        brightness,
        const CupertinoTextThemeData(),
      ),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        L10n.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: wrappedChild,
    ),
  );
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_FakeSettings());
    Get.put<ThemeService>(_FakeTheme());
    Get.put<ControllerTagService>(ControllerTagService());
    Get.put<CacheController>(_FakeCacheController());
    Get.put<ImageBlockController>(_FakeImageBlockController());
    Get.put<DownloadController>(_FakeDownloadController());
    Get.find<ThemeService>().themeModel = ThemesModeEnum.darkMode;
  });

  tearDown(() {
    oktoast.dismissAllToast();
    Get.reset();
  });

  test('resolveGalleryUrl normalizes relative, protocol-relative, uppercase, and rejects invalid URLs', () {
    final base = Uri.parse('https://exhentai.org');
    expect(
      GalleryInfoPage.resolveGalleryUrl(
        const GalleryProvider(url: '//exhentai.org/g/4355554/d1e20e7bcd/'),
        baseUri: base,
      ),
      'https://exhentai.org/g/4355554/d1e20e7bcd/',
    );
    expect(
      GalleryInfoPage.resolveGalleryUrl(
        const GalleryProvider(url: 'g/4355554/d1e20e7bcd/'),
        baseUri: base,
      ),
      'https://exhentai.org/g/4355554/d1e20e7bcd/',
    );
    expect(
      GalleryInfoPage.resolveGalleryUrl(
        const GalleryProvider(url: 'HTTPS://E-HENTAI.ORG/g/4355554/d1e20e7bcd/'),
        baseUri: base,
      ),
      'https://e-hentai.org/g/4355554/d1e20e7bcd/',
    );
    expect(
      GalleryInfoPage.resolveGalleryUrl(
        const GalleryProvider(
          url: 'https://evil.example/g/4355554/d1e20e7bcd/',
          gid: '4355554',
          token: 'd1e20e7bcd',
        ),
        baseUri: base,
      ),
      'https://exhentai.org/g/4355554/d1e20e7bcd/',
    );
    expect(
      GalleryInfoPage.resolveGalleryUrl(
        const GalleryProvider(url: 'javascript:alert(1)'),
        baseUri: base,
      ),
      '',
    );
  });

  testWidgets(
    'GalleryInfoPage renders structured sections, aligns values flush right, keeps SelectableText copy-safe, and uses >=44pt targets',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final clipboardValues = <String>[];
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>?;
            final text = args?['text']?.toString();
            if (text != null) {
              clipboardValues.add(text);
            }
          }
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        SystemChannels.accessibility,
        (dynamic message) async {
          if (message is Map<dynamic, dynamic> &&
              message['type'] == 'announce') {
            final data = message['data'] as Map<dynamic, dynamic>?;
            final text = data?['message']?.toString();
            if (text != null) {
              announcements.add(text);
            }
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler(SystemChannels.accessibility, null),
      );

      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '4355554',
          token: 'd1e20e7bcd',
          url: '//exhentai.org/g/4355554/d1e20e7bcd/',
          englishTitle: '[Artist] Sample Archival Title [Translated]',
          japaneseTitle: '',
          category: 'Misc',
          uploader: 'sdsa123',
          postTime: '2026-11-25 10:44',
          language: 'Japanese',
          filecount: '42',
          filesizeText: '86.4 MB',
          favoritedCount: '518',
          favcat: '1',
          favTitle: 'Favorites 1',
          rating: 4.72,
          ratingCount: '64',
          torrentcount: '2',
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '4355554');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      final searchedUploaders = <String>[];
      final externalUrls = <String>[];

      await tester.pumpWidget(
        _wrapApp(
          supportsAnnounce: true,
          child: GalleryInfoPage(
            onSearchUploader: searchedUploaders.add,
            onOpenExternalUrl: externalUrls.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Structured section headers exist; empty Japanese title is omitted.
      expect(find.text('英文标题'), findsOneWidget);
      expect(find.text('日文标题'), findsNothing);
      expect(find.text('画廊属性'), findsOneWidget);
      expect(find.text('标识与链接'), findsOneWidget);

      // Protocol-relative URL was normalized to canonical https URL.
      expect(
        find.text('https://exhentai.org/g/4355554/d1e20e7bcd/'),
        findsOneWidget,
      );

      // Overview metrics strip values render with no raw 'null'/'false' strings.
      expect(find.text('4.72'), findsOneWidget);
      expect(find.text('64 人评分'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('86.4 MB'), findsOneWidget);
      expect(find.text('518'), findsOneWidget);
      expect(find.text('null'), findsNothing);
      expect(find.text('false'), findsNothing);

      // Detail values align cleanly along the same right edge (no Flexible+Expanded mid-card drift).
      final postedRight = tester.getTopRight(find.text('2026-11-25 10:44')).dx;
      final languageRight = tester.getTopRight(find.text('Japanese')).dx;
      final favRight = tester.getTopRight(find.text('Favorites 1')).dx;
      final torrentRight = tester.getTopRight(find.text('2')).dx;
      expect((postedRight - languageRight).abs(), lessThanOrEqualTo(0.5));
      expect((postedRight - favRight).abs(), lessThanOrEqualTo(0.5));
      expect((postedRight - torrentRight).abs(), lessThanOrEqualTo(0.5));
      expect(postedRight, closeTo(358.0, 2.0));

      // Icon buttons satisfy >=44pt minimum touch targets.
      final copyButtonSize = tester.getSize(find.bySemanticsLabel('复制 英文标题'));
      expect(copyButtonSize.width, greaterThanOrEqualTo(44));
      expect(copyButtonSize.height, greaterThanOrEqualTo(44));

      final searchButtonSize = tester.getSize(find.bySemanticsLabel('按上传者筛选'));
      expect(searchButtonSize.width, greaterThanOrEqualTo(44));
      expect(searchButtonSize.height, greaterThanOrEqualTo(44));

      // Overview category and GID chips are non-interactive badges (full-size
      // copy rows live in Details / Identifiers).
      expect(
        find.ancestor(
          of: find.text('#4355554'),
          matching: find.byType(EhPressable),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('Misc').first,
          matching: find.byType(EhPressable),
        ),
        findsNothing,
      );
      await tester.tap(find.text('#4355554'));
      await tester.pump();
      expect(clipboardValues, isEmpty);

      // Tapping SelectableText directly does NOT trigger unintended clipboard copy.
      await tester.tap(find.byType(SelectableText).first);
      await tester.pump();
      expect(clipboardValues, isEmpty);

      // Explicit Copy button on English title copies title cleanly, updates
      // button semantics to localized confirmation, and announces to screen readers.
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.ensureVisible(find.bySemanticsLabel('复制 英文标题'));
        await tester.tap(find.bySemanticsLabel('复制 英文标题'));
        await tester.pump();
        expect(
          clipboardValues,
          contains('[Artist] Sample Archival Title [Translated]'),
        );
        expect(find.bySemanticsLabel('已复制到剪贴板'), findsOneWidget);
        expect(announcements, contains('已复制到剪贴板'));

        // After confirmation timer expires, semantic label restores to copy action.
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();
        expect(find.bySemanticsLabel('复制 英文标题'), findsOneWidget);
        expect(find.bySemanticsLabel('已复制到剪贴板'), findsNothing);

        // Search uploader button fires callback.
        await tester.ensureVisible(find.bySemanticsLabel('按上传者筛选'));
        await tester.tap(find.bySemanticsLabel('按上传者筛选'));
        await tester.pump();
        expect(searchedUploaders, <String>['sdsa123']);

        // Open in browser button fires callback with normalized URL.
        await tester.ensureVisible(find.bySemanticsLabel('浏览器打开'));
        await tester.tap(find.bySemanticsLabel('浏览器打开'));
        await tester.pump();
        expect(externalUrls, <String>[
          'https://exhentai.org/g/4355554/d1e20e7bcd/',
        ]);

        // Tapping GID cell copies raw GID and announces copy confirmation.
        announcements.clear();
        await tester.ensureVisible(find.text('4355554'));
        await tester.tap(find.text('4355554'));
        await tester.pump();
        expect(clipboardValues, contains('4355554'));
        expect(announcements, contains('已复制到剪贴板'));
      } finally {
        semanticsHandle.dispose();
      }

      oktoast.dismissAllToast();
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryInfoPage updates incremental entry live when download completes while open',
    (tester) async {
      final dlCtrl = Get.find<DownloadController>();
      dlCtrl.dState.galleryTaskMap[3104821] = GalleryTask(
        gid: 3104821,
        token: '9a4f2c1b8e',
        title: 'Yoimachi',
        dirPath: '/tmp/yoimachi',
        fileCount: 48,
        completCount: 20,
        status: TaskStatus.running.value,
      );

      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '3104821',
          token: '9a4f2c1b8e',
          url: 'https://e-hentai.org/g/3104821/9a4f2c1b8e/',
          englishTitle: 'Yoimachi',
          newerVersions: <GalleryNewerVersion>[
            GalleryNewerVersion(
              gid: '3298510',
              token: '1234567890',
              url: 'https://e-hentai.org/g/3298510/1234567890/',
              title: 'Yoimachi [Expanded]',
              addedDate: '2026-03-14 08:20',
            ),
          ],
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '3104821');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      await tester.pumpWidget(_wrapApp(child: const GalleryInfoPage()));
      await tester.pumpAndSettle();

      expect(find.text('增量更新已下载画廊'), findsNothing);

      // Simulate download completing while the metadata page remains open.
      dlCtrl.dState.galleryTaskMap[3104821] = dlCtrl
          .dState
          .galleryTaskMap[3104821]!
          .copyWith(completCount: 48, status: TaskStatus.complete.value);
      await tester.pumpAndSettle();

      expect(find.text('增量更新已下载画廊'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryInfoPage handles external URL launcher returning false and throwing exceptions gracefully',
    (tester) async {
      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '777777',
          token: 'abcdef1234',
          url: 'https://e-hentai.org/g/777777/abcdef1234/',
          englishTitle: 'Launch Error Gallery',
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '777777');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      var attempts = 0;
      await tester.pumpWidget(
        _wrapApp(
          child: GalleryInfoPage(
            externalUrlLauncher: (url) async {
              attempts++;
              if (attempts == 1) {
                return false;
              }
              throw PlatformException(code: 'LAUNCH_FAILED');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openButton = find.bySemanticsLabel('浏览器打开');
      await tester.ensureVisible(openButton);

      // Case 1: returns false -> handled with toast, no uncaught error.
      await tester.tap(openButton);
      await tester.pump();
      expect(attempts, 1);

      // Case 2: throws PlatformException -> caught cleanly with toast.
      await tester.tap(openButton);
      await tester.pump();
      expect(attempts, 2);

      oktoast.dismissAllToast();
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryInfoPage privacy blur avoids unblurred ShownImage placeholder on cover thumbnail',
    (tester) async {
      final settings = Get.find<EhSettingService>();
      settings.isGalleryImgBlur.value = true;

      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '888888',
          token: '123456abcd',
          url: 'https://e-hentai.org/g/888888/123456abcd/',
          imgUrl: 'https://s.exhentai.org/w/01/234/56789-cover.webp',
          englishTitle: 'Blurred Cover Gallery',
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '888888');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      await tester.pumpWidget(_wrapApp(child: const GalleryInfoPage()));
      await tester.pump();

      final cover = tester.widget<CoverImg>(find.byType(CoverImg));
      expect(cover.key, const ValueKey<bool>(true));
      expect(cover.placeholderWhileDecoding, isFalse);
      final placeholderWidget = cover.placeholder!(
        tester.element(find.byType(CoverImg)),
      );
      expect(placeholderWidget, isNot(isA<ShownImage>()));

      // Turning blur off replaces the CoverImg subtree key and re-enables ShownImage.
      final blurredElement = tester.element(find.byType(CoverImg));
      settings.isGalleryImgBlur.value = false;
      await tester.pump();
      final unblurredElement = tester.element(find.byType(CoverImg));
      expect(unblurredElement, isNot(same(blurredElement)));
      final unblurredCover = tester.widget<CoverImg>(find.byType(CoverImg));
      expect(unblurredCover.key, const ValueKey<bool>(false));
      expect(unblurredCover.placeholderWhileDecoding, isTrue);
      final unblurredPlaceholder = unblurredCover.placeholder!(
        unblurredElement,
      );
      expect(unblurredPlaceholder, isA<ShownImage>());

      // Turning blur back on replaces the CoverImg subtree immediately so no
      // gapless unblurred frame can linger during decode.
      settings.isGalleryImgBlur.value = true;
      await tester.pump();
      final reblurredElement = tester.element(find.byType(CoverImg));
      expect(reblurredElement, isNot(same(unblurredElement)));
      final reblurredCover = tester.widget<CoverImg>(find.byType(CoverImg));
      expect(reblurredCover.key, const ValueKey<bool>(true));
      expect(reblurredCover.placeholderWhileDecoding, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryInfoPage formats English singular/plural ratings, Korean counter, unfavorited state, and desktop maxWidth',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '991200',
          token: 'abc1234567',
          englishTitle: 'English Only Title',
          japaneseTitle: '日本語タイトル',
          category: 'Doujinshi',
          favcat: '',
          rating: 5.0,
          ratingCount: '1',
          expunged: true,
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '991200');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      // English singular: "1 rating"
      await tester.pumpWidget(
        _wrapApp(
          locale: const Locale('en'),
          brightness: Brightness.light,
          child: const GalleryInfoPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 rating'), findsOneWidget);
      expect(find.text('Not Favorited'), findsOneWidget);
      expect(find.text('Expunged'), findsNWidgets(2));
      expect(find.text('null'), findsNothing);

      final cardRect = tester.getRect(
        find.byKey(GalleryInfoPage.contentStartKey),
      );
      expect(cardRect.width, lessThanOrEqualTo(640));
      expect(cardRect.center.dx, closeTo(600, 1.0));
      expect(
        tester.getTopLeft(find.text('English Title')).dy,
        lessThan(tester.getTopLeft(find.text('Japanese Title')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GalleryInfoPage formats Korean rating count using 건 counter', (
    tester,
  ) async {
    final state = GalleryPageState()
      ..galleryProvider = const GalleryProvider(
        gid: '991201',
        token: 'abc1234568',
        englishTitle: 'Korean Locale Gallery',
        rating: 4.5,
        ratingCount: '12',
      );
    final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '991201');
    Get.put<GalleryPageController>(
      _FakeGalleryPageController(state),
      tag: tag,
    );

    await tester.pumpWidget(
      _wrapApp(
        locale: const Locale('ko', 'KR'),
        brightness: Brightness.dark,
        child: const GalleryInfoPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('평가 12건'), findsOneWidget);
    // favcat == null represents unknown state ('—'), not 'Not Favorited' (즐겨찾기에 없음).
    expect(find.text('—'), findsWidgets);
    expect(find.text('즐겨찾기에 없음'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GalleryInfoPage suppresses copy confirmation on rejected clipboard write',
    (tester) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'CLIPBOARD_BUSY');
          }
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        SystemChannels.accessibility,
        (dynamic message) async {
          if (message is Map<dynamic, dynamic> &&
              message['type'] == 'announce') {
            final data = message['data'] as Map<dynamic, dynamic>?;
            final text = data?['message']?.toString();
            if (text != null) {
              announcements.add(text);
            }
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler(SystemChannels.accessibility, null),
      );

      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '991202',
          token: 'deadbeef01',
          englishTitle: 'Busy Clipboard Gallery',
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '991202');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      await tester.pumpWidget(
        _wrapApp(
          supportsAnnounce: true,
          child: const GalleryInfoPage(),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.ensureVisible(find.bySemanticsLabel('复制 英文标题'));
        await tester.tap(find.bySemanticsLabel('复制 英文标题'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.bySemanticsLabel('复制 英文标题'), findsOneWidget);
        expect(find.bySemanticsLabel('已复制到剪贴板'), findsNothing);
        expect(announcements, isEmpty);

        await tester.ensureVisible(find.text('991202'));
        await tester.tap(find.text('991202'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.bySemanticsLabel('已复制到剪贴板'), findsNothing);
        expect(announcements, isEmpty);
      } finally {
        semanticsHandle.dispose();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryInfoPage uses semantic liveRegion instead of sendAnnouncement when supportsAnnounce is false',
    (tester) async {
      final clipboardValues = <String>[];
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>?;
            final text = args?['text']?.toString();
            if (text != null) {
              clipboardValues.add(text);
            }
          }
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        SystemChannels.accessibility,
        (dynamic message) async {
          if (message is Map<dynamic, dynamic> &&
              message['type'] == 'announce') {
            final data = message['data'] as Map<dynamic, dynamic>?;
            final text = data?['message']?.toString();
            if (text != null) {
              announcements.add(text);
            }
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler(SystemChannels.accessibility, null),
      );

      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '991203',
          token: 'feedface02',
          englishTitle: 'TalkBack Safe Gallery',
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '991203');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      await tester.pumpWidget(
        _wrapApp(
          supportsAnnounce: false,
          child: const GalleryInfoPage(),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.ensureVisible(find.bySemanticsLabel('复制 英文标题'));
        await tester.tap(find.bySemanticsLabel('复制 英文标题'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(clipboardValues, contains('TalkBack Safe Gallery'));
        expect(announcements, isEmpty);

        final liveRegion = tester.widget<Semantics>(
          find.byKey(GalleryInfoPage.copyLiveRegionKey),
        );
        expect(liveRegion.properties.liveRegion, isTrue);
        expect(liveRegion.properties.label, '已复制到剪贴板');

        // Clears liveRegion label and restores button label after timer expires.
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();
        final clearedLiveRegion = tester.widget<Semantics>(
          find.byKey(GalleryInfoPage.copyLiveRegionKey),
        );
        expect(clearedLiveRegion.properties.label, isNull);
        expect(find.bySemanticsLabel('复制 英文标题'), findsOneWidget);
      } finally {
        semanticsHandle.dispose();
      }
      oktoast.dismissAllToast();
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryInfoPage places GalleryStatsSection collapsed at bottom, loads on demand, supports collapse/re-expand cache, chart interactions, and opens stats.php',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sampleStats = GalleryStats(
        totalVisits: 128450,
        allTimeRanking: 18,
        allTimeScore: 4280,
        yearRanking: 125,
        yearScore: 1520,
        monthRanking: 42,
        monthScore: 890,
        yearlyStats: <GalleryVisitStat>[
          GalleryVisitStat(period: '2025', visits: 80000, hits: 920000),
          GalleryVisitStat(period: '2026', visits: 48450, hits: 540000),
        ],
        monthlyStats: <GalleryVisitStat>[
          GalleryVisitStat(period: 'January', visits: 12400, hits: 140000),
          GalleryVisitStat(period: 'February', visits: 36000, hits: 410000),
          GalleryVisitStat(period: 'March', visits: 18200, hits: 205000),
        ],
        dailyStats: <GalleryVisitStat>[],
      );

      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '3104821',
          token: '9a4f2c1b8e',
          url: 'https://exhentai.org/g/3104821/9a4f2c1b8e/',
          englishTitle: 'Stats Integrated Gallery',
          postTime: '2025-01-10 08:00',
          favoritedCount: '5138',
          parent: '3001122',
          parentHref: 'https://exhentai.org/g/3001122/0123456789/',
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '3104821');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      final externalUrls = <String>[];
      var totalLoadCalls = 0;
      var refreshCalls = 0;

      await tester.pumpWidget(
        _wrapApp(
          child: GalleryInfoPage(
            onOpenExternalUrl: externalUrls.add,
            statsLoader: (gid, token, {refresh = false, cancelToken}) async {
              totalLoadCalls++;
              if (refresh) {
                refreshCalls++;
              }
              return sampleStats;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exact vertical order:
      // Overview < Lineage < Details < Identifiers < Gallery Stats (bottom).
      final overviewY = tester
          .getTopLeft(find.byKey(GalleryInfoPage.contentStartKey))
          .dy;
      final lineageY = tester.getTopLeft(find.text('版本血缘')).dy;
      final detailsY = tester.getTopLeft(find.text('画廊属性')).dy;
      final idsY = tester.getTopLeft(find.text('标识与链接')).dy;
      final statsY = tester
          .getTopLeft(find.byKey(GalleryStatsSection.sectionKey))
          .dy;

      expect(overviewY, lessThan(lineageY));
      expect(lineageY, lessThan(detailsY));
      expect(detailsY, lessThan(idsY));
      expect(idsY, lessThan(statsY));

      // Collapsed by default: zero eager stats.php requests!
      expect(totalLoadCalls, 0);
      expect(find.byKey(GalleryStatsSection.expandToggleKey), findsOneWidget);
      expect(find.text('查看画廊统计'), findsOneWidget);
      expect(find.text('128,450'), findsNothing);

      // Header hint clarifies that rankings & trends belong to the current gid.
      expect(find.text('当前版本 #3104821 · stats.php'), findsOneWidget);

      // Tap expand toggle -> loads stats on demand.
      final expandToggle = find.byKey(GalleryStatsSection.expandToggleKey);
      await tester.ensureVisible(expandToggle);
      final expandSize = tester.getSize(expandToggle);
      expect(expandSize.height, greaterThanOrEqualTo(44));
      await tester.tap(expandToggle);
      await tester.pumpAndSettle();

      expect(totalLoadCalls, 1);
      expect(find.text('128,450'), findsOneWidget);
      expect(find.text('4.0%'), findsOneWidget);
      expect(find.text('#18'), findsOneWidget);
      expect(find.text('#125'), findsOneWidget);
      expect(find.text('未上榜'), findsOneWidget);

      // Collapse and re-expand -> reuses already loaded data without refetching.
      final collapseToggle = find.byKey(GalleryStatsSection.collapseToggleKey);
      await tester.ensureVisible(collapseToggle);
      final collapseSize = tester.getSize(collapseToggle);
      expect(collapseSize.width, greaterThanOrEqualTo(44));
      expect(collapseSize.height, greaterThanOrEqualTo(44));
      await tester.tap(collapseToggle);
      await tester.pumpAndSettle();
      expect(find.text('128,450'), findsNothing);

      await tester.ensureVisible(find.byKey(GalleryStatsSection.expandToggleKey));
      await tester.tap(find.byKey(GalleryStatsSection.expandToggleKey));
      await tester.pumpAndSettle();
      expect(totalLoadCalls, 1);
      expect(find.text('128,450'), findsOneWidget);

      // Default granularity is Monthly (latest bucket March = 18,200).
      expect(find.text('18,200'), findsOneWidget);

      // Tapping the first bar on the left selects January (12,400).
      final chartFinder = find.byKey(GalleryStatsSection.chartKey);
      await tester.ensureVisible(chartFinder);
      final chartRect = tester.getRect(chartFinder);
      await tester.tapAt(Offset(chartRect.left + 60, chartRect.center.dy));
      await tester.pump();
      expect(find.text('12,400'), findsOneWidget);

      // Switching metric to Hits updates readout to latest monthly hits (205,000).
      await tester.tap(find.text('点击量'));
      await tester.pump();
      expect(find.text('205,000'), findsOneWidget);

      // Switching granularity to Yearly shows 2026 hits (540,000).
      await tester.tap(find.text('按年'));
      await tester.pump();
      expect(find.text('540,000'), findsOneWidget);

      // Switching to Daily (empty in fixture) shows clean empty-series notice.
      await tester.tap(find.text('按日'));
      await tester.pump();
      expect(find.text('该周期暂无历史数据'), findsOneWidget);

      // Refresh and Open stats.php buttons work and respect canonical stats URL.
      final refreshBtn = find.bySemanticsLabel('刷新统计');
      await tester.ensureVisible(refreshBtn);
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();
      expect(refreshCalls, 1);

      final openStatsBtn = find.bySemanticsLabel('打开 stats.php');
      await tester.ensureVisible(openStatsBtn);
      await tester.tap(openStatsBtn);
      await tester.pump();
      expect(externalUrls, <String>[
        'https://e-hentai.org/stats.php?gid=3104821&t=9a4f2c1b8e',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryStatsSection renders loading, error retry, unranked, loginRequired, and desktop 640pt layout cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '510001',
          token: 'a1b2c3d4e5',
          englishTitle: 'State Transition Gallery',
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '510001');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      final completer = Completer<GalleryStats>();
      var attempt = 0;

      await tester.pumpWidget(
        _wrapApp(
          child: GalleryInfoPage(
            statsLoader: (gid, token, {refresh = false, cancelToken}) {
              attempt++;
              if (attempt == 1) {
                return completer.future;
              }
              return Future<GalleryStats>.value(
                const GalleryStats(
                  totalVisits: 1450,
                  dailyStats: <GalleryVisitStat>[
                    GalleryVisitStat(period: '14th', visits: 920, hits: 4100),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(attempt, 0);

      // Expand stats section on demand -> triggers first fetch.
      final expandToggle = find.byKey(GalleryStatsSection.expandToggleKey);
      await tester.ensureVisible(expandToggle);
      await tester.tap(expandToggle);
      await tester.pump();

      // Loading skeleton is visible while the request is in flight.
      expect(find.text('正在获取统计数据…'), findsOneWidget);

      // Fail first attempt with network error.
      completer.completeError(
        const GalleryStatsException(GalleryStatsErrorKind.network, 'offline'),
      );
      await tester.pumpAndSettle();
      expect(find.text('获取画廊统计失败'), findsOneWidget);

      // Tap retry -> loads unranked gallery stats cleanly.
      final retryBtn = find.bySemanticsLabel('重新获取');
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(attempt, 2);
      expect(find.text('1,450'), findsOneWidget);
      expect(find.text('920'), findsOneWidget);
      expect(find.text('暂未进入任何周期榜单'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('galleryMoreActions includes galleryInfo entry with info icon', (
    tester,
  ) async {
    final state = GalleryPageState()
      ..galleryProvider = const GalleryProvider(
        gid: '600001',
        token: 'abcdef0123',
        englishTitle: 'More Actions Gallery',
      );
    final controller = _FakeGalleryPageController(state);

    List<GalleryMoreAction>? actions;
    await tester.pumpWidget(
      _wrapApp(
        child: Builder(
          builder: (context) {
            actions = galleryMoreActions(context, controller, isRoot: false);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final infoAction = actions!.firstWhere((a) => a.id == 'galleryInfo');
    expect(infoAction.title, '画廊信息');
    expect(infoAction.symbol, 'info.circle');
    expect(infoAction.icon, CupertinoIcons.info_circle);
    expect(infoAction.enabled, isTrue);
  });

  testWidgets(
    'GalleryStatsSection loaded state wraps cleanly in Russian on 320px at 1.6x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '8002',
          token: '8888888888',
          url: 'https://e-hentai.org/g/8002/8888888888/',
          englishTitle: 'Russian Loaded Stats Test',
          postTime: '2025-05-01 10:00',
          favoritedCount: '420',
          parent: '7999',
          parentHref: 'https://e-hentai.org/g/7999/9999999999/',
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '8002');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      await tester.pumpWidget(
        _wrapApp(
          locale: const Locale('ru'),
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.6),
            ),
            child: GalleryInfoPage(
              statsLoader: (gid, token, {refresh = false, cancelToken}) async =>
                  const GalleryStats(
                    totalVisits: 128450,
                    allTimeRanking: 12,
                    allTimeScore: 4100,
                    yearRanking: 88,
                    yearScore: 1200,
                    monthlyStats: <GalleryVisitStat>[
                      GalleryVisitStat(
                        period: 'January',
                        visits: 12400,
                        hits: 140000,
                      ),
                      GalleryVisitStat(
                        period: 'February',
                        visits: 36000,
                        hits: 410000,
                      ),
                    ],
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify collapsed row wraps cleanly at 320px @ 1.6x, then expand.
      final expandToggle = find.byKey(GalleryStatsSection.expandToggleKey);
      await tester.ensureVisible(expandToggle);
      await tester.tap(expandToggle);
      await tester.pumpAndSettle();

      expect(find.text('128,450'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryStatsSection localizes month labels, exposes adjustable screen-reader actions, and enforces >=44pt touch targets',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sampleStats = GalleryStats(
        totalVisits: 50000,
        monthlyStats: <GalleryVisitStat>[
          GalleryVisitStat(period: 'January', visits: 10000, hits: 50000),
          GalleryVisitStat(period: 'February', visits: 25000, hits: 120000),
          GalleryVisitStat(period: 'March', visits: 15000, hits: 75000),
        ],
      );

      final state = GalleryPageState()
        ..galleryProvider = const GalleryProvider(
          gid: '3104899',
          token: '9a4f2c1b8e',
          englishTitle: 'A11y & Localization Gallery',
        );
      final tag = Get.find<ControllerTagService>().pushPageCtrl(gid: '3104899');
      Get.put<GalleryPageController>(
        _FakeGalleryPageController(state),
        tag: tag,
      );

      await tester.pumpWidget(
        _wrapApp(
          child: GalleryInfoPage(
            statsLoader: (gid, token, {refresh = false, cancelToken}) async =>
                sampleStats,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expandToggle = find.byKey(GalleryStatsSection.expandToggleKey);
      await tester.ensureVisible(expandToggle);
      await tester.tap(expandToggle);
      await tester.pumpAndSettle();

      // Chinese locale localizes "March" -> "3月".
      expect(find.textContaining('3月'), findsOneWidget);

      // Metric tabs, granularity tabs, and Peak button all satisfy >=44pt targets.
      for (final label in <String>['浏览量', '点击量', '按年', '按月', '按日', '峰值 25K']) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.width, greaterThanOrEqualTo(44), reason: '$label width');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$label height');
      }

      // Adjustable semantics allow VoiceOver/TalkBack to step through buckets.
      final semanticsHandle = tester.ensureSemantics();
      try {
        final chartFinder = find.byKey(GalleryStatsSection.chartKey);
        final semanticsOwner = tester.renderObject(chartFinder).owner!.semanticsOwner!;
        final chartSemanticsNode = tester.getSemantics(chartFinder);
        expect(chartSemanticsNode.value, contains('3月'));
        expect(chartSemanticsNode.value, contains('15,000'));

        // Decrease from March (index 2) -> February (index 1: 25,000).
        semanticsOwner.performAction(
          chartSemanticsNode.id,
          SemanticsAction.decrease,
        );
        await tester.pump();
        expect(find.text('25,000'), findsOneWidget);
        expect(find.textContaining('2月'), findsOneWidget);

        // Increase back to March (index 2: 15,000).
        final updatedNode = tester.getSemantics(chartFinder);
        semanticsOwner.performAction(
          updatedNode.id,
          SemanticsAction.increase,
        );
        await tester.pump();
        expect(find.text('15,000'), findsOneWidget);
        expect(find.textContaining('3月'), findsOneWidget);
      } finally {
        semanticsHandle.dispose();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryStatsSection recovers automatically from loginRequired when UserController logs in while mounted',
    (tester) async {
      final userCtrl = Get.put<UserController>(_FakeUserController());
      userCtrl.user(const User());

      var loadCalls = 0;
      await tester.pumpWidget(
        _wrapApp(
          child: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: GalleryStatsSection(
                gid: '620001',
                token: '1234567890',
                initiallyExpanded: true,
                respectUserLoginState: true,
                statsLoader: (gid, token, {refresh = false, cancelToken}) async {
                  loadCalls++;
                  return const GalleryStats(
                    totalVisits: 4321,
                    dailyStats: <GalleryVisitStat>[
                      GalleryVisitStat(period: '25th', visits: 4321, hits: 9900),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially logged out -> blocked by UserController gate, loader not called.
      expect(loadCalls, 0);
      expect(find.text('需要登录 E-Hentai 账号后才能查看画廊统计'), findsOneWidget);
      // Inline Retry action exists and meets >=44pt hit target.
      final retrySize = tester.getSize(find.bySemanticsLabel('重新获取'));
      expect(retrySize.width, greaterThanOrEqualTo(44));
      expect(retrySize.height, greaterThanOrEqualTo(44));

      // Sign in while mounted -> section automatically reloads stats!
      userCtrl.user(
        const User(memberId: '10001', passHash: 'abcdef1234567890'),
      );
      await tester.pumpAndSettle();

      expect(loadCalls, 1);
      expect(find.text('4,321'), findsWidgets);
      expect(find.text('需要登录 E-Hentai 账号后才能查看画廊统计'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryStatsSection ignores stale responses on GID change and stays stable under RTL, High Contrast, 2.0x scale, and non-finite data',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final slowFirst = Completer<GalleryStats>();
      final fastSecond = Completer<GalleryStats>();

      Future<GalleryStats> loader(
        String gid,
        String token, {
        bool refresh = false,
        CancelToken? cancelToken,
      }) => gid == '111111' ? slowFirst.future : fastSecond.future;

      Widget buildForGid(String gid) => _wrapApp(
        locale: const Locale('en'),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 720),
              textScaler: TextScaler.linear(2.0),
              highContrast: true,
            ),
            child: CupertinoPageScaffold(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: GalleryStatsSection(
                  gid: gid,
                  token: 'abcdef1234',
                  initiallyExpanded: true,
                  statsLoader: loader,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(buildForGid('111111'));
      await tester.pump();

      // Switch to second gallery before first finishes.
      await tester.pumpWidget(buildForGid('222222'));
      await tester.pump();

      fastSecond.complete(
        const GalleryStats(
          totalVisits: 8888,
          allTimeRanking: 7,
          allTimeScore: 999,
          monthlyStats: <GalleryVisitStat>[
            GalleryVisitStat(
              period: 'January',
              visits: double.infinity,
              hits: double.nan,
            ),
            GalleryVisitStat(period: 'February', visits: 2400, hits: 12000),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('8,888'), findsOneWidget);

      // Complete stale first gallery response -> must NOT overwrite 8,888.
      slowFirst.complete(const GalleryStats(totalVisits: 1111));
      await tester.pumpAndSettle();

      expect(find.text('8,888'), findsOneWidget);
      expect(find.text('1,111'), findsNothing);

      // Verify chart painter actually honors 2.0x TextScaler & High Contrast bars.
      final chartCustomPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(GalleryStatsSection.chartKey),
          matching: find.byType(CustomPaint),
        ),
      );
      final hcPainter = chartCustomPaint.painter! as GalleryStatsChartPainter;
      expect(hcPainter.textScaler, const TextScaler.linear(2.0));
      expect(hcPainter.leftAxisWidth, greaterThan(42.0));
      expect(hcPainter.bottomAxisHeight, greaterThan(24.0));
      expect(hcPainter.inactiveBarColor.a, greaterThan(0.25));
      expect(hcPainter.peakBarColor.a, greaterThan(0.4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryStatsSection invalidates cached and in-flight stats on logout and A->B account switch while collapsed or expanded',
    (tester) async {
      final userCtrl = Get.put<UserController>(_FakeUserController());
      userCtrl.user(
        const User(memberId: '10001', passHash: 'aaaa1111bbbb2222'),
      );

      var loadCalls = 0;
      Completer<GalleryStats>? pending;

      await tester.pumpWidget(
        _wrapApp(
          child: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: GalleryStatsSection(
                gid: '620002',
                token: '1234567890',
                initiallyExpanded: true,
                respectUserLoginState: true,
                statsLoader: (gid, token, {refresh = false, cancelToken}) {
                  loadCalls++;
                  final pendingCompleter = pending;
                  if (pendingCompleter != null) {
                    return pendingCompleter.future;
                  }
                  final member = userCtrl.user.value.memberId;
                  return Future<GalleryStats>.value(
                    GalleryStats(
                      totalVisits: member == '10001' ? 1111 : 2222,
                      dailyStats: const <GalleryVisitStat>[
                        GalleryVisitStat(period: '26th', visits: 50, hits: 100),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loadCalls, 1);
      expect(find.text('1,111'), findsOneWidget);

      // 1. Collapse, then log out while collapsed -> zero fetch while collapsed;
      //    re-expanding MUST NOT leak previous account's 1,111 stats!
      await tester.tap(find.byKey(GalleryStatsSection.collapseToggleKey));
      await tester.pumpAndSettle();
      userCtrl.user(const User());
      await tester.pump();
      expect(loadCalls, 1);

      await tester.tap(find.byKey(GalleryStatsSection.expandToggleKey));
      await tester.pumpAndSettle();
      expect(loadCalls, 1);
      expect(find.text('1,111'), findsNothing);
      expect(find.text('需要登录 E-Hentai 账号后才能查看画廊统计'), findsOneWidget);

      // 2. Log back in as Account A with a pending in-flight fetch, then log
      //    out mid-flight -> late completion must NOT overwrite loginRequired!
      pending = Completer<GalleryStats>();
      userCtrl.user(
        const User(memberId: '10001', passHash: 'aaaa1111bbbb2222'),
      );
      await tester.pump();
      expect(loadCalls, 2);

      userCtrl.user(const User());
      await tester.pump();
      pending.complete(const GalleryStats(totalVisits: 9999));
      await tester.pumpAndSettle();
      expect(find.text('9,999'), findsNothing);
      expect(find.text('需要登录 E-Hentai 账号后才能查看画廊统计'), findsOneWidget);

      // 3. Log in as Account A, then switch A -> B while expanded -> reloads B.
      pending = null;
      userCtrl.user(
        const User(memberId: '10001', passHash: 'aaaa1111bbbb2222'),
      );
      await tester.pumpAndSettle();
      expect(loadCalls, 3);
      expect(find.text('1,111'), findsOneWidget);

      userCtrl.user(
        const User(memberId: '20002', passHash: 'cccc3333dddd4444'),
      );
      await tester.pumpAndSettle();
      expect(loadCalls, 4);
      expect(find.text('1,111'), findsNothing);
      expect(find.text('2,222'), findsOneWidget);

      // 4. Collapse, then switch B -> A while collapsed -> zero eager fetch;
      //    re-expanding loads fresh stats for A.
      await tester.tap(find.byKey(GalleryStatsSection.collapseToggleKey));
      await tester.pumpAndSettle();
      userCtrl.user(
        const User(memberId: '10001', passHash: 'aaaa1111bbbb2222'),
      );
      await tester.pump();
      expect(loadCalls, 4);

      await tester.tap(find.byKey(GalleryStatsSection.expandToggleKey));
      await tester.pumpAndSettle();
      expect(loadCalls, 5);
      expect(find.text('1,111'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GalleryStatsSection handles collapse-mid-load reopen, collapsed token switch, late response after dispose, and zero/unknown visits',
    (tester) async {
      // 1. Explicit 0 visits renders "0", missing totalVisits renders "—".
      await tester.pumpWidget(
        _wrapApp(
          child: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: GalleryStatsSection(
                gid: '630001',
                token: '1111aaaa22',
                initiallyExpanded: true,
                statsLoader: (gid, token, {refresh = false, cancelToken}) async =>
                    const GalleryStats(totalVisits: 0),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
      expect(find.text('暂无可查看的统计数据'), findsNothing);

      await tester.pumpWidget(
        _wrapApp(
          child: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: GalleryStatsSection(
                gid: '630002',
                token: '1111aaaa33',
                initiallyExpanded: true,
                statsLoader: (gid, token, {refresh = false, cancelToken}) async =>
                    const GalleryStats(
                      monthlyStats: <GalleryVisitStat>[
                        GalleryVisitStat(
                          period: 'March',
                          visits: 320,
                          hits: 1400,
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
      expect(find.text('320'), findsOneWidget);

      // 2. Collapse during in-flight fetch & rapid reopen cancels first request.
      final firstCompleter = Completer<GalleryStats>();
      final secondCompleter = Completer<GalleryStats>();
      CancelToken? firstCancelToken;
      var callCount = 0;

      Widget buildSection(String token) => _wrapApp(
        child: CupertinoPageScaffold(
          child: SingleChildScrollView(
            child: GalleryStatsSection(
              key: const ValueKey<String>('collapseLifecycleSection'),
              gid: '630003',
              token: token,
              statsLoader: (gid, t, {refresh = false, cancelToken}) {
                callCount++;
                if (callCount == 1) {
                  firstCancelToken = cancelToken;
                  return firstCompleter.future;
                }
                if (callCount == 2) {
                  return secondCompleter.future;
                }
                return Future<GalleryStats>.value(
                  const GalleryStats(totalVisits: 777),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(buildSection('aaaa111111'));
      await tester.pumpAndSettle();
      expect(callCount, 0);

      // Expand -> starts first request, then collapse mid-flight -> cancels it.
      await tester.tap(find.byKey(GalleryStatsSection.expandToggleKey));
      await tester.pump();
      expect(callCount, 1);
      expect(firstCancelToken?.isCancelled, isFalse);

      await tester.tap(find.byKey(GalleryStatsSection.collapseToggleKey));
      await tester.pump();
      expect(firstCancelToken?.isCancelled, isTrue);

      // Rapid reopen -> starts second request; stale first completion ignored.
      await tester.tap(find.byKey(GalleryStatsSection.expandToggleKey));
      await tester.pump();
      expect(callCount, 2);

      firstCompleter.complete(const GalleryStats(totalVisits: 111));
      await tester.pump();
      expect(find.text('111'), findsNothing);

      secondCompleter.complete(const GalleryStats(totalVisits: 555));
      await tester.pumpAndSettle();
      expect(find.text('555'), findsOneWidget);

      // 3. Collapse, then switch token while collapsed -> zero eager fetch,
      //    clears cached 555, and loads 777 only when expanded again.
      await tester.tap(find.byKey(GalleryStatsSection.collapseToggleKey));
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildSection('bbbb222222'));
      await tester.pumpAndSettle();
      expect(callCount, 2);

      await tester.tap(find.byKey(GalleryStatsSection.expandToggleKey));
      await tester.pumpAndSettle();
      expect(callCount, 3);
      expect(find.text('777'), findsOneWidget);
      expect(find.text('555'), findsNothing);

      // 4. Dispose while request is in-flight -> late completion causes no crash.
      final lateCompleter = Completer<GalleryStats>();
      await tester.pumpWidget(
        _wrapApp(
          child: CupertinoPageScaffold(
            child: GalleryStatsSection(
              gid: '630004',
              token: 'cccc333333',
              initiallyExpanded: true,
              statsLoader: (gid, t, {refresh = false, cancelToken}) =>
                  lateCompleter.future,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      lateCompleter.complete(const GalleryStats(totalVisits: 444));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
