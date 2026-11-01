import 'dart:math' as math;

import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import 'gallery_item.dart';

const double tagBoxHeight = 18;

class TagListViewBox extends StatelessWidget {
  const TagListViewBox({Key? key, this.simpleTags}) : super(key: key);

  final List<SimpleTag>? simpleTags;

  @override
  Widget build(BuildContext context) {
    final EhSettingService _ehSettingService = Get.find();
    return simpleTags != null && simpleTags!.isNotEmpty
        ? Obx(() => SizedBox(
              height: tagBoxHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children:
                    List<Widget>.from(simpleTags!.map((SimpleTag _simpleTag) {
                  final String? _text = _ehSettingService.isTagTranslate
                      ? _simpleTag.translat
                      : _simpleTag.text;
                  return FrameSeparateWidget(
                    placeHolder: const TagItem(text: ''),
                    index: -1,
                    child: TagItem(
                      text: _text,
                      color: ColorsUtil.getTagColor(_simpleTag.color),
                      backgroundColor:
                          ColorsUtil.getTagColor(_simpleTag.backgrondColor),
                    ),
                  ).paddingOnly(right: 4.0);
                }).toList()), //要显示的子控件集合
              ),
            ))
        : Container();
  }
}

class TagWaterfallFlowViewBox extends StatelessWidget {
  const TagWaterfallFlowViewBox(
      {Key? key,
      this.simpleTags,
      this.crossAxisCount = 2,
      this.splitFrame = false,
      this.rowExtent = 18,
      this.endPadding = 0})
      : super(key: key);

  final List<SimpleTag>? simpleTags;
  final int crossAxisCount;
  final bool splitFrame;
  final double rowExtent;
  final double endPadding;

  @override
  Widget build(BuildContext context) {
    final EhSettingService _ehSettingService = Get.find();

    return Obx(() {
      List<SimpleTag>? _simpleTags =
          getLimitSimpleTags(simpleTags, _ehSettingService.listViewTagLimit);

      if (_simpleTags == null || _simpleTags.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        height: crossAxisCount * rowExtent + (crossAxisCount - 1) * 4,
        child: WaterfallFlow.builder(
          shrinkWrap: true,
          padding: EdgeInsetsDirectional.only(end: endPadding),
          primary: false,
          scrollDirection: Axis.horizontal,
          gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 4.0,
            mainAxisSpacing: 4.0,
          ),
          itemCount: _simpleTags.length,
          itemBuilder: (BuildContext context, int index) {
            return Obx(
              () {
                final _simpleTag = _simpleTags[index];
                final String? _text = _ehSettingService.isTagTranslate
                    ? _simpleTag.translat
                    : _simpleTag.text;
                Widget _item = TagItem(
                  text: _text,
                  color: ColorsUtil.getTagColor(_simpleTag.color),
                  backgroundColor:
                      ColorsUtil.getTagColor(_simpleTag.backgrondColor),
                );

                if (splitFrame) {
                  _item = FrameSeparateWidget(
                    placeHolder: const TagItem(text: '..'),
                    index: -1,
                    child: _item,
                  );
                }

                return _item;
              },
            );
          },
        ),
      );
    });
  }
}

class PlaceHolderLine extends StatelessWidget {
  const PlaceHolderLine({Key? key, this.width}) : super(key: key);
  final double? width;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          color: ehTheme.palette.fill.resolveFrom(context),
          height: 16,
        ),
      ).paddingSymmetric(vertical: 4, horizontal: 4),
    );
  }
}

List<SimpleTag>? getLimitSimpleTags(List<SimpleTag>? simpleTags, int limit) {
  if (limit > -1) {
    return simpleTags?.take(limit).toList();
  } else {
    return simpleTags;
  }
}

class PostTime extends StatelessWidget {
  const PostTime({
    Key? key,
    this.postTime,
    this.expunged = false,
    this.fontSize = 12,
  }) : super(key: key);
  final String? postTime;
  final bool? expunged;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      postTime ?? '',
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: fontSize,
        color: ehTheme.palette.text2.resolveFrom(context),
        decoration: (expunged ?? false)
            ? TextDecoration.lineThrough
            : TextDecoration.none,
      ),
    );
  }
}

/// Lays [children] out in at most [maxRuns] rows. Whatever does not fit is
/// replaced by a "+N" count at the end of the last row, so a card never
/// scrolls sideways and its height stays predictable.
class LimitedWrap extends MultiChildRenderObjectWidget {
  const LimitedWrap({
    super.key,
    super.children,
    this.spacing = 4,
    this.runSpacing = 4,
    this.maxRuns = 2,
    this.overflowStyle = const TextStyle(fontSize: 11),
    this.overflowPadding = const EdgeInsets.symmetric(horizontal: 2),
  }) : assert(maxRuns > 0);

  final double spacing;
  final double runSpacing;
  final int maxRuns;
  final TextStyle overflowStyle;
  final EdgeInsets overflowPadding;

