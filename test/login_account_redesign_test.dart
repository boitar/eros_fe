import 'dart:async';
import 'dart:io';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/parser/user_profile_parser.dart';
import 'package:eros_fe/common/service/auth_session_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/models/index.dart';
import 'package:eros_fe/network/app_dio/exception.dart';
import 'package:eros_fe/pages/login/controller/login_controller.dart';
import 'package:eros_fe/pages/login/view/login_page.dart';
import 'package:eros_fe/pages/login/widget/login_material_chrome.dart';
import 'package:eros_fe/pages/setting/webview/cf_verify_in.dart';
import 'package:eros_fe/utils/cf_verification.dart';
import 'package:eros_fe/widget/auth_expiry_top_banner.dart';
import 'package:eros_fe/widget/flutter_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestSettings extends GetxService implements EhSettingService {
  _TestSettings({bool initialGlass = true}) : _glass = initialGlass.obs;
  final RxBool _glass;
  final Rx<GlassMaterial> _material = GlassMaterial.liquid.obs;
  final RxBool _siteEx = false.obs;
  final RxBool _pureDark = false.obs;

  @override
  bool get liquidGlass => _glass.value;
  @override
  set liquidGlass(bool value) => _glass.value = value;

  @override
  GlassMaterial get glassMaterial => _material.value;
  @override
  set glassMaterial(GlassMaterial value) => _material.value = value;

  @override
  bool get liquidGlassMaterial => glassMaterial.isLiquid;

  @override
  bool get isPureDarkTheme => false;

  @override
  RxBool get pureDarkThemeObs => _pureDark;

  @override
  RxBool get isSiteEx => _siteEx;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserController extends GetxController implements UserController {
  _FakeUserController({this.loggedIn = true});

  final bool loggedIn;

  @override
  final Rx<User> user = const User(
    username: 'miyuu',
    nickName: 'miyuu',
    memberId: '123456',
    passHash: '0123456789abcdef0123456789abcdef',
    igneous: 'a1b2c3d4e5f60718',
  ).obs;

  @override
  bool get isLogin =>
      loggedIn &&
      (user.value.memberId?.isNotEmpty ?? false) &&
      (user.value.passHash?.isNotEmpty ?? false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
    Get.put<EhSettingService>(_TestSettings(), permanent: true);
    Get.put<ThemeService>(ThemeService(), permanent: true);
  });

  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    FlutterGlassRuntime.debugAvailable = null;
    Get.reset();
  });

  group('ExitTraceInfo & Cloudflare detection', () {
    test('parses Cloudflare trace and flags Asian exit nodes', () {
      final jp = ExitTraceInfo.tryParse(
        'fl=448f588\nh=forums.e-hentai.org\nloc=JP\ncolo=NRT\nwarp=off\n',
        nowMs: 1700000000000,
      );
      expect(jp, isNotNull);
      expect(jp!.isAsianRegion, isTrue);
      expect(jp.displayLabel(zh: true), '日本 · 东京');
      expect(jp.compactWithColo(zh: true), '日本 · 东京（NRT）');

      final us = ExitTraceInfo.tryParse(
        'loc=US\ncolo=LAX\n',
        nowMs: 1700000000000,
      );
      expect(us, isNotNull);
      expect(us!.isAsianRegion, isFalse);
      expect(us.displayLabel(zh: true), '美国 · 洛杉矶');
    });

    test('recognizes cf-mitigated header and CloudflareChallengeException', () {
      expect(isCloudflareMitigatedHeader('challenge'), isTrue);
      expect(isCloudflareMitigatedHeader('none'), isFalse);
      expect(isCfBlockedError(CloudflareChallengeException()), isTrue);
    });

    test('CfVerification distinguishes mystery igneous from real token', () {
      final denied = CfVerification(
        <Cookie>[
          Cookie('ipb_member_id', '123456'),
          Cookie('ipb_pass_hash', '0123456789abcdef0123456789abcdef'),
          Cookie('igneous', 'mystery'),
          Cookie('cf_clearance', 'cf_token'),
        ],
        'TestUA/1.0',
        exVisited: true,
      );
      expect(denied.hasLoginSession, isTrue);
      expect(denied.isComplete, isTrue);
      expect(denied.hasValidIgneous, isFalse);

      final granted = CfVerification(
        <Cookie>[
          Cookie('ipb_member_id', '123456'),
          Cookie('ipb_pass_hash', '0123456789abcdef0123456789abcdef'),
          Cookie('igneous', 'a1b2c3d4e5f60718'),
        ],
        'TestUA/1.0',
      );
      expect(granted.hasValidIgneous, isTrue);
    });
  });

  group('30-day countdown & in-app top banner cooldown', () {
    test('transitions across valid -> expiring -> expired and respects 24h cooldown', () {
      DateTime fakeNow = DateTime(2026, 11, 1, 12, 0);
      final service = AuthSessionService(
        clock: () => fakeNow,
        traceProbe: () async => const ExitTraceInfo(
          countryCode: 'US',
          colo: 'LAX',
          fetchedAtMs: 1,
        ),
      );
      service.onInit();

      service.recordAuthSuccess(
        memberId: '987654',
        method: AuthMethodKind.password,
        hasExAccess: true,
        verifiedCf: true,
      );

      expect(service.snapshot.value.remainingDaysAt(fakeNow), 30);
      expect(
        service.snapshot.value.statusAt(fakeNow),
        AuthCountdownStatus.valid,
      );
      expect(service.shouldShowStartupBanner(isLoggedIn: true), isFalse);

      fakeNow = DateTime(2026, 11, 29, 13, 0);
      service.resetSessionBannerFlag();
      expect(service.snapshot.value.remainingDaysAt(fakeNow), 2);
      expect(
        service.snapshot.value.statusAt(fakeNow),
        AuthCountdownStatus.expiring,
      );
      expect(service.shouldShowStartupBanner(isLoggedIn: true), isTrue);

      service.dismissStartupBannerForCooldown();
      service.resetSessionBannerFlag();
      fakeNow = DateTime(2026, 11, 30, 1, 0);
      expect(service.shouldShowStartupBanner(isLoggedIn: true), isFalse);

      fakeNow = DateTime(2026, 11, 30, 14, 0);
      expect(service.shouldShowStartupBanner(isLoggedIn: true), isTrue);

      fakeNow = DateTime(2026, 12, 3, 12, 0);
      service.resetSessionBannerFlag();
      expect(service.snapshot.value.remainingDaysAt(fakeNow), 0);
      expect(
        service.snapshot.value.statusAt(fakeNow),
        AuthCountdownStatus.expired,
      );
    });

    test('parses Cookie clipboard formats accurately', () {
      const sampleIg = 'a1b2c3d4e5f60718';
      final kv = LoginController.parseCookieFromText(
        'ipb_member_id=7654321; ipb_pass_hash=fedcba9876543210fedcba9876543210; igneous=$sampleIg',
      );
      expect(kv['ipb_member_id'], '7654321');
      expect(kv['ipb_pass_hash'], 'fedcba9876543210fedcba9876543210');
      expect(kv['igneous'], sampleIg);
    });

    testWidgets('slides down in-app top banner when session is expiring',
        (tester) async {
      DateTime fakeNow = DateTime(2026, 11, 1, 10, 0);
      Get.put<UserController>(_FakeUserController(), permanent: true);
      final authService = Get.put<AuthSessionService>(
        AuthSessionService(clock: () => fakeNow, traceProbe: () async => null),
        permanent: true,
      );
      authService.recordAuthSuccess(
        memberId: '123456',
        method: AuthMethodKind.password,
        hasExAccess: true,
      );
      // Advance 28 days so 2 days remain (<= 3 days threshold)
      fakeNow = DateTime(2026, 11, 29, 12, 0);
      authService.resetSessionBannerFlag();

      await tester.pumpWidget(
        const CupertinoApp(
          locale: Locale('zh', 'CN'),
          supportedLocales: <Locale>[Locale('zh', 'CN'), Locale('en', 'US')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: AuthExpiryTopBannerHost(
            launchDelay: Duration(milliseconds: 50),
            autoHideDuration: Duration(seconds: 2),
            child: CupertinoPageScaffold(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.byKey(const ValueKey<String>('auth-expiry-top-banner')),
        findsOneWidget,
      );
      expect(find.textContaining('2 天后到期'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('auth-expiry-banner-action')),
        findsOneWidget,
      );

      // Auto-hides cleanly after duration
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('auth-expiry-top-banner')),
        findsNothing,
      );
    });
  });

  group('Three-state material & cross-platform widgets', () {
    for (final materialMode in <({bool enabled, GlassMaterial mat})>[
      (enabled: true, mat: GlassMaterial.liquid),
      (enabled: true, mat: GlassMaterial.frosted),
      (enabled: false, mat: GlassMaterial.frosted),
    ]) {
      testWidgets(
        'renders LoginFloatingMaterial & CoverMosaicCurtain in enabled=${materialMode.enabled} ${materialMode.mat}',
        (tester) async {
          PlatformCapabilities.debugHostPlatformOverride =
              TargetPlatform.android;
          FlutterGlassRuntime.debugAvailable = false;
          final settings = Get.find<EhSettingService>();
          settings.liquidGlass = materialMode.enabled;
          settings.glassMaterial = materialMode.mat;

          await tester.pumpWidget(
            GlassCapabilityScope(
              child: GlassPreference(
                enabled: materialMode.enabled,
                material: materialMode.mat,
                child: CupertinoApp(
                  home: CupertinoPageScaffold(
                    child: Stack(
                      children: <Widget>[
                        const SizedBox(
                          height: 240,
                          width: 360,
                          child: CoverMosaicCurtain(columns: 3),
                        ),
                        LoginFloatingCircleButton(
                          icon: CupertinoIcons.chevron_back,
                          onPressed: () {},
                        ),
                        LoginTintedActionPill(
                          label: '重新认证',
                          onPressed: () {},
                        ),
                        const LoginStepChainCard(
                          states: <LoginStepState>[
                            LoginStepState.done,
                            LoginStepState.running,
                            LoginStepState.waiting,
                            LoginStepState.waiting,
                          ],
                          metas: <String?>['LAX · 120 ms', null, null, null],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('重新认证'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('CfVerifyWebView layout geometry & flow mode separation', () {
    testWidgets(
      'Desktop interactive Web Sign-in dialog uses non-overlapping 3-band layout, wider size, and manual login copy even when window has top safe area',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
        FlutterGlassRuntime.debugAvailable = false;
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        Get.put<UserController>(_FakeUserController(), permanent: true);
        final authService = Get.put<AuthSessionService>(
          AuthSessionService(traceProbe: () async => null),
          permanent: true,
        );
        authService.currentExit.value = const ExitTraceInfo(
          countryCode: 'JP',
          colo: 'NRT',
          fetchedAtMs: 1,
        );

        await tester.pumpWidget(
          GetCupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const <Locale>[
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              // Simulate MacOSWindowChrome injecting unified titlebar safeTop = 40
              return MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(top: 40),
                  viewPadding: media.viewPadding.copyWith(top: 40),
                ),
                child: child!,
              );
            },
            home: CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  key: const ValueKey<String>('trigger-web-login'),
                  child: const Text('打开网页登录'),
                  onPressed: () {
                    openCfVerification(
                      interactiveWebLogin: true,
                      debugWebViewBuilder: (_) => const ColoredBox(
                        key: ValueKey<String>('mock-webview'),
                        color: Color(0xFFFFFFFF),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey<String>('trigger-web-login')));
        await tester.pumpAndSettle();

        final dialogRect = tester.getRect(
          find.byKey(const ValueKey<String>('desktop-web-auth-dialog')),
        );
        final topBarRect = tester.getRect(
          find.byKey(const ValueKey<String>('web-auth-top-bar')),
        );
        final webSlotRect = tester.getRect(
          find.byKey(const ValueKey<String>('web-auth-webview-slot')),
        );
        final bottomDockRect = tester.getRect(
          find.byKey(const ValueKey<String>('web-auth-bottom-dock')),
        );

        // Wide comfortable desktop dialog for full forum login page
        expect(dialogRect.width, 820.0);
        expect(dialogRect.height, 660.0);

        // Top bar, WebView, and bottom dock must never overlap or clip outside dialog
        expect(topBarRect.top, greaterThanOrEqualTo(dialogRect.top));
        expect(topBarRect.height, 48.0);
        expect(topBarRect.bottom, lessThanOrEqualTo(webSlotRect.top));
        expect(webSlotRect.height, greaterThan(450.0));
        expect(webSlotRect.bottom, lessThanOrEqualTo(bottomDockRect.top));
        expect(bottomDockRect.bottom, lessThanOrEqualTo(dialogRect.bottom));

        // Copy must reflect manual Web Sign-in rather than auto credential injection
        expect(find.textContaining('网页登录 · forums.e-hentai.org'), findsOneWidget);
        expect(find.text('登录论坛'), findsOneWidget);
        expect(find.text('获取里站权限'), findsOneWidget);
        expect(find.text('关闭窗口'), findsOneWidget);
        expect(find.textContaining('请在页面中登录 E-Hentai 论坛'), findsOneWidget);
        expect(find.text('自动登录'), findsNothing);
        expect(find.textContaining('会自动提交账号'), findsNothing);

        // Trouble toggle expands helper chips cleanly
        await tester.tap(
          find.byKey(const ValueKey<String>('web-auth-trouble-toggle')),
        );
        await tester.pump();
        expect(find.text('清除站点数据并刷新'), findsOneWidget);

        // Close button dismisses dialog cleanly
        await tester.tap(
          find.byKey(const ValueKey<String>('web-auth-close-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('desktop-web-auth-dialog')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Desktop auto-credential CF check dialog uses compact size and auto-login copy',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
        FlutterGlassRuntime.debugAvailable = false;
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        Get.put<UserController>(_FakeUserController(), permanent: true);
        Get.put<AuthSessionService>(
          AuthSessionService(traceProbe: () async => null),
          permanent: true,
        );

        await tester.pumpWidget(
          GetCupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const <Locale>[Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  key: const ValueKey<String>('trigger-cf-auto'),
                  child: const Text('打开验证'),
                  onPressed: () {
                    openCfVerification(
                      username: 'miyuu',
                      password: 'secret',
                      debugWebViewBuilder: (_) => const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey<String>('trigger-cf-auto')));
        await tester.pumpAndSettle();

        final dialogRect = tester.getRect(
          find.byKey(const ValueKey<String>('desktop-web-auth-dialog')),
        );
        expect(dialogRect.width, 520.0);
        expect(dialogRect.height, 580.0);
        expect(find.textContaining('安全验证 · forums.e-hentai.org'), findsOneWidget);
        expect(find.text('完成验证'), findsOneWidget);
        expect(find.text('自动登录'), findsOneWidget);
        expect(find.textContaining('会自动提交账号并返回'), findsOneWidget);
      },
    );

    testWidgets(
      'iOS full-screen CfVerifyWebView expands Stack to full height and hides bottom dock when keyboard opens',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
        FlutterGlassRuntime.debugAvailable = false;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(top: 54, bottom: 34);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetPadding();
          tester.view.resetViewInsets();
        });

        Get.put<UserController>(_FakeUserController(), permanent: true);
        Get.put<AuthSessionService>(
          AuthSessionService(traceProbe: () async => null),
          permanent: true,
        );

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const <Locale>[Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: CfVerifyWebView(
              interactiveWebLogin: true,
              debugWebViewBuilder: (_) => const SizedBox.expand(),
            ),
          ),
        );
        await tester.pump();

        final webSlotRect = tester.getRect(
          find.byKey(const ValueKey<String>('web-auth-webview-slot')),
        );
        final topBarRect = tester.getRect(
          find.byKey(const ValueKey<String>('web-auth-top-bar')),
        );
        final bottomDockRect = tester.getRect(
          find.byKey(const ValueKey<String>('web-auth-bottom-dock')),
        );

        expect(webSlotRect.size, const Size(390, 844));
        expect(topBarRect.bottom, lessThan(120));
        expect(bottomDockRect.top, greaterThan(620));
        expect(bottomDockRect.bottom, lessThanOrEqualTo(844));

        // Simulate soft keyboard opening for forum form input
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('web-auth-bottom-dock')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Android Web Sign-in shows Web Sign-in header title and hides bottom sheet when keyboard opens',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
        FlutterGlassRuntime.debugAvailable = false;
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
        });

        Get.put<UserController>(_FakeUserController(), permanent: true);
        Get.put<AuthSessionService>(
          AuthSessionService(traceProbe: () async => null),
          permanent: true,
        );

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const <Locale>[Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: CfVerifyWebView(
              interactiveWebLogin: true,
              debugWebViewBuilder: (_) => const SizedBox.expand(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('网页登录'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('web-auth-bottom-dock')),
          findsOneWidget,
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('web-auth-bottom-dock')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'manual Web Sign-in waits for stale-cookie cleanup before loading the page',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
        FlutterGlassRuntime.debugAvailable = false;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        Get.put<UserController>(
          _FakeUserController(loggedIn: false),
          permanent: true,
        );
        Get.put<AuthSessionService>(
          AuthSessionService(traceProbe: () async => null),
          permanent: true,
        );

        final cleanup = Completer<void>();
        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const <Locale>[Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: CfVerifyWebView(
              interactiveWebLogin: true,
              debugCookieCleanup: () => cleanup.future,
              debugWebViewBuilder: (_) => const ColoredBox(
                key: ValueKey<String>('mock-webview-after-cleanup'),
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('mock-webview-after-cleanup')),
          findsNothing,
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          find.byKey(const ValueKey<String>('mock-webview-after-cleanup')),
          findsNothing,
        );

        cleanup.complete();
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('mock-webview-after-cleanup')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'manual Web Sign-in stays closed after cleanup failure and retries cleanup',
      (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
        FlutterGlassRuntime.debugAvailable = false;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        Get.put<UserController>(
          _FakeUserController(loggedIn: false),
          permanent: true,
        );
        Get.put<AuthSessionService>(
          AuthSessionService(traceProbe: () async => null),
          permanent: true,
        );

        var cleanupCalls = 0;
        Future<void> cleanup() async {
          cleanupCalls++;
          if (cleanupCalls == 1) {
            throw StateError('cleanup failed');
          }
        }

        await tester.pumpWidget(
          CupertinoApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const <Locale>[Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: CfVerifyWebView(
              interactiveWebLogin: true,
              debugCookieCleanup: cleanup,
              debugWebViewBuilder: (_) => const ColoredBox(
                key: ValueKey<String>('mock-webview-after-cleanup'),
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(cleanupCalls, 1);
        expect(
          find.byKey(const ValueKey<String>('web-auth-cookie-cleanup-error')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('mock-webview-after-cleanup')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('web-auth-cookie-cleanup-retry')),
        );
        await tester.pump();

        expect(cleanupCalls, 2);
        expect(
          find.byKey(const ValueKey<String>('mock-webview-after-cleanup')),
          findsOneWidget,
        );
      },
    );
  });

  group('LoginController verification window recovery', () {
    test(
      'both verification entry points reset the busy flag after an error',
      () async {
        Get.put<UserController>(_FakeUserController(), permanent: true);

        Future<CfVerification?> failToOpen({
          required String? username,
          required String? password,
          required bool interactiveWebLogin,
          required bool acquireExSession,
        }) async {
          throw StateError('route push failed');
        }

        final controller = LoginController(verificationOpener: failToOpen);

        await controller.handOnWeblogin();
        expect(controller.verifyWindowOpen, isFalse);
        expect(controller.inlineError, isNotEmpty);

        await controller.continueWithCfBrowser();
        expect(controller.verifyWindowOpen, isFalse);
        expect(controller.inlineError, isNotEmpty);

        controller.onClose();
      },
    );
  });
}
