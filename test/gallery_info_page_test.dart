// ignore_for_file: must_call_super

import 'package:eros_fe/common/controller/cache_controller.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/controller/image_block_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/view/gallery_info_page.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/image/eh_cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
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
}
