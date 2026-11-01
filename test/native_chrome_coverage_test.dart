import 'dart:io';

import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/index.dart' show Global, kDefProfile;
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/controller/taginfo_controller.dart';
import 'package:eros_fe/pages/gallery/view/add_tags_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Old pages that no route opens. Each stays exempt only while the token that
/// would open it, its constructor or an import of it, appears nowhere else.
const _unreachable = <String, String>{
  'lib/pages/gallery/view/sliver/gallery_page_sliver.dart':
      'GallerySliverPage(',
  'lib/pages/tab/view/quick_search_page_o.dart': 'quick_search_page_o.dart',
  'lib/pages/tab/view/donwload_labels_page.dart': 'donwload_labels_page.dart',
};

/// The source without its line comments, so commented-out bars don't count.
String _code(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

class _Settings extends GetxService implements EhSettingService {
  @override
  bool get liquidGlass => false;
  @override
  bool get liquidGlassFollowSystemTransparency => true;
  @override
  bool get isTagTranslate => false;
  @override
  bool get isPureDarkTheme => false;
  @override
  RxBool get pureDarkThemeObs => false.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting: ${invocation.memberName}');
}

class _Page extends GetxController implements GalleryPageController {
  _Page(this.gState);
  @override
  final GalleryPageState gState;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected page access: ${invocation.memberName}');
}

void main() {
  test('every page with a Flutter bar says what the native bar shows', () {
    final sources = {
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')))
        file.path: _code(file),
    };
    final bar = RegExp(r'\bCupertino(Sliver)?NavigationBar\(');
    // Without native chrome the shell hides its bar for the page, and beside
    // the vertical bar everything under it moves by the bar's band.
    final missing = [
      for (final MapEntry(key: path, value: code) in sources.entries)
        if (bar.hasMatch(code) &&
            !code.contains('NativeNavigationScope.isEnabled') &&
            !_unreachable.containsKey(path))
          path,
    ];
    expect(missing, isEmpty,
        reason: 'Use SettingScaffold, or publish NativePageChrome and keep '
            'the Flutter bar for when the native shell is off.');

    for (final MapEntry(key: exempt, value: token) in _unreachable.entries) {
      final openers = [
        for (final MapEntry(key: path, value: code) in sources.entries)
          if (path != exempt && code.contains(token)) path,
      ];
      expect(openers, isEmpty, reason: '$exempt is reachable again');
    }
  });

  test('a pushed page without chrome keeps the bar band', () {
    final route = PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const SizedBox());
    final fallback = pushedPageChrome(route);
    expect(fallback.ownBar, isTrue);
    expect(fallback.navigationBarVisible, isFalse);

    const chrome = NativePageChrome(title: 'Page');
    final owner = Object();
    NativeNavigationBridge.registerChrome(route, owner, chrome);
    addTearDown(() => NativeNavigationBridge.unregisterChrome(route, owner));
    expect(pushedPageChrome(route), same(chrome));
  });

  group('adding tags', () {
    tearDown(() {
      NativeNavigationBridge.enabled.value = false;
      Get.reset();
    });

    Future<Future<String?>> open(WidgetTester tester,
        {required bool native}) async {
      Get.testMode = true;
      NativeNavigationBridge.enabled.value = native;
      Get.put<EhSettingService>(_Settings());
      Global.profile = kDefProfile;
      Get.put(ThemeService());
      Get.put<GalleryPageController>(_Page(GalleryPageState()), tag: '42');
      Get.put(TagInfoController(galleryTag: '42'), tag: '42');
      await tester.pumpWidget(GetCupertinoApp(
        locale: const Locale('en'),
        localizationsDelegates: const [L10n.delegate],
        home: NativeNavigationScope(child: const SizedBox()),
      ));
      final result = Get.to<String>(() => NativeNavigationScope(
            child: const ControllerTagScope(
              snapshot: ControllerTagSnapshot(galleryTag: '42'),
              child: AddTagPage(),
            ),
          ));
      await tester.pumpAndSettle();
      return result!;
    }

    testWidgets('the native bar carries the title and a prominent Done',
        (tester) async {
      final result = await open(tester, native: true);
      expect(find.byType(CupertinoNavigationBar), findsNothing);
      final route = ModalRoute.of(tester.element(find.byType(AddTagPage)))!;
      final chrome = NativeNavigationBridge.chromeFor(route)!;
      expect(chrome.title, 'Add tags');
      expect(chrome.navigationBarVisible, isTrue);
      final done = chrome.actions.single;
      expect(done.prominent, isTrue);

      await tester.enterText(find.byType(CupertinoTextField), 'f:glasses');
      // Lets the delayed tag lookup finish before the page goes.
      await tester.pump(const Duration(seconds: 1));
      await done.onPressed!();
      await tester.pumpAndSettle();
      expect(await result, 'f:glasses');
    });

    testWidgets('without the native shell a Flutter bar shows them',
        (tester) async {
      await open(tester, native: false);
      final bar = find.byType(CupertinoNavigationBar);
      expect(find.descendant(of: bar, matching: find.text('Add tags')),
          findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('Done')),
          findsOneWidget);
    });
  });
}
