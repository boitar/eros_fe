import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/widget/app_modal.dart';
import 'package:eros_fe/widget/appkit_interaction.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final originalConfig = SmartDialog.config.loading;
  setUp(() {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
    SmartDialog.config.loading = SmartConfigLoading();
    messenger.setMockMethodCallHandler(
      AppKitInteraction.channel,
      (_) async => null,
    );
  });
  tearDown(() {
    expect(AppKitInteraction.blocked, isFalse);
    SmartDialog.config.loading = originalConfig;
    PlatformCapabilities.debugHostPlatformOverride = null;
    messenger.setMockMethodCallHandler(AppKitInteraction.channel, null);
  });

  for (final block in [false, true]) {
    testWidgets(
      block
          ? 'explicit block loading survives system back'
          : 'default loading closes on system back',
      (tester) async {
        await tester.pumpWidget(
          CupertinoApp(
            builder: FlutterSmartDialog.init(),
            home: const Text('Underlying page'),
          ),
        );
        final loading = block
            ? AppModal.showLoading<void>(
                builder: (_) => const Text('Working'),
                backType: SmartBackType.block,
              )
            : AppModal.showLoading<void>(builder: (_) => const Text('Working'));
        await tester.pumpAndSettle();
        expect(find.text('Working'), findsOneWidget);
        expect(AppKitInteraction.blocked, isTrue);
        final back = tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await back;
        expect(find.text('Working'), block ? findsOneWidget : findsNothing);
        expect(AppKitInteraction.blocked, block);
        expect(find.text('Underlying page'), findsOneWidget);
        if (block) {
          SmartDialog.dismiss(status: SmartStatus.loading);
          await tester.pumpAndSettle();
        }
        await loading;
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('omitted options inherit global loading settings', (
    tester,
  ) async {
    const mask = Color(0xA1345678);
    SmartDialog.config.loading = SmartConfigLoading(
      backType: SmartBackType.block,
      clickMaskDismiss: true,
      useAnimation: false,
      animationType: SmartAnimationType.centerScale_otherSlide,
      maskColor: mask,
    );
    await tester.pumpWidget(
      CupertinoApp(
        builder: FlutterSmartDialog.init(),
        home: const Text('Underlying page'),
      ),
    );
    final loading = AppModal.showLoading<void>(
      builder: (_) => const Text('Working'),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Container && widget.color == mask,
      ),
      findsOneWidget,
    );
    final back = tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await back;
    expect(find.text('Working'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await loading;
    expect(find.text('Working'), findsNothing);
    expect(AppKitInteraction.blocked, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
