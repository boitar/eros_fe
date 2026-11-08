import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/pages/tab/view/top_bar_layout_reset.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  final Rx<LiquidGlassTopBarLayout> _layout =
      LiquidGlassTopBarLayout.twoRow.obs;
  @override
  Rx<LiquidGlassTopBarLayout> get liquidGlassTopBarLayoutRx => _layout;
  @override
  LiquidGlassTopBarLayout get liquidGlassTopBarLayout => _layout.value;
  @override
  set liquidGlassTopBarLayout(LiquidGlassTopBarLayout value) =>
      _layout.value = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Page extends StatefulWidget {
  const _Page({required this.onReset});

  final VoidCallback onReset;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with TopBarLayoutReset<_Page> {
  @override
  void resetForTopBarLayout() => widget.onReset();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  late _Settings settings;

  setUp(() => settings = Get.put<EhSettingService>(_Settings()) as _Settings);
  tearDown(Get.reset);

  Widget host({required bool visible, required VoidCallback onReset}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(
          enabled: visible,
          child: _Page(onReset: onReset),
        ),
      );

  testWidgets('a visible page starts over after the frame', (tester) async {
    var resets = 0;
    await tester.pumpWidget(host(visible: true, onReset: () => resets++));
    expect(resets, 0);

    settings.liquidGlassTopBarLayout = LiquidGlassTopBarLayout.inline;
    expect(resets, 0);
    await tester.pump();
    expect(resets, 1);

    // Nothing else moves it again.
    await tester.pump();
    expect(resets, 1);
  });

  testWidgets('an offstage tab waits until it is shown again', (tester) async {
    var resets = 0;
    await tester.pumpWidget(host(visible: false, onReset: () => resets++));

    settings.liquidGlassTopBarLayout = LiquidGlassTopBarLayout.inline;
    settings.liquidGlassTopBarLayout = LiquidGlassTopBarLayout.twoRow;
    await tester.pump();
    await tester.pump();
    expect(resets, 0);

    await tester.pumpWidget(host(visible: true, onReset: () => resets++));
    await tester.pump();
    expect(resets, 1, reason: 'several changes while hidden reset once');

    await tester.pumpWidget(host(visible: false, onReset: () => resets++));
    await tester.pumpWidget(host(visible: true, onReset: () => resets++));
    await tester.pump();
    expect(resets, 1, reason: 'switching tabs alone keeps the position');
  });

  testWidgets('a disposed page stops listening', (tester) async {
    var resets = 0;
    await tester.pumpWidget(host(visible: true, onReset: () => resets++));
    await tester.pumpWidget(const SizedBox());
    settings.liquidGlassTopBarLayout = LiquidGlassTopBarLayout.inline;
    await tester.pump();
    expect(resets, 0);
    expect(tester.takeException(), isNull);
  });
}
