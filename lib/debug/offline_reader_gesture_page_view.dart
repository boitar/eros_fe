import 'package:extended_image/extended_image.dart';
import 'package:flutter/widgets.dart';

import '../utils/logger.dart';

/// Observes the existing gesture implementation without changing its decisions.
class OfflineReaderGesturePageView extends ExtendedImageGesturePageView {
  OfflineReaderGesturePageView({
    super.key,
    required super.controller,
    required super.itemCount,
    required super.itemBuilder,
    super.onPageChanged,
    super.physics,
    super.reverse,
  }) : super.builder();

  @override
  ExtendedImageGesturePageViewState createState() =>
      _OfflineReaderGestureState();
}

class _OfflineReaderGestureState extends ExtendedImageGesturePageViewState {
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (event) =>
            logger.d('OFFLINE_READER_POINTER_DOWN pointer=${event.pointer};'
                'position=${event.localPosition};dragging=$isDraging'),
        onPointerUp: (event) => logger.d(
            'OFFLINE_READER_POINTER_UP pointer=${event.pointer};'
            'position=${event.localPosition};dragging=$isDraging;'
            'page=${pageController.page};'
            'scales=${extendedImageGestureStates.map((state) => state?.gestureDetails?.totalScale).join(",")}'),
        child: super.build(context),
      );

  @override
  void onDragStart(DragStartDetails details) {
    logger.d('OFFLINE_READER_DRAG_START page=${pageController.page};'
        'states=${extendedImageGestureStates.length}');
    super.onDragStart(details);
  }

  @override
  void onDragEnd(DragEndDetails details) {
    logger.d('OFFLINE_READER_DRAG_END page=${pageController.page};'
        'velocity=${details.primaryVelocity}');
    super.onDragEnd(details);
  }

  @override
  void onScaleStart(ScaleStartDetails details) {
    logger.d(
        'OFFLINE_READER_SCALE_START states=${extendedImageGestureStates.length}'
        ';dragging=$isDraging');
    super.onScaleStart(details);
  }

  @override
  void onScaleUpdate(ScaleUpdateDetails details) {
    logger.d('OFFLINE_READER_SCALE_UPDATE scale=${details.scale};'
        'pointers=${details.pointerCount};dragging=$isDraging;'
        'states=${extendedImageGestureStates.length}');
    super.onScaleUpdate(details);
  }
}
