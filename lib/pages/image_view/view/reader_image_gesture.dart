import 'dart:math' as math;

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_view/photo_view.dart';

/// Lets the parent PhotoView own Ctrl+wheel even over list padding and gaps.
/// Ordinary scrolling and the mobile scroll physics keep their usual behavior.
class ReaderPhotoViewScrollPhysics extends ScrollPhysics {
  const ReaderPhotoViewScrollPhysics({super.parent});

  @override
  ReaderPhotoViewScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      ReaderPhotoViewScrollPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    if (PlatformCapabilities.isDesktop &&
        HardwareKeyboard.instance.isControlPressed) {
      return false;
    }
    return super.shouldAcceptUserOffset(position);
  }
}

/// Ctrl+wheel zoom for the PhotoView backend. Put this inside a scrollable's
/// item as well as around its viewport, so zoom claims the signal before the
/// list can treat the same event as ordinary scrolling.
class ReaderPhotoViewScroll extends StatelessWidget {
  const ReaderPhotoViewScroll({
    super.key,
    required this.controller,
    required this.minScale,
    required this.maxScale,
    required this.child,
  });

  final PhotoViewControllerBase controller;
  final double minScale;
  final double maxScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!PlatformCapabilities.isDesktop) {
      return child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent ||
            !HardwareKeyboard.instance.isControlPressed) {
          return;
        }
        GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
          final scroll = signal as PointerScrollEvent;
          final delta =
              scroll.scrollDelta.dy.abs() >= scroll.scrollDelta.dx.abs()
              ? scroll.scrollDelta.dy
              : scroll.scrollDelta.dx;
          final scale = controller.scale ?? minScale;
          controller.scale = (scale * (1 + delta / 1000))
              .clamp(minScale, maxScale)
              .toDouble();
          scroll.respond(allowPlatformDefault: false);
        });
      },
      child: child,
    );
  }
}

/// Keeps extended_image's pan, pinch and double-tap behavior, while reserving
/// ordinary desktop wheel events for paging (or vertical scrolling).
///
/// The pinned extended_image 10.0.1 handles wheel zoom directly rather than
/// through PointerSignalResolver, so the filter must replace its listener,
/// before that handler runs. Every completed reader image uses this adapter,
/// including local files, archives and network images.
Widget readerCompletedImage(ExtendedImageState state) =>
    PlatformCapabilities.isDesktop &&
        state.imageWidget.mode == ExtendedImageMode.gesture
    ? _ReaderImageGesture(state, key: state.imageWidget.extendedImageGestureKey)
    : state.completedWidget;

class _ReaderImageGesture extends ExtendedImageGesture {
  const _ReaderImageGesture(super.extendedImageState, {super.key});

  @override
  ExtendedImageGestureState createState() => _ReaderImageGestureState();
}

class _ReaderImageGestureState extends ExtendedImageGestureState {
  @override
  Widget build(BuildContext context) {
    // This is the library's outer Listener; the original child retains all
    // image gestures and page-view coordination.
    final listener = super.build(context) as Listener;
    return Listener(
      behavior: listener.behavior,
      onPointerDown: listener.onPointerDown,
      onPointerMove: listener.onPointerMove,
      onPointerUp: listener.onPointerUp,
      onPointerCancel: listener.onPointerCancel,
      onPointerHover: listener.onPointerHover,
      onPointerPanZoomStart: listener.onPointerPanZoomStart,
      onPointerPanZoomUpdate: listener.onPointerPanZoomUpdate,
      onPointerPanZoomEnd: listener.onPointerPanZoomEnd,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          if (HardwareKeyboard.instance.isControlPressed) {
            // Claim zoom before a parent vertical Scrollable can also scroll.
            GestureBinding.instance.pointerSignalResolver.register(event, (
              event,
            ) {
              final scroll = event as PointerScrollEvent;
              final delta =
                  scroll.scrollDelta.dy.abs() >= scroll.scrollDelta.dx.abs()
                  ? scroll.scrollDelta.dy
                  : scroll.scrollDelta.dx;
              final speed = imageGestureConfig?.speed ?? 1.0;
              final factor = math.max(0.01, 1 + delta * speed / 1000);
              handleScaleStart(ScaleStartDetails(focalPoint: scroll.position));
              handleScaleUpdate(
                ScaleUpdateDetails(
                  focalPoint: scroll.position,
                  scale: factor,
                  focalPointDelta: Offset.zero,
                ),
              );
              handleScaleEnd(ScaleEndDetails());
              scroll.respond(allowPlatformDefault: false);
            });
          }
        } else {
          listener.onPointerSignal?.call(event);
        }
      },
      child: listener.child,
    );
  }
}
