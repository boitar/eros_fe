import 'package:flutter/widgets.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Keeps the point within the top visible image stable when its pane resizes.
class ReaderContinuousViewport extends StatefulWidget {
  const ReaderContinuousViewport({
    super.key,
    required this.positions,
    required this.itemScrollController,
    required this.builder,
    this.trailingSpacing = 0,
    this.reflowKey,
  });

  final ItemPositionsListener positions;
  final ItemScrollController itemScrollController;
  final Widget Function(BuildContext, ScrollOffsetController) builder;
  final double trailingSpacing;
  final Object? reflowKey;

  @override
  State<ReaderContinuousViewport> createState() =>
      _ReaderContinuousViewportState();
}

class _ReaderContinuousViewportState extends State<ReaderContinuousViewport> {
  final _offset = ScrollOffsetController();
  Size? _size;
  Object? _reflowKey;
  ({int index, double fraction})? _anchor;
  int _generation = 0;

  ({int index, double fraction})? _capture() {
    final visible = widget.positions.itemPositions.value
        .where((p) => p.itemLeadingEdge <= 0 && p.itemTrailingEdge > 0);
    if (visible.isEmpty) {
      return null;
    }
    final item = visible.reduce((a, b) => a.index < b.index ? a : b);
    final extent = item.itemTrailingEdge -
        item.itemLeadingEdge -
        widget.trailingSpacing / _size!.height;
    if (!extent.isFinite || extent <= 0) {
      return null;
    }
    return (
      index: item.index,
      fraction: (-item.itemLeadingEdge / extent).clamp(0.0, 1.0),
    );
  }

  void _restore(int generation, {bool recoverMissingItem = true}) {
    // The list publishes its new item extents at the end of this frame. Read
    // them in the next frame rather than using the pre-resize positions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _restorePosition(generation, recoverMissingItem: recoverMissingItem));
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  Future<void> _restorePosition(int generation,
      {required bool recoverMissingItem}) async {
    if (!mounted || generation != _generation) {
      return;
    }
    final anchor = _anchor;
    if (anchor == null) {
      return;
    }
    final items = widget.positions.itemPositions.value
        .where((p) => p.index == anchor.index);
    if (items.isEmpty &&
        recoverMissingItem &&
        widget.itemScrollController.isAttached) {
      widget.itemScrollController.jumpTo(index: anchor.index);
      _restore(generation, recoverMissingItem: false);
      return;
    }
    if (items.isNotEmpty) {
      final item = items.first;
      final extent =
          (item.itemTrailingEdge - item.itemLeadingEdge) * _size!.height -
              widget.trailingSpacing;
      final delta =
          item.itemLeadingEdge * _size!.height + anchor.fraction * extent;
      // Relative scrolling avoids an invalid negative jumpTo alignment for
      // images taller than the viewport.
      if (delta.isFinite && delta.abs() > 0.5) {
        await _offset.animateScroll(
          offset: delta,
          duration: const Duration(milliseconds: 1),
        );
      }
    }
    if (mounted && generation == _generation) {
      _anchor = null;
    }
  }

  void _cancelRestore() {
    _generation++;
    _anchor = null;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (_size != null &&
              size.isFinite &&
              size.height > 0 &&
              (_size != size || _reflowKey != widget.reflowKey)) {
            _anchor ??= _capture();
            _restore(++_generation);
          }
          _size = size;
          _reflowKey = widget.reflowKey;
          return Listener(
            onPointerDown: (_) => _cancelRestore(),
            child: widget.builder(context, _offset),
          );
        },
      );
}
