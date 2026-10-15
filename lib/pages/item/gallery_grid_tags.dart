import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import '../../const/const.dart';
import '../../models/simple_tag.dart';
import 'item_base.dart';

/// Shared geometry for the grid, its real cards, and its width preview.
class GalleryGridTagsMetrics {
  const GalleryGridTagsMetrics({
    required this.titleLineHeight,
    required this.tagRowExtent,
    required this.timeLineHeight,
  });

  factory GalleryGridTagsMetrics.of(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final inherited = DefaultTextStyle.of(context).style;

    double lineHeight(TextStyle style, {StrutStyle? strutStyle}) {
      final painter = TextPainter(
        text: TextSpan(text: 'Mg国', style: inherited.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        strutStyle: strutStyle,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    return GalleryGridTagsMetrics(
      titleLineHeight: math.max(16, lineHeight(titleStyle)),
      tagRowExtent: math.max(
        18,
        lineHeight(const TextStyle(fontSize: 12, height: 1),
                strutStyle: const StrutStyle(height: 1)) +
            4,
      ),
      timeLineHeight: math.max(14, lineHeight(timeStyle)),
    );
  }

  static const double coverHeightRatio = 4 / 3;
  static const double padding = 8;
  static const double titleGap = 6;
  static const double timeGap = 4;
  static const double tagGap = 4;
  static const int titleLines = 2;
  static const int tagRows = 2;
  static const titleStyle = TextStyle(fontSize: 12, height: 4 / 3);
  static const timeStyle = TextStyle(fontSize: 12, height: 7 / 6);

  final double titleLineHeight;
  final double tagRowExtent;
  final double timeLineHeight;

  double get titleHeight => titleLines * titleLineHeight;
  double get tagsHeight => tagRows * tagRowExtent + tagGap;
  double get informationHeight =>
      padding * 2 +
      titleHeight +
      titleGap +
      tagsHeight +
      timeGap +
      timeLineHeight;

  double cardHeight(double width) =>
      width * coverHeightRatio + informationHeight;
}

/// Keeps each tile equally tall while allowing text scaling and adaptive columns.
class GalleryGridTagsSliver extends StatelessWidget {
  const GalleryGridTagsSliver({
    super.key,
    required this.delegate,
    this.maxCrossAxisExtent = EHConst.gridMaxCrossAxisExtent,
  });

  final SliverChildDelegate delegate;
  final double maxCrossAxisExtent;

  @override
  Widget build(BuildContext context) {
    final metrics = GalleryGridTagsMetrics.of(context);
    final widthDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: maxCrossAxisExtent,
      crossAxisSpacing: EHConst.gridCrossAxisSpacing,
      mainAxisSpacing: EHConst.gridMainAxisSpacing,
    );

    return SliverLayoutBuilder(builder: (context, constraints) {
      final layout =
          widthDelegate.getLayout(constraints) as SliverGridRegularTileLayout;
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent,
          crossAxisSpacing: EHConst.gridCrossAxisSpacing,
          mainAxisSpacing: EHConst.gridMainAxisSpacing,
          mainAxisExtent: metrics.cardHeight(layout.childCrossAxisExtent),
        ),
        delegate: delegate,
      );
    });
  }
}

class GalleryGridTagsInfo extends StatelessWidget {
  const GalleryGridTagsInfo({
    super.key,
    required this.title,
    required this.backgroundColor,
    this.simpleTags,
    this.postTime,
    this.expunged = false,
  });

  final String title;
  final Color backgroundColor;
  final List<SimpleTag>? simpleTags;
  final String? postTime;
  final bool? expunged;

  @override
  Widget build(BuildContext context) {
    final metrics = GalleryGridTagsMetrics.of(context);
    final background = CupertinoDynamicColor.resolve(backgroundColor, context);
    return Padding(
      padding: const EdgeInsets.all(GalleryGridTagsMetrics.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: const ValueKey('grid-tags-title'),
            height: metrics.titleHeight,
            width: double.infinity,
            child: Text(
              title,
              maxLines: GalleryGridTagsMetrics.titleLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: GalleryGridTagsMetrics.titleStyle,
            ),
          ),
          const SizedBox(height: GalleryGridTagsMetrics.titleGap),
          SizedBox(
            key: const ValueKey('grid-tags-tags'),
            height: metrics.tagsHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TagWaterfallFlowViewBox(
                  simpleTags: simpleTags,
                  crossAxisCount: GalleryGridTagsMetrics.tagRows,
                  rowExtent: metrics.tagRowExtent,
                  endPadding: 10,
                ),
                PositionedDirectional(
                  end: 0,
                  top: 0,
                  bottom: 0,
                  width: 10,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: AlignmentDirectional.centerStart,
                          end: AlignmentDirectional.centerEnd,
                          colors: [background.withValues(alpha: 0), background],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: GalleryGridTagsMetrics.timeGap),
          SizedBox(
            key: const ValueKey('grid-tags-time'),
            height: metrics.timeLineHeight,
            child: Text(
              postTime ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GalleryGridTagsMetrics.timeStyle.copyWith(
                color: CupertinoDynamicColor.resolve(
                        CupertinoColors.label, context)
                    .withValues(alpha: .65),
                decoration:
                    expunged == true ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
