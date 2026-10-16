import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/debug/offline_glass.dart';
import 'package:eros_fe/widget/liquid_glass_scroll_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('probe follows silent layout corrections after scrolling settles',
      (tester) async {
    Get.put<EhSettingService>(_Settings());
    final controller = ScrollController();
    String label() => tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((widget) =>
            widget.properties.identifier == 'offline-glass-probe-gallery')
        .properties
        .label!;
    try {
      await tester.pumpWidget(CupertinoApp(
        home: OfflineGlassProbe(
          route: 'gallery',
          page: () => 'corrected',
          scrollController: controller,
          firstCardTop: () => 0,
          child: CustomScrollView(controller: controller, slivers: const [
            SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(label(), contains('outer=0.0'));
      // Refresh slivers use layout corrections that do not dispatch scroll
      // notifications. A quiet page still needs a fresh observation.
      controller.position.correctBy(38);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(controller.position.pixels, 38);
      expect(label(), contains('outer=38.0'));
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      Get.reset();
    }
  });

  testWidgets('probe remeasures a cached page when it becomes active',
      (tester) async {
    Get.put<EhSettingService>(_Settings());
    final controller = ScrollController();
    final active = ValueNotifier(false);
    final first = GlobalKey();
    String label() => tester
        .widgetList<Semantics>(find.byType(Semantics, skipOffstage: false))
        .firstWhere((widget) =>
            widget.properties.identifier == 'offline-glass-probe-gallery')
        .properties
        .label!;
    try {
      await tester.pumpWidget(CupertinoApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          child: OfflineGlassProbe(
            route: 'gallery',
            page: () => 'cached',
            scrollController: controller,
            firstCardTop: () => liquidGlassScreenTop(first),
            child: CustomScrollView(
              controller: controller,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(top: 60),
                  sliver: SliverToBoxAdapter(
                      child: SizedBox(key: first, height: 1000)),
                ),
              ],
            ),
          ),
          builder: (context, enabled, child) => Offstage(
            offstage: !enabled,
            child: TickerMode(enabled: enabled, child: child!),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(label(), contains('first=offscreen'));
      active.value = true;
      await tester.pumpAndSettle();
      expect(controller.position.pixels, 0);
      expect(label(), contains('first=60.0'));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      active.dispose();
      Get.reset();
    }
  });

  testWidgets(
      'probe observes asynchronously laid-out first card without scrolling',
      (tester) async {
    Get.put<EhSettingService>(_Settings());
    final controller = ScrollController();
    final loaded = ValueNotifier(false);
    final first = GlobalKey();
    String label() => tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((widget) =>
            widget.properties.identifier == 'offline-glass-probe-gallery')
        .properties
        .label!;
    try {
      await tester.pumpWidget(CupertinoApp(
        home: OfflineGlassProbe(
          route: 'gallery',
          page: () => 'async',
          scrollController: controller,
          firstCardTop: () => liquidGlassScreenTop(first),
          child: ValueListenableBuilder<bool>(
            valueListenable: loaded,
            builder: (context, ready, child) => CustomScrollView(
              controller: controller,
              slivers: [
                if (ready)
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 60),
                    sliver: SliverToBoxAdapter(
                        child: SizedBox(key: first, height: 1000)),
                  )
                else
                  const SliverFillRemaining(child: SizedBox()),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(label(), contains('first=offscreen'));
      loaded.value = true;
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
      expect(controller.position.pixels, 0);
      expect(label(), contains('first=60.0'));
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      loaded.dispose();
      Get.reset();
    }
  });
}

class _Settings extends GetxService implements EhSettingService {
  final glass = false.obs;
  @override
  bool get liquidGlass => glass.value;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}
