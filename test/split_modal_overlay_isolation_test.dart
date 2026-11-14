import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/appkit_interaction.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _GlassSettings extends GetxService implements EhSettingService {
  @override
  bool get liquidGlass => true;
  @override
  GlassMaterial get glassMaterial => GlassMaterial.liquid;
  @override
  final RxBool vibrate = false.obs;
  @override
  bool get isPureDarkTheme => false;
  @override
  RxBool get pureDarkThemeObs => false.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting $invocation');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
    Get.put<EhSettingService>(_GlassSettings());
    Get.put(ThemeService());
  });

  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    Get.reset();
  });

  testWidgets(
      'root modal suppresses underlying UiKitView category rail and glass buttons in nested split panes',
      (tester) async {
    final rootModals = AppKitModalObserver(root: true);
    final primaryModals = AppKitModalObserver();
    addTearDown(() {
      rootModals.dispose();
      primaryModals.dispose();
    });

    await tester.pumpWidget(
      GetCupertinoApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        navigatorObservers: [rootModals],
        home: Row(
          children: [
            Expanded(
              child: Navigator(
                observers: [primaryModals],
                onGenerateRoute: (_) => CupertinoPageRoute<void>(
                  builder: (_) => Stack(
                    children: [
                      LiquidGlassRail(
                        title: '热门',
                        safeTop: 20,
                        fadeProgress: 0,
                        layout: LiquidGlassTopBarLayout.inline,
                        categories: [
                          LiquidGlassRailCategory(title: '热门', onTap: () {}),
                          LiquidGlassRailCategory(title: '画廊', onTap: () {}),
                        ],
                        selectedIndex: 0,
                        categoryTrailing: [
                          LiquidGlassRailAction(
                            icon: CupertinoIcons.bars,
                            label: 'menu',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Builder(
                builder: (detailContext) => CupertinoButton(
                  onPressed: () {
                    showCupertinoDialog<void>(
                      context: detailContext,
                      barrierDismissible: true,
                      builder: (dialogContext) => EhAlertDialog(
                        insetForm: true,
                        title: const Text('添加收藏夹'),
                        content: Builder(
                          builder: (innerContext) => Text(
                            AppKitInteraction.isCoveredByModal(innerContext)
                                ? 'covered'
                                : 'topmost',
                          ),
                        ),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('取消'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('open fav'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Baseline: category rail & menu glass use UiKitViews on iOS.
    expect(find.byType(UiKitView), findsWidgets);
    expect(find.byType(NativeCategoryRail), findsOneWidget);

    // Open root dialog from detail pane -> background category rail & buttons
    // yield to Flutter composition so nothing pierces above the modal scrim.
    await tester.tap(find.text('open fav'));
    await tester.pumpAndSettle();

    expect(find.text('添加收藏夹'), findsOneWidget);
    expect(find.text('topmost'), findsOneWidget);
    expect(find.byType(NativeCategoryRail), findsNothing);
    expect(
      tester
          .widgetList<UiKitView>(find.byType(UiKitView))
          .where((v) =>
              v.viewType == 'eros/liquid-glass-categories' ||
              v.viewType == LiquidGlassPlatform.viewType),
      isEmpty,
    );

    // Dismissing restores native category rail and glass buttons.
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(NativeCategoryRail), findsOneWidget);
  });
}
