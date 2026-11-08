import 'dart:io';

import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/index.dart';
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
  final _material = GlassMaterial.liquid.obs;
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
  const switchKey = LiquidGlassSettingsSection.switchKey;
  const materialKey = LiquidGlassSettingsSection.materialKey;

  // HiveHelper keeps its boxes in static fields, so every profile test
  // shares one Hive session.
  late Directory hiveDir;
  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('eros-glass-settings-');
    Hive.init(hiveDir.path);
    await Hive.openBox<String>(configBox);
  });
  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

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
      expect(find.text('Glass effect'), findsOneWidget);
      // The material only applies while the glass effect is on.
      expect(find.byKey(materialKey), findsNothing);
      expect(GlassMode.resolve(enabled: settings.liquidGlass), GlassMode.off);
      await tester.tap(find.byKey(switchKey));
      await tester.pumpAndSettle();
      expect(settings.liquidGlass, isTrue);
      expect(find.byKey(materialKey), findsOneWidget);
      expect(find.text('Glass material'), findsOneWidget);
      // The old "system Liquid Glass appearance" switch is gone everywhere.
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      // Only the UIKit renderer has system bars that ignore the material.
      expect(
          find.textContaining('iPhone Duo'),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing);
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
    final labels = <Locale, (String, String, String)>{
      const Locale('en'): ('Glass effect', 'Liquid glass', 'Frosted glass'),
      const Locale('ja'): ('ガラス効果', 'リキッドガラス', 'すりガラス'),
      const Locale('ko', 'KR'): ('유리 효과', '리퀴드 글래스', '젖빛 유리'),
      const Locale('ru'): ('Эффект стекла', 'Жидкое стекло', 'Матовое стекло'),
      const Locale('zh', 'CN'): ('玻璃效果', '液态玻璃', '毛玻璃'),
      const Locale('zh', 'TW'): ('玻璃效果', '液態玻璃', '毛玻璃'),
    };
    for (final entry in labels.entries) {
      final strings = await L10n.load(entry.key);
      expect(strings.glass_effect, entry.value.$1);
      expect(strings.glass_material_liquid, entry.value.$2);
      expect(strings.glass_material_frosted, entry.value.$3);
      for (final text in [
        strings.liquid_glass_description,
        strings.glass_material,
        strings.glass_material_liquid_detail,
        strings.glass_material_frosted_detail,
        strings.glass_system_bar_note,
      ]) {
        expect(text, isNotEmpty, reason: '${entry.key}');
      }
    }
  });

  test('new and upgraded profiles preserve saved choices and persist toggles',
      () async {
    final originalProfile = Global.profile;
    addTearDown(() => Global.profile = originalProfile);
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
          settings.glassMaterial = GlassMaterial.frosted;
          expect(NativeNavigationBridge.barMaterial.value, NativeBarMaterial.blur);
          settings.glassMaterial = GlassMaterial.liquid;
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

  test('the material migrates from the old system appearance switch', () {
    expect(GlassMaterial.migrate(), GlassMaterial.liquid);
    expect(GlassMaterial.migrate(legacyFollowSystem: true), GlassMaterial.liquid);
    expect(
        GlassMaterial.migrate(legacyFollowSystem: false), GlassMaterial.frosted);
    // A stored material wins over the legacy switch.
    expect(GlassMaterial.migrate(stored: 'liquid', legacyFollowSystem: false),
        GlassMaterial.liquid);
    expect(GlassMaterial.migrate(stored: 'frosted', legacyFollowSystem: true),
        GlassMaterial.frosted);
    // An unknown value from a newer build falls back like a missing one.
    expect(GlassMaterial.migrate(stored: 'crystal', legacyFollowSystem: false),
        GlassMaterial.frosted);
  });

  test('profiles restore, migrate and persist the glass material', () async {
    final originalProfile = Global.profile;
    addTearDown(() => Global.profile = originalProfile);
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    final cases = <(String?, bool?), GlassMaterial>{
      (null, null): GlassMaterial.liquid,
      (null, true): GlassMaterial.liquid,
      (null, false): GlassMaterial.frosted,
      ('frosted', true): GlassMaterial.frosted,
      ('liquid', false): GlassMaterial.liquid,
    };
    for (final entry in cases.entries) {
      Get.reset();
      Global.profile = kDefProfile.copyWith(
          ehConfig: kDefEhConfig.copyWith(
        liquidGlass: true.oN,
        glassMaterial: entry.key.$1.oN,
        liquidGlassFollowSystemTransparency: entry.key.$2.oN,
      ));
      Get.put<LocaleService>(LocaleService());
      final settings = EhSettingService()..initLiquidGlassPreference();
      expect(settings.glassMaterial, entry.value, reason: '${entry.key}');
      expect(NativeNavigationBridge.barMaterial.value,
          entry.value.isLiquid ? NativeBarMaterial.glass : NativeBarMaterial.blur);

      final next = entry.value.isLiquid
          ? GlassMaterial.frosted
          : GlassMaterial.liquid;
      settings.glassMaterial = next;
      expect(settings.liquidGlassMaterial, next.isLiquid);
      expect(NativeNavigationBridge.barMaterial.value,
          next.isLiquid ? NativeBarMaterial.glass : NativeBarMaterial.blur);
      final saved = hiveHelper.profile.ehConfig;
      expect(saved.glassMaterial, next.name);
      // Older builds read the legacy switch and must open the same material.
      expect(saved.liquidGlassFollowSystemTransparency, next.isLiquid);

      // Round-trips through JSON like a real profile.
      final restored = EhConfig.fromJson(saved.toJson());
      Get.reset();
      Global.profile = kDefProfile.copyWith(ehConfig: restored);
      Get.put<LocaleService>(LocaleService());
      final reopened = EhSettingService()..initLiquidGlassPreference();
      expect(reopened.glassMaterial, next);
    }
  });
}
