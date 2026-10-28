import 'dart:math';

import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

const kDuration = Duration(milliseconds: 300);
const double kDefIndicatorHeight = 4;

final LinkScrollBarController _defaultLinkScrollBarController =
    LinkScrollBarController();

double _linkItemWidth(
    BuildContext context, LinkTabItem item, EdgeInsetsGeometry padding) {
  final painter = TextPainter(
    text: TextSpan(
      text: item.title,
      style: DefaultTextStyle.of(context)
          .style
          .merge(const TextStyle(fontSize: 14)),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width.ceilToDouble() +
      padding.horizontal +
      (item.icon == null ? 0 : 20);
  painter.dispose();
  return width;
}

class LinkTabItem {
  LinkTabItem({
    required this.title,
    this.icon,
    this.iconColor,
    this.actinos,
  });

  final String title;
  final Object? icon;
  final Color? iconColor;
  final List<LinkTabItemAction>? actinos;
}

class LinkTabItemAction {
  LinkTabItemAction({
    required this.actinoText,
    this.icon,
    this.onTap,
    this.color,
  });
  final String actinoText;
  final Object? icon;
  final VoidCallback? onTap;
  final Color? color;
}

class LinkScrollBar extends StatefulWidget {
  LinkScrollBar({
    super.key,
    LinkScrollBarController? controller,
    this.pageController,
    required this.items,
    required this.initIndex,
    this.indicatorHeight = kDefIndicatorHeight,
    this.itemPadding = const EdgeInsets.only(left: 10, right: 10),
    this.onItemChange,
  }) : controller = controller ?? _defaultLinkScrollBarController;

  final List<LinkTabItem> items;
  final int initIndex;
  final double indicatorHeight;
  final EdgeInsetsGeometry itemPadding;
  final LinkScrollBarController controller;
  final ValueChanged<int>? onItemChange;
  final PageController? pageController;

  @override
  State<LinkScrollBar> createState() => _LinkScrollBarState();
}

class _LinkScrollBarState extends State<LinkScrollBar> {
  int selectIndex = 0;
  List<ItemFrame> channelFrameList = [];
  double _maxScrollViewWidth = 0;
  double _indicatorPositionedLeft = 0;
  double _indicatorWidth = 0.0;
  final ScrollController _scrollController = ScrollController();

  double boxWidth = 0.0;
  late ValueChanged<int> _scrollToItemCall;

  List<Widget> _getBarItems(BuildContext context, double boxWidth) {
    this.boxWidth = boxWidth;
    channelFrameList.clear();
    List<Widget> barItems = [];
    _maxScrollViewWidth = 0;

    for (int i = 0; i < widget.items.length; i++) {
      final width =
          _linkItemWidth(context, widget.items[i], widget.itemPadding);
      channelFrameList
          .add(ItemFrame(left: _maxScrollViewWidth, width: width, index: i));
      _maxScrollViewWidth += width;
      final barItem = SizedBox(
        width: width,
        child: Builder(builder: (context) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            child: InnerLinkTabItem(
              title: widget.items[i].title,
              icon: widget.items[i].icon,
              selected: i == selectIndex,
              padding: widget.itemPadding,
              index: i,
            ),
            onTap: () {
              widget.controller.disableScrollToItem();
              setState(() {
                selectIndex = i;
                // WSLCustomTabbarNotification(index: selectIndex).dispatch(context);
                scrollToItem(selectIndex);
                widget.onItemChange?.call(selectIndex);
              });
            },
            onLongPress: () async {
              if (widget.items[i].actinos == null) {
                return;
              }
              vibrateUtil.medium();
              logger.d('onLongPress $i');
              await showItemAttach(
                  margin: const EdgeInsets.only(
                      left: 10, right: 10, top: 10, bottom: 40),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.items[i].actinos!
                          .map((e) => GestureDetector(
                                onTap: () {
                                  SmartDialog.dismiss();
                                  e.onTap?.call();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (e.icon != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 12.0),
                                          child: _buildLinkIcon(
                                            e.icon,
                                            size: 16,
                                            color: e.color ??
                                                CupertinoDynamicColor.resolve(
                                                    CupertinoColors.label,
                                                    context),
                                          ),
                                        ),
                                      Text(
                                        e.actinoText,
                                        style: TextStyle(
                                            fontSize: 16, color: e.color),
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  targetContext: context);
            },
          );
        }),
      );

      barItems.add(barItem);
    }
    if (channelFrameList.isNotEmpty) {
      final selected =
          channelFrameList[selectIndex.clamp(0, channelFrameList.length - 1)];
      _indicatorPositionedLeft =
          selected.left + widget.itemPadding.horizontal / 2;
      _indicatorWidth = max(0, selected.width - widget.itemPadding.horizontal);
    }
    return barItems;
  }

  void scrollToItem(int index) {
    if (!mounted || channelFrameList.isEmpty || !_scrollController.hasClients) {
      return;
    }
    ItemFrame channelFrame = channelFrameList[
        min(max(index, 0), max(channelFrameList.length - 1, 0))];

    _indicatorPositionedLeft =
        channelFrame.left + widget.itemPadding.horizontal / 2;
    _indicatorWidth = channelFrame.width - widget.itemPadding.horizontal;

    //计算选中的导航item的中心点
    double centerX = channelFrame.left + channelFrame.width / 2.0;
    //设定需要滚动的偏移量
    double needScrollView = 0;
    //当选中的导航item在中心偏左时
    if (centerX - _scrollController.offset < boxWidth / 2.0) {
      needScrollView = boxWidth / 2.0 - centerX + _scrollController.offset;
      //存在滚动条件
      if (_scrollController.offset > 0) {
        //当无法满足滚动到正中心的位置，就直接回到偏移量原点
        if (_scrollController.offset < needScrollView) {
          needScrollView = _scrollController.offset;
        }
        //进行偏移量动画滚动
        _scrollController.animateTo(_scrollController.offset - needScrollView,
            duration: kDuration, curve: Curves.ease);
      }
    } else {
      //当选中的导航item在中心偏右时
      needScrollView = centerX - _scrollController.offset - boxWidth / 2.0;
      if (_scrollController.position.maxScrollExtent -
              _scrollController.offset >
          0) {
        //不满足回滚到中间位置，设置为滚到最大位置
        if (_scrollController.position.maxScrollExtent -
                _scrollController.offset <
            needScrollView) {
          needScrollView = _scrollController.position.maxScrollExtent -
              _scrollController.offset;
        }
        _scrollController.animateTo(_scrollController.offset + needScrollView,
            duration: kDuration, curve: Curves.ease);
      }
    }
  }

  void bindController() {
    final owner = widget.controller;
    _scrollToItemCall = (index) {
      if (!mounted || !identical(widget.controller, owner)) {
        return;
      }
      setState(() {
        selectIndex = index;
      });
      scrollToItem(index);
    };
    owner.scrollToItemCall = _scrollToItemCall;
  }

  void _unbindController(LinkScrollBarController controller) {
    if (identical(controller.scrollToItemCall, _scrollToItemCall)) {
      controller.scrollToItemCall = null;
    }
  }

  @override
  void didUpdateWidget(covariant LinkScrollBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _unbindController(oldWidget.controller);
      bindController();
    }
  }

  @override
  void dispose() {
    _unbindController(widget.controller);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    bindController();
    logger.t('_LinkScrollBarState initState selectIndex:${widget.initIndex}');

    selectIndex = widget.initIndex;
    // _indicatorPositionedLeft = widget.itemPadding.horizontal / 2;

    // Item extents are known on the first layout, including text scaling.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      scrollToItem(widget.initIndex);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final bool useLiquidGlass = Get.isRegistered<EhSettingService>() &&
        Get.find<EhSettingService>().liquidGlass &&
        LiquidGlassPlatform.isSupported;

    final indicator = AnimatedContainer(
      height: widget.indicatorHeight,
      width: _indicatorWidth,
      decoration: BoxDecoration(
        color: CupertinoColors.activeBlue,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.indicatorHeight * 3 / 4),
          topRight: Radius.circular(widget.indicatorHeight * 3 / 4),
        ),
      ),
      duration: kDuration,
      curve: Curves.ease,
    );

    return LayoutBuilder(builder: (context, c) {
      final items = _getBarItems(context, c.maxWidth);
      final scrollViewWidth = _maxScrollViewWidth;
      return SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _maxScrollViewWidth,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: items,
                ),
              ),
              if (!useLiquidGlass && widget.pageController == null)
                Stack(
                  children: [
                    SizedBox(
                        height: widget.indicatorHeight, width: scrollViewWidth),
                    AnimatedPositioned(
                      left: _indicatorPositionedLeft,
                      duration: kDuration,
                      curve: Curves.ease,
                      child: indicator,
                    ),
                  ],
                ),
              if (!useLiquidGlass &&
                  widget.pageController != null &&
                  channelFrameList.isNotEmpty)
                TitleIndicator(
                  height: widget.indicatorHeight,
                  pageController: widget.pageController,
                  channelFrameList: channelFrameList,
                  maxWidth: scrollViewWidth,
                  width: c.maxWidth,
                  index: selectIndex,
                  itemPadding: widget.itemPadding,
                ),
            ],
          ),
        ),
      );
    });
  }
}

