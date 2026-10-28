import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/debug/offline_reader_gesture_page_view.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/widgets.dart';

/// Keeps each sliver extent uniform while leaving a gap outside the image.
class ReaderGesturePageView extends StatelessWidget {
  ReaderGesturePageView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
    this.physics,
    this.reverse = false,
    this.pageSpacing = 0,
  })  : assert(pageSpacing >= 0 && pageSpacing < double.infinity),
        assert(controller.pageSpacing == 0),
        assert(controller.viewportFraction == 1);

  final ExtendedPageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onPageChanged;
  final ScrollPhysics? physics;
  final bool reverse;
  final double pageSpacing;

  @override
  Widget build(BuildContext context) {
    final reversed =
        reverse != (Directionality.of(context) == TextDirection.rtl);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth + pageSpacing;
      Widget buildPage(BuildContext context, int index) => Padding(
            padding: reversed
                ? EdgeInsets.only(left: pageSpacing)
                : EdgeInsets.only(right: pageSpacing),
            child: itemBuilder(context, index),
          );
      final pager = offlineAcceptanceEnabled &&
              const bool.fromEnvironment('EROS_DUO_ACCEPTANCE')
          ? OfflineReaderGesturePageView(
              controller: controller,
              itemCount: itemCount,
              onPageChanged: onPageChanged,
              physics: physics,
              reverse: reverse,
              itemBuilder: buildPage,
            )
          : ExtendedImageGesturePageView.builder(
              controller: controller,
              itemCount: itemCount,
              onPageChanged: onPageChanged,
              physics: physics,
              reverse: reverse,
              itemBuilder: buildPage,
            );
      // extended_image's native spacing produces a non-uniform scroll extent.
      // Extend the viewport instead; the gap stays outside the resting image.
      return ClipRect(
        child: OverflowBox(
          alignment: reversed ? Alignment.centerRight : Alignment.centerLeft,
          minWidth: width,
          maxWidth: width,
          child: pager,
        ),
      );
    });
  }
}
