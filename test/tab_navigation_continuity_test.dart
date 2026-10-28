import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/setting/setting_items/single_input_page.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/home_page_large.dart';
import 'package:eros_fe/pages/image_view/view/view_page.dart';
import 'package:eros_fe/route/app_pages.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/route/navigator_util.dart';
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
      'production shell retains independent drafts, routes and chrome per tab',
      (tester) async {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    final settings = Get.put<EhSettingService>(_Settings());
    Get.put<ThemeService>(_Theme());
    final layout = Get.put<LayoutServices>(_Layout());
    final home = Get.put<TabHomeController>(_Home());
    home.tabNameList.assignAll([EHRoutes.gallery, EHRoutes.favorite]);
    home.tabMap.assignAll({EHRoutes.gallery: true, EHRoutes.favorite: true});
    final tags = Get.put(ControllerTagService());
    final routeTags = <String, String>{};
    final ownedRoute = GetPage<void>(
      name: '/test/owned-controller',
      page: () => Builder(builder: (context) {
        final tag = pageCtrlTagOf(context);
        final title =
            tag.startsWith('A@') ? 'Gallery A draft' : 'Favorite B draft';
        routeTags[title] = tag;
        return SingleInputPage(title: title);
      }),
    );
    AppPages.routes.add(ownedRoute);
    addTearDown(() => AppPages.routes.remove(ownedRoute));
    final publications = <Map<dynamic, dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async {
        if (call.method == 'getShellState') return true;
        if (call.method == 'publishState') {
          publications.add(Map<dynamic, dynamic>.from(call.arguments as Map));
        }
        return null;
      },
    );
    final geometry =
        ValueNotifier(const AdaptiveEnvironmentSnapshot(size: Size(900, 650)));
    final scrolls = <String, ScrollController>{};
    final mounts = <String, int>{};
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = geometry.value.size;
    MainNavigatorObserver().resetHistory();
    addTearDown(() {
      NativeNavigationBridge.enabled.value = false;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
      geometry.dispose();
      for (final scroll in scrolls.values) {
        scroll.dispose();
      }
      Get.reset();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(GetCupertinoApp(
      localizationsDelegates: const [L10n.delegate],
      navigatorObservers: [MainNavigatorObserver()],
      builder: (context, child) => NativeNavigationHost(
        observer: MainNavigatorObserver(),
        navigatorKey: Get.key,
        child: child!,
      ),
      home: ValueListenableBuilder(
        valueListenable: geometry,
        builder: (_, environment, __) {
          layout.layoutMode =
              environment.isSplit ? LayoutMode.large : LayoutMode.small;
          return AdaptiveEnvironmentScope(
            snapshot: environment,
            child: TabHomeLarge(
              split: environment.isSplit,
              destinationBuilder: (_, route) {
                final identity = home.navigationIdentity;
                final scroll =
                    scrolls.putIfAbsent(identity, () => ScrollController());
                return _Root(
                  route: route,
                  scroll: scroll,
                  onMount: () => mounts[identity] = (mounts[identity] ?? 0) + 1,
                );
              },
            ),
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    final gallery = layout.tabNavigation.selected!;
    final galleryTag = tags.pushPageCtrl(gid: 'A');
    scrolls[EHRoutes.gallery]!.jumpTo(300);
    Get.toNamed<void>('/test/owned-controller',
        id: detailNavigatorId, preventDuplicates: false);
    await tester.pumpAndSettle();
    final editorA = tester
        .widget<CupertinoTextField>(find.byType(CupertinoTextField))
        .controller!;
    editorA.value = const TextEditingValue(
      text: 'Unsent gallery A',
      selection: TextSelection(baseOffset: 2, extentOffset: 7),
      composing: TextRange(start: 2, end: 7),
    );
    final valueA = editorA.value;
    final routeA = gallery.detailObserver.history.last;
    await _native(tester, 'selectTab', EHRoutes.favorite);
    final favorite = layout.tabNavigation.selected!;
    expect(favorite.primaryId, isNot(gallery.primaryId));
    expect(favorite.detailObserver.history, hasLength(1));
    expect(find.text('Gallery A draft'), findsNothing);
    final favoriteTag = tags.pushPageCtrl(gid: 'B');
    scrolls[EHRoutes.favorite]!.jumpTo(450);
    Get.toNamed<void>('/test/owned-controller',
        id: detailNavigatorId, preventDuplicates: false);
    await tester.pumpAndSettle();
    final editorB = tester
        .widget<CupertinoTextField>(find.byType(CupertinoTextField))
        .controller!;
    editorB.value = const TextEditingValue(
      text: 'Unsent favorite B',
      selection: TextSelection.collapsed(offset: 8),
      composing: TextRange(start: 1, end: 8),
    );
    final valueB = editorB.value;
    final routeB = favorite.detailObserver.history.last;

    for (var cycle = 0; cycle < 20; cycle++) {
      for (final size in const [
        Size(390, 844),
        Size(669, 951),
        Size(951, 669),
      ]) {
        tester.view.physicalSize = size;
        geometry.value = AdaptiveEnvironmentSnapshot(size: size);
        await _native(tester, 'selectTab', EHRoutes.gallery);
        expect(primaryNavigatorId, gallery.primaryId);
        expect(detailNavigatorId, gallery.detailId);
        expect(gallery.detailObserver.history.last, same(routeA));
        expect(pageCtrlTag, galleryTag);
        expect(editorA.value, valueA);
        expect(publications.last['title'], 'Gallery A draft');
        expect(publications.last['visible'], isTrue);
        await _native(tester, 'selectTab', EHRoutes.favorite);
        expect(favorite.detailObserver.history.last, same(routeB));
        expect(pageCtrlTag, favoriteTag);
        expect(editorB.value, valueB);
        expect(publications.last['title'], 'Favorite B draft');
        expect(publications.last['selectedTabId'], EHRoutes.favorite);
        expect(publications.last['canGoBack'], isTrue);
        expect(scrolls[EHRoutes.gallery]!.offset, 300);
        expect(scrolls[EHRoutes.favorite]!.offset, 450);
        expect(routeTags['Gallery A draft'], galleryTag);
        expect(routeTags['Favorite B draft'], favoriteTag);
        expect(tester.takeException(), isNull);
      }
    }

    home.tabNameList.assignAll([EHRoutes.favorite, EHRoutes.gallery]);
    await tester.pumpAndSettle();
    expect(home.currentIndex, 0);
    expect(layout.tabNavigation.selected, same(favorite));
    home.tabMap[EHRoutes.gallery] = false;
    await tester.pumpAndSettle();
    expect(layout.tabNavigation.selected, same(favorite));
    expect(editorB.value, valueB);
    home.tabMap[EHRoutes.gallery] = true;
    await tester.pumpAndSettle();

    settings.isSafeMode.value = true;
    await tester.pumpAndSettle();
    expect(layout.tabNavigation.selectedId, 'safe:${EHRoutes.gallery}');
    expect(find.byType(CupertinoTextField), findsNothing);
    expect(publications.last['tabs'],
        everyElement(isNot(containsPair('id', EHRoutes.favorite))));
    await _native(tester, 'selectTab', EHRoutes.favorite);
    expect(layout.tabNavigation.selectedId, 'safe:${EHRoutes.gallery}');
    await _native(tester, 'selectTab', EHRoutes.setting);
    expect(layout.tabNavigation.selectedId, 'safe:${EHRoutes.setting}');
    await _native(tester, 'selectTab', EHRoutes.gallery);
    expect(layout.tabNavigation.selectedId, 'safe:${EHRoutes.gallery}');
    settings.isSafeMode.value = false;
    await tester.pumpAndSettle();
    await _native(tester, 'selectTab', EHRoutes.favorite);
    expect(layout.tabNavigation.selected, same(favorite));
    expect(editorB.value, valueB);

    await _native(tester, 'goBack');
    expect(favorite.detailObserver.history, hasLength(1));
    expect(gallery.detailObserver.history.last, same(routeA));
    await _native(tester, 'selectTab', EHRoutes.gallery);
    expect(editorA.value, valueA);
    Get.to<void>(() => const SingleInputPage(title: 'Gallery search draft'),
        id: primaryNavigatorId);
    await tester.pumpAndSettle();
    expect(layout.activePaneNavigatorId, gallery.primaryId);
    // Compact back uses push chronology across only the selected tab's panes.
    tester.view.physicalSize = const Size(390, 844);
    geometry.value = const AdaptiveEnvironmentSnapshot(size: Size(390, 844));
    await tester.pumpAndSettle();
    await _native(tester, 'goBack');
    expect(gallery.primaryObserver.history, hasLength(1));
    expect(gallery.detailObserver.history.last, same(routeA));
    // Opening a different editor intentionally ends the active IME session,
    // unlike a resize or a retained-tab switch. Text and selection survive.
    expect(editorA.value, valueA.copyWith(composing: TextRange.empty));
    await _native(tester, 'goBack');
    expect(gallery.detailObserver.history, hasLength(1));
    expect(mounts[EHRoutes.gallery], 1);
    expect(mounts[EHRoutes.favorite], 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('controller completion removes its own slot, not another tab stack', () {
    Get.testMode = true;
    final layout = Get.put<LayoutServices>(_Layout());
    final tags = Get.put(ControllerTagService());
    addTearDown(Get.reset);
    layout.tabNavigation.select(EHRoutes.gallery);
    final gallery = tags.pushPageCtrl(gid: 'same-gallery');
    final searchA = tags.pushSearchPageCtrl(searchText: 'A');
    layout.tabNavigation.select(EHRoutes.favorite);
    final favorite = tags.pushPageCtrl(gid: 'same-gallery');
    final searchB = tags.pushSearchPageCtrl(searchText: 'B');
    expect(gallery, isNot(favorite));
    expect(searchA, isNot(searchB));
    tags.popPageCtrl(tag: gallery);
    tags.popSearchPageCtrl(tag: searchA);
    expect(pageCtrlTag, favorite);
    expect(searchPageCtrlTag, searchB);
    layout.tabNavigation.select(EHRoutes.gallery);
    expect(pageCtrlTag, isEmpty);
    expect(searchPageCtrlTag, '0');
    layout.tabNavigation.select(EHRoutes.favorite);
    expect(tags.currGid, 'same-gallery');
    expect(tags.currSearchText, 'B');
  });

  testWidgets('a root reader captures the launching gallery controller slot',
      (tester) async {
    Get.testMode = true;
    final layout = Get.put<LayoutServices>(_Layout());
    final tags = Get.put(ControllerTagService());
    addTearDown(Get.reset);
    layout.tabNavigation.select(EHRoutes.gallery);
    final galleryTag = tags.pushPageCtrl(gid: 'A');
    ViewRepository? arguments;
    await tester.pumpWidget(GetCupertinoApp(
      home: const SizedBox.expand(),
      getPages: [
        GetPage<void>(
          name: EHRoutes.galleryViewExt,
          page: () {
            arguments = Get.arguments as ViewRepository;
            return const SizedBox.expand();
          },
        ),
      ],
    ));
    NavigatorUtil.goGalleryViewPage(5, 'A');
    // The root reader may build after the native tab selection event arrives.
    layout.tabNavigation.select(EHRoutes.favorite);
    tags.pushPageCtrl(gid: 'B');
    await tester.pumpAndSettle();
    expect(arguments?.gid, 'A');
    expect(arguments?.galleryControllerTag, galleryTag);
    Get.back<void>();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Root extends StatefulWidget {
  const _Root(
      {required this.route, required this.scroll, required this.onMount});
  final String route;
  final ScrollController scroll;
  final VoidCallback onMount;
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => NativeNavigationPage(
        tabId: widget.route,
        chrome: NativePageChrome(title: widget.route),
        child: CupertinoPageScaffold(
          child: ListView.builder(
            controller: widget.scroll,
            itemExtent: 50,
            itemCount: 100,
            itemBuilder: (_, index) => Text('${widget.route} item $index'),
          ),
        ),
      );
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
