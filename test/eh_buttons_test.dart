import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  @override
  bool get isPureDarkTheme => false;
  @override
  RxBool get pureDarkThemeObs => false.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting $invocation');
}

Widget _app(Widget child, {bool reduceMotion = false}) => CupertinoApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: child!,
  ),
  home: Center(child: child),
);

BoxDecoration _feedback(WidgetTester tester, Finder pressable) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: pressable,
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    Get.put<EhSettingService>(_Settings());
    Get.put(ThemeService());
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    PlatformCapabilities.debugHostPlatformOverride = null;
    Get.reset();
  });

  testWidgets(
    'Tab skips disabled controls; activation does not repeat or long-press',
    (tester) async {
      var first = 0;
      var last = 0;
      var longPress = 0;
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EhPressable(
                key: const Key('first'),
                onPressed: () => first++,
                onLongPress: () => longPress++,
                child: const SizedBox(
                  width: 100,
                  height: 50,
                  child: Text('first'),
                ),
              ),
              const EhButton(label: 'disabled', onPressed: null),
              EhButton(label: 'last', onPressed: () => last++),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final firstControl = find.byKey(const Key('first'));
      expect(_feedback(tester, firstControl).border, isNotNull);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(seconds: 1));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(first, 1);
      expect(longPress, 0);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(first, 2);
      expect(longPress, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      expect(last, 1);
      expect(first, 2);
      expect(_feedback(tester, firstControl).border, isNull);
    },
  );

  testWidgets('mouse hover uses click cursor and clears when disabled', (
    tester,
  ) async {
    var tapped = 0;
    Widget button(bool enabled) => _app(
      EhPressable(
        onPressed: enabled ? () => tapped++ : null,
        child: const SizedBox(width: 100, height: 50),
      ),
    );
    await tester.pumpWidget(button(true));
    final control = find.byType(EhPressable);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(control));
    await tester.pumpAndSettle();
    expect(_feedback(tester, control).color!.a, greaterThan(0));
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
    await tester.tap(control);
    expect(tapped, 1);

    await tester.pumpWidget(button(false));
    await tester.pumpAndSettle();
    expect(_feedback(tester, control).color, isNull);
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      isNot(SystemMouseCursors.click),
    );
    await tester.tap(control);
    expect(tapped, 1);
    await mouse.removePointer();
  });

  testWidgets(
    'touch long press preserves its separate action without tapping',
    (tester) async {
      var tapped = 0;
      var longPressed = 0;
      await tester.pumpWidget(
        _app(
          EhPressable(
            onPressed: () => tapped++,
            onLongPress: () => longPressed++,
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      );
      await tester.longPress(find.byType(EhPressable));
      await tester.pumpAndSettle();
      expect(longPressed, 1);
      expect(tapped, 0);
    },
  );

  testWidgets(
    'Android compact buttons keep visuals and expose a 48 dp hit target',
    (tester) async {
      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.android;
      var tapped = 0;
      await tester.pumpWidget(
        _app(
          EhButton(
            icon: CupertinoIcons.xmark,
            size: 32,
            onPressed: () => tapped++,
          ),
        ),
      );
      final control = find.byType(EhPressable);
      expect(tester.getSize(control), const Size(48, 48));
      final rect = tester.getRect(control);
      await tester.tapAt(rect.topLeft + const Offset(2, 2));
      expect(tapped, 1);

      PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        _app(
          EhButton(
            icon: CupertinoIcons.xmark,
            size: 32,
            onPressed: () => tapped++,
          ),
        ),
      );
      expect(tester.getSize(control), const Size(32, 32));
    },
  );

  testWidgets(
    'reduced motion keeps press feedback without scale or animation',
    (tester) async {
      await tester.pumpWidget(
        _app(EhButton(label: 'press', onPressed: () {}), reduceMotion: true),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(EhButton)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1);
      expect(scale.duration, Duration.zero);
      for (final opacity in tester.widgetList<AnimatedOpacity>(
        find.descendant(
          of: find.byType(EhButton),
          matching: find.byType(AnimatedOpacity),
        ),
      )) {
        expect(opacity.duration, Duration.zero);
      }
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );
}
