import 'dart:ui' as ui;

import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/desktop_ui_preferences.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/android_setting_group.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/user.dart';
import 'package:eros_fe/pages/login/controller/login_controller.dart';
import 'package:eros_fe/pages/setting/layout_setting_page.dart';
import 'package:eros_fe/pages/tab/controller/setting_controller.dart';
import 'package:eros_fe/pages/tab/controller/splash_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/setting_page.dart';
import 'package:eros_fe/pages/tab/view/splash_page.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/widget/cupertino/list_tile.dart';
import 'package:eros_fe/widget/cupertino/sliver_list_section.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/desktop_sidebar.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Icons, Tooltip;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'support/waterfall_fixture.dart';

void main() {
  setUp(() {
    registerWaterfallFixture();
    Global.packageInfo = PackageInfo(
      appName: 'Eros-FE',
      packageName: 'cn.honjow.fehv',
      version: '1.10.1',
      buildNumber: '568',
    );
  });

  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    SettingGlassBar.debugActive = null;
    Get.reset();
  });

  group('EhSvgIcon and path parser', () {
    test('parses complex SVG path commands including arcs and packed numbers', () {
      final path = parseEhSvgPathData(
        'M4-2l6.5.5h4v5c0 1.5-1 2.5-2.5 2.5s-2.5-1-2.5-2.5q2-3 4 0t4 0a4 4 0 014 4z',
      );
      expect(path.getBounds().isEmpty, isFalse);

      final evenOdd = parseEhSvgPathData(
        'M0 0h20v20H0zM5 5h10v10H5z',
        fillEvenOdd: true,
      );
      expect(evenOdd.fillType, ui.PathFillType.evenOdd);
      expect(evenOdd.contains(const Offset(10, 10)), isFalse);
      expect(evenOdd.contains(const Offset(2, 2)), isTrue);
    });

    testWidgets(
      'EhSvgIcon & EhSvgFaIcon render CustomPaint and match find.byIcon',
      (tester) async {
        await tester.pumpWidget(
          const CupertinoApp(
            home: Row(
              children: <Widget>[
                EhSvgIcon(CupertinoIcons.search, size: 18),
                EhSvgIcon(Icons.arrow_back, size: 18),
                EhSvgFaIcon(FontAwesomeIcons.solidHeart, size: 16),
                EhSvgFaIcon(FontAwesomeIcons.poop, size: 16),
              ],
            ),
          ),
        );

        expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(find.byIcon(FontAwesomeIcons.solidHeart.data), findsOneWidget);
        expect(find.bySubtype<Icon>(), findsNWidgets(4));
        expect(find.bySubtype<FaIcon>(), findsNWidgets(2));
        // 3 registered icons render via CustomPaint; decorative poop falls back to RichText.
        expect(
          find.descendant(
            of: find.byType(EhSvgIcon),
            matching: find.byType(CustomPaint),
          ),
          findsNWidgets(2),
        );
        expect(
          find.descendant(
            of: find.byType(EhSvgFaIcon),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'EhCupertinoListTile promotes leading Icon and trailing CupertinoListTileChevron to SVG',
      (tester) async {
        await tester.pumpWidget(
          const CupertinoApp(
            home: CupertinoPageScaffold(
              child: EhCupertinoListTile(
                leading: Icon(CupertinoIcons.globe),
                title: Text('Site'),
                trailing: CupertinoListTileChevron(),
              ),
            ),
          ),
        );

        expect(find.byType(EhSvgIcon), findsAtLeastNWidgets(2));
        expect(find.byType(EhSvgListTileChevron), findsOneWidget);
        expect(find.bySubtype<CupertinoListTileChevron>(), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.globe), findsOneWidget);
      },
    );
  });

  group('DesktopSidebar redesign', () {
    testWidgets(
      'collapsed section summaries stay right-aligned with chevrons in one column',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
        final prefs = DesktopUiPreferences()
          ..collapsed.addAll(const <String>{'browse', 'library', 'groups'});
        addTearDown(prefs.dispose);

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: 700,
                child: DesktopSidebar(
                  routes: const <String>[
                    EHRoutes.gallery,
                    EHRoutes.toplist,
                    EHRoutes.favorite,
                    EHRoutes.download,
                    EHRoutes.history,
                    EHRoutes.setting,
                  ],
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: EhSvgIcon(CupertinoIcons.square_grid_2x2),
                      label: '画廊',
                    ),
                    BottomNavigationBarItem(
                      icon: EhSvgIcon(CupertinoIcons.list_bullet),
                      label: '排行榜',
                    ),
                    BottomNavigationBarItem(
                      icon: EhSvgIcon(CupertinoIcons.heart),
                      label: '收藏',
                    ),
                    BottomNavigationBarItem(
                      icon: EhSvgIcon(CupertinoIcons.arrow_down_to_line),
                      label: '下载',
                    ),
                    BottomNavigationBarItem(
                      icon: EhSvgIcon(CupertinoIcons.clock),
                      label: '历史',
                    ),
                    BottomNavigationBarItem(
                      icon: EhSvgIcon(CupertinoIcons.settings),
                      label: '设置',
                    ),
                  ],
                  currentIndex: 5, // Settings selected
                  onTap: (_) {},
                  searchLabel: '搜索',
                  onSearch: () {},
                  browseLabel: '浏览',
                  libraryLabel: '资料库',
                  groupsLabel: '分组',
                  groupSummary: '热门',
                  groups: const <DesktopSidebarGroup>[
                    DesktopSidebarGroup(title: '热门', selected: false),
                  ],
                  preferences: prefs,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('画廊'), findsOneWidget);
        expect(find.text('热门'), findsOneWidget);

        final chevronRights = <double>[];
        for (final id in <String>['browse', 'library', 'groups', 'recent']) {
          final chevron = find.descendant(
            of: find.byKey(ValueKey<String>('desktop-section-$id')),
            matching: find.byIcon(CupertinoIcons.chevron_right),
          );
          expect(chevron, findsOneWidget);
          chevronRights.add(tester.getRect(chevron).right);
        }

        final minRight = chevronRights.reduce((a, b) => a < b ? a : b);
        final maxRight = chevronRights.reduce((a, b) => a > b ? a : b);
        expect(maxRight - minRight, lessThanOrEqualTo(0.5));

        final selectedSettingCtrl = tester.widget<DesktopControl>(
          find
              .descendant(
                of: find.byKey(
                  const ValueKey<String>(
                    'desktop-sidebar-${EHRoutes.setting}',
                  ),
                ),
                matching: find.byType(DesktopControl),
              )
              .first,
        );
        expect(selectedSettingCtrl.radius, 999);
        expect(selectedSettingCtrl.selected, isTrue);
      },
    );
  });

  group('iOS 27 split-view Settings master & detail', () {
    testWidgets(
      'split SettingTab drops top blur mask, uses full capsule rows, and filters via search',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
        SettingGlassBar.debugActive = true;
        final layout = Get.put<LayoutServices>(_SplitLayout());
        layout.layoutMode = LayoutMode.large;
        final controller = Get.put(SettingViewController());
        controller.openCategory.value = EHRoutes.layoutSetting;

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: const BrowsePaneScope(
              split: true,
              child: SettingTab(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Zero top blur mask or glass bar in split master column.
        expect(find.byType(SettingGlassBar), findsNothing);
        expect(find.byType(SoftScrollEdgeEffect), findsNothing);
        expect(find.byType(SliverCupertinoListSection), findsNothing);
        expect(find.bySubtype<CupertinoListTileChevron>(), findsNothing);

        // Profile header + all 8 categories visible.
        expect(
          find.byKey(const ValueKey<String>('setting-profile-row')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('setting-link-${EHRoutes.layoutSetting}')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('setting-link-${EHRoutes.about}')),
          findsOneWidget,
        );

        // Selected row uses stadium capsule (999) + neutral gray selection fill.
        final selectedContainer = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('setting-link-${EHRoutes.layoutSetting}'),
            ),
            matching: find.byType(AnimatedContainer),
          ),
        );
        final decoration = selectedContainer.decoration! as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(999));
        expect(
          decoration.color,
          DesktopBrowseStyle.capsuleSelected(
            tester.element(find.byType(SettingTab)),
          ),
        );

        // Floating glass search capsule filters categories in real time.
        await tester.enterText(
          find.byKey(const ValueKey<String>('setting-master-search-field')),
          'ExHentai',
        );
        await tester.pumpAndSettle();
        // Default site is E-Hentai, so query 'E-Hentai' matches Site row only.
        await tester.enterText(
          find.byKey(const ValueKey<String>('setting-master-search-field')),
          'E-Hentai',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('setting-link-${EHRoutes.ehSetting}')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('setting-link-${EHRoutes.about}')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('setting-master-search-clear')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('setting-link-${EHRoutes.about}')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'split detail root category uses canvas background, omits top bar, and renders 24px Hero Card',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
        final layout = Get.put<LayoutServices>(_SplitLayout());
        layout.layoutMode = LayoutMode.large;
        final stack = layout.tabNavigation.select(EHRoutes.setting);
        addTearDown(() => layout.tabNavigation.reset());

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: BrowsePaneScope(
              split: true,
              child: Navigator(
                key: Get.nestedKey(stack.detailId),
                observers: <NavigatorObserver>[stack.detailObserver],
                initialRoute: EHRoutes.layoutSetting,
                onGenerateInitialRoutes: (_, _) => <Route<void>>[
                  PageRouteBuilder<void>(
                    settings: const RouteSettings(name: EHRoutes.empty),
                    pageBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
                  PageRouteBuilder<void>(
                    settings: const RouteSettings(name: EHRoutes.layoutSetting),
                    pageBuilder: (_, _, _) => const SettingScaffold(
                      title: '外观与布局',
                      child: CustomScrollView(
                        slivers: <Widget>[
                          SliverSettingCategoryHero(
                            route: EHRoutes.layoutSetting,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onGenerateRoute: (settings) => PageRouteBuilder<void>(
                  settings: settings,
                  pageBuilder: (_, _, _) => const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CupertinoNavigationBar), findsNothing);
        expect(find.byType(SettingGlassBar), findsNothing);
        expect(find.byType(SettingCategoryHeroCard), findsOneWidget);

        final scaffold = tester.widget<CupertinoPageScaffold>(
          find.byType(CupertinoPageScaffold),
        );
        final ctx = tester.element(find.byType(SettingScaffold));
        expect(
          scaffold.backgroundColor,
          ehTheme.palette.canvas.resolveFrom(ctx),
        );

        final heroDecorated = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(SettingCategoryHeroCard),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final shape = (heroDecorated.decoration as ShapeDecoration).shape
            as RoundedSuperellipseBorder;
        expect(
          shape.borderRadius,
          BorderRadius.circular(kInsetGroupedSectionRadius),
        );
      },
    );

    testWidgets(
      'single-column SliverSettingCategoryHero collapses when not split',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('en'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: const SettingScaffold(
              title: 'Appearance',
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverSettingCategoryHero(route: EHRoutes.layoutSetting),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SettingCategoryHeroCard), findsNothing);
      },
    );

    testWidgets(
      'iOS split SettingTab syncs category and signed-in account selection and clears on pop or single-column',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
        final layout = Get.put<LayoutServices>(_SplitLayout());
        layout.layoutMode = LayoutMode.large;
        final controller = Get.put(SettingViewController());
        final stack = layout.tabNavigation.select(EHRoutes.setting);
        final userController = Get.find<UserController>();
        userController.user(
          const User(
            username: 'ios_user',
            nickName: 'iOS Tester',
            memberId: '12345',
            passHash: 'abcdef',
          ),
        );
        final splitNotifier = ValueNotifier<bool>(true);
        addTearDown(() {
          splitNotifier.dispose();
          layout.tabNavigation.reset();
        });

        List<String?> detailRoutes() => stack.detailObserver.history
            .map((route) => route.settings.name)
            .toList();

        Color rowColor(Key key) {
          final container = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(AnimatedContainer),
            ),
          );
          return (container.decoration! as BoxDecoration).color!;
        }

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: ValueListenableBuilder<bool>(
              valueListenable: splitNotifier,
              builder: (context, isSplit, _) => BrowsePaneScope(
                split: isSplit,
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 340, child: SettingTab()),
                    Expanded(
                      child: Navigator(
                        key: Get.nestedKey(stack.detailId),
                        observers: <NavigatorObserver>[stack.detailObserver],
                        onGenerateInitialRoutes: (_, _) => <Route<void>>[
                          PageRouteBuilder<void>(
                            settings: const RouteSettings(name: EHRoutes.empty),
                            pageBuilder: (_, _, _) => const SizedBox.expand(),
                          ),
                        ],
                        onGenerateRoute: (settings) => PageRouteBuilder<void>(
                          settings: settings,
                          pageBuilder: (_, _, _) => const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final selectedFill = DesktopBrowseStyle.capsuleSelected(
          tester.element(find.byType(SettingTab)),
        );
        const readKey = ValueKey<String>(
          'setting-link-${EHRoutes.readSetting}',
        );
        const aboutKey = ValueKey<String>('setting-link-${EHRoutes.about}');
        const profileKey = ValueKey<String>('setting-profile-row');

        // 1. iOS starts with an empty detail pane and no highlighted row.
        expect(detailRoutes(), <String>[EHRoutes.empty]);
        expect(controller.openCategory.value, isNull);
        expect(rowColor(readKey).a, 0.0);
        expect(rowColor(profileKey).a, 0.0);

        // 2. Tapping a category updates detail stack and highlights that row.
        await tester.tap(find.byKey(readKey));
        await tester.pumpAndSettle();
        expect(detailRoutes(), <String>[EHRoutes.empty, EHRoutes.readSetting]);
        expect(controller.openCategory.value, EHRoutes.readSetting);
        expect(rowColor(readKey), selectedFill);
        expect(rowColor(aboutKey).a, 0.0);

        // 3. Pushing a sub-page keeps the parent category selected.
        Get.toNamed<void>(EHRoutes.customHosts, id: stack.detailId);
        await tester.pumpAndSettle();
        expect(detailRoutes(), <String>[
          EHRoutes.empty,
          EHRoutes.readSetting,
          EHRoutes.customHosts,
        ]);
        expect(controller.openCategory.value, EHRoutes.readSetting);
        expect(rowColor(readKey), selectedFill);

        // 4. Tapping another category replaces sub-pages and moves selection.
        await tester.tap(find.byKey(aboutKey));
        await tester.pumpAndSettle();
        expect(detailRoutes(), <String>[EHRoutes.empty, EHRoutes.about]);
        expect(controller.openCategory.value, EHRoutes.about);
        expect(rowColor(aboutKey), selectedFill);
        expect(rowColor(readKey).a, 0.0);

        // 5. Tapping the signed-in profile header selects accountSession.
        await tester.tap(find.byKey(profileKey));
        await tester.pumpAndSettle();
        expect(detailRoutes(), <String>[
          EHRoutes.empty,
          EHRoutes.accountSession,
        ]);
        expect(controller.openCategory.value, EHRoutes.accountSession);
        expect(rowColor(profileKey), selectedFill);
        expect(rowColor(aboutKey).a, 0.0);

        // 6. Popping back to empty clears selection without auto-reopening.
        Get.nestedKey(stack.detailId)!.currentState!.pop();
        await tester.pumpAndSettle();
        expect(detailRoutes(), <String>[EHRoutes.empty]);
        expect(controller.openCategory.value, isNull);
        expect(rowColor(profileKey).a, 0.0);
        expect(rowColor(aboutKey).a, 0.0);

        // 7. Switching to single-column clears split selection and restores chevrons.
        await tester.tap(find.byKey(readKey));
        await tester.pumpAndSettle();
        expect(controller.openCategory.value, EHRoutes.readSetting);

        layout.layoutMode = LayoutMode.small;
        splitNotifier.value = false;
        await tester.pumpAndSettle();
        expect(controller.openCategory.value, isNull);
        expect(find.bySubtype<CupertinoListTileChevron>(), findsWidgets);
      },
    );
  });

  group('Post-199 5-issue regressions', () {
    testWidgets(
      'EhSvgIcon stays centered at its declared size under tight parent constraints',
      (tester) async {
        await tester.pumpWidget(
          CupertinoApp(
            home: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: const EhSvgIcon(CupertinoIcons.book_fill, size: 15),
              ),
            ),
          ),
        );

        final customPaintFinder = find.descendant(
          of: find.byType(EhSvgIcon),
          matching: find.byType(CustomPaint),
        );
        expect(tester.getSize(customPaintFinder), const Size(15, 15));
        final bookFillSpec = EhSvgRegistry.lookup(CupertinoIcons.book_fill);
        expect(bookFillSpec, isNotNull);
        expect(bookFillSpec!.shapes.every((s) => s.filled), isTrue);
      },
    );

    testWidgets(
      'opening LayoutSettingPage does not register LoginController or read clipboard',
      (tester) async {
        Get.put<TagTransController>(_TagTrans());
        var clipboardReads = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.getData') {
              clipboardReads++;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: const LayoutSettingPage(),
          ),
        );
        await tester.pumpAndSettle();

        expect(Get.isRegistered<LoginController>(), isFalse);
        expect(clipboardReads, 0);
      },
    );

    testWidgets(
      'macOS sidebar suppresses redundant row tooltips, uses arrow cursor, and shows hover fill on rows and EhCupertinoListTile',
      (tester) async {
        Future<void> pumpSidebarFor(TargetPlatform host) async {
          PlatformCapabilities.debugHostPlatformOverride = host;
          final prefs = DesktopUiPreferences();
          addTearDown(prefs.dispose);
          await tester.pumpWidget(
            CupertinoApp(
              locale: const Locale('zh', 'CN'),
              supportedLocales: L10n.delegate.supportedLocales,
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                L10n.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              home: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  height: 700,
                  child: DesktopSidebar(
                    routes: const <String>[
                      EHRoutes.gallery,
                      EHRoutes.favorite,
                      EHRoutes.setting,
                    ],
                    items: const <BottomNavigationBarItem>[
                      BottomNavigationBarItem(
                        icon: EhSvgIcon(CupertinoIcons.square_grid_2x2),
                        label: '画廊',
                      ),
                      BottomNavigationBarItem(
                        icon: EhSvgIcon(CupertinoIcons.heart),
                        label: '收藏',
                      ),
                      BottomNavigationBarItem(
                        icon: EhSvgIcon(CupertinoIcons.settings),
                        label: '设置',
                      ),
                    ],
                    currentIndex: 0,
                    onTap: (_) {},
                    searchLabel: '搜索',
                    onSearch: () {},
                    browseLabel: '浏览',
                    libraryLabel: '资料库',
                    groupsLabel: '分组',
                    preferences: prefs,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pumpSidebarFor(TargetPlatform.macOS);

        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('desktop-sidebar-${EHRoutes.favorite}')),
            matching: find.byType(Tooltip),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('desktop-sidebar-search')),
            matching: find.byType(Tooltip),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('desktop-hide-sidebar')),
            matching: find.byType(Tooltip),
          ),
          findsOneWidget,
        );

        final favFinder = find.byKey(
          const ValueKey<String>('desktop-sidebar-${EHRoutes.favorite}'),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(400, 400));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(favFinder));
        await tester.pumpAndSettle();

        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.basic,
        );
        final favBox = tester.widget<AnimatedContainer>(
          find.descendant(
            of: favFinder,
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(
          (favBox.decoration! as BoxDecoration).color,
          DesktopBrowseStyle.capsuleHover(
            tester.element(find.byType(DesktopSidebar)),
          ),
        );

        // Windows keeps the hand cursor and working hover highlights.
        await pumpSidebarFor(TargetPlatform.windows);
        await mouse.moveTo(tester.getCenter(favFinder));
        await tester.pumpAndSettle();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.click,
        );

        // EhCupertinoListTile also responds smoothly to desktop mouse hover.
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoPageScaffold(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    EhCupertinoListTile(
                      key: const ValueKey<String>('hoverable-tile'),
                      title: const Text('Theme'),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tileFinder = find.byKey(const ValueKey<String>('hoverable-tile'));
        await mouse.moveTo(const Offset(5, 5));
        await tester.pump();
        expect(
          tester.widget<CupertinoListTile>(
            find.descendant(of: tileFinder, matching: find.byType(CupertinoListTile)),
          ).backgroundColor,
          isNull,
        );

        await mouse.moveTo(tester.getCenter(tileFinder));
        await tester.pumpAndSettle();
        expect(
          tester.widget<CupertinoListTile>(
            find.descendant(of: tileFinder, matching: find.byType(CupertinoListTile)),
          ).backgroundColor,
          DesktopBrowseStyle.listRowHover(tester.element(tileFinder)),
        );
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.basic,
        );
      },
    );

    testWidgets(
      'Android settings use monochrome squircle badges, opaque top scroll edge, and outline bottom-bar heart',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
        expect(SoftEdgeCurve.withoutBlur.alphas.first, 1.0);
        expect(SoftEdgeCurve.withoutBlurDark.alphas.first, 1.0);

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: CupertinoPageScaffold(
              child: AndroidSettingGroup(
                header: '浏览',
                children: <Widget>[
                  AndroidSettingTile(
                    icon: CupertinoIcons.square_grid_2x2,
                    title: const Text('外观与布局'),
                    subtitle: const Text('瀑布流 - 大'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Trailing affordance stays an EhSvgIcon chevron without pulling in CupertinoListTileChevron.
        expect(find.bySubtype<CupertinoListTileChevron>(), findsNothing);
        expect(find.byIcon(CupertinoIcons.chevron_right), findsOneWidget);
        expect(
          tester.getSize(
            find.descendant(
              of: find.byIcon(CupertinoIcons.square_grid_2x2),
              matching: find.byType(CustomPaint),
            ),
          ),
          const Size(19, 19),
        );

        final tabs = Get.find<TabHomeController>();
        tabs.init(
          inContext: tester.element(find.byType(CupertinoPageScaffold)),
        );
        final navItems = tabs.listBottomNavigationBarItem;
        final favItem = navItems.firstWhere(
          (item) => (item.icon is EhSvgIcon) &&
              (item.icon as EhSvgIcon).icon == CupertinoIcons.heart,
        );
        expect(favItem.activeIcon, isA<EhSvgFaIcon>());
      },
    );

    testWidgets(
      'DesktopSidebar rows and EhCupertinoListTile animate hover smoothly and settle cushioned quick taps',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
        final prefs = DesktopUiPreferences();
        addTearDown(prefs.dispose);
        int? tappedRouteIndex;

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: L10n.delegate.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              L10n.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                height: 700,
                child: DesktopSidebar(
                  routes: const <String>[
                    EHRoutes.gallery,
                    EHRoutes.favorite,
                    EHRoutes.setting,
                  ],
                  items: const <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                      icon: EhSvgIcon(CupertinoIcons.square_grid_2x2),
                      label: '画廊',
                    ),
                    BottomNavigationBarItem(
                      icon: EhSvgIcon(CupertinoIcons.heart),
                      label: '收藏',
                    ),
                    BottomNavigationBarItem(
                      icon: EhSvgIcon(CupertinoIcons.settings),
                      label: '设置',
                    ),
                  ],
                  currentIndex: 0,
                  onTap: (index) => tappedRouteIndex = index,
                  searchLabel: '搜索',
                  onSearch: () {},
                  browseLabel: '浏览',
                  libraryLabel: '资料库',
                  groupsLabel: '分组',
                  preferences: prefs,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final favFinder = find.byKey(
          const ValueKey<String>('desktop-sidebar-${EHRoutes.favorite}'),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(400, 400));
        addTearDown(mouse.removePointer);

        await mouse.moveTo(tester.getCenter(favFinder));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        final targetSidebarHover = DesktopBrowseStyle.capsuleHover(
          tester.element(find.byType(DesktopSidebar)),
        );
        final midSidebarBox = tester.widget<AnimatedContainer>(
          find.descendant(
            of: favFinder,
            matching: find.byType(AnimatedContainer),
          ),
        );
        final midSidebarColor =
            (midSidebarBox.decoration! as BoxDecoration).color!;
        expect(midSidebarColor.a, greaterThan(0.0));
        expect(midSidebarColor.a, lessThan(targetSidebarHover.a));

        await tester.pumpAndSettle();
        final settledSidebarBox = tester.widget<AnimatedContainer>(
          find.descendant(
            of: favFinder,
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(
          (settledSidebarBox.decoration! as BoxDecoration).color,
          targetSidebarHover,
        );

        await tester.tap(favFinder);
        await tester.pumpAndSettle();
        expect(tappedRouteIndex, 1);
        expect(tester.takeException(), isNull);

        await mouse.moveTo(const Offset(400, 400));
        await tester.pumpAndSettle();
        final restSidebarBox = tester.widget<AnimatedContainer>(
          find.descendant(
            of: favFinder,
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect((restSidebarBox.decoration! as BoxDecoration).color!.a, 0.0);

        // EhCupertinoListTile smooth hover transition & cushioned quick tap.
        var tileTaps = 0;
        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoPageScaffold(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    EhCupertinoListTile(
                      key: const ValueKey<String>('smooth-hover-tile'),
                      title: const Text('Theme'),
                      onTap: () => tileTaps++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tileFinder = find.byKey(
          const ValueKey<String>('smooth-hover-tile'),
        );
        await mouse.moveTo(const Offset(5, 5));
        await tester.pump();
        expect(
          tester
              .widget<CupertinoListTile>(
                find.descendant(
                  of: tileFinder,
                  matching: find.byType(CupertinoListTile),
                ),
              )
              .backgroundColor,
          isNull,
        );

        await mouse.moveTo(tester.getCenter(tileFinder));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        final targetTileHover = DesktopBrowseStyle.listRowHover(
          tester.element(tileFinder),
        );
        final midTileBg = tester
            .widget<CupertinoListTile>(
              find.descendant(
                of: tileFinder,
                matching: find.byType(CupertinoListTile),
              ),
            )
            .backgroundColor;
        expect(midTileBg, isNotNull);
        expect(midTileBg!.a, greaterThan(0.0));
        expect(midTileBg.a, lessThan(targetTileHover.a));

        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CupertinoListTile>(
                find.descendant(
                  of: tileFinder,
                  matching: find.byType(CupertinoListTile),
                ),
              )
              .backgroundColor,
          targetTileHover,
        );

        await tester.tap(tileFinder);
        await tester.pumpAndSettle();
        expect(tileTaps, 1);
        expect(tester.takeException(), isNull);

        await mouse.moveTo(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CupertinoListTile>(
                find.descendant(
                  of: tileFinder,
                  matching: find.byType(CupertinoListTile),
                ),
              )
              .backgroundColor,
          isNull,
        );
      },
    );

    testWidgets(
      'SplashPage renders vector EhFeAppLogo without exceptions in light and dark themes',
      (tester) async {
        Get.put<SplashController>(_SplashStub());
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            CupertinoApp(
              locale: const Locale('zh', 'CN'),
              supportedLocales: L10n.delegate.supportedLocales,
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                L10n.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              theme: CupertinoThemeData(brightness: brightness),
              home: const SplashPage(),
            ),
          );
          await tester.pumpAndSettle();

          final logoFinder = find.byType(EhFeAppLogo);
          expect(logoFinder, findsOneWidget);
          expect(tester.widget<EhFeAppLogo>(logoFinder).style, EhFeLogoStyle.minimal);
          expect(tester.getSize(logoFinder), const Size(108, 108));
          expect(find.text('Eros-FE'), findsOneWidget);
          expect(
            find.descendant(
              of: logoFinder,
              matching: find.byType(CustomPaint),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: logoFinder,
              matching: find.byType(DecoratedBox),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}

class _SplitLayout extends LayoutServices {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _TagTrans extends TagTransController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _SplashStub extends GetxController implements SplashController {
  @override
  String? sharedText = '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
