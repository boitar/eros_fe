import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/route_cover.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/pages/setting/setting_items/single_input_page.dart';
import 'package:eros_fe/pages/tab/view/home_page_large.dart';
import 'package:eros_fe/route/first_observer.dart';
import 'package:eros_fe/route/second_observer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('production navigators have one root and keep an editing route',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      Get.testMode = true;
      Get.put<LocaleService>(LocaleService());
      Get.put<EhSettingService>(_Settings());
      Get.put<ThemeService>(_Theme());
      final layout = Get.put<LayoutServices>(_Layout());
      final scroll = ScrollController();
      final geometry = ValueNotifier(
          const AdaptiveEnvironmentSnapshot(size: Size(900, 650)));
      addTearDown(scroll.dispose);
      addTearDown(geometry.dispose);
      addTearDown(Get.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = geometry.value.size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final list = CupertinoPageScaffold(
        child: ListView.builder(
          controller: scroll,
          itemExtent: 48,
          itemCount: 100,
          itemBuilder: (_, index) => Text('Gallery $index'),
        ),
      );

      await tester.pumpWidget(GetCupertinoApp(
        home: ValueListenableBuilder(
          valueListenable: geometry,
          builder: (_, environment, __) {
            layout.layoutMode =
                environment.isSplit ? LayoutMode.large : LayoutMode.small;
            return AdaptiveEnvironmentScope(
              snapshot: environment,
              child:
                  TabHomeLarge(split: environment.isSplit, primaryRoot: list),
            );
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(FirstNavigatorObserver().history, hasLength(1));
      expect(SecondNavigatorObserver().history, hasLength(1));
      expect(Get.nestedKey(1)!.currentState!.canPop(), isFalse);
      expect(Get.nestedKey(2)!.currentState!.canPop(), isFalse);
      expect(find.bySemanticsLabel('Gallery 0'), findsOneWidget);
      scroll.jumpTo(480);
      Get.to<void>(
        () => const SingleInputPage(title: 'Draft', initValue: 'Saved'),
        id: detailNavigatorId,
      );
      await tester.pumpAndSettle();
      final editor = tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!;
      editor.value = const TextEditingValue(
        text: 'Unsent draft',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 1, end: 5),
      );
      final value = editor.value;
      final route = SecondNavigatorObserver().history.last;
      for (var cycle = 0; cycle < 20; cycle++) {
        for (final size in [const Size(390, 844), const Size(900, 650)]) {
          tester.view.physicalSize = size;
          geometry.value = AdaptiveEnvironmentSnapshot(size: size);
          await tester.pumpAndSettle();
          expect(primaryNavigatorId, 1);
          expect(detailNavigatorId, 2);
          expect(SecondNavigatorObserver().history.last, same(route));
          expect(
              tester
                  .widget<CupertinoTextField>(find.byType(CupertinoTextField))
                  .controller,
              same(editor));
          expect(editor.value, value);
          expect(scroll.offset, 480);
          expect(tester.takeException(), isNull);
        }
      }
      tester.view.physicalSize = const Size(390, 844);
      geometry.value = const AdaptiveEnvironmentSnapshot(size: Size(390, 844));
      Get.nestedKey(1)!.currentState!.push(CupertinoPageRoute<void>(
            builder: (_) => const CupertinoPageScaffold(
                child: Center(child: Text('Primary search'))),
          ));
      await tester.pumpAndSettle();
      expect(layout.activePaneNavigatorId, 1);
      expect(find.text('Primary search'), findsOneWidget);
      Get.nestedKey(2)!.currentState!.push(CupertinoPageRoute<void>(
            builder: (_) => const CupertinoPageScaffold(
                child: Center(child: Text('Quick search selector'))),
          ));
      await tester.pumpAndSettle();
      expect(layout.activePaneNavigatorId, 2);
      expect(find.text('Quick search selector'), findsOneWidget);
      Get.nestedKey(2)!.currentState!.pop();
      await tester.pumpAndSettle();
      expect(layout.activePaneNavigatorId, 1);
      expect(find.text('Primary search'), findsOneWidget);
      Get.nestedKey(1)!.currentState!.pop();
      await tester.pumpAndSettle();
      expect(layout.activePaneNavigatorId, 2);
      expect(editor.text, value.text);
      Get.back<void>(id: detailNavigatorId);
      await tester.pumpAndSettle();
      expect(SecondNavigatorObserver().history, hasLength(1));
      expect(scroll.offset, 480);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a detail page pushed in one column never leaves a blank frame',
      (tester) async {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<ThemeService>(_Theme());
    final layout = Get.put<LayoutServices>(_Layout());
    addTearDown(Get.reset);
    const size = Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    layout.layoutMode = LayoutMode.small;

    await tester.pumpWidget(GetCupertinoApp(
      home: AdaptiveEnvironmentScope(
        snapshot: const AdaptiveEnvironmentSnapshot(size: size),
        child: TabHomeLarge(
          split: false,
          primaryRoot: CupertinoPageScaffold(
            child: ListView.builder(
              itemExtent: 48,
              itemCount: 100,
              itemBuilder: (_, index) => Text('Gallery $index'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    Get.nestedKey(detailNavigatorId)!.currentState!.push(
        CupertinoPageRoute<void>(
            builder: (_) => const CupertinoPageScaffold(
                child: Center(child: Text('Gallery detail')))));
    // The first frame lays the new page out offstage, so it draws nothing
    // yet; the list must stay on screen under it.
    await tester.pump();
    expect(find.text('Gallery 0'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Gallery 0'), findsOneWidget);
    expect(find.text('Gallery detail'), findsOneWidget);

    // Covered whole, the list stops drawing.
    await tester.pumpAndSettle();
    expect(find.text('Gallery 0'), findsNothing);
    expect(find.text('Gallery detail'), findsOneWidget);

    Get.nestedKey(detailNavigatorId)!.currentState!.pop();
    await tester.pump();
    expect(find.text('Gallery 0'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Gallery 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a list page opened from a detail page in one column shows',
      (tester) async {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_Settings());
    Get.put<ThemeService>(_Theme());
    final layout = Get.put<LayoutServices>(_Layout());
    addTearDown(Get.reset);
    const size = Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    layout.layoutMode = LayoutMode.small;

    await tester.pumpWidget(GetCupertinoApp(
      home: AdaptiveEnvironmentScope(
        snapshot: const AdaptiveEnvironmentSnapshot(size: size),
        child: TabHomeLarge(
          split: false,
          primaryRoot: CupertinoPageScaffold(
            child: ListView.builder(
              itemExtent: 48,
              itemCount: 100,
              itemBuilder: (_, index) => Text('Gallery $index'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(listNavigatorId, primaryNavigatorId);

    Rect? listClip() =>
        RouteCoverClip.debugVisibleRectOf(tester.renderObject(find
            .ancestor(
                of: find.byKey(Get.nestedKey(primaryNavigatorId)!,
                    skipOffstage: false),
                matching: find.byType(RouteCoverClip, skipOffstage: false))
            .first));
    Widget page(String text) =>
        CupertinoPageScaffold(child: Center(child: Text(text)));

    // Production pages report where they are drawn, so the list can find
    // the page covering it.
    Get.nestedKey(detailNavigatorId)!.currentState!.push(
        CupertinoPageRoute<void>(
            builder: (context) => RouteSurface(
                route: ModalRoute.of(context), child: page('Gallery detail'))));
    await tester.pumpAndSettle();
    expect(listClip(), Rect.zero);

    // Search from a tag slides over the detail page it was opened from.
    expect(listNavigatorId, detailNavigatorId);
    Get.nestedKey(listNavigatorId)!
        .currentState!
        .push(CupertinoPageRoute<void>(builder: (_) => page('Tag search')));
    await tester.pumpAndSettle();
    expect(find.text('Tag search'), findsOneWidget);
    Get.nestedKey(listNavigatorId)!.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Gallery detail'), findsOneWidget);

    // A page pushed onto the list itself brings the list back on top, and
    // the detail page it no longer shows under must not hide it.
    Get.nestedKey(primaryNavigatorId)!
        .currentState!
        .push(CupertinoPageRoute<void>(builder: (_) => page('Downloads')));
    await tester.pumpAndSettle();
    expect(layout.activePaneNavigatorId, primaryNavigatorId);
    expect(find.text('Downloads'), findsOneWidget);
    expect(listClip(), isNull);

    layout.layoutMode = LayoutMode.large;
    expect(listNavigatorId, primaryNavigatorId);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('20 compact/grid/split changes keep routes, scroll and drafts',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 650);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final detailKey = GlobalKey<NavigatorState>();
    final scroll = ScrollController();
    final draft = TextEditingController();
    final geometry =
        ValueNotifier(const AdaptiveEnvironmentSnapshot(size: Size(900, 650)));
    final hasDetail = ValueNotifier(false);
    var listMounts = 0;
    var detailMounts = 0;
    addTearDown(scroll.dispose);
    addTearDown(draft.dispose);
    addTearDown(geometry.dispose);
    addTearDown(hasDetail.dispose);

    final primary = _MountProbe(
      onMount: () => listMounts++,
      child: ListView.builder(
        controller: scroll,
        itemCount: 100,
        itemExtent: 48,
        itemBuilder: (_, index) => Text('Gallery $index'),
      ),
    );
    final detail = Navigator(
      key: detailKey,
      onGenerateRoute: (_) => CupertinoPageRoute<void>(
        builder: (_) => const Center(child: Text('Select a gallery')),
      ),
    );
    await tester.pumpWidget(CupertinoApp(
      home: ValueListenableBuilder(
        valueListenable: geometry,
        builder: (context, environment, _) => ValueListenableBuilder(
          valueListenable: hasDetail,
          builder: (context, active, _) => AdaptiveBrowseLayout(
            environment: environment,
            split: environment.isSplit,
            detailActive: active,
            primary: primary,
            detail: detail,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Select a gallery'), findsOneWidget);
    scroll.jumpTo(480);
    detailKey.currentState!.push(CupertinoPageRoute<void>(
      builder: (_) => _MountProbe(
        onMount: () => detailMounts++,
        child: CupertinoPageScaffold(
          child: SafeArea(
            child: CupertinoTextField(controller: draft),
          ),
        ),
      ),
    ));
    hasDetail.value = true;
    await tester.pumpAndSettle();
    draft.value = const TextEditingValue(
      text: 'Unsent search / favorite note',
      selection: TextSelection.collapsed(offset: 6),
      composing: TextRange(start: 1, end: 6),
    );
    final originalDraft = draft.value;

    for (var index = 0; index < 20; index++) {
      for (final size in <Size>[
        const Size(390, 844),
        const Size(669, 900),
        const Size(900, 650),
      ]) {
        tester.view.physicalSize = size;
        geometry.value = AdaptiveEnvironmentSnapshot(size: size);
        await tester.pumpAndSettle();
        expect(detailKey.currentState!.canPop(), isTrue);
        expect(scroll.offset, 480);
        expect(draft.value, originalDraft);
        expect(tester.takeException(), isNull);
      }
    }
    expect(listMounts, 1);
    expect(detailMounts, 1);
    detailKey.currentState!.pop();
    hasDetail.value = false;
    await tester.pumpAndSettle();
    expect(scroll.offset, 480);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Layout extends LayoutServices {
  @override
  void onInit() {}
}

class _Settings extends EhSettingService {
  @override
  void onInit() {}
}

class _Theme extends ThemeService {
  @override
  void onInit() {}
}

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.onMount, required this.child});
  final VoidCallback onMount;
  final Widget child;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