  @override
  RenderLimitedWrap createRenderObject(BuildContext context) {
    return RenderLimitedWrap(
      spacing: spacing,
      runSpacing: runSpacing,
      maxRuns: maxRuns,
      overflowStyle: overflowStyle,
      overflowPadding: overflowPadding,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderLimitedWrap renderObject) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..maxRuns = maxRuns
      ..overflowStyle = overflowStyle
      ..overflowPadding = overflowPadding
      ..textDirection = Directionality.of(context)
      ..textScaler = MediaQuery.textScalerOf(context);
  }
}

class LimitedWrapParentData extends ContainerBoxParentData<RenderBox> {
  bool shown = true;
}

class RenderLimitedWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, LimitedWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, LimitedWrapParentData> {
  RenderLimitedWrap({
    required double spacing,
    required double runSpacing,
    required int maxRuns,
    required TextStyle overflowStyle,
    required EdgeInsets overflowPadding,
    required TextDirection textDirection,
    required TextScaler textScaler,
  })  : _spacing = spacing,
        _runSpacing = runSpacing,
        _maxRuns = maxRuns,
        _overflowStyle = overflowStyle,
        _overflowPadding = overflowPadding,
        _textDirection = textDirection,
        _textScaler = textScaler;

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) {
      return;
    }
    _spacing = value;
    markNeedsLayout();
  }

  double get runSpacing => _runSpacing;
  double _runSpacing;
  set runSpacing(double value) {
    if (value == _runSpacing) {
      return;
    }
    _runSpacing = value;
    markNeedsLayout();
  }

  int get maxRuns => _maxRuns;
  int _maxRuns;
  set maxRuns(int value) {
    if (value == _maxRuns) {
      return;
    }
    _maxRuns = value;
    markNeedsLayout();
  }

  TextStyle get overflowStyle => _overflowStyle;
  TextStyle _overflowStyle;
  set overflowStyle(TextStyle value) {
    if (value == _overflowStyle) {
      return;
    }
    _overflowStyle = value;
    markNeedsLayout();
  }

  EdgeInsets get overflowPadding => _overflowPadding;
  EdgeInsets _overflowPadding;
  set overflowPadding(EdgeInsets value) {
    if (value == _overflowPadding) {
      return;
    }
    _overflowPadding = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) {
      return;
    }
    _textScaler = value;
    markNeedsLayout();
  }

  // Dry layout may measure other counts, so painting keeps its own painter.
  final TextPainter _measurePainter = TextPainter(maxLines: 1);
  final TextPainter _overflowPainter = TextPainter(maxLines: 1);
  Offset _overflowOffset = Offset.zero;

  /// Children replaced by the "+N" count after the last layout.
  int get hiddenCount => _hiddenCount;
  int _hiddenCount = 0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! LimitedWrapParentData) {
      child.parentData = LimitedWrapParentData();
    }
  }

  Size _overflowSize(int hidden, [TextPainter? painter]) {
    final target = painter ?? _measurePainter;
    target
      ..text = TextSpan(text: '+$hidden', style: overflowStyle)
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..layout();
    return Size(
      target.width + overflowPadding.horizontal,
      target.height + overflowPadding.vertical,
    );
  }

  _LimitedWrapPlan _plan(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) sizeOf,
  ) {
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    final sizes = <Size>[];
    var child = firstChild;
    while (child != null) {
      sizes.add(sizeOf(child, childConstraints));
      child = childAfter(child);
    }
    return _LimitedWrapPlan.compute(
      sizes: sizes,
      maxWidth: constraints.maxWidth,
      spacing: spacing,
      runSpacing: runSpacing,
      maxRuns: maxRuns,
      overflowSize: _overflowSize,
      textDirection: textDirection,
      constraints: constraints,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return _plan(constraints, ChildLayoutHelper.dryLayoutChild).size;
  }

  @override
  void performLayout() {
    final plan = _plan(constraints, ChildLayoutHelper.layoutChild);
    var index = 0;
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as LimitedWrapParentData;
      parentData.shown = index < plan.visible;
      parentData.offset = parentData.shown ? plan.offsets[index] : Offset.zero;
      index++;
      child = parentData.nextSibling;
    }
    final hidden = plan.offsets.length - plan.visible;
    if (hidden != _hiddenCount) {
      _hiddenCount = hidden;
      markNeedsSemanticsUpdate();
    }
    if (hidden > 0) {
      _overflowSize(hidden, _overflowPainter);
      _overflowOffset = plan.overflowOffset! +
          Offset(overflowPadding.left, overflowPadding.top);
    }
    size = plan.size;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var width = 0.0;
    var child = firstChild;
    while (child != null) {
      width = math.max(width, child.getMinIntrinsicWidth(double.infinity));
      child = childAfter(child);
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = 0.0;
    var count = 0;
    var child = firstChild;
    while (child != null) {
      width += child.getMaxIntrinsicWidth(double.infinity);
      count++;
      child = childAfter(child);
    }
    return width + spacing * math.max(0, count - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as LimitedWrapParentData;
      if (parentData.shown) {
        context.paintChild(child, parentData.offset + offset);
      }
      child = parentData.nextSibling;
    }
    if (_hiddenCount > 0) {
      _overflowPainter.paint(context.canvas, offset + _overflowOffset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final current = child;
      final parentData = current.parentData! as LimitedWrapParentData;
      if (parentData.shown &&
          result.addWithPaintOffset(
            offset: parentData.offset,
            position: position,
            hitTest: (result, transformed) =>
                current.hitTest(result, position: transformed),
          )) {
        return true;
      }
      child = parentData.previousSibling;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as LimitedWrapParentData;
      if (parentData.shown) {
        visitor(child);
      }
      child = parentData.nextSibling;
    }
  }

  @override
  void dispose() {
    _measurePainter.dispose();
    _overflowPainter.dispose();
    super.dispose();
  }
}

class _LimitedWrapPlan {
  const _LimitedWrapPlan({
    required this.offsets,
    required this.visible,
    required this.size,
    this.overflowOffset,
  });

  /// One offset per child; only the first [visible] are meaningful.
  final List<Offset> offsets;
  final int visible;
  final Size size;
  final Offset? overflowOffset;

  static _LimitedWrapPlan compute({
    required List<Size> sizes,
    required double maxWidth,
    required double spacing,
    required double runSpacing,
    required int maxRuns,
    required Size Function(int hidden) overflowSize,
    required TextDirection textDirection,
    required BoxConstraints constraints,
  }) {
    // Greedy runs, stopping before a child would open run number maxRuns.
    final runOf = <int>[];
    var run = 0;
    var end = 0.0;
    var inRun = 0;
    for (final size in sizes) {
      if (inRun > 0 && end + spacing + size.width > maxWidth) {
        run++;
        end = 0;
        inRun = 0;
      }
      if (run >= maxRuns) {
        break;
      }
      end = inRun == 0 ? size.width : end + spacing + size.width;
      inRun++;
      runOf.add(run);
    }

    // Overflow only happens once every run holds a child, so the count
    // always joins the last run; drop its tail until the count fits.
    Size? more;
    if (runOf.length < sizes.length) {
      final lastRun = maxRuns - 1;
      while (true) {
        more = overflowSize(sizes.length - runOf.length);
        var runEnd = 0.0;
        var count = 0;
        for (var i = 0; i < runOf.length; i++) {
          if (runOf[i] == lastRun) {
            runEnd =
                count == 0 ? sizes[i].width : runEnd + spacing + sizes[i].width;
            count++;
          }
        }
        if (count == 0 || runEnd + spacing + more.width <= maxWidth) {
          break;
        }
        runOf.removeLast();
      }
    }

    final visible = runOf.length;
    final runCount =
        more != null ? maxRuns : (visible == 0 ? 0 : runOf.last + 1);
    final runHeights = List<double>.filled(runCount, 0);
    final runWidths = List<double>.filled(runCount, 0);
    final runItems = List<int>.filled(runCount, 0);
    for (var i = 0; i < visible; i++) {
      final r = runOf[i];
      runHeights[r] = math.max(runHeights[r], sizes[i].height);
      runWidths[r] += (runItems[r] == 0 ? 0 : spacing) + sizes[i].width;
      runItems[r]++;
    }
    if (more != null) {
      final r = runCount - 1;
      runHeights[r] = math.max(runHeights[r], more.height);
      runWidths[r] += (runItems[r] == 0 ? 0 : spacing) + more.width;
    }

    final runTops = List<double>.filled(runCount, 0);
    var height = 0.0;
    for (var r = 0; r < runCount; r++) {
      runTops[r] = height;
      height += runHeights[r] + (r < runCount - 1 ? runSpacing : 0);
    }
    final width = constraints.constrainWidth(runWidths.fold(0.0, math.max));
    final rtl = textDirection == TextDirection.rtl;

    final offsets = List<Offset>.filled(sizes.length, Offset.zero);
    final cursor = List<double>.filled(runCount, 0);
    Offset place(Size size, int r) {
      final x = cursor[r];
      cursor[r] = x + size.width + spacing;
      final dx = rtl ? width - x - size.width : x;
      return Offset(dx, runTops[r] + (runHeights[r] - size.height) / 2);
    }

    for (var i = 0; i < visible; i++) {
      offsets[i] = place(sizes[i], runOf[i]);
    }
    final overflowOffset = more != null ? place(more, runCount - 1) : null;

    return _LimitedWrapPlan(
      offsets: offsets,
      visible: visible,
      size: constraints.constrain(Size(width, height)),
      overflowOffset: overflowOffset,
    );
  }
}
