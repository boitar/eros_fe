import 'dart:io';

import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/setting/layout_setting_page.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class _Settings extends GetxService implements EhSettingService {
  _Settings(bool initial) : _glass = initial.obs;
  final RxBool _glass;
  @override
  bool get liquidGlass => _glass.value;
  @override
  set liquidGlass(bool value) => _glass.value = value;
  @override
  bool get isPureDarkTheme => false;
  @override
  bool get liquidGlassFollowSystemTransparency => true;
  @override
  LiquidGlassTopBarLayout get liquidGlassTopBarLayout =>
      LiquidGlassTopBarLayout.twoRow;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const platforms = [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows
  ];
  const switchKey = ValueKey('liquid-glass-style-switch');

  tearDown(() async {
    PlatformCapabilities.debugHostPlatformOverride = null;
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
  });

  for (final platform in platforms) {
    testWidgets('$platform displays the switch and updates GlassMode',
        (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      final settings = _Settings(false);
      Get.put<EhSettingService>(settings);
      await tester.pumpWidget(CupertinoApp(
        localizationsDelegates: const [L10n.delegate],
        home: CupertinoPageScaffold(
            child: CustomScrollView(slivers: [
          LiquidGlassSettingsSection(settings: settings),
        ])),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(switchKey), findsOneWidget);
      expect(find.text('Liquid glass style'), findsOneWidget);
      expect(GlassMode.resolve(enabled: settings.liquidGlass), GlassMode.off);
      await tester.tap(find.byKey(switchKey));
      await tester.pumpAndSettle();
      expect(settings.liquidGlass, isTrue);
      expect(
          GlassMode.resolve(enabled: settings.liquidGlass),
          platform == TargetPlatform.iOS
              ? GlassMode.native
              : GlassMode.flutter);
      await tester.tap(find.byKey(switchKey));
      await tester.pumpAndSettle();
      expect(GlassMode.resolve(enabled: settings.liquidGlass), GlassMode.off);
    });
  }

  testWidgets('unsupported Linux does not expose the switch', (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.linux;
    final settings = _Settings(false);
    await tester.pumpWidget(CupertinoApp(
      localizationsDelegates: const [L10n.delegate],
      home: CupertinoPageScaffold(
          child: CustomScrollView(slivers: [
        LiquidGlassSettingsSection(settings: settings),
      ])),
    ));
    expect(find.byKey(switchKey), findsNothing);
  });

  test('glass labels are available in every supported locale', () async {
    final labels = <Locale, String>{
      const Locale('en'): 'Liquid glass style',
      const Locale('ja'): 'リキッドガラスのスタイル',
      const Locale('ko', 'KR'): '리퀴드 글래스 스타일',
      const Locale('ru'): 'Стиль жидкого стекла',
      const Locale('zh', 'CN'): '液态玻璃风格',
      const Locale('zh', 'TW'): '液態玻璃風格',
    };
    for (final entry in labels.entries) {
      final strings = await L10n.load(entry.key);
      expect(strings.liquid_glass_style, entry.value);
      expect(strings.liquid_glass_description, isNotEmpty);
    }
  });

  test('new and upgraded profiles preserve saved choices and persist toggles',
      () async {
    final dir = await Directory.systemTemp.createTemp('eros-glass-settings-');
    final originalProfile = Global.profile;
    Hive.init(dir.path);
    await Hive.openBox<String>(configBox);
    addTearDown(() async {
      Global.profile = originalProfile;
      await Hive.close();
      await dir.delete(recursive: true);
    });
    for (final platform in platforms) {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      final expectedDefault = platform != TargetPlatform.iOS;
      expect(kDefEhConfig.liquidGlass, isNull);
      for (final saved in <bool?>[null, false, true]) {
        Get.reset();
        Global.profile = kDefProfile.copyWith(
            ehConfig: kDefEhConfig.copyWith(liquidGlass: saved.oN));
        Get.put<LocaleService>(LocaleService());
        final settings = EhSettingService()..initLiquidGlassPreference();
        expect(settings.liquidGlass, saved ?? expectedDefault,
            reason: '$platform, saved=$saved');
        // The iOS 27.1 native shell draws its bars from the same preference.
        expect(NativeNavigationBridge.barMaterial.value,
            settings.liquidGlass ? NativeBarMaterial.glass : NativeBarMaterial.opaque);
        settings.liquidGlass = !settings.liquidGlass;
        expect(NativeNavigationBridge.barMaterial.value,
            settings.liquidGlass ? NativeBarMaterial.glass : NativeBarMaterial.opaque);
        if (settings.liquidGlass) {
          settings.liquidGlassFollowSystemTransparency = false;
          expect(NativeNavigationBridge.barMaterial.value, NativeBarMaterial.blur);
          settings.liquidGlassFollowSystemTransparency = true;
        }
        expect(Global.profile.ehConfig.liquidGlass, settings.liquidGlass);
        expect(hiveHelper.profile.ehConfig.liquidGlass, settings.liquidGlass);
        final restored = hiveHelper.profile;
        Get.reset();
        Global.profile = restored;
        Get.put<LocaleService>(LocaleService());
        final reopened = EhSettingService()..initLiquidGlassPreference();
        expect(reopened.liquidGlass, restored.ehConfig.liquidGlass);
      }
    }
  });
}
