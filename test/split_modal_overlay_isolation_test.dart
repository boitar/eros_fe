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
      'root modal unmounts UiKitViews cleanly, preserves cacheId across restore, waits for update before removing underlay, and releases cache on dispose',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final categoryCacheIds = <Object?>[];
    final glassCacheIds = <Object?>[];
    final released = <String>[];
    final createdChannels = <String>[];
    final updateCompleters = <Completer<void>>[];
    var holdCategoryUpdate = false;

    messenger.setMockMethodCallHandler(
      const MethodChannel('eros/liquid-glass-cache'),
      (call) async {
        if (call.method == 'release' && call.arguments is Map) {
          final args = call.arguments as Map<dynamic, dynamic>;
          released.add('${args['kind']}:${args['cacheId']}');
        }
        return null;
      },
    );

    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final id = args['id'] as int;
        final viewType = args['viewType'] as String;
        final params = const StandardMessageCodec().decodeMessage(
          ByteData.sublistView(args['params'] as Uint8List),
        ) as Map<dynamic, dynamic>;
        if (viewType == 'eros/liquid-glass-categories') {
          categoryCacheIds.add(params['cacheId']);
        } else {
          glassCacheIds.add(params['cacheId']);
        }
        final channelName = viewType == 'eros/liquid-glass-categories'
            ? 'eros/liquid-glass-categories/$id'
            : 'eros/liquid-glass/$id';
        createdChannels.add(channelName);
        messenger.setMockMethodCallHandler(MethodChannel(channelName), (
          viewCall,
        ) async {
          if (viewCall.method == 'update' && holdCategoryUpdate) {
            final completer = Completer<void>();
            updateCompleters.add(completer);
            await completer.future;
          }
          return null;
        });
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel('eros/liquid-glass-cache'),
        null,
      );
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
    expect(categoryCacheIds, hasLength(1));
    expect(glassCacheIds, hasLength(1));
    final initialCategoryCacheId = categoryCacheIds.single;
    final initialGlassCacheId = glassCacheIds.single;
    expect(initialCategoryCacheId, isA<int>());
    expect(initialGlassCacheId, isA<int>());
    expect(
      find.byKey(const ValueKey<String>('native-category-rail-modal-underlay')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('liquid-glass-modal-underlay')),
      findsNothing,
    );

    // Open root dialog from detail pane -> native UiKitViews leave the
    // LayerTree so overlapping BackdropFilter popups never slice, while
    // Flutter underlays remain visible.
    await tester.tap(find.text('open fav'));
    await tester.pumpAndSettle();

    expect(find.text('添加收藏夹'), findsOneWidget);
    expect(find.text('topmost'), findsOneWidget);
    expect(categoryViewFinder, findsNothing);
    expect(glassViewFinder, findsNothing);
    expect(
      find.byKey(const ValueKey<String>('native-category-rail-modal-underlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('liquid-glass-modal-underlay')),
      findsOneWidget,
    );

    // Dismissing remounts UiKitViews with the same cacheId and keeps the
    // category underlay mounted until update + post-frame commit finish.
    holdCategoryUpdate = true;
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(categoryViewFinder, findsOneWidget);
    expect(glassViewFinder, findsOneWidget);
    expect(
      categoryCacheIds,
      <Object?>[initialCategoryCacheId, initialCategoryCacheId],
    );
    expect(glassCacheIds, <Object?>[initialGlassCacheId, initialGlassCacheId]);
    expect(updateCompleters, hasLength(1));
    expect(
      find.byKey(const ValueKey<String>('native-category-rail-modal-underlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('liquid-glass-modal-underlay')),
      findsNothing,
    );

    for (final completer in updateCompleters) {
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

    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      released,
      containsAll(<String>[
        'category:$initialCategoryCacheId',
        'glass:$initialGlassCacheId',
      ]),
    );
  });
}
