import 'dart:async';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/appkit_interaction.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
      'root modal hides underlying UiKitViews synchronously without destroying them and waits for setHidden(false) before removing fallback underlay',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final categoryHiddenCalls = <bool>[];
    final glassHiddenCalls = <bool>[];
    final createdChannels = <String>[];
    final unhideCompleters = <Completer<void>>[];
    var holdUnhide = false;

    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final id = args['id'] as int;
        final viewType = args['viewType'] as String;
        final channelName = viewType == 'eros/liquid-glass-categories'
            ? 'eros/liquid-glass-categories/$id'
            : 'eros/liquid-glass/$id';
        createdChannels.add(channelName);
        messenger.setMockMethodCallHandler(MethodChannel(channelName), (
          viewCall,
        ) async {
          if (viewCall.method == 'setHidden') {
            final hidden = viewCall.arguments as bool;
            if (viewType == 'eros/liquid-glass-categories') {
              categoryHiddenCalls.add(hidden);
            } else {
              glassHiddenCalls.add(hidden);
            }
            if (!hidden && holdUnhide) {
              final completer = Completer<void>();
              unhideCompleters.add(completer);
              await completer.future;
            }
          }
          return null;
        });
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channelName in createdChannels) {
        messenger.setMockMethodCallHandler(MethodChannel(channelName), null);
      }
    });

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

    // Baseline: category rail & menu glass keep live UiKitViews on iOS.
    final categoryViewFinder = find.byWidgetPredicate(
      (w) => w is UiKitView && w.viewType == 'eros/liquid-glass-categories',
    );
    final glassViewFinder = find.byWidgetPredicate(
      (w) => w is UiKitView && w.viewType == LiquidGlassPlatform.viewType,
    );
    expect(categoryViewFinder, findsOneWidget);
    expect(glassViewFinder, findsOneWidget);
    final baselineCategoryElement = tester.element(categoryViewFinder);
    final baselineGlassElement = tester.element(glassViewFinder);
    expect(
      find.byKey(const ValueKey<String>('native-category-rail-modal-underlay')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('liquid-glass-modal-underlay')),
      findsNothing,
    );

    // Open root dialog from detail pane -> native views stay mounted in-place,
    // hide via setHidden(true), and Flutter underlays appear below the scrim.
    await tester.tap(find.text('open fav'));
    await tester.pumpAndSettle();

    expect(find.text('添加收藏夹'), findsOneWidget);
    expect(find.text('topmost'), findsOneWidget);
    expect(categoryHiddenCalls, <bool>[true]);
    expect(glassHiddenCalls, <bool>[true]);
    expect(
      find.byKey(const ValueKey<String>('native-category-rail-modal-underlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('liquid-glass-modal-underlay')),
      findsOneWidget,
    );
    expect(
      identical(tester.element(categoryViewFinder), baselineCategoryElement),
      isTrue,
    );
    expect(
      identical(tester.element(glassViewFinder), baselineGlassElement),
      isTrue,
    );

    // Dismissing calls setHidden(false) without recreating UiKitViews and holds
    // the underlays until Swift acknowledges unhide.
    holdUnhide = true;
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(categoryHiddenCalls, <bool>[true, false]);
    expect(glassHiddenCalls, <bool>[true, false]);
    expect(unhideCompleters, hasLength(2));
    expect(
      find.byKey(const ValueKey<String>('native-category-rail-modal-underlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('liquid-glass-modal-underlay')),
      findsOneWidget,
    );

    for (final completer in unhideCompleters) {
      completer.complete();
    }
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('native-category-rail-modal-underlay')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('liquid-glass-modal-underlay')),
      findsNothing,
    );
    expect(
      identical(tester.element(categoryViewFinder), baselineCategoryElement),
      isTrue,
    );
    expect(
      identical(tester.element(glassViewFinder), baselineGlassElement),
      isTrue,
    );
  });
}
