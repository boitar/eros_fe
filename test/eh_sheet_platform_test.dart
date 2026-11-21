import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  @override
  bool get liquidGlass => false;
  @override
  bool get isPureDarkTheme => false;
  @override
  RxBool get pureDarkThemeObs => false.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting $invocation');
}

Widget _app({
  double keyboard = 0,
  double textScale = 1,
  bool dismissible = true,
  bool reduceMotion = false,
  ValueChanged<String?>? onResult,
}) => CupertinoApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      viewInsets: EdgeInsets.only(bottom: keyboard),
      padding: const EdgeInsets.fromLTRB(24, 30, 18, 20),
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
    ),
    child: child!,
  ),
  home: CupertinoPageScaffold(
    child: Center(
      child: Builder(
        builder: (context) => CupertinoButton(
          child: const Text('open'),
          onPressed: () async {
            final result = await showEhSheet<String>(
              context: context,
              barrierDismissible: dismissible,
              builder: (context) => SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EhSheetHeader(title: 'Options', subtitle: 'Details'),
                    EhSheetOptionRow(
                      label: 'Choose',
                      icon: CupertinoIcons.checkmark,
                      onPressed: () => Navigator.of(context).pop('chosen'),
                    ),
                    const EhSheetOptionRow(
                      label: 'Disabled',
                      icon: CupertinoIcons.xmark,
                      enabled: false,
                    ),
                  ],
                ),
              ),
            );
            onResult?.call(result);
          },
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    Get.put<EhSettingService>(_Settings());
    Get.put(ThemeService());
  });
  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    Get.reset();
  });

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    testWidgets('$platform keeps a narrow dialog centered and traps Tab', (
      tester,
    ) async {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(480, 600);
      addTearDown(tester.view.reset);
      var closed = false;
      await tester.pumpWidget(_app(onResult: (_) => closed = true));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(EhSheetSurface));
      expect(rect.center.dy, closeTo(305, 1));
      expect(rect.left, greaterThanOrEqualTo(24));
      expect(rect.right, lessThanOrEqualTo(462));

      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus!.context!;
        expect(
          focus.findAncestorWidgetOfExactType<EhSheetSurface>(),
          isNotNull,
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(find.byType(EhSheetSurface), findsNothing);
    });
  }

  testWidgets('Android sheet avoids IME and system bars; Back dismisses', (
    tester,
  ) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 700);
    addTearDown(tester.view.reset);
    var closed = false;
    await tester.pumpWidget(
      _app(keyboard: 280, textScale: 1.5, onResult: (_) => closed = true),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(EhSheetSurface));
    expect(rect.bottom, lessThanOrEqualTo(420));
    expect(rect.left, greaterThanOrEqualTo(24));
    expect(rect.right, lessThanOrEqualTo(394));
    final close = find.descendant(
      of: find.byType(EhSheetHeader),
      matching: find.byType(EhPressable),
    );
    expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(find.byType(EhSheetSurface), findsNothing);
  });

  testWidgets(
    'wide Android dialog supports large text and keyboard selection',
    (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 500);
      addTearDown(tester.view.reset);
      String? result;
      await tester.pumpWidget(
        _app(textScale: 2, onResult: (value) => result = value),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(EhSheetSurface));
      expect(rect.width, lessThanOrEqualTo(EhSheetTokens.maxWidth));
      expect(rect.center.dy, closeTo(255, 1));
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result, 'chosen');
    },
  );

  testWidgets('non-dismissible sheets ignore Escape and reduce motion', (
    tester,
  ) async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_app(dismissible: false, reduceMotion: true));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(EhSheetSurface));
    expect(
      (ModalRoute.of(context)! as TransitionRoute).transitionDuration,
      Duration.zero,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(EhSheetSurface), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(EhSheetHeader),
        matching: find.byIcon(CupertinoIcons.xmark),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EhSheetSurface), findsNothing);
  });
}
