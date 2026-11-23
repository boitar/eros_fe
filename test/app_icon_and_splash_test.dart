import 'dart:io';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/app_icon_service.dart';
import 'package:eros_fe/common/service/auth_session_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/login/controller/login_controller.dart';
import 'package:eros_fe/pages/login/view/login_page.dart';
import 'package:eros_fe/pages/setting/layout_setting_page.dart';
import 'package:eros_fe/pages/tab/controller/splash_controller.dart';
import 'package:eros_fe/pages/tab/view/splash_page.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/flutter_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/waterfall_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const lightPearlColors = <Color>[
    Color(0xFFFCFDFF),
    Color(0xFFEEF2F8),
    Color(0xFFDDE3EF),
  ];
  const darkObsidianColors = <Color>[
    Color(0xFF222631),
    Color(0xFF151821),
    Color(0xFF0C0E14),
  ];

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
    Get.reset();
  });

  testWidgets(
    'SplashPage renders minimal EhFeAppLogo without DecoratedBox squircle',
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
        expect(
          tester.widget<EhFeAppLogo>(logoFinder).style,
          EhFeLogoStyle.minimal,
        );
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

  testWidgets(
    'EhFeAppLogo monochrome adapts, lightGlass/darkGlass stay fixed, and adaptiveSplit renders diagonal split squircle',
    (tester) async {
      for (final brightness in Brightness.values) {
        // 1. monochrome adapts dynamically to Light / Dark theme brightness.
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: const Center(
              child: EhFeAppLogo(size: 32.0, style: EhFeLogoStyle.monochrome),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final monoLogo = find.byType(EhFeAppLogo);
        expect(tester.getSize(monoLogo), const Size(32, 32));
        final monoDecorated = find.descendant(
          of: monoLogo,
          matching: find.byType(DecoratedBox),
        );
        expect(monoDecorated, findsOneWidget);
        final monoDecoration =
            tester.widget<DecoratedBox>(monoDecorated).decoration
                as ShapeDecoration;
        final monoGradient = monoDecoration.gradient! as LinearGradient;
        expect(
          monoGradient.colors,
          brightness == Brightness.light
              ? lightPearlColors
              : darkObsidianColors,
        );
        expect(
          find.descendant(of: monoLogo, matching: find.byType(CustomPaint)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // 2. lightGlass is always Ceramic Silver-Pearl in both Light and Dark.
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: const Center(
              child: EhFeAppLogo(size: 32.0, style: EhFeLogoStyle.lightGlass),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final lightLogo = find.byType(EhFeAppLogo);
        final lightDecorated = find.descendant(
          of: lightLogo,
          matching: find.byType(DecoratedBox),
        );
        expect(lightDecorated, findsOneWidget);
        final lightDecoration =
            tester.widget<DecoratedBox>(lightDecorated).decoration
                as ShapeDecoration;
        expect(
          (lightDecoration.gradient! as LinearGradient).colors,
          lightPearlColors,
        );
        expect(
          find.descendant(of: lightLogo, matching: find.byType(CustomPaint)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // 3. darkGlass is always Studio Obsidian in both Light and Dark.
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: const Center(
              child: EhFeAppLogo(size: 32.0, style: EhFeLogoStyle.darkGlass),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final darkLogo = find.byType(EhFeAppLogo);
        final darkDecorated = find.descendant(
          of: darkLogo,
          matching: find.byType(DecoratedBox),
        );
        expect(darkDecorated, findsOneWidget);
        final darkDecoration =
            tester.widget<DecoratedBox>(darkDecorated).decoration
                as ShapeDecoration;
        expect(
          (darkDecoration.gradient! as LinearGradient).colors,
          darkObsidianColors,
        );
        expect(
          find.descendant(of: darkLogo, matching: find.byType(CustomPaint)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        // 4. adaptiveSplit uses a single DecoratedBox + RoundedSuperellipseBorder + CustomPaint.
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: const Center(
              child: EhFeAppLogo(
                size: 32.0,
                style: EhFeLogoStyle.adaptiveSplit,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final splitLogo = find.byType(EhFeAppLogo);
        expect(tester.getSize(splitLogo), const Size(32, 32));
        final splitDecorated = find.descendant(
          of: splitLogo,
          matching: find.byType(DecoratedBox),
        );
        expect(splitDecorated, findsOneWidget);
        final splitDecoration =
            tester.widget<DecoratedBox>(splitDecorated).decoration
                as ShapeDecoration;
        expect(splitDecoration.shape, isA<RoundedSuperellipseBorder>());
        expect(
          find.descendant(of: splitLogo, matching: find.byType(CustomPaint)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  test(
    'EhAppIconStyle.parse maps legacy monochrome to auto and EhSettingService defaults safely',
    () async {
      expect(EhAppIconStyle.parse('monochrome'), EhAppIconStyle.auto);
      expect(EhAppIconStyle.parse('auto'), EhAppIconStyle.auto);
      expect(EhAppIconStyle.parse('light'), EhAppIconStyle.light);
      expect(EhAppIconStyle.parse('dark'), EhAppIconStyle.dark);
      expect(EhAppIconStyle.parse('purple'), EhAppIconStyle.purple);
      expect(EhAppIconStyle.parse(null), EhAppIconStyle.auto);
      expect(EhAppIconStyle.parse('unknown'), EhAppIconStyle.auto);

      final settings = Get.find<EhSettingService>();
      expect(settings.appIconStyle, EhAppIconStyle.auto);

      // Safe initialization when Hive configBox is not open in isolated tests.
      settings.initAppIconPreference();
      expect(settings.appIconStyle, EhAppIconStyle.auto);

      // MissingPluginException and PlatformException never propagate.
      await AppIconService.setAppIcon(EhAppIconStyle.purple);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AppIconService.channel, (call) async {
        throw PlatformException(code: 'TEST_ERR', message: 'simulated failure');
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AppIconService.channel, null),
      );
      await AppIconService.setAppIcon(EhAppIconStyle.purple);
    },
  );

  test(
    'EhSettingService persists all 4 styles in Hive and applies platform startup sync rules',
    () async {
      final Directory hiveDir =
          await Directory.systemTemp.createTemp('eros-app-icon-');
      Hive.init(hiveDir.path);
      final Box<String> box = await Hive.openBox<String>(configBox);
      addTearDown(() async {
        await box.close();
        await Hive.close();
        await hiveDir.delete(recursive: true);
      });

      final List<MethodCall> calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AppIconService.channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AppIconService.channel, null),
      );

      Get.reset();
      Get.testMode = true;
      Get.put<LocaleService>(LocaleService());
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;

      // Legacy persisted 'monochrome' upgrades cleanly to auto.
      await box.put(EhSettingService.appIconStyleKey, 'monochrome');
      final migrated = EhSettingService()..initAppIconPreference();
      await Future<void>.delayed(Duration.zero);
      expect(migrated.appIconStyle, EhAppIconStyle.auto);
      expect(calls, isEmpty);

      // Persists each of the 4 styles in Hive and forwards channel payload.
      for (final style in const <EhAppIconStyle>[
        EhAppIconStyle.light,
        EhAppIconStyle.dark,
        EhAppIconStyle.purple,
        EhAppIconStyle.auto,
      ]) {
        calls.clear();
        await migrated.setAppIconStyle(style);
        expect(migrated.appIconStyle, style);
        expect(box.get(EhSettingService.appIconStyleKey), style.name);
        expect(calls.map((c) => c.arguments).toList(), <Object?>[style.name]);
      }

      // Mobile startup NEVER invokes setAppIcon for any style.
      for (final mobile in const <TargetPlatform>[
        TargetPlatform.iOS,
        TargetPlatform.android,
      ]) {
        PlatformCapabilities.debugHostPlatformOverride = mobile;
        for (final style in EhAppIconStyle.values) {
          calls.clear();
          await box.put(EhSettingService.appIconStyleKey, style.name);
          final reopened = EhSettingService()..initAppIconPreference();
          await Future<void>.delayed(Duration.zero);
          expect(reopened.appIconStyle, style);
          expect(calls, isEmpty);
        }
      }

      // macOS startup skips auto (bundle native AppIcon.icon) and syncs light/dark/purple.
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
      for (final style in EhAppIconStyle.values) {
        calls.clear();
        await box.put(EhSettingService.appIconStyleKey, style.name);
        final reopened = EhSettingService()..initAppIconPreference();
        await Future<void>.delayed(Duration.zero);
        expect(reopened.appIconStyle, style);
        if (style == EhAppIconStyle.auto) {
          expect(calls, isEmpty);
        } else {
          expect(
            calls.map((c) => c.arguments).toList(),
            <Object?>[style.name],
          );
        }
      }

      // Windows startup ALWAYS syncs all 4 styles including auto.
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
      for (final style in EhAppIconStyle.values) {
        calls.clear();
        await box.put(EhSettingService.appIconStyleKey, style.name);
        final reopened = EhSettingService()..initAppIconPreference();
        await Future<void>.delayed(Duration.zero);
        expect(reopened.appIconStyle, style);
        expect(calls.map((c) => c.arguments).toList(), <Object?>[style.name]);
      }
    },
  );

  testWidgets(
    'LayoutSettingList switches all 4 App Icon styles via MethodChannel and handles 320px width with textScale 2.0',
    (tester) async {
      Get.put<TagTransController>(_TagTransStub());
      final settings = Get.find<EhSettingService>();
      expect(settings.appIconStyle, EhAppIconStyle.auto);

      final List<MethodCall> calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AppIconService.channel,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          AppIconService.channel,
          null,
        ),
      );

      Widget buildList({
        required Locale locale,
        double textScale = 1.0,
      }) {
        return CupertinoApp(
          locale: locale,
          supportedLocales: L10n.delegate.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            L10n.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: CupertinoPageScaffold(
            child: CustomScrollView(
              slivers: <Widget>[
                LayoutSettingList(),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildList(locale: const Locale('zh', 'CN')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('setting-app-icon-selector')),
        findsOneWidget,
      );
      expect(find.text('应用图标'), findsOneWidget);
      expect(find.text('自适应'), findsOneWidget);
      expect(find.text('凝脂白'), findsOneWidget);
      expect(find.text('曜石黑'), findsOneWidget);
      expect(find.text('紫韵经典'), findsOneWidget);

      final autoFinder =
          find.byKey(const ValueKey<String>('app-icon-option-auto'));
      final lightFinder =
          find.byKey(const ValueKey<String>('app-icon-option-light'));
      final darkFinder =
          find.byKey(const ValueKey<String>('app-icon-option-dark'));
      final purpleFinder =
          find.byKey(const ValueKey<String>('app-icon-option-purple'));

      await tester.ensureVisible(lightFinder);
      await tester.tap(lightFinder);
      await tester.pumpAndSettle();
      expect(settings.appIconStyle, EhAppIconStyle.light);

      await tester.ensureVisible(darkFinder);
      await tester.tap(darkFinder);
      await tester.pumpAndSettle();
      expect(settings.appIconStyle, EhAppIconStyle.dark);

      await tester.ensureVisible(purpleFinder);
      await tester.tap(purpleFinder);
      await tester.pumpAndSettle();
      expect(settings.appIconStyle, EhAppIconStyle.purple);

      await tester.ensureVisible(autoFinder);
      await tester.tap(autoFinder);
      await tester.pumpAndSettle();
      expect(settings.appIconStyle, EhAppIconStyle.auto);

      expect(calls.every((c) => c.method == 'setAppIcon'), isTrue);
      expect(
        calls.map((c) => c.arguments).toList(),
        <Object?>['light', 'dark', 'purple', 'auto'],
      );
      expect(tester.takeException(), isNull);

      // Accessibility verification: 320px split-pane width + textScale 2.0.
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(320 * 3, 874 * 3);
      addTearDown(tester.view.reset);

      for (final locale in const <Locale>[Locale('zh', 'CN'), Locale('en')]) {
        await tester.pumpWidget(buildList(locale: locale, textScale: 2.0));
        await tester.pumpAndSettle();

        final selectorFinder = find.byKey(
          const ValueKey<String>('setting-app-icon-selector'),
        );
        await tester.ensureVisible(selectorFinder);
        await tester.pumpAndSettle();

        expect(selectorFinder, findsOneWidget);
        expect(autoFinder, findsOneWidget);
        expect(lightFinder, findsOneWidget);
        expect(darkFinder, findsOneWidget);
        expect(purpleFinder, findsOneWidget);
        if (locale.languageCode == 'zh') {
          expect(find.text('应用图标'), findsOneWidget);
          expect(find.text('自适应'), findsOneWidget);
          expect(find.text('凝脂白'), findsOneWidget);
          expect(find.text('曜石黑'), findsOneWidget);
          expect(find.text('紫韵经典'), findsOneWidget);
        } else {
          expect(find.text('App Icon'), findsOneWidget);
          expect(find.text('Auto'), findsOneWidget);
          expect(find.text('Light'), findsOneWidget);
          expect(find.text('Dark'), findsOneWidget);
          expect(find.text('Classic Purple'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'LoginPage maps all 4 App Icon styles cleanly in desktop and mobile layouts',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FlutterGlassRuntime.debugAvailable = false;
      addTearDown(() => FlutterGlassRuntime.debugAvailable = null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AppIconService.channel,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          AppIconService.channel,
          null,
        ),
      );
      Get.put<AuthSessionService>(
        AuthSessionService(traceProbe: () async => null),
      );
      Get.put<UserController>(_UserStub());
      Get.put<LoginController>(_LoginStub());
      final settings = Get.find<EhSettingService>();

      // Desktop wide split layout (macOS dark + light)
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(1200 * 2, 760 * 2);
      addTearDown(tester.view.reset);

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
            home: const LoginPage(),
          ),
        );
        await tester.pump();

        final logoFinder = find.byType(EhFeAppLogo);
        expect(logoFinder, findsOneWidget);
        expect(
          tester.widget<EhFeAppLogo>(logoFinder).style,
          EhFeLogoStyle.monochrome,
        );
        expect(tester.getSize(logoFinder), const Size(54, 54));
        expect(find.text('EH'), findsNothing);
        expect(tester.takeException(), isNull);
      }

      // Dynamically tracks light, dark, purple, and auto icon preferences.
      final expectedMapping = <EhAppIconStyle, EhFeLogoStyle>{
        EhAppIconStyle.light: EhFeLogoStyle.lightGlass,
        EhAppIconStyle.dark: EhFeLogoStyle.darkGlass,
        EhAppIconStyle.purple: EhFeLogoStyle.brandSquircle,
        EhAppIconStyle.auto: EhFeLogoStyle.monochrome,
      };
      for (final entry in expectedMapping.entries) {
        await settings.setAppIconStyle(entry.key);
        await tester.pump();
        expect(
          tester.widget<EhFeAppLogo>(find.byType(EhFeAppLogo)).style,
          entry.value,
        );
        expect(tester.takeException(), isNull);
      }

      // Mobile iOS curtain layout
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      await tester.pumpWidget(
        CupertinoApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: L10n.delegate.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            L10n.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: const CupertinoThemeData(brightness: Brightness.dark),
          home: const LoginPage(),
        ),
      );
      await tester.pump();

      final mobileLogoFinder = find.byType(EhFeAppLogo);
      expect(mobileLogoFinder, findsOneWidget);
      expect(
        tester.widget<EhFeAppLogo>(mobileLogoFinder).style,
        EhFeLogoStyle.monochrome,
      );
      expect(tester.getSize(mobileLogoFinder), const Size(52, 52));
      expect(find.text('EH'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _TagTransStub extends TagTransController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _UserStub extends UserController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _LoginStub extends LoginController {
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
