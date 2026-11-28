import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/fav_rule_safe_area.dart';
import 'package:eros_fe/widget/flutter_glass.dart';
import 'package:eros_fe/widget/gallery_card_context_menu.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/liquid_glass_rail.dart';
import 'package:eros_fe/widget/segmented_rail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class _StubEhSettingService extends GetxService implements EhSettingService {
  bool glassOn = true;
  bool pureDark = false;

  @override
  bool get liquidGlass => glassOn;

  @override
  bool get isPureDarkTheme => pureDark;

  @override
  final RxBool vibrate = false.obs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

double _wcagContrast(Color a, Color b) {
  final lums = <double>[a.computeLuminance(), b.computeLuminance()]..sort();
  return (lums.last + 0.05) / (lums.first + 0.05);
}

void main() {
  tearDown(() async {
    PlatformCapabilities.debugHostPlatformOverride = null;
    FlutterGlassRuntime.debugAvailable = null;
    (LiquidGlassAccessibilitySettings.reduceTransparency
            as ValueNotifier<bool?>)
        .value = null;
    await LiquidGlassAccessibilitySettings.stopWatching();
    if (Get.isRegistered<EhSettingService>()) {
      Get.delete<EhSettingService>(force: true);
    }
  });
  for (final host in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows
  ]) {
    for (final enabled in [true, false]) {
      testWidgets(
          '$host glass=$enabled surfaces, tab callbacks and category gestures',
          (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = host;
        final calls = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        for (final channel in [
          'flutter/platform_views',
          'eros/accessibility-settings'
        ]) {
          messenger.setMockMethodCallHandler(MethodChannel(channel),
              (call) async {
            calls.add('$channel/${call.method}');
            return null;
          });
          addTearDown(() =>
              messenger.setMockMethodCallHandler(MethodChannel(channel), null));
        }
        Future<void> pump(Widget child) async {
          await tester.pumpWidget(CupertinoApp(
              home: GlassPreference(
                  enabled: enabled, child: Center(child: child))));
          await tester.pump();
          expect(find.byType(UiKitView), findsNothing);
          expect(tester.takeException(), isNull);
        }

        await pump(const LiquidGlassSurface(
            enabled: true, child: SizedBox(width: 160, height: 40)));
        expect(find.byType(GlassContainer),
            enabled ? findsOneWidget : findsNothing);
        var selected = -1;
        var searched = false;
        await pump(LiquidGlassTabBar(
          items: const [
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.star), label: 'Favorites')
          ],
          onTap: (value) => selected = value,
          onSearch: () => searched = true,
          searchLabel: 'Search',
        ));
        expect(
            find.byType(GlassTabBar), enabled ? findsOneWidget : findsNothing);
        await tester.tap(find.text('Favorites').first);
        expect(selected, 1);
        if (enabled) {
          await tester.tap(find.byIcon(CupertinoIcons.search));
          expect(searched, isTrue);
        }
        var tapped = false;
        var held = false;
        final items = [
          LiquidGlassRailCategory(title: 'First', onTap: () {}),
          LiquidGlassRailCategory(
              title: 'Second',
              onTap: () => tapped = true,
              onLongPress: () => held = true)
        ];
        await pump(SegmentedRail(items: items, selectedIndex: 0));
        expect(find.byType(GlassContainer),
            enabled ? findsOneWidget : findsNothing);
        await tester.tap(find.text('Second'));
        await tester.longPress(find.text('Second'));
        expect(tapped, isTrue);
        expect(held, isTrue);
        await pump(NativeCategoryRail(
            categories: items,
            selectedIndex: 0,
            followSystemTransparency: true,
            brightness: Brightness.light,
            fontSize: 15,
            layout: LiquidGlassTopBarLayout.inline,
            initialOffset: 0,
            onOffset: (_) {},
            opacity: 1,
            interactive: true));
        expect(find.byType(GlassContainer),
            enabled ? findsOneWidget : findsNothing);
        await pump(EhActionSheet(
            glassEnabled: enabled,
            title: const Text('Title'),
            actions: [
              CupertinoActionSheetAction(
                  onPressed: () {}, child: const Text('Action'))
            ]));
        expect(find.byType(GlassContainer),
            enabled ? findsOneWidget : findsNothing);
        expect(calls, isEmpty);
      });
    }
  }
  testWidgets('nested surfaces share one refractive panel', (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(const CupertinoApp(
        home: Center(
            child: LiquidGlassSurface(
                enabled: true,
                child: LiquidGlassSurface(
                    enabled: true, child: SizedBox(width: 100, height: 40))))));
    expect(find.byType(GlassContainer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('high contrast popup uses an opaque surface without shader blur',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(const CupertinoApp(
        home: MediaQuery(
            data: MediaQueryData(highContrast: true),
            child: LiquidGlassPopupSurface(
                enabled: true, child: Text('Readable')))));
    expect(find.byType(GlassContainer), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Readable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shader initialization failure retains lightweight blur renderer',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    FlutterGlassRuntime.debugAvailable = false;
    await tester.pumpWidget(const CupertinoApp(
        home: LiquidGlassSurface(
            enabled: true, child: SizedBox(width: 100, height: 40))));
    expect(find.byType(GlassContainer), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(UiKitView), findsNothing);
  });

  testWidgets(
      'popup and fav-rule surfaces use readable glass variant while rails keep control defaults',
      (tester) async {
    final stubSettings = _StubEhSettingService();
    Get.put<EhSettingService>(stubSettings);
    for (final host in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      PlatformCapabilities.debugHostPlatformOverride = host;
      for (final material in GlassMaterial.values) {
        for (final dark in <bool>[false, true]) {
          stubSettings.pureDark = false;
          Future<void> pumpScene(Widget child) async {
            await tester.pumpWidget(
              CupertinoApp(
                theme: CupertinoThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: FlutterGlassRuntime.wrap(
                  Center(child: child),
                  enabled: true,
                  material: material,
                ),
              ),
            );
            await tester.pump();
          }

          // Control rail retains null explicit settings (uses package theme).
          await pumpScene(
            SegmentedRail(
              items: <LiquidGlassRailCategory>[
                LiquidGlassRailCategory(title: 'Popular', onTap: () {}),
                LiquidGlassRailCategory(title: 'Watched', onTap: () {}),
              ],
              selectedIndex: 0,
            ),
          );
          final railContainer =
              tester.widget<GlassContainer>(find.byType(GlassContainer));
          expect(railContainer.settings, isNull);
          expect(railContainer.clipBehavior, Clip.none);
          expect(railContainer.quality, material.quality);

          // LiquidGlassPopupSurface uses readable settings.
          await pumpScene(
            const LiquidGlassPopupSurface(
              enabled: true,
              child: Text('Popup Text'),
            ),
          );
          final popupContainer =
              tester.widget<GlassContainer>(find.byType(GlassContainer));
          final popupSettings = popupContainer.settings!;
          expect(popupContainer.useOwnLayer, isTrue);
          expect(popupContainer.clipBehavior, Clip.antiAlias);
          expect(popupContainer.quality, material.quality);
          expect(popupSettings.bodyMode, GlassBodyMode.clear);
          expect(popupSettings.blur, 24.0);
          expect(popupSettings.saturation, 1.0);
          expect(popupSettings.fresnelStrength, 1.0);
          expect(popupSettings.lightIntensity, greaterThan(0.6));
          if (dark) {
            expect(
              popupSettings.glassColor,
              EhPalette.graphite.raised.darkColor.withValues(alpha: 0.80),
            );
          } else {
            expect(
              popupSettings.glassColor,
              const Color.fromRGBO(248, 248, 250, 0.78),
            );
          }

          // buildFavRuleGlassOrCardSurface also routes through readable glass.
          await pumpScene(
            Builder(
              builder: (ctx) => buildFavRuleGlassOrCardSurface(
                context: ctx,
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                child: const Text('Menu Item'),
              ),
            ),
          );
          final favContainer =
              tester.widget<GlassContainer>(find.byType(GlassContainer));
          expect(favContainer.settings, isNotNull);
          expect(favContainer.settings!.bodyMode, GlassBodyMode.clear);
          expect(favContainer.settings!.blur, 24.0);
          expect(favContainer.settings!.saturation, 1.0);
        }
      }
    }
  });

  testWidgets(
      'reduceTransparency and highContrast degrade popup and fav-rule glass to opaque cards',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    Get.put<EhSettingService>(_StubEhSettingService());
    final notifier = LiquidGlassAccessibilitySettings.reduceTransparency
        as ValueNotifier<bool?>;

    await tester.pumpWidget(
      CupertinoApp(
        home: FlutterGlassRuntime.wrap(
          Builder(
            builder: (ctx) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const LiquidGlassPopupSurface(
                  enabled: true,
                  child: Text('Dialog Body'),
                ),
                buildFavRuleGlassOrCardSurface(
                  context: ctx,
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  child: const Text('Context Menu Row'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(GlassContainer), findsNWidgets(2));

    // Enabling Reduce Transparency removes all shader glass and blur layers.
    notifier.value = true;
    await tester.pump();
    expect(find.byType(GlassContainer), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    final shapeDecorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .where((dec) => dec.color != null)
        .toList();
    expect(shapeDecorations, isNotEmpty);
    expect(shapeDecorations.first.color!.a, 1.0);

    // Restoring Reduce Transparency brings glass back.
    notifier.value = false;
    await tester.pump();
    expect(find.byType(GlassContainer), findsNWidgets(2));
  });

  testWidgets(
      'context menu readable glass and backdrop tint keep >= 4.5:1 contrast over saturated covers',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    final stub = _StubEhSettingService();
    Get.put<EhSettingService>(stub);

    const saturatedCovers = <Color>[
      Color(0xFFF4D23A), // bright yellow
      Color(0xFFE8743B), // bright orange
      Color(0xFFF06292), // vivid pink
      Color(0xFFFFFFFF), // pure white
      Color(0xFF000000), // pure black
    ];

    const provider = GalleryProvider(
      gid: '777',
      token: 'nonhtok',
      englishTitle: 'Non-H Contrast Verification Fixture',
      category: 'Non-H',
      uploader: 'neutral-uploader',
    );

    for (final material in GlassMaterial.values) {
      for (final dark in <bool>[false, true]) {
        for (final pureDark in (dark ? <bool>[false, true] : <bool>[false])) {
          stub.pureDark = pureDark;
          final evalNotifier =
              RuleMenuEvalController(const RuleMenuEvalSnapshot.idle());
          addTearDown(evalNotifier.dispose);

          await tester.pumpWidget(
            CupertinoApp(
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                L10n.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: L10n.delegate.supportedLocales,
              theme: CupertinoThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: FlutterGlassRuntime.wrap(
                CupertinoPageScaffold(
                  child: Center(
                    child: Builder(
                      builder: (cardContext) => GestureDetector(
                        onTap: () {
                          showGalleryCardContextMenu(
                            cardContext: cardContext,
                            provider: provider,
                            isAlreadyFav: false,
                            currentFavcat: '',
                            evalNotifier: evalNotifier,
                            onApplyRule: (_) {},
                            entries: <GalleryContextMenuEntry>[
                              GalleryContextMenuEntry(
                                label: '选择收藏夹',
                                icon: CupertinoIcons.folder,
                                showChevron: true,
                                onPressed: () {},
                              ),
                              GalleryContextMenuEntry(
                                label: '按上传者筛选',
                                trailing: 'neutral-uploader',
                                icon: CupertinoIcons.person,
                                onPressed: () {},
                              ),
                            ],
                            onCreateRuleFromGallery: () {},
                          );
                        },
                        child: const SizedBox(
                          width: 140,
                          height: 200,
                          child: Text('OpenContextMenu'),
                        ),
                      ),
                    ),
                  ),
                ),
                enabled: true,
                material: material,
              ),
            ),
          );

          await tester.tap(find.text('OpenContextMenu'));
          await tester.pumpAndSettle();

          final backdropColor = tester
              .widget<ColoredBox>(find.byKey(kGalleryContextMenuBackdropKey))
              .color;
          if (dark) {
            expect(backdropColor.toARGB32(), 0x66000000);
          } else {
            expect(
              backdropColor.toARGB32(),
              const Color(0xFFF2F3F6).withValues(alpha: 0.30).toARGB32(),
            );
          }

          final glassContainer = tester.widget<GlassContainer>(
            find.descendant(
              of: find.byKey(kGalleryContextMenuSurfaceKey),
              matching: find.byType(GlassContainer),
            ),
          );
          final glassColor = glassContainer.settings!.glassColor;

          final primaryLabelColor = tester
              .widget<Text>(find.text('按上传者筛选'))
              .style!
              .color!;
          final secondaryTrailingRaw = tester
              .widget<Text>(find.text('neutral-uploader'))
              .style!
              .color!;

          for (final cover in saturatedCovers) {
            final tintedBackdrop = Color.alphaBlend(backdropColor, cover);
            final menuSurface = Color.alphaBlend(glassColor, tintedBackdrop);
            final effectivePrimary =
                Color.alphaBlend(primaryLabelColor, menuSurface);
            final effectiveSecondary =
                Color.alphaBlend(secondaryTrailingRaw, menuSurface);

            expect(
              _wcagContrast(effectivePrimary, menuSurface),
              greaterThanOrEqualTo(4.5),
              reason:
                  'primary contrast failed for material=$material dark=$dark pureDark=$pureDark cover=$cover',
            );
            expect(
              _wcagContrast(effectiveSecondary, menuSurface),
              greaterThanOrEqualTo(4.5),
              reason:
                  'secondary contrast failed for material=$material dark=$dark pureDark=$pureDark cover=$cover',
            );
          }

          Navigator.of(
            tester.element(find.byKey(kGalleryContextMenuSurfaceKey)),
          ).pop();
          await tester.pumpAndSettle();
        }
      }
    }
  });
}
