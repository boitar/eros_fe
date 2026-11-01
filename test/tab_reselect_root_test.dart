import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/home_page_large.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _channel = MethodChannel('eros/native-navigation');

Future<void> _selectTab(WidgetTester tester, String route) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec()
          .encodeMethodCall(MethodCall('selectTab', route)),
      (_) {});
  await tester.pumpAndSettle();
}

void main() {
  late LayoutServices layout;
  late ValueNotifier<AdaptiveEnvironmentSnapshot> geometry;

  Future<void> mount(WidgetTester tester, Size size) async {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<ThemeService>(_Theme());
    layout = Get.put<LayoutServices>(_Layout());
    final home = Get.put<TabHomeController>(_Home());
    home.tabNameList.assignAll([EHRoutes.gallery, EHRoutes.favorite]);
    home.tabMap.assignAll({EHRoutes.gallery: true, EHRoutes.favorite: true});
    Get.put(ControllerTagService());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => call.method == 'getShellState' ? true : null,
    );
    geometry = ValueNotifier(AdaptiveEnvironmentSnapshot(size: size));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    MainNavigatorObserver().resetHistory();
    addTearDown(() {
      NativeNavigationBridge.enabled.value = false;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
      geometry.dispose();
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
              destinationBuilder: (_, route) => CupertinoPageScaffold(
                child: Center(child: Text('$route root')),
              ),
            ),
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> push(WidgetTester tester, String title, int? id) async {
    Get.to<void>(
      () => CupertinoPageScaffold(child: Center(child: Text(title))),
      id: id,
      preventDuplicates: false,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reselecting settings returns to the settings home',
      (tester) async {
    await mount(tester, const Size(390, 844));
    await _selectTab(tester, EHRoutes.setting);
    final settings = layout.tabNavigation.selected!;
    await push(tester, 'Reading', detailNavigatorId);
    await push(tester, 'Double page', detailNavigatorId);
    expect(find.text('Double page'), findsOneWidget);

    await _selectTab(tester, EHRoutes.setting);

    expect(settings.detailObserver.history, hasLength(1));
    expect(find.text('Reading'), findsNothing);
    expect(find.text('${EHRoutes.setting} root'), findsOneWidget);
    // At the root a further reselect has nothing left to pop.
    await _selectTab(tester, EHRoutes.setting);
    expect(find.text('${EHRoutes.setting} root'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reselecting a list tab pops its pushed pages first',
      (tester) async {
    await mount(tester, const Size(390, 844));
    final gallery = layout.tabNavigation.selected!;
    await push(tester, 'Gallery detail', detailNavigatorId);
    await push(tester, 'Search', primaryNavigatorId);

    await _selectTab(tester, EHRoutes.gallery);

    expect(gallery.primaryObserver.history, hasLength(1));
    expect(gallery.detailObserver.history, hasLength(1));
    expect(find.text('${EHRoutes.gallery} root'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a split layout keeps the detail pane beside the root',
      (tester) async {
    await mount(tester, const Size(900, 650));
    final gallery = layout.tabNavigation.selected!;
    await push(tester, 'Gallery detail', detailNavigatorId);
    await push(tester, 'Search', primaryNavigatorId);

    await _selectTab(tester, EHRoutes.gallery);

    expect(gallery.primaryObserver.history, hasLength(1));
    expect(gallery.detailObserver.history, hasLength(2));
    expect(find.text('Gallery detail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Layout extends LayoutServices {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Settings extends EhSettingService {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Theme extends ThemeService {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Home extends TabHomeController {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}