class TitleIndicator extends StatefulWidget {
  const TitleIndicator({
    super.key,
    this.maxWidth,
    this.pageController,
    required this.channelFrameList,
    required this.width,
    required this.index,
    this.itemPadding,
    this.height = 0.0,
  });
  final double? maxWidth;
  final PageController? pageController;
  final List<ItemFrame> channelFrameList;
  final double width;
  final double height;
  final int index;
  final EdgeInsetsGeometry? itemPadding;

  @override
  State<TitleIndicator> createState() => _TitleIndicatorState();
}

class _TitleIndicatorState extends State<TitleIndicator> {
  double positionedLeft = 0.0;
  double _indicatorWidth = 0.0;
  @override
  void initState() {
    super.initState();
    logger.t('_TitleIndicatorState initState index:${widget.index}');
    _updateGeometry();
    widget.pageController?.addListener(_listen);
  }

  void _updateGeometry() {
    final frames = widget.channelFrameList;
    if (frames.isEmpty) {
      positionedLeft = 0;
      _indicatorWidth = 0;
      return;
    }
    final controller = widget.pageController;
    final page = (controller != null && controller.positions.length == 1
            ? controller.page ?? widget.index.toDouble()
            : widget.index.toDouble())
        .clamp(0.0, frames.length - 1.0);
    final index = page.floor();
    final next = min(index + 1, frames.length - 1);
    final fraction = page - index;
    final padding = widget.itemPadding?.horizontal ?? 0;
    positionedLeft = frames[index].left +
        fraction * (frames[next].left - frames[index].left) +
        padding / 2;
    _indicatorWidth = max(
        0,
        frames[index].width +
            fraction * (frames[next].width - frames[index].width) -
            padding);
  }

