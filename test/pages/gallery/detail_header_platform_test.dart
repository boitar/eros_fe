import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_page.dart';
import 'package:eros_fe/widget/detail_window_backdrop.dart';
import 'package:eros_fe/widget/windows_window_content.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
  });
  for (final host in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.iOS,
  ]) {
    for (final enabled in [true, false]) {
      testWidgets('$host glass=$enabled header routing', (tester) async {
        PlatformCapabilities.debugHostPlatformOverride = host;
        bool? floating;
        await tester.pumpWidget(
          GlassPreference(
            enabled: enabled,
            child: CupertinoApp(
              home: Builder(
                builder: (context) {
                  floating = usesFloatingGalleryHeader(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        expect(floating, enabled && host != TargetPlatform.iOS);
      });
    }
  }
  testWidgets(
    'transparent titlebar preserves controls safe area and full canvas',
    (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: WindowsWindowContent(
            titleBarHeight: 32,
            child: DetailWindowBackdrop(
              enabled: true,
              child: SizedBox(key: Key('canvas')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const Key('canvas'))).dy, 0);
      final context = tester.element(find.byKey(const Key('canvas')));
      expect(MediaQuery.paddingOf(context).top, 32);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(DetailWindowBackdrop.active.value, false);
    },
  );
  testWidgets('nested detail never leases window chrome when root covers it', (
    tester,
  ) async {
    final root = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: root,
        home: Navigator(
          onGenerateRoute: (_) => CupertinoPageRoute<void>(
            builder: (_) =>
                const DetailWindowBackdrop(enabled: true, child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(DetailWindowBackdrop.active.value, false);
    root.currentState!.push(
      CupertinoPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await tester.pumpAndSettle();
    expect(DetailWindowBackdrop.active.value, false);
    root.currentState!.pop();
    await tester.pumpAndSettle();
    expect(DetailWindowBackdrop.active.value, false);
  });
  testWidgets('hidden tab releases lease without replacing overlay', (
    tester,
  ) async {
    final enabled = ValueNotifier(true);
    await tester.pumpWidget(
      CupertinoApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (_, active, __) => TickerMode(
            enabled: active,
            child: const DetailWindowBackdrop(enabled: true, child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pump();
    final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
    expect(DetailWindowBackdrop.active.value, true);
    enabled.value = false;
    await tester.pump();
    await tester.pump();
    expect(DetailWindowBackdrop.active.value, false);
    expect(
      tester.state<OverlayState>(find.byType(Overlay).first),
      same(overlay),
    );
    enabled.value = true;
    await tester.pump();
    await tester.pump();
    expect(DetailWindowBackdrop.active.value, true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    enabled.dispose();
  });
  testWidgets('production floating controls dispatch and disable reading', (
    tester,
  ) async {
    var back = 0, more = 0, share = 0, read = 0;
    Future<void> render(bool collapsed, bool readable) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: GlassPreference(
          enabled: false,
          child: GalleryFloatingNavigation(
            title: 'Non-H fixture',
            showTitle: collapsed,
            enableRead: readable,
            onBack: () => back++,
            onMore: () => more++,
            onShare: () => share++,
            onRead: () => read++,
          ),
        ),
      ),
    );
    await render(false, false);
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.book), findsNothing);
    await tester.tap(find.byIcon(CupertinoIcons.back));
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.tap(find.byIcon(CupertinoIcons.share));
    expect([back, more, share], [1, 1, 1]);
    await render(true, false);
    await tester.pumpAndSettle();
    final button = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.byIcon(CupertinoIcons.book),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(button.onPressed, isNull);
    await render(true, true);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.book));
    expect(read, 1);
    expect(
      tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
          .opacity,
      1,
    );
  });

  testWidgets('split detail does not lease global titlebar', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: BrowsePaneScope(
          split: true,
          child: DetailWindowBackdrop(enabled: true, child: SizedBox()),
        ),
      ),
    );
    await tester.pump();
    expect(DetailWindowBackdrop.active.value, false);
  });
  testWidgets('cancelled back gesture preserves lease and overlay identity', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(navigatorKey: nav, home: const SizedBox()),
    );
    nav.currentState!.push(
      CupertinoPageRoute<void>(
        builder: (_) => const DetailWindowBackdrop(
          enabled: true,
          child: CupertinoPageScaffold(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
    expect(DetailWindowBackdrop.active.value, true);
    final gesture = await tester.startGesture(const Offset(1, 200));
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(DetailWindowBackdrop.active.value, true);
    expect(
      tester.state<OverlayState>(find.byType(Overlay).first),
      same(overlay),
    );
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(DetailWindowBackdrop.active.value, false);
  });
}
