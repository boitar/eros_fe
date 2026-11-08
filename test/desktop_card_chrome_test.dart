import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/widget/desktop_card_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  late LayoutServices layout;
  final navigator = GlobalKey<NavigatorState>();

  Future<void> pump(WidgetTester tester, TargetPlatform host) async {
    Get.testMode = true;
    PlatformCapabilities.debugHostPlatformOverride = host;
    DesktopCardChrome.debugGidForTag = (tag) => tag.replaceFirst('tag-', '');
    layout = Get.put<LayoutServices>(_Layout());
    layout.layoutMode = LayoutMode.large;
    final stack = layout.tabNavigation.select(EHRoutes.gallery);
    addTearDown(() {
      PlatformCapabilities.debugHostPlatformOverride = null;
      DesktopCardChrome.debugGidForTag = null;
      Get.reset();
    });
    await tester.pumpWidget(
      CupertinoApp(
        home: Row(
          children: <Widget>[
            const SizedBox(
              width: 300,
              child: Column(
                children: <Widget>[
                  DesktopCardChrome(gid: '1', child: _Card()),
                  DesktopCardChrome(gid: '2', child: _Card()),
                ],
              ),
            ),
            Expanded(
              child: Navigator(
                key: navigator,
                observers: <NavigatorObserver>[stack.detailObserver],
                onGenerateRoute: (settings) => PageRouteBuilder<void>(
                  settings: settings,
                  pageBuilder: (_, _, _) => const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget? ring(WidgetTester tester, String gid) {
    final found = find.byKey(ValueKey('desktop-card-ring-$gid'));
    return found.evaluate().isEmpty ? null : tester.widget(found);
  }

  Future<void> openDetail(WidgetTester tester, String gid) async {
    navigator.currentState!.pushNamed(
      EHRoutes.galleryPage,
      arguments: ControllerTagSnapshot(galleryTag: 'tag-$gid'),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the gallery open in the detail pane keeps a ring', (
    tester,
  ) async {
    await pump(tester, TargetPlatform.macOS);
    expect(ring(tester, '1'), isNull);
    expect(ring(tester, '2'), isNull);

    await openDetail(tester, '2');
    expect(ring(tester, '1'), isNull);
    expect(ring(tester, '2'), isNotNull);

    // A page opened on top of the gallery (comments) keeps its ring.
    navigator.currentState!.pushNamed(EHRoutes.galleryComment);
    await tester.pumpAndSettle();
    expect(ring(tester, '2'), isNotNull);

    navigator.currentState!
      ..pop()
      ..pop();
    await tester.pumpAndSettle();
    expect(ring(tester, '2'), isNull);

    // A single column covers the list with the detail: no ring needed.
    await openDetail(tester, '1');
    expect(ring(tester, '1'), isNotNull);
    layout.layoutMode = LayoutMode.small;
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hovered card lifts', (tester) async {
    await pump(tester, TargetPlatform.windows);
    Matrix4? transform() => tester
        .widget<AnimatedContainer>(find.byKey(const ValueKey('desktop-card-1')))
        .transform;
    expect(transform()!.getTranslation().y, 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('desktop-card-1'))),
    );
    await tester.pumpAndSettle();
    expect(transform()!.getTranslation().y, -2);
    await mouse.moveTo(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(transform()!.getTranslation().y, 0);
  });

  testWidgets('touch platforms get the card unchanged', (tester) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    addTearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);
    await tester.pumpWidget(
      const DesktopCardChrome(
        gid: '1',
        child: SizedBox(key: ValueKey('card')),
      ),
    );
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.byKey(const ValueKey('card')), findsOneWidget);
  });
}

/// Real cards paint and take hits; an empty box would not.
class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF202020),
    child: SizedBox(height: 100, width: double.infinity),
  );
}

class _Layout extends LayoutServices {
  // Stubs skip the service setup on purpose.
  @override
  // ignore: must_call_super
  void onInit() {}
}