  void _listen() {
    if (mounted) setState(_updateGeometry);
  }

  @override
  void didUpdateWidget(TitleIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pageController, widget.pageController)) {
      oldWidget.pageController?.removeListener(_listen);
      widget.pageController?.addListener(_listen);
    }
    _updateGeometry();
  }

  @override
  void dispose() {
    widget.pageController?.removeListener(_listen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned(
            left: positionedLeft,
            child: Container(
              width: _indicatorWidth,
              height: widget.height,
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(widget.height * 3 / 4),
                  topRight: Radius.circular(widget.height * 3 / 4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//导航栏item组件封装
class InnerLinkTabItem extends StatefulWidget {
  const InnerLinkTabItem({
    super.key,
    required this.title,
    this.selected = false,
    this.padding,
    required this.index,
    this.icon,
    double? iconSize,
  }) : iconSize = icon == null ? 0 : (iconSize ?? 16);

  final String title;
  final EdgeInsetsGeometry? padding;
  final bool selected;
  final int index;
  final Object? icon;
  final double iconSize;

  @override
  State<InnerLinkTabItem> createState() => _InnerLinkTabItemState();
}

class _InnerLinkTabItemState extends State<InnerLinkTabItem> {
  final GlobalKey _key = GlobalKey();

  double get width {
    return getTextSize(widget.title, style).width +
        (widget.padding?.horizontal ?? 0);
  }

  TextStyle get style => TextStyle(
        fontSize: widget.selected ? 14.0 : 14.0,
        color: CupertinoDynamicColor.resolve(
            widget.selected
                ? CupertinoColors.activeBlue
                : CupertinoColors.label,
            context),
        // fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      );

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance?.addPostFrameCallback((_) {
    //   logger.d('${context.size?.width} $width');
    //   // WSLGetWidgetWithNotification(
    //   //         width: context.size?.width ?? 0.0, index: widget.index)
    //   //     .dispatch(context);
    //   // WSLGetWidgetWithNotification(width: width, index: widget.index)
    //   //     .dispatch(context);
    // });
  }

  @override
  Widget build(BuildContext context) {
    if (Get.isRegistered<EhSettingService>()) {
      return Obx(() => _buildItem(
            context,
            Get.find<EhSettingService>().liquidGlass &&
                LiquidGlassPlatform.isSupported,
            Get.find<EhSettingService>().liquidGlassFollowSystemTransparency,
          ));
    }
    return _buildItem(context, false, true);
  }

  Widget _buildItem(
    BuildContext context,
    bool liquidGlassEnabled,
    bool followSystemTransparency,
  ) {
    WSLGetWidgetWithNotification(
            width: width + widget.iconSize + 4, index: widget.index)
        .dispatch(context);

    final Widget item = Container(
      key: _key,
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          Row(
            children: [
              if (widget.icon != null)
                _buildLinkIcon(
                  widget.icon,
                  size: widget.iconSize,
                ),
              if (widget.icon != null) const SizedBox(width: 4),
              Text(
                widget.title,
                style: style,
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );

    if (!liquidGlassEnabled || !widget.selected) {
      return item;
    }

    return LiquidGlassSurface(
      enabled: true,
      borderRadius: BorderRadius.circular(18),
      followSystemTransparency: followSystemTransparency,
      child: item,
    );
  }
}

Widget _buildLinkIcon(
  Object? icon, {
  required double size,
  Color? color,
}) {
  if (icon is FaIconData) {
    return FaIcon(icon, size: size, color: color);
  }
  return Icon(icon as IconData?, size: size, color: color);
}

class WSLChannelScrollViewNeedScrollEvent {
  WSLChannelScrollViewNeedScrollEvent(this.index);

  int index = 0;
}

class WSLCustomTabbarNotification extends Notification {
  WSLCustomTabbarNotification({required this.index});

  final int index;
}

class WSLGetWidgetWithNotification extends Notification {
  WSLGetWidgetWithNotification({required this.width, required this.index});

  final double width;
  final int index;
}

class ItemFrame {
  ItemFrame({
    this.left = 0,
    this.width = 0,
    this.index = 0,
  });

  double left; //距离左侧距离
  double width; //item宽度
  int index;
}

class FooSliverPersistentHeaderDelegate extends SliverPersistentHeaderDelegate {
  FooSliverPersistentHeaderDelegate({
    required this.builder,
    required this.maxHeight,
    required this.minHeight,
  });

  final double minHeight;
  final double maxHeight;

  final Widget Function(
      BuildContext context, double shrinkOffset, bool overlapsContent) builder;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      builder(context, shrinkOffset, overlapsContent);

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    // The builder captures live tab state (selected index, categories and
    // Liquid Glass transition progress). Comparing only the extents leaves a
    // stale header in place after PageView changes tabs.
    return true;
  }
}

Future showItemAttach({
  required BuildContext targetContext,
  required Widget child,
  String? tag,
  VoidCallback? onDismiss,
  double? width,
  EdgeInsetsGeometry? margin,
  AlignmentGeometry? alignmentTemp,
}) async {
  await SmartDialog.showAttach(
    highlightBuilder: (Offset targetOffset, Size targetSize) {
      return Positioned(
        left: targetOffset.dx,
        top: targetOffset.dy + 2,
        child: Container(
          height: targetSize.height - 4,
          width: targetSize.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
        ),
      );
    },
    tag: tag,
    keepSingle: true,
    targetContext: targetContext,
    onDismiss: onDismiss,
    builder: (BuildContext context) {
      return SafeArea(
        top: false,
        bottom: false,
        child: Container(
          width: width,
          margin: margin,
          // constraints: const BoxConstraints(maxHeight: 300, minHeight: 50),
          // decoration: BoxDecoration(
          //   borderRadius: BorderRadius.circular(16),
          //   boxShadow: [
          //     BoxShadow(
          //       color: Colors.black.withOpacity(0.2),
          //       offset: const Offset(0, 0),
          //       blurRadius: 10, //阴影模糊程度
          //       spreadRadius: 1, //阴影扩散程度
          //     ),
          //   ],
          // ),
          // color: CupertinoColors.systemGrey5,
          child: EhPopupSurface(
            child: child,
          ),
        ),
      );
    },
  );
}
