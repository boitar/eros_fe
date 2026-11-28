import 'dart:async';

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/models/gallery_tag.dart';
import 'package:eros_fe/models/simple_tag.dart';
import 'package:eros_fe/models/tag_group.dart';
import 'package:eros_fe/models/user.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_hero.dart';
import 'package:eros_fe/pages/gallery/view/taginfo_dialog.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/pages/setting/fav_rule/fav_rule_condition_sheet.dart';
import 'package:eros_fe/pages/setting/fav_rule/fav_rule_edit_page.dart';
import 'package:eros_fe/pages/setting/fav_rule/fav_rule_setting_page.dart';
import 'package:eros_fe/pages/setting/fav_rule/fav_rule_test_page.dart';
import 'package:eros_fe/route/app_pages.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/route/second_observer.dart';
import 'package:eros_fe/store/db/entity/tag_translat.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/fav_rule_toast.dart';
import 'package:eros_fe/widget/fav_rule_widgets.dart';
import 'package:eros_fe/widget/gallery_card_context_menu.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oktoast/oktoast.dart';

class _TestSettings extends GetxService implements EhSettingService {
  final RxBool _liquidGlass = true.obs;
  @override
  RxBool isFavPicker = false.obs;
  @override
  RxBool isFavLongTap = false.obs;
  @override
  final RxBool vibrate = false.obs;
  @override
  String lastFavcat = '1';
  @override
  bool get isPureDarkTheme => false;
  @override
  bool get liquidGlass => _liquidGlass.value;
  @override
  bool get liquidGlassMaterial => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestTheme extends GetxService implements ThemeService {
  @override
  ThemesModeEnum get themeModel => ThemesModeEnum.darkMode;
  @override
  EhPalette get palette => EhPalette.graphite;
  @override
  CupertinoThemeData? get themeData =>
      const CupertinoThemeData(brightness: Brightness.dark);
  bool get isDarkMode => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapApp(
  Widget home, {
  Brightness brightness = Brightness.dark,
  EdgeInsets safePadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return OKToast(
    child: GetCupertinoApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: CupertinoThemeData(brightness: brightness),
      builder: (context, child) {
        final base = MediaQuery.of(context);
        return MediaQuery(
          data: base.copyWith(
            padding: safePadding,
            viewPadding: safePadding,
            viewInsets: viewInsets,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home,
    ),
  );
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('eros/accessibility-settings'),
      (_) async => null,
    );
    Get.testMode = true;
    Get.reset();
    Get.put<EhSettingService>(_TestSettings());
    Get.put<ThemeService>(_TestTheme());
  });

  tearDown(() {
    dismissFavRuleFeedbackBanner();
    Get.reset();
  });

  testWidgets('FavRuleSettingPage renders controls, styles, and rules',
      (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => true,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    await service.addRule(
      const FavRule(
        id: 'r1',
        name: '喜欢的画师',
        favcat: '1',
        conditions: <FavRuleCondition>[
          FavRuleCondition(namespace: 'artist', value: 'mitsuki'),
        ],
      ),
    );
    Get.put<FavRuleService>(service);

    await tester.pumpWidget(_wrapApp(const FavRuleSettingPage()));
    await tester.pumpAndSettle();

    expect(find.text('规则收藏'), findsOneWidget);
    expect(find.text('单点收藏已升级为规则收藏'), findsOneWidget);
    expect(find.text('触发方式'), findsOneWidget);
    expect(find.text('列表长按菜单'), findsOneWidget);
    expect(find.text('收藏夹选择弹窗'), findsOneWidget);
    expect(find.text('喜欢的画师'), findsOneWidget);
  });

  testWidgets('FavRuleEditPage renders prefilled rule and folder grid',
      (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    Get.put<FavRuleService>(service);

    await tester.pumpWidget(
      _wrapApp(
        const FavRuleEditPage(
          args: FavRuleEditArgs(
            initialConditions: <FavRuleCondition>[
              FavRuleCondition(
                namespace: 'artist',
                op: FavRuleOp.equals,
                value: 'mitsuki',
              ),
            ],
            initialFavcat: '2',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('mitsuki'), findsOneWidget);
    expect(find.text('添加条件'), findsOneWidget);
    expect(find.text('收进'), findsOneWidget);
    expect(find.text('本地收藏'), findsOneWidget);
  });

  testWidgets('FavRuleTestPage evaluates custom tags live', (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    await service.addRule(
      const FavRule(
        id: 'r1',
        name: '足控',
        favcat: '2',
        conditions: <FavRuleCondition>[
          FavRuleCondition(op: FavRuleOp.contains, value: 'foot'),
        ],
      ),
    );
    Get.put<FavRuleService>(service);

    await tester.pumpWidget(_wrapApp(const FavRuleTestPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('手动输入标签'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(CupertinoTextField),
      'female:foot focus',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('规则「足控」'), findsOneWidget);
  });

  testWidgets('FavRuleFeedbackBanner displays rule info and fires Undo',
      (tester) async {
    var undone = false;
    await tester.pumpWidget(
      _wrapApp(
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () {
                  showFavRuleFeedbackBanner(
                    context: context,
                    favcat: '1',
                    title: '已收进「收藏夹 1」',
                    subtitle: '规则「喜欢的画师」· artist:mitsuki',
                    secondaryNote: '另有「足控」也命中，按顺序未采用',
                    actions: <FavRuleBannerAction>[
                      FavRuleBannerAction(
                        label: '撤销',
                        onPressed: () => undone = true,
                      ),
                    ],
                  );
                },
                child: const Text('Trigger'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.text('已收进「收藏夹 1」'), findsOneWidget);
    expect(find.text('另有「足控」也命中，按顺序未采用'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(undone, isTrue);
  });

  testWidgets('FavController grid picker renders miss card, last badge, and picks folder',
      (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    Get.put<FavRuleService>(service);
    final favCtrl = Get.put<FavController>(FavController());

    Favcat? picked;
    await tester.pumpWidget(
      _wrapApp(
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () async {
                  picked = await favCtrl.showFavListDialog(
                    context,
                    const <Favcat>[
                      Favcat(favId: '0', favTitle: '收藏夹 0', totNum: 42),
                      Favcat(favId: '1', favTitle: '收藏夹 1', totNum: 128),
                      Favcat(favId: '2', favTitle: '收藏夹 2', totNum: 77),
                    ],
                    ruleMissContext: const FavRuleMissContext(
                      galleryTitle: 'Idolmaster Art',
                      keyTags: <NormalizedTag>[
                        NormalizedTag(
                          namespace: 'artist',
                          title: 'hanako',
                          rawTitle: 'hanako',
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    expect(find.text('没有规则命中'), findsOneWidget);
    expect(find.text('上次'), findsOneWidget);
    expect(find.text('收藏夹 1'), findsOneWidget);

    await tester.tap(find.text('收藏夹 2'));
    await tester.pumpAndSettle();
    expect(picked?.favId, '2');
  });

  testWidgets('Floating card context menu displays matched rule banner and triggers callback',
      (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    await service.addRule(
      const FavRule(
        id: 'r1',
        name: '足控',
        favcat: '2',
        conditions: <FavRuleCondition>[
          FavRuleCondition(op: FavRuleOp.contains, value: 'foot'),
        ],
      ),
    );
    Get.put<FavRuleService>(service);

    const provider = GalleryProvider(
      gid: '99',
      token: 'tok',
      englishTitle: 'Blue Hour',
      category: 'Non-H',
      tagsFromApi: <dynamic>['female:foot focus'],
    );
    final evalNotifier = createRuleEvalNotifier(provider);
    addTearDown(evalNotifier.dispose);

    FavRuleEvalResult? applied;
    await tester.pumpWidget(
      _wrapApp(
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () {
                  showGalleryCardContextMenu(
                    cardContext: context,
                    provider: provider,
                    isAlreadyFav: false,
                    currentFavcat: '',
                    evalNotifier: evalNotifier,
                    onApplyRule: (eval) => applied = eval,
                    entries: <GalleryContextMenuEntry>[
                      GalleryContextMenuEntry(
                        label: '选择收藏夹',
                        icon: CupertinoIcons.heart,
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: const Text('LongPressCard'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('LongPressCard'));
    await tester.pumpAndSettle();

    expect(find.textContaining('规则「足控」'), findsOneWidget);
    expect(find.text('选择收藏夹'), findsOneWidget);

    await tester.tap(find.textContaining('规则「足控」'));
    await tester.pumpAndSettle();
    expect(applied?.primary?.rule.id, 'r1');
  });

  testWidgets(
      'Condition sheet (④) and flat picker (⑦) avoid side safe area in light & dark modes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const sideSafe = EdgeInsets.fromLTRB(44, 24, 68, 24);
    final envService = Get.put<AdaptiveEnvironmentService>(
      AdaptiveEnvironmentService(),
    );
    envService.acceptNativeSnapshot(<Object?, Object?>{
      'width': 440.0,
      'height': 760.0,
      'safeLeft': 44.0,
      'safeTop': 24.0,
      'safeRight': 68.0,
      'safeBottom': 24.0,
      'systemBarEdge': 'right',
      'duoVerticalBar': true,
      'layoutVersion': 1,
      'nativeSupported': true,
    });

    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    Get.put<FavRuleService>(service);
    final favCtrl = Get.put<FavController>(FavController());

    FavRuleCondition? savedCondition;
    await tester.pumpWidget(
      _wrapApp(
        brightness: Brightness.light,
        safePadding: sideSafe,
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CupertinoButton(
                  onPressed: () async {
                    savedCondition = await showFavRuleConditionSheet(context);
                  },
                  child: const Text('OpenConditionSheet'),
                ),
                CupertinoButton(
                  onPressed: () async {
                    await favCtrl.showFavListDialog(
                      context,
                      const <Favcat>[
                        Favcat(favId: '0', favTitle: '收藏夹 0', totNum: 42),
                        Favcat(favId: '1', favTitle: '收藏夹 1', totNum: 128),
                      ],
                      galleryTitle: 'Safe Area Gallery',
                      ruleMissContext: const FavRuleMissContext(
                        galleryTitle: 'Safe Area Gallery',
                        keyTags: <NormalizedTag>[
                          NormalizedTag(
                            namespace: 'artist',
                            title: 'hanako',
                            rawTitle: 'hanako',
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('OpenFlatPicker'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 1) Verify ④ Condition Sheet respects left (44+8=52) & right (440-68-8=364) safe margins
    await tester.tap(find.text('OpenConditionSheet'));
    await tester.pumpAndSettle();

    final condSheetRect = tester.getRect(find.byType(LiquidGlassPopupSurface));
    expect(condSheetRect.left, greaterThanOrEqualTo(52.0));
    expect(condSheetRect.right, lessThanOrEqualTo(364.0));

    await tester.tap(find.byKey(kFavRuleConditionSheetOperatorKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('包含'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'foot');
    await tester.pump();
    await tester.tap(find.byKey(kFavRuleConditionSheetSaveKey));
    await tester.pumpAndSettle();

    expect(savedCondition?.op, FavRuleOp.contains);
    expect(savedCondition?.value, 'foot');

    // 2) Verify ⑦ Flat Single-Surface Picker also respects side safe area & renders neutral chips
    await tester.tap(find.text('OpenFlatPicker'));
    await tester.pumpAndSettle();

    final pickerRect = tester.getRect(find.byType(LiquidGlassPopupSurface));
    expect(pickerRect.left, greaterThanOrEqualTo(52.0));
    expect(pickerRect.right, lessThanOrEqualTo(364.0));
    expect(find.text('画师'), findsOneWidget);
    expect(find.text('hanako'), findsOneWidget);
    expect(find.textContaining('artist:hanako'), findsNothing);
    expect(find.text('新建规则'), findsOneWidget);
  });

  testWidgets(
      'RuleMenuEvalController safely ignores late async completion after dispose',
      (tester) async {
    final completer = Completer<List<String>>();
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
      fetchApiTags: (_, _) => completer.future,
    );
    service.loadAndMigrate();
    await service.addRule(
      const FavRule(
        id: 'r1',
        favcat: '1',
        conditions: <FavRuleCondition>[
          FavRuleCondition(namespace: 'artist', value: 'mitsuki'),
        ],
      ),
    );
    Get.put<FavRuleService>(service);

    const card = GalleryProvider(
      gid: '777',
      token: 'tok',
      simpleTags: <SimpleTag>[SimpleTag(text: 'stockings')],
    );
    final notifier = createRuleEvalNotifier(card);
    expect(notifier.value.state, RuleMenuEvalState.loading);

    // User dismisses menu before gdata resolves
    notifier.dispose();
    completer.complete(<String>['artist:mitsuki']);
    await tester.pump();
    // No use-after-dispose exception thrown
  });

  testWidgets(
      'Dark mode + keyboard viewInsets keep condition sheet (④) and flat picker (⑦) inside safe bounds without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const sideSafe = EdgeInsets.fromLTRB(59, 20, 68, 21);
    const keyboardInsets = EdgeInsets.only(bottom: 336);
    final envService = Get.put<AdaptiveEnvironmentService>(
      AdaptiveEnvironmentService(),
    );
    envService.acceptNativeSnapshot(<Object?, Object?>{
      'width': 440.0,
      'height': 760.0,
      'safeLeft': 59.0,
      'safeTop': 20.0,
      'safeRight': 68.0,
      'safeBottom': 21.0,
      'systemBarEdge': 'right',
      'duoVerticalBar': true,
      'layoutVersion': 1,
      'nativeSupported': true,
    });

    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    Get.put<FavRuleService>(service);
    final favCtrl = Get.put<FavController>(FavController());

    FavRuleCondition? saved;
    await tester.pumpWidget(
      _wrapApp(
        brightness: Brightness.dark,
        safePadding: sideSafe,
        viewInsets: keyboardInsets,
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CupertinoButton(
                  onPressed: () async {
                    saved = await showFavRuleConditionSheet(context);
                  },
                  child: const Text('OpenDarkCondition'),
                ),
                CupertinoButton(
                  onPressed: () async {
                    await favCtrl.showFavListDialog(
                      context,
                      const <Favcat>[
                        Favcat(favId: '0', favTitle: '收藏夹 0', totNum: 12),
                        Favcat(favId: '1', favTitle: '收藏夹 1', totNum: 34),
                        Favcat(favId: '2', favTitle: '收藏夹 2', totNum: 56),
                        Favcat(favId: '3', favTitle: '收藏夹 3', totNum: 78),
                      ],
                      galleryTitle: 'Dark Keyboard Gallery',
                    );
                  },
                  child: const Text('OpenDarkPicker'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OpenDarkCondition'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final condRect = tester.getRect(find.byType(LiquidGlassPopupSurface));
    expect(condRect.left, greaterThanOrEqualTo(67.0));
    expect(condRect.right, lessThanOrEqualTo(440.0 - 76.0));
    expect(condRect.bottom, lessThanOrEqualTo(760.0 - 336.0 + 0.5));

    await tester.enterText(find.byType(CupertinoTextField), 'mitsuki');
    await tester.pump();
    await tester.tap(find.byKey(kFavRuleConditionSheetSaveKey));
    await tester.pumpAndSettle();
    expect(saved?.value, 'mitsuki');

    await tester.tap(find.text('OpenDarkPicker'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final pickerRect = tester.getRect(find.byType(LiquidGlassPopupSurface));
    expect(pickerRect.left, greaterThanOrEqualTo(67.0));
    expect(pickerRect.right, lessThanOrEqualTo(440.0 - 76.0));
    expect(pickerRect.bottom, lessThanOrEqualTo(760.0 - 336.0 + 0.5));
  });

  testWidgets(
      'GalleryItemController.applyRuleOrFallback honors last and fixed fallbacks on miss',
      (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    await service.setEnabled(true);
    await service.setFallback(FavRuleFallback.fixed);
    await service.setFallbackFavcat('3');
    Get.put<FavRuleService>(service);

    final fakeUser = _LoggedInUserController();
    Get.put<UserController>(fakeUser);
    final fakeFav = _RecordingFavController();
    Get.put<FavController>(fakeFav);

    final itemCtrl = GalleryItemController(
      galleryProvider: const GalleryProvider(
        gid: '888',
        token: 'tok',
        englishTitle: 'Fallback Gallery',
        simpleTags: <SimpleTag>[SimpleTag(text: 'artist:hanako')],
      ),
    );

    await tester.pumpWidget(
      _wrapApp(
        CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () => itemCtrl.applyRuleOrFallback(FavRuleEvalResult.miss),
              child: const Text('RunFallback'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('RunFallback'));
    await tester.pumpAndSettle();

    expect(fakeFav.savedFavcats, <String>['3']);
    expect(fakeFav.pickerOpened, 0);
    dismissFavRuleFeedbackBanner();

    // Switch to fallback=last (lastFavcat='1') on an un-favorited item
    final itemCtrl2 = GalleryItemController(
      galleryProvider: const GalleryProvider(
        gid: '889',
        token: 'tok',
        englishTitle: 'Last Fallback Gallery',
      ),
    );
    await service.setFallback(FavRuleFallback.last);
    await tester.pumpWidget(
      _wrapApp(
        CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () =>
                  itemCtrl2.applyRuleOrFallback(FavRuleEvalResult.miss),
              child: const Text('RunLastFallback'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('RunLastFallback'));
    await tester.pumpAndSettle();

    expect(fakeFav.savedFavcats, <String>['3', '1']);
    expect(fakeFav.pickerOpened, 0);
  });

  testWidgets(
      'Grid card context menu places below lifted card at real aspect ratio and respects side safe area',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const sideSafe = EdgeInsets.fromLTRB(44, 24, 68, 24);
    final envService = Get.put<AdaptiveEnvironmentService>(
      AdaptiveEnvironmentService(),
    );
    envService.acceptNativeSnapshot(<Object?, Object?>{
      'width': 440.0,
      'height': 820.0,
      'safeLeft': 44.0,
      'safeTop': 24.0,
      'safeRight': 68.0,
      'safeBottom': 24.0,
      'systemBarEdge': 'right',
      'duoVerticalBar': true,
      'layoutVersion': 1,
      'nativeSupported': true,
    });

    const provider = GalleryProvider(
      gid: '501',
      token: 'gridtok',
      englishTitle: 'Masonry Waterfall Card Title Without Vertical Clipping',
      category: 'Manga',
    );
    final evalNotifier =
        RuleMenuEvalController(const RuleMenuEvalSnapshot.idle());
    addTearDown(evalNotifier.dispose);

    var readCount = 0;
    await tester.pumpWidget(
      _wrapApp(
        brightness: Brightness.dark,
        safePadding: sideSafe,
        CupertinoPageScaffold(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 68,
                top: 110,
                width: 148,
                height: 224,
                child: Builder(
                  builder: (cardCtx) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showGalleryCardContextMenu(
                        cardContext: cardCtx,
                        provider: provider,
                        isAlreadyFav: false,
                        currentFavcat: '',
                        evalNotifier: evalNotifier,
                        onApplyRule: (_) {},
                        quickActions: <GalleryContextQuickAction>[
                          GalleryContextQuickAction(
                            label: '收藏夹',
                            icon: CupertinoIcons.heart,
                            onPressed: () {},
                          ),
                          GalleryContextQuickAction(
                            label: '阅读',
                            icon: CupertinoIcons.book,
                            onPressed: () => readCount++,
                          ),
                          GalleryContextQuickAction(
                            label: '复制链接',
                            icon: CupertinoIcons.link,
                            onPressed: () {},
                          ),
                        ],
                        entries: <GalleryContextMenuEntry>[
                          GalleryContextMenuEntry(
                            label: '选择收藏夹',
                            icon: CupertinoIcons.folder,
                            onPressed: () {},
                          ),
                          GalleryContextMenuEntry(
                            label: '按上传者筛选',
                            trailing: 'honjow',
                            icon: CupertinoIcons.person,
                            onPressed: () {},
                          ),
                        ],
                      );
                    },
                    child: RepaintBoundary(
                      child: Container(
                        color: const Color(0xFF202126),
                        alignment: Alignment.center,
                        child: const Text('GridCardTarget'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('GridCardTarget'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(LiquidGlassPopupSurface), findsOneWidget);
    expect(find.byKey(kGalleryContextMenuQuickBarKey), findsOneWidget);

    final backdropBox = tester.widget<ColoredBox>(
      find.byKey(kGalleryContextMenuBackdropKey),
    );
    expect(backdropBox.color.toARGB32(), 0x66000000);

    final liftedRect = tester.getRect(
      find.byKey(kGalleryContextMenuLiftedCardKey),
    );
    expect(liftedRect.width / liftedRect.height, closeTo(148.0 / 224.0, 0.01));
    expect(liftedRect.width, closeTo(148.0 * 1.035, 1.0));
    expect(liftedRect.left, greaterThanOrEqualTo(56.0));
    expect(liftedRect.right, lessThanOrEqualTo(360.0));

    final menuRect = tester.getRect(find.byKey(kGalleryContextMenuSurfaceKey));
    expect(menuRect.width, closeTo(252.0, 0.5));
    expect(menuRect.top, closeTo(liftedRect.bottom + 10.0, 1.0));
    expect(menuRect.left, closeTo(liftedRect.left, 1.0));
    expect(menuRect.left, greaterThanOrEqualTo(56.0));
    expect(menuRect.right, lessThanOrEqualTo(360.0));

    await tester.tap(find.text('阅读'));
    await tester.pumpAndSettle();
    expect(readCount, 1);
  });

  testWidgets(
      'Tall card context menu places beside lifted card on right or left while avoiding side safe rail',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const sideSafe = EdgeInsets.fromLTRB(24, 24, 68, 24);
    final envService = Get.put<AdaptiveEnvironmentService>(
      AdaptiveEnvironmentService(),
    );
    envService.acceptNativeSnapshot(<Object?, Object?>{
      'width': 760.0,
      'height': 760.0,
      'safeLeft': 24.0,
      'safeTop': 24.0,
      'safeRight': 68.0,
      'safeBottom': 24.0,
      'systemBarEdge': 'right',
      'duoVerticalBar': true,
      'layoutVersion': 1,
      'nativeSupported': true,
    });

    const provider = GalleryProvider(
      gid: '502',
      token: 'talltok',
      englishTitle: 'Tall Showcase Illustration Card',
      category: 'Artist CG',
    );
    final evalNotifier =
        RuleMenuEvalController(const RuleMenuEvalSnapshot.idle());
    addTearDown(evalNotifier.dispose);

    List<GalleryContextMenuEntry> buildEntries() {
      return <GalleryContextMenuEntry>[
        GalleryContextMenuEntry(
          label: '选择收藏夹',
          icon: CupertinoIcons.heart,
          onPressed: () {},
        ),
        GalleryContextMenuEntry(
          label: '阅读',
          icon: CupertinoIcons.book,
          onPressed: () {},
        ),
        GalleryContextMenuEntry(
          label: '复制链接',
          icon: CupertinoIcons.link,
          onPressed: () {},
        ),
        GalleryContextMenuEntry(
          label: '按上传者筛选',
          icon: CupertinoIcons.person,
          onPressed: () {},
        ),
      ];
    }

    await tester.pumpWidget(
      _wrapApp(
        brightness: Brightness.light,
        safePadding: sideSafe,
        CupertinoPageScaffold(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 60,
                top: 120,
                width: 250,
                height: 520,
                child: Builder(
                  builder: (leftCardCtx) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showGalleryCardContextMenu(
                        cardContext: leftCardCtx,
                        provider: provider,
                        isAlreadyFav: false,
                        currentFavcat: '',
                        evalNotifier: evalNotifier,
                        onApplyRule: (_) {},
                        entries: buildEntries(),
                      );
                    },
                    child: RepaintBoundary(
                      child: Container(
                        color: const Color(0xFFFFFFFF),
                        alignment: Alignment.center,
                        child: const Text('LeftTallCard'),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 410,
                top: 120,
                width: 250,
                height: 520,
                child: Builder(
                  builder: (rightCardCtx) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showGalleryCardContextMenu(
                        cardContext: rightCardCtx,
                        provider: provider,
                        isAlreadyFav: false,
                        currentFavcat: '',
                        evalNotifier: evalNotifier,
                        onApplyRule: (_) {},
                        entries: buildEntries(),
                      );
                    },
                    child: RepaintBoundary(
                      child: Container(
                        color: const Color(0xFFFFFFFF),
                        alignment: Alignment.center,
                        child: const Text('RightTallCard'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 1) Left tall card -> menu placed to the RIGHT with 12pt gap
    await tester.tap(find.text('LeftTallCard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final lightBackdrop = tester.widget<ColoredBox>(
      find.byKey(kGalleryContextMenuBackdropKey),
    );
    expect(
      lightBackdrop.color.toARGB32(),
      const Color(0xFFF2F3F6).withValues(alpha: 0.30).toARGB32(),
    );

    final liftedLeft = tester.getRect(
      find.byKey(kGalleryContextMenuLiftedCardKey),
    );
    final menuRightSide = tester.getRect(
      find.byKey(kGalleryContextMenuSurfaceKey),
    );
    expect(liftedLeft.width / liftedLeft.height, closeTo(250.0 / 520.0, 0.01));
    expect(menuRightSide.left, closeTo(liftedLeft.right + 12.0, 1.5));
    expect(menuRightSide.top, closeTo(liftedLeft.top, 1.5));
    expect(menuRightSide.right, lessThanOrEqualTo(680.0));

    // Leading-icon check on rows (`[18pt leading icon]  [15pt label]`)
    final bookIconRect = tester.getRect(
      find.descendant(
        of: find.byKey(kGalleryContextMenuSurfaceKey),
        matching: find.byWidgetPredicate(
          (w) => w is EhSvgIcon && w.icon == CupertinoIcons.book,
        ),
      ),
    );
    final readLabelRect = tester.getRect(find.text('阅读'));
    expect(bookIconRect.right, lessThan(readLabelRect.left));

    Navigator.of(
      tester.element(find.byKey(kGalleryContextMenuSurfaceKey)),
    ).pop();
    await tester.pumpAndSettle();

    // 2) Right tall card near Duo right rail -> menu flips to the LEFT with 12pt gap
    await tester.tap(find.text('RightTallCard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final liftedRight = tester.getRect(
      find.byKey(kGalleryContextMenuLiftedCardKey),
    );
    final menuLeftSide = tester.getRect(
      find.byKey(kGalleryContextMenuSurfaceKey),
    );
    expect(liftedRight.left - menuLeftSide.right, closeTo(12.0, 1.5));
    expect(menuLeftSide.left, greaterThanOrEqualTo(36.0));
    expect(liftedRight.right, lessThanOrEqualTo(680.0));
  });

  testWidgets(
      'GalleryItemController long-press wires rule-hit strip, quick actions, and leading-icon rows',
      (tester) async {
    String? copiedText;
    final toasts = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<dynamic, dynamic>;
        copiedText = args['text'] as String?;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': copiedText};
      }
      return null;
    });
    DesktopGalleryActions.debugToast = toasts.add;
    addTearDown(() {
      DesktopGalleryActions.debugToast = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    await service.setEnabled(true);
    await service.setListMenuStyle(FavListMenuStyle.contextMenu);
    await service.addRule(
      const FavRule(
        id: 'r_artist',
        name: '画师精选',
        favcat: '2',
        conditions: <FavRuleCondition>[
          FavRuleCondition(namespace: 'artist', value: 'mitsuki'),
        ],
      ),
    );
    Get.put<FavRuleService>(service);
    Get.put<UserController>(_LoggedInUserController());
    final fakeFav = _RecordingFavController()..pickerResult = null;
    Get.put<FavController>(fakeFav);

    final itemCtrl = GalleryItemController(
      galleryProvider: const GalleryProvider(
        gid: '1024',
        token: 'abcd1234',
        url: 'https://e-hentai.org/g/1024/abcd1234/',
        englishTitle: 'Moonlight Sketchbook',
        category: 'Non-H',
        uploader: 'mitsuki_san',
        tagsFromApi: <dynamic>['artist:mitsuki'],
      ),
    );

    await tester.pumpWidget(
      _wrapApp(
        CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 160,
              height: 236,
              child: Builder(
                builder: (cardCtx) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => itemCtrl.onLongPress(cardCtx),
                  child: RepaintBoundary(
                    child: Container(
                      color: const Color(0xFF202126),
                      alignment: Alignment.center,
                      child: const Text('ControllerCard'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // 1) Open menu and verify single glass surface, rule-hit strip, quick bar & leading-icon rows
    await tester.tap(find.text('ControllerCard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(LiquidGlassPopupSurface), findsOneWidget);
    expect(find.byKey(kGalleryContextMenuRuleBannerKey), findsOneWidget);
    expect(find.textContaining('收进「Favorites 2」'), findsOneWidget);
    expect(find.textContaining('规则「画师精选」'), findsOneWidget);
    expect(find.text('收藏夹'), findsOneWidget);
    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('复制链接'), findsOneWidget);
    expect(find.text('选择收藏夹'), findsOneWidget);
    expect(find.text('按上传者筛选'), findsOneWidget);
    expect(find.text('mitsuki_san'), findsOneWidget);

    final folderIconRect = tester.getRect(
      find.descendant(
        of: find.byKey(kGalleryContextMenuSurfaceKey),
        matching: find.byWidgetPredicate(
          (w) => w is EhSvgIcon && w.icon == CupertinoIcons.folder,
        ),
      ),
    );
    final chooseLabelRect = tester.getRect(find.text('选择收藏夹'));
    expect(folderIconRect.right, lessThan(chooseLabelRect.left));

    // 2) Tap 复制链接 -> copies URL to clipboard
    await tester.tap(find.text('复制链接'));
    await tester.pumpAndSettle();
    expect(copiedText, 'https://e-hentai.org/g/1024/abcd1234/');

    // 3) Re-open and tap 选择收藏夹 -> opens manual folder picker
    await tester.tap(find.text('ControllerCard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择收藏夹'));
    await tester.pumpAndSettle();
    expect(fakeFav.pickerOpened, 1);

    // 4) Re-open on a fresh unfavorited item and tap rule-hit banner -> saves to folder 2
    final itemCtrl2 = GalleryItemController(
      galleryProvider: const GalleryProvider(
        gid: '1025',
        token: 'efgh5678',
        englishTitle: 'Starlight Sketchbook',
        tagsFromApi: <dynamic>['artist:mitsuki'],
      ),
    );
    await tester.pumpWidget(
      _wrapApp(
        CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 160,
              height: 236,
              child: Builder(
                builder: (cardCtx) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => itemCtrl2.onLongPress(cardCtx),
                  child: RepaintBoundary(
                    child: Container(
                      color: const Color(0xFF202126),
                      alignment: Alignment.center,
                      child: const Text('ControllerCard2'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ControllerCard2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kGalleryContextMenuRuleBannerKey));
    await tester.pumpAndSettle();
    expect(fakeFav.savedFavcats, <String>['2']);
    dismissFavRuleFeedbackBanner();

    // 5) Unmatched item + quick-bar `收藏夹` routes through configured fallback
    // (populates `FavRuleMissContext` on picker, or saves directly on `last`)
    final unmatchedCtrl = GalleryItemController(
      galleryProvider: const GalleryProvider(
        gid: '1026',
        token: 'ijkl9012',
        englishTitle: 'Unmatched Sketchbook',
        tagsFromApi: <dynamic>['artist:sakuya', 'parody:original'],
      ),
    );
    await tester.pumpWidget(
      _wrapApp(
        CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 160,
              height: 236,
              child: Builder(
                builder: (cardCtx) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unmatchedCtrl.onLongPress(cardCtx),
                  child: RepaintBoundary(
                    child: Container(
                      color: const Color(0xFF202126),
                      alignment: Alignment.center,
                      child: const Text('UnmatchedCard'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('UnmatchedCard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收藏夹'));
    await tester.pumpAndSettle();
    expect(fakeFav.pickerOpened, 2);
    expect(fakeFav.lastMissContext, isNotNull);
    expect(
      fakeFav.lastMissContext!.keyTags.map((t) => t.key),
      contains('artist:sakuya'),
    );
  });

  testWidgets(
      'showGalleryCardContextMenu respects true narrow/short safe bounds and uses compact fallback without rail intrusion',
      (tester) async {
    // Counterexample from review: 240pt wide with 44pt left and 68pt right insets
    // -> true safe right bound with 12pt margin is 160pt (raw rail edge 172pt).
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(240, 600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const crampedSafe = EdgeInsets.fromLTRB(44, 24, 68, 20);
    final evalNotifier = ValueNotifier<RuleMenuEvalSnapshot>(
      const RuleMenuEvalSnapshot.miss(),
    );
    addTearDown(evalNotifier.dispose);

    const provider = GalleryProvider(
      gid: '2048',
      token: 'narrow01',
      englishTitle: 'Narrow Split Viewport Gallery',
      uploader: 'mitsuki_long_uploader_name',
    );

    var chooseTapped = false;
    await tester.pumpWidget(
      _wrapApp(
        safePadding: crampedSafe,
        CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 96,
              height: 150,
              child: Builder(
                builder: (cardCtx) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    showGalleryCardContextMenu(
                      cardContext: cardCtx,
                      provider: provider,
                      isAlreadyFav: false,
                      currentFavcat: '',
                      evalNotifier: evalNotifier,
                      onApplyRule: (_) {},
                      quickActions: <GalleryContextQuickAction>[
                        GalleryContextQuickAction(
                          label: '收藏夹',
                          icon: CupertinoIcons.heart,
                          onPressed: () {},
                        ),
                        GalleryContextQuickAction(
                          label: '阅读',
                          icon: CupertinoIcons.book,
                          onPressed: () {},
                        ),
                        GalleryContextQuickAction(
                          label: '复制链接',
                          icon: CupertinoIcons.link,
                          onPressed: () {},
                        ),
                      ],
                      entries: <GalleryContextMenuEntry>[
                        GalleryContextMenuEntry(
                          label: '选择收藏夹',
                          icon: CupertinoIcons.folder,
                          showChevron: true,
                          onPressed: () => chooseTapped = true,
                        ),
                        GalleryContextMenuEntry(
                          label: '按上传者筛选',
                          trailing: 'mitsuki_long_uploader_name',
                          icon: CupertinoIcons.person,
                          onPressed: () {},
                        ),
                      ],
                    );
                  },
                  child: RepaintBoundary(
                    child: Container(
                      color: const Color(0xFF202126),
                      alignment: Alignment.center,
                      child: const Text('NarrowCard'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('NarrowCard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Compact fallback hides lifted card and keeps menu strictly inside [56, 160]
    expect(find.byKey(kGalleryContextMenuLiftedCardKey), findsNothing);
    final menuRect = tester.getRect(find.byKey(kGalleryContextMenuSurfaceKey));
    expect(menuRect.left, greaterThanOrEqualTo(56.0));
    expect(menuRect.right, lessThanOrEqualTo(160.0));
    expect(menuRect.top, greaterThanOrEqualTo(36.0));
    expect(menuRect.bottom, lessThanOrEqualTo(568.0));

    await tester.tap(find.text('选择收藏夹'));
    await tester.pumpAndSettle();
    expect(chooseTapped, isTrue);

    // Also exercise the short-height compact fallback branch (`availWidth >= 160`
    // while `safeHeight < 240`), e.g. landscape split view with keyboard up:
    chooseTapped = false;
    tester.view.physicalSize = const Size(420, 210);
    await tester.pumpWidget(
      _wrapApp(
        safePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 160,
              height: 140,
              child: Builder(
                builder: (shortCtx) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    showGalleryCardContextMenu(
                      cardContext: shortCtx,
                      provider: provider,
                      isAlreadyFav: false,
                      currentFavcat: '',
                      evalNotifier: evalNotifier,
                      onApplyRule: (_) {},
                      quickActions: <GalleryContextQuickAction>[
                        GalleryContextQuickAction(
                          label: '收藏夹',
                          icon: CupertinoIcons.heart,
                          onPressed: () {},
                        ),
                      ],
                      entries: <GalleryContextMenuEntry>[
                        GalleryContextMenuEntry(
                          label: '选择收藏夹',
                          icon: CupertinoIcons.folder,
                          showChevron: true,
                          onPressed: () => chooseTapped = true,
                        ),
                      ],
                    );
                  },
                  child: RepaintBoundary(
                    child: Container(
                      color: const Color(0xFF202126),
                      alignment: Alignment.center,
                      child: const Text('ShortCard'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ShortCard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(kGalleryContextMenuLiftedCardKey), findsNothing);
    final shortMenuRect =
        tester.getRect(find.byKey(kGalleryContextMenuSurfaceKey));
    expect(shortMenuRect.top, greaterThanOrEqualTo(24.0));
    expect(shortMenuRect.bottom, lessThanOrEqualTo(186.0));
    expect(shortMenuRect.left, greaterThanOrEqualTo(28.0));
    expect(shortMenuRect.right, lessThanOrEqualTo(392.0));
  });

  testWidgets(
      'Rule-miss +tag chip carries clicked tag into FavRuleEditPage across nested detailNavigatorId',
      (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    Get.put<FavRuleService>(service);
    final favCtrl = Get.put<FavController>(FavController());

    // Mount adaptive navigation so `usesAdaptiveNavigation == true` and
    // `detailNavigatorId` resolves to nested navigator id 2 (the exact path
    // where global `Get.arguments` stays null!).
    final layoutServices = Get.put<LayoutServices>(_TestLayoutServices());
    final tabStack = layoutServices.tabNavigation.select('home');
    MainNavigatorObserver().history.clear();
    addTearDown(() {
      layoutServices.tabNavigation.dispose();
      MainNavigatorObserver().history.clear();
    });

    await tester.pumpWidget(
      GetCupertinoApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        navigatorObservers: <NavigatorObserver>[MainNavigatorObserver()],
        initialRoute: EHRoutes.home,
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: EHRoutes.home,
            page: () => CupertinoPageScaffold(
              child: Navigator(
                key: Get.nestedKey(tabStack.detailId),
                observers: <NavigatorObserver>[
                  SecondNavigatorObserver.forId(tabStack.detailId),
                ],
                onGenerateRoute: (settings) {
                  if (settings.name == Navigator.defaultRouteName) {
                    return CupertinoPageRoute<void>(
                      settings: settings,
                      builder: (innerCtx) => Center(
                        child: CupertinoButton(
                          onPressed: () {
                            favCtrl.showFavListDialog(
                              innerCtx,
                              const <Favcat>[
                                Favcat(favId: '0', favTitle: '收藏夹 0', totNum: 5),
                                Favcat(favId: '2', favTitle: '插画精选', totNum: 19),
                              ],
                              ruleMissContext: const FavRuleMissContext(
                                galleryTitle: 'Touhou Illustration Book',
                                keyTags: <NormalizedTag>[
                                  NormalizedTag(
                                    namespace: 'artist',
                                    title: 'sakuya',
                                    rawTitle: 'sakuya',
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('TriggerMissPicker'),
                        ),
                      ),
                    );
                  }
                  return AppPages.onGenerateRoute(settings);
                },
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(usesAdaptiveNavigation, isTrue);
    expect(detailNavigatorId, tabStack.detailId);

    // 1) Open rule-miss picker and tap neutral `画师 sakuya` chip (no `+` or `:`)
    await tester.tap(find.text('TriggerMissPicker'));
    await tester.pumpAndSettle();
    expect(find.text('画师'), findsOneWidget);
    expect(find.text('sakuya'), findsOneWidget);
    expect(find.textContaining('artist:sakuya'), findsNothing);

    await tester.tap(find.text('sakuya'));
    await tester.pumpAndSettle();

    // 2) Verify FavRuleEditPage opened on nested detail navigator WITH the tag,
    //    and new-rule `_favcat` starts empty (`✓` disabled until a folder is chosen)!
    expect(find.byType(FavRuleEditPage), findsOneWidget);
    expect(find.text('画师'), findsOneWidget);
    expect(find.text('sakuya'), findsOneWidget);
    expect(find.text('收进'), findsOneWidget);
    expect(find.text('选一个收藏夹'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.checkmark_alt));
    await tester.pump();
    expect(service.rules, isEmpty);

    // Select a folder to enable `✓`, then save and verify persistence
    await tester.tap(find.text('Favorites 2'));
    await tester.pump();
    expect(find.text('选一个收藏夹'), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.checkmark_alt));
    await tester.pumpAndSettle();

    expect(service.rules.length, 1);
    expect(service.rules.single.favcat, '2');
    expect(service.rules.single.conditions.length, 1);
    expect(service.rules.single.conditions.single.namespace, 'artist');
    expect(service.rules.single.conditions.single.value, 'sakuya');

    // 3) Re-open rule-miss picker and tap blank `新建规则` -> must open empty!
    await tester.tap(find.text('TriggerMissPicker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建规则'));
    await tester.pumpAndSettle();

    expect(find.byType(FavRuleEditPage), findsOneWidget);
    expect(find.text('sakuya'), findsNothing);
  });

  testWidgets(
      'Dynamic Island capsule unfurl, hold-tension haptics, and rubber-band card drag-to-dismiss work smoothly',
      (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
    final setting = Get.find<EhSettingService>() as _TestSettings;
    setting.vibrate.value = true;

    final hapticCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('eros/haptics'),
      (call) async {
        hapticCalls.add(call.method);
        return null;
      },
    );
    addTearDown(() {
      PlatformCapabilities.debugHostPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('eros/haptics'), null);
    });

    final evalNotifier =
        RuleMenuEvalController(const RuleMenuEvalSnapshot.idle());
    addTearDown(evalNotifier.dispose);

    const provider = GalleryProvider(
      gid: '3099',
      token: 'di_spring',
      englishTitle: 'Dynamic Island Spring Card',
      category: 'Illust',
    );

    await tester.pumpWidget(
      _wrapApp(
        CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 150,
              height: 210,
              child: GalleryCardPressFeedback(
                onTap: () {},
                onLongPress: (cardCtx) {
                  showGalleryCardContextMenu(
                    cardContext: cardCtx,
                    provider: provider,
                    isAlreadyFav: false,
                    currentFavcat: '',
                    evalNotifier: evalNotifier,
                    onApplyRule: (_) {},
                    quickActions: <GalleryContextQuickAction>[
                      GalleryContextQuickAction(
                        label: '收藏夹',
                        icon: CupertinoIcons.heart,
                        onPressed: () {},
                      ),
                    ],
                    entries: <GalleryContextMenuEntry>[
                      GalleryContextMenuEntry(
                        label: '选择收藏夹',
                        icon: CupertinoIcons.folder,
                        onPressed: () {},
                      ),
                      GalleryContextMenuEntry(
                        label: '复制链接',
                        icon: CupertinoIcons.link,
                        onPressed: () {},
                      ),
                    ],
                  );
                },
                child: RepaintBoundary(
                  child: Container(
                    color: const Color(0xFF202126),
                    alignment: Alignment.center,
                    child: const Text('DynamicIslandCard'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // 1) Hold finger down -> kPressTimeout (100ms) + 135ms AnimatedScale
    //    compresses card to 0.97 and fires preview tension tick
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('DynamicIslandCard')));
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(hapticCalls, contains('prepare'));
    expect(hapticCalls, contains('contextMenuPreviewTick'));

    // 2) Advance past kLongPressTimeout (500ms total) to trigger Dynamic Island pop!
    await tester.pump(const Duration(milliseconds: 260));
    await gesture.up();
    await tester.pump();
    expect(hapticCalls, contains('contextMenuPop'));

    // Mid-flight at t ~ 55ms: horizontal capsule factor leads vertical unfurl
    await tester.pump(const Duration(milliseconds: 55));
    final midMenuRect =
        tester.getRect(find.byKey(kGalleryContextMenuSurfaceKey));
    expect(midMenuRect.width / 252.0, greaterThan(midMenuRect.height / 155.0));

    // Settle completely -> resting geometry is exact and clean
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final settledMenuRect =
        tester.getRect(find.byKey(kGalleryContextMenuSurfaceKey));
    expect(settledMenuRect.width, closeTo(252.0, 0.5));

    // 3) Rubber-band drag the lifted card past threshold (64pt down) -> dismisses with settle haptic!
    await tester.drag(
      find.byKey(kGalleryContextMenuLiftedCardKey),
      const Offset(0, 64),
    );
    await tester.pumpAndSettle();

    expect(hapticCalls, contains('contextMenuDismiss'));
    expect(find.byKey(kGalleryContextMenuSurfaceKey), findsNothing);
  });

  testWidgets(
      'Delayed async image capture preserves pre-await 0.97 press scale even after card resets or unmounts',
      (tester) async {
    final evalNotifier =
        RuleMenuEvalController(const RuleMenuEvalSnapshot.idle());
    addTearDown(evalNotifier.dispose);

    const provider = GalleryProvider(
      gid: '4101',
      token: 'async_cap',
      englishTitle: 'Async Capture Card',
      category: 'Manga',
    );

    final showSourceCard = ValueNotifier<bool>(true);
    addTearDown(showSourceCard.dispose);
    final captureCompleter = Completer<void>();

    await tester.pumpWidget(
      _wrapApp(
        CupertinoPageScaffold(
          child: ValueListenableBuilder<bool>(
            valueListenable: showSourceCard,
            builder: (context, visible, _) {
              if (!visible) {
                return const SizedBox.shrink();
              }
              return Center(
                child: SizedBox(
                  width: 150,
                  height: 210,
                  child: GalleryCardPressFeedback(
                    onTap: () {},
                    onLongPress: (cardCtx) {
                      showGalleryCardContextMenu(
                        cardContext: cardCtx,
                        provider: provider,
                        isAlreadyFav: false,
                        currentFavcat: '',
                        evalNotifier: evalNotifier,
                        onApplyRule: (_) {},
                        debugCaptureImage: () async {
                          await captureCompleter.future;
                          return null;
                        },
                        entries: <GalleryContextMenuEntry>[
                          GalleryContextMenuEntry(
                            label: '选择收藏夹',
                            icon: CupertinoIcons.folder,
                            onPressed: () {},
                          ),
                        ],
                      );
                    },
                    child: RepaintBoundary(
                      child: Container(
                        color: const Color(0xFF202126),
                        alignment: Alignment.center,
                        child: const Text('AsyncCaptureCard'),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Hold past 500ms so press scale is 0.97 and onLongPress fires
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('AsyncCaptureCard')),
    );
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 410));
    await gesture.up();

    // Pump extra frames while `debugCaptureImage` is still awaiting AND unmount
    // the source card completely to prove `cardContext` is never touched post-await!
    await tester.pump(const Duration(milliseconds: 50));
    showSourceCard.value = false;
    await tester.pump(const Duration(milliseconds: 50));

    // Complete async capture -> Frame 0 of the overlay mounts
    captureCompleter.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);

    // At u == 0.0 (mount frame), lifted card starts from compressed 0.97x width!
    final initialLiftedRect = tester.getRect(
      find.byKey(kGalleryContextMenuLiftedCardKey),
    );
    expect(initialLiftedRect.width, closeTo(150.0 * 0.97, 1.0));

    // Settle -> springs cleanly to 1.035x width
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final settledLiftedRect = tester.getRect(
      find.byKey(kGalleryContextMenuLiftedCardKey),
    );
    expect(settledLiftedRect.width, closeTo(150.0 * 1.035, 1.0));
  });

  testWidgets(
      'showGalleryCardContextMenu constrains lifted card and menu to anchor pane around Duo division regions',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 760);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const duoSafe = EdgeInsets.fromLTRB(16, 24, 68, 24);
    final envService = Get.put<AdaptiveEnvironmentService>(
      AdaptiveEnvironmentService(),
    );
    // Book-folded Duo: 24pt vertical hinge at [368, 392] + 68pt right vertical bar
    envService.acceptNativeSnapshot(<Object?, Object?>{
      'width': 760.0,
      'height': 760.0,
      'safeLeft': 16.0,
      'safeTop': 24.0,
      'safeRight': 68.0,
      'safeBottom': 24.0,
      'systemBarEdge': 'right',
      'duoVerticalBar': true,
      'layoutVersion': 1,
      'nativeSupported': true,
      'reservedRegions': <Map<String, Object>>[
        <String, Object>{
          'x': 368.0,
          'y': 0.0,
          'width': 24.0,
          'height': 760.0,
          'kind': 'division',
          'active': true,
        },
      ],
    });

    final evalNotifier =
        RuleMenuEvalController(const RuleMenuEvalSnapshot.idle());
    addTearDown(evalNotifier.dispose);

    const provider = GalleryProvider(
      gid: '4202',
      token: 'duo_hinge',
      englishTitle: 'Duo Hinge Boundary Card',
      category: 'Non-H',
    );

    await tester.pumpWidget(
      _wrapApp(
        safePadding: duoSafe,
        CupertinoPageScaffold(
          child: Stack(
            children: <Widget>[
              // Card in left pane right next to the 368pt hinge (right edge = 356)
              Positioned(
                left: 208,
                top: 120,
                width: 148,
                height: 220,
                child: Builder(
                  builder: (leftPaneCtx) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showGalleryCardContextMenu(
                        cardContext: leftPaneCtx,
                        provider: provider,
                        isAlreadyFav: false,
                        currentFavcat: '',
                        evalNotifier: evalNotifier,
                        onApplyRule: (_) {},
                        entries: <GalleryContextMenuEntry>[
                          GalleryContextMenuEntry(
                            label: '选择收藏夹',
                            icon: CupertinoIcons.folder,
                            onPressed: () {},
                          ),
                          GalleryContextMenuEntry(
                            label: '复制链接',
                            icon: CupertinoIcons.link,
                            onPressed: () {},
                          ),
                        ],
                      );
                    },
                    child: RepaintBoundary(
                      child: Container(
                        color: const Color(0xFF202126),
                        alignment: Alignment.center,
                        child: const Text('LeftHingeCard'),
                      ),
                    ),
                  ),
                ),
              ),
              // Card in right pane right next to the 392pt hinge (left edge = 404)
              Positioned(
                left: 404,
                top: 120,
                width: 148,
                height: 220,
                child: Builder(
                  builder: (rightPaneCtx) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showGalleryCardContextMenu(
                        cardContext: rightPaneCtx,
                        provider: provider,
                        isAlreadyFav: false,
                        currentFavcat: '',
                        evalNotifier: evalNotifier,
                        onApplyRule: (_) {},
                        entries: <GalleryContextMenuEntry>[
                          GalleryContextMenuEntry(
                            label: '选择收藏夹',
                            icon: CupertinoIcons.folder,
                            onPressed: () {},
                          ),
                        ],
                      );
                    },
                    child: RepaintBoundary(
                      child: Container(
                        color: const Color(0xFF202126),
                        alignment: Alignment.center,
                        child: const Text('RightHingeCard'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 1) Left-pane card near hinge -> neither lifted card nor 252pt menu crosses x=368!
    await tester.tap(find.text('LeftHingeCard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final leftLifted =
        tester.getRect(find.byKey(kGalleryContextMenuLiftedCardKey));
    final leftMenu = tester.getRect(find.byKey(kGalleryContextMenuSurfaceKey));
    expect(leftLifted.right, lessThanOrEqualTo(356.0));
    expect(leftMenu.right, lessThanOrEqualTo(356.0));
    expect(leftMenu.left, greaterThanOrEqualTo(28.0));

    Navigator.of(tester.element(find.byKey(kGalleryContextMenuSurfaceKey))).pop();
    await tester.pumpAndSettle();

    // 2) Right-pane card near hinge -> stays strictly inside [404, 680] (clears hinge & right bar!)
    await tester.tap(find.text('RightHingeCard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final rightLifted =
        tester.getRect(find.byKey(kGalleryContextMenuLiftedCardKey));
    final rightMenu = tester.getRect(find.byKey(kGalleryContextMenuSurfaceKey));
    expect(rightLifted.left, greaterThanOrEqualTo(404.0));
    expect(rightMenu.left, greaterThanOrEqualTo(404.0));
    expect(rightMenu.right, lessThanOrEqualTo(680.0));

    Navigator.of(tester.element(find.byKey(kGalleryContextMenuSurfaceKey))).pop();
    await tester.pumpAndSettle();

    // 3) Horizontal tabletop fold at y=[220, 244] -> upper pane height < 240 triggers compact fallback inside upper pane!
    envService.acceptNativeSnapshot(<Object?, Object?>{
      'width': 760.0,
      'height': 760.0,
      'safeLeft': 16.0,
      'safeTop': 24.0,
      'safeRight': 68.0,
      'safeBottom': 24.0,
      'layoutVersion': 2,
      'nativeSupported': true,
      'reservedRegions': <Map<String, Object>>[
        <String, Object>{
          'x': 0.0,
          'y': 220.0,
          'width': 760.0,
          'height': 24.0,
          'kind': 'division',
          'active': true,
        },
      ],
    });
    await tester.pump();

    await tester.tap(find.text('LeftHingeCard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byKey(kGalleryContextMenuLiftedCardKey), findsNothing);
    final tabletopMenu =
        tester.getRect(find.byKey(kGalleryContextMenuSurfaceKey));
    expect(tabletopMenu.bottom, lessThanOrEqualTo(208.0));
  });

  testWidgets(
      'Automatic rule/fallback moves abort when loadFavoriteNote fails instead of erasing existing note',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (_) async => true,
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      );
    });

    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    await service.setEnabled(true);
    await service.setExisting(FavRuleExisting.move);
    await service.setFallback(FavRuleFallback.fixed);
    await service.setFallbackFavcat('4');
    await service.addRule(
      const FavRule(
        id: 'r_move',
        name: '移动画师',
        favcat: '3',
        conditions: <FavRuleCondition>[
          FavRuleCondition(namespace: 'artist', value: 'sakuya'),
        ],
      ),
    );
    Get.put<FavRuleService>(service);
    Get.put<UserController>(_LoggedInUserController());
    final fakeFav = _RecordingFavController()
      ..storedNote = 'precious note'
      ..throwOnNoteRead = true;
    Get.put<FavController>(fakeFav);

    final matchedCtrl = GalleryItemController(
      galleryProvider: const GalleryProvider(
        gid: '5001',
        token: 'tok5001',
        favcat: '1',
        favTitle: '收藏夹 1',
        englishTitle: 'Already Favorited Hit',
        tagsFromApi: <dynamic>['artist:sakuya'],
      ),
    );
    final fallbackCtrl = GalleryItemController(
      galleryProvider: const GalleryProvider(
        gid: '5002',
        token: 'tok5002',
        favcat: '1',
        favTitle: '收藏夹 1',
        englishTitle: 'Already Favorited Miss',
        tagsFromApi: <dynamic>['artist:other'],
      ),
    );

    await tester.pumpWidget(
      _wrapApp(
        CupertinoPageScaffold(
          child: Column(
            children: <Widget>[
              CupertinoButton(
                onPressed: () => matchedCtrl.applyRuleOrFallback(
                  service.evaluateGallerySync(matchedCtrl.galleryProvider),
                ),
                child: const Text('TryMoveHit'),
              ),
              CupertinoButton(
                onPressed: () =>
                    fallbackCtrl.applyRuleOrFallback(FavRuleEvalResult.miss),
                child: const Text('TryMoveFallback'),
              ),
            ],
          ),
        ),
      ),
    );

    // 1) When loadFavoriteNote throws, neither rule hit nor fallback calls saveToFavcat!
    await tester.tap(find.text('TryMoveHit'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(fakeFav.savedFavcats, isEmpty);
    expect(matchedCtrl.favCat, '1');

    await tester.tap(find.text('TryMoveFallback'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(fakeFav.savedFavcats, isEmpty);
    expect(fallbackCtrl.favCat, '1');

    // 2) Once loadFavoriteNote succeeds, existing note is preserved across move!
    fakeFav.throwOnNoteRead = false;
    await tester.tap(find.text('TryMoveHit'));
    await tester.pumpAndSettle();
    expect(fakeFav.savedFavcats, <String>['3']);
    expect(fakeFav.savedNotes, <String>['precious note']);
    dismissAllToast(showAnim: false);
    dismissFavRuleFeedbackBanner();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'showFavRuleFeedbackBanner stays inside a single Duo pane and never straddles active division regions',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(760, 760);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final envService = Get.put<AdaptiveEnvironmentService>(
      AdaptiveEnvironmentService(),
    );
    envService.acceptNativeSnapshot(<Object?, Object?>{
      'width': 760.0,
      'height': 760.0,
      'safeLeft': 16.0,
      'safeTop': 24.0,
      'safeRight': 68.0,
      'safeBottom': 24.0,
      'systemBarEdge': 'right',
      'duoVerticalBar': true,
      'layoutVersion': 1,
      'nativeSupported': true,
      'reservedRegions': <Map<String, Object>>[
        <String, Object>{
          'x': 368.0,
          'y': 0.0,
          'width': 24.0,
          'height': 760.0,
          'kind': 'division',
          'active': true,
        },
      ],
    });

    await tester.pumpWidget(
      _wrapApp(
        safePadding: const EdgeInsets.fromLTRB(16, 24, 68, 24),
        CupertinoPageScaffold(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                bottom: 0,
                child: Builder(
                  builder: (rootCtx) => CupertinoButton(
                    onPressed: () {
                      showFavRuleFeedbackBanner(
                        context: rootCtx,
                        favcat: '1',
                        title: '已收进「收藏夹 1」',
                        subtitle: '规则「画师」',
                      );
                    },
                    child: const Text('ShowRootBanner'),
                  ),
                ),
              ),
              Positioned(
                left: 392,
                top: 0,
                width: 300,
                height: 760,
                child: Builder(
                  builder: (rightPaneCtx) => CupertinoButton(
                    onPressed: () {
                      showFavRuleFeedbackBanner(
                        context: rightPaneCtx,
                        favcat: '2',
                        title: '右栏已收进「收藏夹 2」',
                      );
                    },
                    child: const Text('ShowRightPaneBanner'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 1) Root-overlay banner picks largest single pane (left: [16, 368]) -> right <= 356
    await tester.tap(find.text('ShowRootBanner'));
    await tester.pumpAndSettle();
    final rootBannerRect = tester.getRect(find.byType(LiquidGlassPopupSurface));
    expect(rootBannerRect.left, greaterThanOrEqualTo(28.0));
    expect(rootBannerRect.right, lessThanOrEqualTo(356.0));
    dismissFavRuleFeedbackBanner();
    await tester.pumpAndSettle();

    // 2) Right-pane caller stays strictly inside right pane [404, 680]
    await tester.tap(find.text('ShowRightPaneBanner'));
    await tester.pumpAndSettle();
    final rightBannerRect =
        tester.getRect(find.byType(LiquidGlassPopupSurface));
    expect(rightBannerRect.left, greaterThanOrEqualTo(404.0));
    expect(rightBannerRect.right, lessThanOrEqualTo(680.0));
    dismissFavRuleFeedbackBanner();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'FavRuleConditionSheet discards stale out-of-order async preview queries',
      (tester) async {
    final slowFirstQuery = Completer<(List<TagTranslat>, int)>();
    final fastSecondQuery = Completer<(List<TagTranslat>, int)>();

    await tester.pumpWidget(
      _wrapApp(
        Builder(
          builder: (ctx) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () {
                  showFavRuleConditionSheet(
                    ctx,
                    debugCountOverride: () async => 100,
                    debugQueryOverride: ({
                      required String value,
                      String? namespace,
                      required String opName,
                      required bool matchTranslation,
                      required int limit,
                    }) {
                      if (value == 'old') {
                        return slowFirstQuery.future;
                      }
                      return fastSecondQuery.future;
                    },
                  );
                },
                child: const Text('OpenPreviewSheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OpenPreviewSheet'));
    await tester.pumpAndSettle();

    // Type 'old' and let its 180ms debounce dispatch query #1
    await tester.enterText(find.byType(CupertinoTextField), 'old');
    await tester.pump(const Duration(milliseconds: 200));

    // Type 'new' and let its 180ms debounce dispatch query #2
    await tester.enterText(find.byType(CupertinoTextField), 'new');
    await tester.pump(const Duration(milliseconds: 200));

    // Complete query #2 FIRST ('new_artist')
    fastSecondQuery.complete((
      <TagTranslat>[
        TagTranslat(
          namespace: 'artist',
          key: 'new_artist',
          name: '新画师',
        ),
      ],
      1,
    ));
    await tester.pump();
    expect(find.textContaining('new_artist'), findsOneWidget);

    // Complete stale query #1 LATER ('stale_old_artist') -> MUST be ignored!
    slowFirstQuery.complete((
      <TagTranslat>[
        TagTranslat(
          namespace: 'artist',
          key: 'stale_old_artist',
          name: '旧画师',
        ),
      ],
      99,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('new_artist'), findsOneWidget);
    expect(find.textContaining('stale_old_artist'), findsNothing);
  });

  test(
      'favRuleOnCategoryColor picks WCAG dark #1A1406 on bright swatches and #FFFFFF on dark swatches',
      () {
    // Bright category swatches -> #1A1406
    expect(
      favRuleOnCategoryColor(const Color(0xFFFBC02D)), // Artist CG light
      const Color(0xFF1A1406),
    );
    expect(
      favRuleOnCategoryColor(const Color(0xFF2196F3)), // Non-H light
      const Color(0xFF1A1406),
    );
    expect(
      favRuleOnCategoryColor(
        const Color.fromARGB(255, 112, 168, 203), // Non-H dark
      ),
      const Color(0xFF1A1406),
    );

    // Dark category swatches -> #FFFFFF
    expect(
      favRuleOnCategoryColor(const Color(0xFF3F51B5)), // Image Set light
      const Color(0xFFFFFFFF),
    );
    expect(
      favRuleOnCategoryColor(const Color(0xFF9C27B0)), // Cosplay light
      const Color(0xFFFFFFFF),
    );
  });

  testWidgets(
      'Panel ④ condition sheet supports 画廊分类 multi-select (Non-H + Image Set), '
      '不是 pull-down exclusion, shrink-wrap height, 删除条件, and Duo unfolded/folded safe areas in light & dark modes',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1104, 820);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final envService = Get.put<AdaptiveEnvironmentService>(
      AdaptiveEnvironmentService(),
    );
    // 1) Light mode on iPhone Duo unfolded (1104×820, hinge x=540..564, right bar 68pt)
    envService.acceptNativeSnapshot(<Object?, Object?>{
      'width': 1104.0,
      'height': 820.0,
      'safeLeft': 16.0,
      'safeTop': 24.0,
      'safeRight': 68.0,
      'safeBottom': 24.0,
      'systemBarEdge': 'right',
      'duoVerticalBar': true,
      'layoutVersion': 1,
      'nativeSupported': true,
      'reservedRegions': <Map<String, Object>>[
        <String, Object>{
          'x': 540.0,
          'y': 0.0,
          'width': 24.0,
          'height': 820.0,
          'kind': 'division',
          'active': true,
        },
      ],
    });

    FavRuleCondition? created;
    await tester.pumpWidget(
      _wrapApp(
        brightness: Brightness.light,
        safePadding: const EdgeInsets.fromLTRB(16, 24, 68, 24),
        Builder(
          builder: (ctx) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () async {
                  created = await showFavRuleConditionSheet(
                    ctx,
                    debugCountOverride: () async => 0,
                  );
                },
                child: const Text('OpenPanel4Unfolded'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OpenPanel4Unfolded'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 'category' must never appear in tag namespace chips
    expect(
      find.byKey(const ValueKey<String>('fav_rule_ns_chip_category')),
      findsNothing,
    );

    final tagModeRect = tester.getRect(find.byType(LiquidGlassPopupSurface));
    // Stays strictly inside Duo unfolded left pane [24, 532] without crossing x=540..564 hinge
    expect(tagModeRect.left, greaterThanOrEqualTo(24.0 - 0.5));
    expect(tagModeRect.right, lessThanOrEqualTo(532.0 + 0.5));
    // Shrink-wraps well below the 0.88 * 820 = 721.6pt ceiling
    expect(tagModeRect.height, lessThan(700.0));

    // Switch top segmented control to `画廊分类`
    await tester.tap(find.text('画廊分类'));
    await tester.pumpAndSettle();

    expect(find.text('在下方选择分类'), findsOneWidget);
    expect(find.text('至少选择一个分类'), findsOneWidget);
    expect(find.text('是 ▾'), findsOneWidget);

    // Save button is disabled with 0 selected categories
    await tester.tap(find.byKey(kFavRuleConditionSheetSaveKey));
    await tester.pump();
    expect(created, isNull);

    // Select `Non-H` + `Image Set` -> operator becomes `是其中之一 ▾`
    await tester.tap(
      find.byKey(const ValueKey<String>('fav_rule_cat_tile_Non-H')),
    );
    await tester.pumpAndSettle();
    expect(find.text('属于该分类就算匹配'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('fav_rule_cat_tile_Image Set')),
    );
    await tester.pumpAndSettle();
    expect(find.text('是其中之一 ▾'), findsOneWidget);
    expect(find.text('属于任一所选分类就算匹配'), findsOneWidget);
    expect(find.text('清除'), findsOneWidget);

    final catModeRect = tester.getRect(find.byType(LiquidGlassPopupSurface));
    expect(catModeRect.left, greaterThanOrEqualTo(24.0 - 0.5));
    expect(catModeRect.right, lessThanOrEqualTo(532.0 + 0.5));
    expect(catModeRect.height, lessThan(700.0));

    // Toggle `不是` via pull-down menu (which also stays strictly inside left pane!)
    await tester.tap(find.byKey(kFavRuleConditionSheetOperatorKey));
    await tester.pumpAndSettle();
    final pullDownRect =
        tester.getRect(find.byType(LiquidGlassPopupSurface).last);
    expect(pullDownRect.left, greaterThanOrEqualTo(24.0 - 0.5));
    expect(pullDownRect.right, lessThanOrEqualTo(530.0 + 0.5));

    await tester.tap(find.text('不是'));
    await tester.pumpAndSettle();
    expect(find.text('不是 ▾'), findsOneWidget);
    expect(find.text('属于所选分类的画廊不会匹配这条规则'), findsOneWidget);

    // Confirm save
    await tester.tap(find.byKey(kFavRuleConditionSheetSaveKey));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.isCategory, isTrue);
    expect(created!.categoryValues, <String>['Non-H', 'Image Set']);
    expect(created!.negated, isTrue);

    // 2) Dark mode on folded Duo (440×820, side safe area 44/68) + `onDelete` (`删除条件`)
    tester.view.physicalSize = const Size(440, 820);
    envService.acceptNativeSnapshot(<Object?, Object?>{
      'width': 440.0,
      'height': 820.0,
      'safeLeft': 44.0,
      'safeTop': 24.0,
      'safeRight': 68.0,
      'safeBottom': 24.0,
      'systemBarEdge': 'right',
      'duoVerticalBar': true,
      'layoutVersion': 2,
      'nativeSupported': true,
    });

    var deleted = false;
    FavRuleCondition? editedResult = FavRuleCondition.category(
      const <String>['Non-H'],
    );
    await tester.pumpWidget(
      _wrapApp(
        brightness: Brightness.dark,
        safePadding: const EdgeInsets.fromLTRB(44, 24, 68, 24),
        Builder(
          builder: (ctx) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () async {
                  editedResult = await showFavRuleConditionSheet(
                    ctx,
                    initial: FavRuleCondition.category(const <String>['Non-H']),
                    onDelete: () => deleted = true,
                    debugCountOverride: () async => 0,
                  );
                },
                child: const Text('OpenPanel4FoldedDark'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OpenPanel4FoldedDark'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final foldedSheetRect =
        tester.getRect(find.byType(LiquidGlassPopupSurface));
    expect(foldedSheetRect.left, greaterThanOrEqualTo(52.0 - 0.5));
    expect(foldedSheetRect.right, lessThanOrEqualTo(364.0 + 0.5));
    expect(find.byKey(kFavRuleConditionSheetDeleteKey), findsOneWidget);
    expect(find.text('删除条件'), findsOneWidget);

    await tester.ensureVisible(find.byKey(kFavRuleConditionSheetDeleteKey));
    await tester.tap(find.byKey(kFavRuleConditionSheetDeleteKey));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(editedResult, isNull);
  });

  testWidgets(
      'FavRuleEditPage disables save until folder is picked, renders 且/或 joiner & FavCategoryBadge, '
      'and FavRuleSettingPage renders compact category badge and 收进 destination',
      (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    Get.put<FavRuleService>(service);

    await tester.pumpWidget(
      _wrapApp(
        CupertinoPageScaffold(
          child: Builder(
            builder: (ctx) => Center(
              child: CupertinoButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    CupertinoPageRoute<bool>(
                      builder: (_) => FavRuleEditPage(
                        args: FavRuleEditArgs(
                          initialConditions: <FavRuleCondition>[
                            FavRuleCondition.category(const <String>['Non-H']),
                            const FavRuleCondition(
                              namespace: 'parody',
                              op: FavRuleOp.equals,
                              value: 'blue archive',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('OpenNewCategoryRule'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OpenNewCategoryRule'));
    await tester.pumpAndSettle();

    // New rule starts with empty `_favcat`: `选一个收藏夹` shown & `✓` button disabled!
    expect(find.text('新建规则 · 名字可留空'), findsOneWidget);
    expect(find.text('收进'), findsOneWidget);
    expect(find.text('选一个收藏夹'), findsOneWidget);
    expect(find.byType(FavCategoryBadge), findsOneWidget);
    expect(find.text('或'), findsOneWidget);
    expect(find.text('任一 ▾'), findsOneWidget);

    final disabledSaveBtn = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.byIcon(CupertinoIcons.checkmark_alt),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(disabledSaveBtn.onPressed, isNull);

    // Switch `任一 ▾` -> `全部` via pull-down and verify joiner badge updates `或` -> `且`!
    await tester.tap(find.text('任一 ▾'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('全部 ▾'), findsOneWidget);
    expect(find.text('且'), findsOneWidget);

    // Select folder `Favorites 0` -> enables `✓` and saves!
    await tester.ensureVisible(find.text('Favorites 0'));
    await tester.tap(find.text('Favorites 0'));
    await tester.pump();
    expect(find.text('选一个收藏夹'), findsNothing);

    final enabledSaveBtn = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.byIcon(CupertinoIcons.checkmark_alt),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(enabledSaveBtn.onPressed, isNotNull);

    await tester.tap(find.byIcon(CupertinoIcons.checkmark_alt));
    await tester.pumpAndSettle();

    expect(service.rules, hasLength(1));
    expect(service.rules.single.favcat, '0');
    expect(service.rules.single.match, FavRuleMatch.all);
    expect(service.rules.single.conditions.first.categoryValues, <String>['Non-H']);

    // Verify FavRuleSettingPage renders FavCategoryBadge.compact, `且`, and `收进「Favorites 0」`!
    await tester.pumpWidget(_wrapApp(const FavRuleSettingPage()));
    await tester.pumpAndSettle();

    expect(find.byType(FavCategoryBadge), findsOneWidget);
    expect(find.text('原作 blue archive'), findsOneWidget);
    expect(find.text('且'), findsOneWidget);
    expect(find.textContaining('收进「Favorites 0」'), findsOneWidget);
  });

  testWidgets(
      'Panel ① showGalleryCardContextMenu renders bottom 按「Non-H」新建规则 on miss '
      'and FavCategoryBadge.mini without trailing chevron on category hit',
      (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    await service.addRule(
      FavRule(
        id: 'r_nonh_hit',
        name: '全年龄归档',
        favcat: '0',
        conditions: <FavRuleCondition>[
          FavRuleCondition.category(const <String>['Non-H']),
        ],
      ),
    );
    Get.put<FavRuleService>(service);

    const nonHProvider = GalleryProvider(
      gid: '6101',
      token: 'tok6101',
      englishTitle: 'Sunny Horizon Sketchbook',
      category: 'Non-H',
    );
    final missNotifier = ValueNotifier<RuleMenuEvalSnapshot>(
      const RuleMenuEvalSnapshot.miss(),
    );
    final hitNotifier = createRuleEvalNotifier(nonHProvider);
    addTearDown(() {
      missNotifier.dispose();
      hitNotifier.dispose();
    });

    var createRuleCalls = 0;
    FavRuleEvalResult? appliedEval;

    await tester.pumpWidget(
      _wrapApp(
        CupertinoPageScaffold(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Builder(
                builder: (missCtx) => CupertinoButton(
                  onPressed: () {
                    showGalleryCardContextMenu(
                      cardContext: missCtx,
                      provider: nonHProvider,
                      isAlreadyFav: false,
                      currentFavcat: '',
                      evalNotifier: missNotifier,
                      onApplyRule: (e) => appliedEval = e,
                      onCreateRuleFromGallery: () => createRuleCalls++,
                      entries: <GalleryContextMenuEntry>[
                        GalleryContextMenuEntry(
                          label: '选择收藏夹',
                          icon: CupertinoIcons.folder,
                          onPressed: () {},
                        ),
                      ],
                    );
                  },
                  child: const Text('OpenMenuOnMiss'),
                ),
              ),
              Builder(
                builder: (hitCtx) => CupertinoButton(
                  onPressed: () {
                    showGalleryCardContextMenu(
                      cardContext: hitCtx,
                      provider: nonHProvider,
                      isAlreadyFav: false,
                      currentFavcat: '',
                      evalNotifier: hitNotifier,
                      onApplyRule: (e) => appliedEval = e,
                      onCreateRuleFromGallery: () => createRuleCalls++,
                      entries: <GalleryContextMenuEntry>[
                        GalleryContextMenuEntry(
                          label: '选择收藏夹',
                          icon: CupertinoIcons.folder,
                          onPressed: () {},
                        ),
                      ],
                    );
                  },
                  child: const Text('OpenMenuOnCategoryHit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 1) On miss with Non-H: top banner is hidden; bottom `按「Non-H」新建规则` entry
    //    renders with FavCategorySwatchSquare!
    await tester.tap(find.text('OpenMenuOnMiss'));
    await tester.pumpAndSettle();

    expect(find.byKey(kGalleryContextMenuRuleBannerKey), findsNothing);
    expect(find.byKey(kGalleryContextMenuCreateRuleRowKey), findsOneWidget);
    expect(find.text('按「Non-H」新建规则'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(kGalleryContextMenuCreateRuleRowKey),
        matching: find.byType(FavCategorySwatchSquare),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(kGalleryContextMenuCreateRuleRowKey));
    await tester.pumpAndSettle();
    expect(createRuleCalls, 1);

    // 2) On category hit with Non-H: bottom create-rule row is hidden; top banner
    //    renders FavCategoryBadge.mini WITHOUT any trailing chevron!
    await tester.tap(find.text('OpenMenuOnCategoryHit'));
    await tester.pumpAndSettle();

    expect(find.byKey(kGalleryContextMenuCreateRuleRowKey), findsNothing);
    expect(find.byKey(kGalleryContextMenuRuleBannerKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(kGalleryContextMenuRuleBannerKey),
        matching: find.byType(FavCategoryBadge),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(kGalleryContextMenuRuleBannerKey),
        matching: find.byIcon(CupertinoIcons.chevron_forward),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(kGalleryContextMenuRuleBannerKey));
    await tester.pumpAndSettle();
    expect(appliedEval?.primary?.rule.id, 'r_nonh_hit');
  });

  testWidgets(
      'Panel ② FavController.showFavListDialog orders folder grid above note field '
      'above bottom 没有规则命中 neutral chips with Non-H swatch first and no + or :',
      (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    Get.put<FavRuleService>(service);
    final favCtrl = Get.put<FavController>(FavController());

    const provider = GalleryProvider(
      gid: '6201',
      token: 'tok6201',
      englishTitle: 'Blue Sky Artbook',
      category: 'Non-H',
      tagGroup: <TagGroup>[
        TagGroup(
          tagType: 'artist',
          galleryTags: <GalleryTag>[
            GalleryTag(title: 'mitsuki', type: 'artist', tagTranslat: '三月'),
          ],
        ),
        TagGroup(
          tagType: 'parody',
          galleryTags: <GalleryTag>[
            GalleryTag(
              title: 'blue archive',
              type: 'parody',
              tagTranslat: '蔚蓝档案',
            ),
          ],
        ),
      ],
    );
    final keyTags = service.extractSuggestionTags(provider);

    await tester.pumpWidget(
      _wrapApp(
        Builder(
          builder: (ctx) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () {
                  favCtrl.showFavListDialog(
                    ctx,
                    const <Favcat>[
                      Favcat(favId: '0', favTitle: '全年龄', totNum: 18),
                      Favcat(favId: '1', favTitle: '插画集', totNum: 42),
                    ],
                    galleryTitle: provider.englishTitle,
                    ruleMissContext: FavRuleMissContext(
                      galleryTitle: provider.englishTitle!,
                      keyTags: keyTags,
                    ),
                  );
                },
                child: const Text('OpenPanel2Picker'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OpenPanel2Picker'));
    await tester.pumpAndSettle();

    // Strict top-to-bottom order: Folder Grid -> Note Field -> 没有规则命中 strip
    final gridRect = tester.getRect(find.byType(FavFolderTwoColumnGrid));
    final noteRect = tester.getRect(find.byType(CupertinoTextField));
    final missHeaderRect = tester.getRect(find.text('没有规则命中'));
    expect(gridRect.bottom, lessThanOrEqualTo(noteRect.top));
    expect(noteRect.bottom, lessThanOrEqualTo(missHeaderRect.top));

    // Neutral chips: Non-H swatch chip first, clean namespace + tag text, zero `+` or `:`
    expect(find.byType(FavCategorySwatchSquare), findsOneWidget);
    expect(find.text('Non-H'), findsOneWidget);
    expect(find.text('原作'), findsOneWidget);
    expect(find.text('蔚蓝档案'), findsOneWidget);
    expect(find.text('画师'), findsOneWidget);
    expect(find.text('三月'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);
    expect(find.textContaining(':'), findsNothing);

    final nonHRect = tester.getRect(find.text('Non-H'));
    final parodyRect = tester.getRect(find.text('蔚蓝档案'));
    expect(nonHRect.left, lessThan(parodyRect.left));
  });

  testWidgets(
      'Panel ③ GalleryHeroCategoryButton enforces >=44x44 touch target and showCategoryInfoPopover '
      'displays Non-H header, toggles rule-usage footer (0 vs >=1), and clamps to single pane on Duo unfolded',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1104, 820);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final envService = Get.put<AdaptiveEnvironmentService>(
      AdaptiveEnvironmentService(),
    );
    // iPhone Duo unfolded: 1104×820 with 24pt vertical hinge at x=540..564 + 68pt right bar
    envService.acceptNativeSnapshot(<Object?, Object?>{
      'width': 1104.0,
      'height': 820.0,
      'safeLeft': 16.0,
      'safeTop': 24.0,
      'safeRight': 68.0,
      'safeBottom': 24.0,
      'systemBarEdge': 'right',
      'duoVerticalBar': true,
      'layoutVersion': 1,
      'nativeSupported': true,
      'reservedRegions': <Map<String, Object>>[
        <String, Object>{
          'x': 540.0,
          'y': 0.0,
          'width': 24.0,
          'height': 820.0,
          'kind': 'division',
          'active': true,
        },
      ],
    });

    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    Get.put<FavRuleService>(service);

    const leftHeroKey = ValueKey<String>('hero-cat-left');
    const rightHeroKey = ValueKey<String>('hero-cat-right');

    await tester.pumpWidget(
      _wrapApp(
        safePadding: const EdgeInsets.fromLTRB(16, 24, 68, 24),
        const CupertinoPageScaffold(
          child: Stack(
            children: <Widget>[
              // Left-pane swatch right beside x=540 hinge
              Positioned(
                left: 456,
                top: 120,
                child: GalleryHeroCategoryButton(
                  key: leftHeroKey,
                  category: 'Non-H',
                ),
              ),
              // Right-pane swatch right beside x=564 hinge
              Positioned(
                left: 576,
                top: 120,
                child: GalleryHeroCategoryButton(
                  key: rightHeroKey,
                  category: 'Non-H',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 1) Verify >=44×44 touch target on Non-H swatch while visual pill stays 28pt tall (no `▾`)
    final leftHitRect = tester.getRect(find.byKey(leftHeroKey));
    expect(leftHitRect.width, greaterThanOrEqualTo(44.0));
    expect(leftHitRect.height, greaterThanOrEqualTo(44.0));
    final visualPillRect = tester.getRect(
      find.descendant(
        of: find.byKey(leftHeroKey),
        matching: find.byType(FavCategoryBadge),
      ),
    );
    expect(visualPillRect.height, 28.0);
    expect(find.textContaining('▾'), findsNothing);

    // 2) At 0 rules: tap left-pane swatch -> header shows Non-H + 无H · 全年龄 + 分类,
    //    usage footer is hidden, and popover stays strictly inside left pane (< 540)!
    await tester.tap(find.byKey(leftHeroKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byKey(kCategoryInfoPopoverSurfaceKey), findsOneWidget);
    expect(find.byKey(kCategoryInfoPopoverArrowKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(kCategoryInfoPopoverSurfaceKey),
        matching: find.text('Non-H'),
      ),
      findsOneWidget,
    );
    expect(find.text('无H · 全年龄'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('搜索此分类'), findsOneWidget);
    expect(find.text('新建规则'), findsOneWidget);
    expect(find.textContaining('category:non-h'), findsNothing);
    expect(find.textContaining('条规则用到这个分类'), findsNothing);

    final leftPopRect =
        tester.getRect(find.byKey(kCategoryInfoPopoverSurfaceKey));
    expect(leftPopRect.left, greaterThanOrEqualTo(30.0 - 0.5));
    expect(leftPopRect.right, lessThanOrEqualTo(526.0 + 0.5));

    Navigator.of(
      tester.element(find.byKey(kCategoryInfoPopoverSurfaceKey)),
    ).pop();
    await tester.pumpAndSettle();

    // 3) Add 1 rule using Non-H -> tap right-pane swatch -> usage footer appears
    //    and popover stays strictly inside right pane [578, 1022]!
    await service.addRule(
      FavRule(
        id: 'r_nonh_usage',
        favcat: '0',
        conditions: <FavRuleCondition>[
          FavRuleCondition.category(const <String>['Non-H']),
        ],
      ),
    );

    await tester.tap(find.byKey(rightHeroKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('已有 1 条规则用到这个分类'), findsOneWidget);

    final rightPopRect =
        tester.getRect(find.byKey(kCategoryInfoPopoverSurfaceKey));
    expect(rightPopRect.left, greaterThanOrEqualTo(578.0 - 0.5));
    expect(rightPopRect.right, lessThanOrEqualTo(1022.0 + 0.5));

    Navigator.of(
      tester.element(find.byKey(kCategoryInfoPopoverSurfaceKey)),
    ).pop();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'showFavRulePullDownMenu clamps height and scrolls inside a short safe pane without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(400, 760);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(400, 760));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    const safePadding = EdgeInsets.fromLTRB(16, 20, 16, 20);
    const keyboardInsets = EdgeInsets.only(bottom: 580);
    // Safe pane vertical range: [20, 180] -> margin 10 -> [30, 170] (height 140pt).

    String? picked;
    await tester.pumpWidget(
      _wrapApp(
        brightness: Brightness.dark,
        safePadding: safePadding,
        viewInsets: keyboardInsets,
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Align(
              alignment: const Alignment(0, -0.75),
              child: Builder(
                builder: (buttonCtx) => CupertinoButton(
                  onPressed: () async {
                    picked = await showFavRulePullDownMenu<String>(
                      anchorContext: buttonCtx,
                      selectedValue: 'opt_0',
                      items: <FavRulePullDownItem<String>>[
                        for (var i = 0; i < 6; i++)
                          FavRulePullDownItem<String>(
                            value: 'opt_$i',
                            title: '选项 $i',
                            subtitle: '用于短安全窗格越界回归验证 $i',
                          ),
                      ],
                    );
                  },
                  child: const Text('OpenShortPaneMenu'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OpenShortPaneMenu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final scrollRect = tester.getRect(find.byType(SingleChildScrollView).last);
    expect(scrollRect.top, greaterThanOrEqualTo(30.0 - 0.5));
    expect(scrollRect.bottom, lessThanOrEqualTo(170.0 + 0.5));

    await tester.scrollUntilVisible(
      find.text('选项 5'),
      60,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('选项 5'));
    await tester.pumpAndSettle();
    expect(picked, 'opt_5');
  });

  testWidgets(
      'Same-frame banner replacement cleans up unmounted entry and Remember undo restores disabled state',
      (tester) async {
    String? stored;
    final service = FavRuleService(
      readJson: () => stored,
      writeJson: (json) async => stored = json,
      readLegacyOneStep: () => false,
      readLegacyFavPicker: () => false,
    );
    service.loadAndMigrate();
    await service.setFallback(FavRuleFallback.last);
    expect(service.enabled, isFalse);
    expect(service.config.fallback, FavRuleFallback.last);
    Get.put<FavRuleService>(service);

    late BuildContext hostCtx;
    await tester.pumpWidget(
      _wrapApp(
        Builder(
          builder: (context) {
            hostCtx = context;
            return const CupertinoPageScaffold(child: SizedBox.expand());
          },
        ),
      ),
    );

    // 1) Replace an unmounted OverlayEntry in the same frame before pump():
    var firstDismissed = 0;
    showFavRuleFeedbackBanner(
      context: hostCtx,
      favcat: '0',
      title: 'FirstUnmountedBanner',
      onDismiss: () => firstDismissed++,
    );
    showFavRuleFeedbackBanner(
      context: hostCtx,
      favcat: '1',
      title: 'SecondActiveBanner',
    );
    await tester.pumpAndSettle();
    expect(firstDismissed, 1);
    expect(find.text('FirstUnmountedBanner'), findsNothing);
    expect(find.text('SecondActiveBanner'), findsOneWidget);

    dismissFavRuleFeedbackBanner();
    await tester.pumpAndSettle();
    expect(find.text('SecondActiveBanner'), findsNothing);

    // 2) Remember rule auto-enables disabled service, and Undo restores enabled: false:
    final shown = maybeShowRememberCategoryBanner(
      context: hostCtx,
      ruleService: service,
      rawCategory: 'Non-H',
      chosenFavcat: '2',
      chosenFavTitle: '全年龄收藏',
    );
    expect(shown, isTrue);
    await tester.pumpAndSettle();

    await tester.tap(find.text('记住'));
    await tester.pumpAndSettle();
    expect(service.enabled, isTrue);
    expect(service.rules.length, 1);
    expect(find.text('已新建规则'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(service.rules, isEmpty);
    expect(service.enabled, isFalse);
    expect(service.config.fallback, FavRuleFallback.last);
  });
}

class _TestLayoutServices extends GetxService implements LayoutServices {
  @override
  final TabNavigationRegistry tabNavigation = TabNavigationRegistry();
  @override
  bool get adaptiveNavigationMounted => true;
  @override
  bool get isLayoutLarge => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LoggedInUserController extends GetxController implements UserController {
  @override
  final Rx<User> user = const User(memberId: '1', passHash: 'hash').obs;
  @override
  bool get isLogin => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingFavController extends FavController {
  final List<String> savedFavcats = <String>[];
  final List<String> savedNotes = <String>[];
  int pickerOpened = 0;
  FavRuleMissContext? lastMissContext;
  Favcat? pickerResult = const Favcat(favId: '0', favTitle: '收藏夹 0');
  String? storedNote = '';
  bool throwOnNoteRead = false;

  @override
  Future<String?> loadFavoriteNote(String gid, String token) async {
    if (throwOnNoteRead) {
      throw StateError('network error');
    }
    return storedNote;
  }

  @override
  Future<Favcat?> addFav(
    String gid,
    String token, {
    String oriFavcat = '',
    String oriFavnote = '',
    String? galleryTitle,
    GalleryProvider? galleryProvider,
    FavRuleMissContext? ruleMissContext,
  }) async {
    pickerOpened++;
    lastMissContext = ruleMissContext;
    return pickerResult;
  }

  @override
  Future<Favcat> saveToFavcat(
    String gid,
    String token,
    String targetFavcat, {
    String oriFavcat = '',
    String favnote = '',
    GalleryProvider? galleryProvider,
  }) async {
    savedFavcats.add(targetFavcat);
    savedNotes.add(favnote);
    return Favcat(favId: targetFavcat, favTitle: '收藏夹 $targetFavcat');
  }
}
