import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/pages/image_view/controller/view_controller.dart';
import 'package:eros_fe/pages/image_view/controller/view_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const _third = ItemPosition(
  index: 3,
  itemLeadingEdge: -0.2,
  itemTrailingEdge: 0.9,
);

void main() {
  testWidgets('continuous position ignores non-visible cached items',
      (tester) async {
    final state = _State();
    final reader = _Reader(state);
    reader.handItemPositionsChange(const [
      ItemPosition(index: 2, itemLeadingEdge: -2, itemTrailingEdge: -1),
      ItemPosition(index: 4, itemLeadingEdge: 1.1, itemTrailingEdge: 2),
    ]);
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.currentItemIndex, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old continuous callback cannot overwrite a paged reader',
      (tester) async {
    final state = _State();
    final reader = _Reader(state);
    reader.handItemPositionsChange(const [_third]);
    state.viewMode = ViewMode.rightToLeft;
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.currentItemIndex, 5);
  });

  testWidgets('continuous callback respects a later position lock',
      (tester) async {
    final state = _State();
    final reader = _Reader(state);
    reader.handItemPositionsChange(const [_third]);
    state.conditionItemIndex = false;
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.currentItemIndex, 5);
  });

  testWidgets('continuous callback cannot write after controller closure',
      (tester) async {
    final state = _State();
    final reader = _Reader(state);
    reader.handItemPositionsChange(const [_third]);
    reader.onDelete();
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.currentItemIndex, 5);
  });

  testWidgets('continuous callbacks settle only the newest visible position',
      (tester) async {
    final state = _State();
    final reader = _Reader(state);
    reader.handItemPositionsChange(const [_third]);
    await tester.pump(const Duration(milliseconds: 100));
    reader.handItemPositionsChange(const [
      ItemPosition(index: 6, itemLeadingEdge: -0.2, itemTrailingEdge: 0.9),
    ]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.currentItemIndex, 5);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.currentItemIndex, 6);
    expect(state.sliderValue, 6);
  });
}

class _Reader extends ViewExtController {
  _Reader(_State state) : super(state: state);

  @override
  // ignore: must_call_super
  void onClose() {}
}

class _State extends Fake implements ViewExtState {
  @override
  int currentItemIndex = 5;
  @override
  ViewMode viewMode = ViewMode.topToBottom;
  @override
  bool conditionItemIndex = true;
  @override
  int tempIndex = 5;
  @override
  int minImageIndex = 5;
  @override
  int maxImageIndex = 5;
  @override
  double sliderValue = 5;
  @override
  bool get syncThumbList => false;
}
