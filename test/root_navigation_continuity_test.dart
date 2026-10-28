import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/pages/setting/setting_items/single_input_page.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/home_page_large.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _channel = MethodChannel('eros/native-navigation');

Future<void> _native(WidgetTester tester, String method,
    [Object? arguments]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec()
          .encodeMethodCall(MethodCall(method, arguments)),
      (_) {});
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'root replacement hands off chrome and ownership then restores retained Home',
      (tester) async {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<ThemeService>(_Theme());
    final layout = Get.put<LayoutServices>(_Layout());
    final home = Get.put<TabHomeController>(_Home());
    home.tabNameList.assignAll([EHRoutes.gallery, EHRoutes.favorite]);
    home.tabMap.assignAll({EHRoutes.gallery: true, EHRoutes.favorite: true});
    Get.put(ControllerTagService());
    final observer = MainNavigatorObserver()..resetHistory();
    final publications = <Map<dynamic, dynamic>>[];
    final rootTags = <String>[];
    var homeActions = 0;
    var rootActions = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel,
        (call) async {
      if (call.method == 'getShellState') return true;
      if (call.method == 'publishState') {
        publications.add(Map<dynamic, dynamic>.from(call.arguments as Map));
      }
      return null;
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(951, 669);
    addTearDown(() {
      observer.resetHistory();
      NativeNavigationBridge.enabled.value = false;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
      Get.reset();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Widget homePage() => AdaptiveEnvironmentScope(
          snapshot: const AdaptiveEnvironmentSnapshot(size: Size(951, 669)),
          child: TabHomeLarge(
            split: true,
            destinationBuilder: (_, route) => NativeNavigationPage(
              chrome: NativePageChrome(title: route, actions: [
                NativeNavigationAction(
                    id: 'oldHomeAction',
                    title: 'Home action',
                    onPressed: () => homeActions++),
              ]),
              child: const CupertinoPageScaffold(child: SizedBox.expand()),
            ),
          ),
        );

    await tester.pumpWidget(GetCupertinoApp(
      localizationsDelegates: const [L10n.delegate],
      navigatorObservers: [observer],
      initialRoute: EHRoutes.home,
      builder: (_, child) => NativeNavigationHost(
          observer: observer, navigatorKey: Get.key, child: child!),
      getPages: [
        GetPage(name: EHRoutes.home, page: homePage),
        GetPage(
          name: EHRoutes.galleryPage,
          page: () => ControllerTagRoute(
            child: Builder(builder: (context) {
              final tag = pageCtrlTagOf(context);
              rootTags.add(tag);
              return NativeNavigationPage(
                chrome: NativePageChrome(title: 'Root $tag', actions: [
                  NativeNavigationAction(
                      id: 'rootAction',
                      title: 'Root action',
                      onPressed: () => rootActions++),
                ]),
                child: CupertinoPageScaffold(child: Text('Scope $tag')),
              );
            }),
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();
    final originalStack = layout.tabNavigation.selected!;
    Get.to<void>(() => const SingleInputPage(title: 'Retained draft'),
        id: originalStack.primaryId);
    await tester.pumpAndSettle();
    final draft = tester
        .widget<CupertinoTextField>(find.byType(CupertinoTextField))
        .controller!;
    draft.value = const TextEditingValue(
        text: 'do not lose this draft',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 1, end: 5));

    // The reader is a root route. Clipboard/deep-link replacement must target
    // that route, not a now-hidden nested detail stack.
    Get.to<void>(() => const SingleInputPage(title: 'Root reader'));
    await tester.pumpAndSettle();
    expect(publications.last['visible'], isFalse);
    NavigatorUtil.goGalleryPage(
        galleryProvider: const GalleryProvider(gid: '42'), forceReplace: true);
    await tester.pumpAndSettle();
    final tag = rootTags.last;
    expect(tag, startsWith('42@'));
    expect(publications.last['title'], 'Root $tag');
    expect(publications.last['navigationBarVisible'], isTrue);
    expect(publications.last['visible'], isFalse);
    expect(publications.last['canGoBack'], isTrue);
    expect(primaryNavigatorId, isNull);
    expect(detailNavigatorId, isNull);
    await _native(tester, 'selectTab', EHRoutes.favorite);
    await _native(tester, 'action', 'oldHomeAction');
    expect(homeActions, 0);
    expect(home.currRoute, EHRoutes.gallery);
    await _native(tester, 'action', 'rootAction');
    expect(rootActions, 1);

    Get.to<void>(() => const SingleInputPage(title: 'Root edit'));
    await tester.pumpAndSettle();
    expect(publications.last['title'], 'Root edit');
    await _native(tester, 'goBack');
    expect(publications.last['title'], 'Root $tag');
    await _native(tester, 'goBack');
    expect(layout.tabNavigation.selected, same(originalStack));
    expect(primaryNavigatorId, originalStack.primaryId);
    expect(draft.text, 'do not lose this draft');
    expect(draft.selection, const TextSelection.collapsed(offset: 5));
    expect(publications.last['title'], 'Retained draft');

    // Forced replacement of Home itself releases only that Home's source.
    // New Homes get fresh Navigator IDs even while an old transition unmounts.
    final ids = <int>{originalStack.primaryId};
    for (var iteration = 0; iteration < 3; iteration++) {
      NavigatorUtil.goGalleryPage(
          galleryProvider: GalleryProvider(gid: '${100 + iteration}'),
          forceReplace: true);
      await tester.pumpAndSettle();
      final rootTag = rootTags.last;
      expect(layout.adaptiveNavigationMounted, isFalse);
      expect(pageCtrlTag, rootTag);
      for (final size in const [Size(466, 678), Size(951, 669)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(pageCtrlTag, rootTag);
        expect(publications.last['title'], 'Root $rootTag');
        expect(NativeNavigationBridge.enabled.value, isTrue);
      }
      await _native(tester, 'selectTab', EHRoutes.favorite);
      Get.offNamed<void>(EHRoutes.home, preventDuplicates: false);
      await tester.pumpAndSettle();
      final newId = layout.tabNavigation.selected!.primaryId;
      expect(ids.add(newId), isTrue);
      expect(publications.last['visible'], isTrue);
      await _native(tester, 'selectTab', EHRoutes.favorite);
      expect(layout.tabNavigation.selected!.id, EHRoutes.favorite);
      expect(tester.takeException(), isNull);
    }
    // Replacing Home with Home also overlaps two retained shells temporarily.
    Get.offNamed<void>(EHRoutes.home, preventDuplicates: false);
    await tester.pumpAndSettle();
    expect(layout.adaptiveNavigationMounted, isTrue);
    expect(publications.last['visible'], isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(NativeNavigationBridge.enabled.value, isFalse);
  });
}

class _Layout extends LayoutServices {
  @override
  void onInit() {}
}

class _Settings extends EhSettingService {
  @override
  void onInit() {}
}

class _Theme extends ThemeService {
  @override
  void onInit() {}
}

class _Home extends TabHomeController {
  @override
  void onInit() {}
}
