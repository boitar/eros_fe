import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// The top obstruction that a portrait iPhone exposes through its safe area.
///
/// We deliberately classify by the runtime safe-area geometry instead of by a
/// model-name list. This keeps the collapse behavior working for new iPhones
/// whose cutout dimensions are not known when this app is built.
enum LiquidGlassCutout {
  dynamicIsland,
  notch,
  none,
}

/// The two public UIKit Liquid Glass variants available on iOS 26+ and
/// refined by the iOS 27 system appearance.
///
/// `regular` is the legibility-first material used by navigation surfaces.
/// `clear` is reserved for small controls over visually rich content, matching
/// the distinction Apple makes in the HIG and the local XHS reference build.
enum LiquidGlassStyle {
  regular,
  clear,
}

@immutable
class LiquidGlassTopLayout {
  const LiquidGlassTopLayout({
    required this.safeTop,
    required this.cutout,
  });

  factory LiquidGlassTopLayout.fromMediaQuery(MediaQueryData data) {
    // The current top rail is a portrait iPhone interaction. In landscape the
    // notch can be represented by horizontal insets, but moving a vertical
    // rail into that area would make the content and hit targets ambiguous.
    final double safeTop =
        data.orientation == Orientation.portrait ? data.viewPadding.top : 0.0;
    return LiquidGlassTopLayout.fromTopInset(safeTop);
  }

  factory LiquidGlassTopLayout.fromTopInset(double topInset) {
    final double safeTop = topInset.isFinite ? math.max(0.0, topInset) : 0.0;
    final LiquidGlassCutout cutout;
    if (safeTop >= 54.0) {
      cutout = LiquidGlassCutout.dynamicIsland;
    } else if (safeTop >= 40.0) {
      cutout = LiquidGlassCutout.notch;
    } else {
      cutout = LiquidGlassCutout.none;
    }
    return LiquidGlassTopLayout(safeTop: safeTop, cutout: cutout);
  }

  final double safeTop;
  final LiquidGlassCutout cutout;

  bool get canDockTopRail => cutout != LiquidGlassCutout.none;

  /// The bottom edge to which the rail is docked before it is removed.
  ///
  /// Dynamic Island devices leave a larger gap between the island and the
  /// safe-area content than notch devices do. The values describe an
  /// occlusion target, not a fake island drawn by the app.
  double get dockedBottom {
    switch (cutout) {
      case LiquidGlassCutout.dynamicIsland:
        return math.max(0.0, safeTop - 22.0);
      case LiquidGlassCutout.notch:
        return math.max(0.0, safeTop - 3.0);
      case LiquidGlassCutout.none:
        return 0.0;
    }
  }

  /// Additional translation after the sliver has collapsed to the safe area.
  double get dockingTranslation =>
      canDockTopRail ? math.max(0.0, safeTop - dockedBottom) : 0.0;

  /// The empty pinned height left by a fully collapsed top rail.
  double get collapsedHeaderHeight => safeTop;

  double collapseProgress(double offset, double maxOffset) {
    if (maxOffset <= 0.0) {
      return 0.0;
    }
    return (offset / maxOffset).clamp(0.0, 1.0);
  }
}

class LiquidGlassPlatform {
  LiquidGlassPlatform._();

  static const String viewType = 'eros/liquid-glass';
  static const String tabBarViewType = 'eros/liquid-glass-tab-bar';

  /// The setting must remain visible in hosted runtimes such as LiveContainer.
  ///
  /// Dart's `Platform.operatingSystemVersion` can describe the host/runtime
  /// differently from the iOS version exposed to UIKit there. The native
  /// platform view already performs the real availability check with
  /// `#available(iOS 26.0, *)` and falls back to a system blur on older iOS,
  /// so a Dart version parser must not hide the user's switch or disable the
  /// whole feature path.
  static bool get isSupported {
    return Platform.isIOS;
  }
}

/// Serializable description of one tab for the native bottom-bar renderer.
/// The Flutter tab item remains the source of truth for navigation; this
/// descriptor only lets UIKit draw the same icon and localized label.
@immutable
class LiquidGlassTabItem {
  const LiquidGlassTabItem({
    required this.label,
    required this.codePoint,
    this.fontFamily,
    this.fontPackage,
    required this.fallbackSymbol,
  });

  final String label;
  final int codePoint;
  final String? fontFamily;
  final String? fontPackage;
  final String fallbackSymbol;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'label': label,
        'codePoint': codePoint,
        'fontFamily': fontFamily,
        'fontPackage': fontPackage,
        'fallbackSymbol': fallbackSymbol,
      };
}

/// A small native Liquid Glass surface that can sit behind Flutter content.
///
/// The Flutter fallback is intentionally only used when the native material
/// is unavailable. The app never creates a platform view on non-iOS targets.
class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.enabled,
    this.borderRadius = BorderRadius.zero,
    this.style = LiquidGlassStyle.regular,
    this.interactive = false,
    this.followSystemTransparency = true,
    this.useNativeGlass = true,
    this.containerSpacing = 0.0,
    this.emphasizeFallbackEdge = false,
    this.child,
  });

  final bool enabled;
  final BorderRadius borderRadius;
  final LiquidGlassStyle style;
  final bool interactive;

  /// When true, use UIKit's UIGlassEffect so iOS owns the Liquid Glass
  /// appearance (including the system Appearance > Liquid Glass setting).
  /// When false, the native bridge uses the legacy blur fallback.
  final bool followSystemTransparency;

  /// Large background surfaces can opt into Flutter composition. A UIKit
  /// platform view is always composited above the Flutter scene on iOS; that
  /// is correct for a glass control with native children, but it can occlude
  /// sibling Flutter labels in a large tab rail. The Flutter path keeps the
  /// same material intent while allowing the tab content to remain legible.
  final bool useNativeGlass;
  final double containerSpacing;

  /// Adds the explicit outline/highlight needed by a large Flutter-composed
  /// surface. Native UIGlassEffect owns this edge treatment itself; the
  /// fallback needs a small amount of adaptive definition so a wide capsule
  /// does not disappear into a light background or become a flat dark block.
  final bool emphasizeFallbackEdge;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size viewport = MediaQuery.sizeOf(context);
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : viewport.width;
        final double maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : viewport.height;
        final double minWidth = math.min(
          constraints.minWidth.isFinite ? constraints.minWidth : 0.0,
          maxWidth,
        );
        final double minHeight = math.min(
          constraints.minHeight.isFinite ? constraints.minHeight : 0.0,
          maxHeight,
        );

        final Widget background;
        if (enabled && useNativeGlass && LiquidGlassPlatform.isSupported) {
          background = UiKitView(
            key: ValueKey<String>(
              '${style.name}:$followSystemTransparency:$interactive:$containerSpacing',
            ),
            viewType: LiquidGlassPlatform.viewType,
            creationParams: <String, dynamic>{
              'cornerRadius': borderRadius.topLeft.x,
              'style': style.name,
              'interactive': interactive,
              'followSystemTransparency': followSystemTransparency,
              'containerSpacing': containerSpacing,
            },
            creationParamsCodec: const StandardMessageCodec(),
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          );
        } else if (enabled) {
          final bool isClear = style == LiquidGlassStyle.clear;
          final bool isDark =
              CupertinoTheme.brightnessOf(context) == Brightness.dark;
          final Color fallbackBackground = CupertinoDynamicColor.resolve(
            isClear
                ? CupertinoColors.systemBackground
                : CupertinoColors.secondarySystemBackground,
            context,
          );
          final Color separator = CupertinoDynamicColor.resolve(
            CupertinoColors.separator,
            context,
          );
          final Color highlight = CupertinoDynamicColor.resolve(
            CupertinoColors.systemBackground,
            context,
          );
          final double fillAlpha = isClear
              ? 0.26
              : (emphasizeFallbackEdge ? (isDark ? 0.72 : 0.64) : 0.68);
          final double borderAlpha = isClear
              ? 0.14
              : (emphasizeFallbackEdge ? (isDark ? 0.34 : 0.28) : 0.22);
          background = BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: isClear ? 12.0 : 18.0,
              sigmaY: isClear ? 12.0 : 18.0,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: fallbackBackground.withValues(alpha: fillAlpha),
                    border: Border.all(
                      color: separator.withValues(alpha: borderAlpha),
                      width: emphasizeFallbackEdge ? 0.8 : 1.0,
                    ),
                    boxShadow: emphasizeFallbackEdge
                        ? <BoxShadow>[
                            BoxShadow(
                              color: CupertinoColors.black.withValues(
                                alpha: isDark ? 0.28 : 0.08,
                              ),
                              blurRadius: 8.0,
                              offset: const Offset(0.0, 2.0),
                            ),
                          ]
                        : null,
                  ),
                ),
                if (emphasizeFallbackEdge)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: highlight.withValues(
                            alpha: isDark ? 0.16 : 0.52,
                          ),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        } else {
          background = const SizedBox.expand();
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            maxHeight: maxHeight,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              // Keep a selected category capsule at its intrinsic width; the
              // platform view must never inherit an infinite loose width.
              fit: StackFit.passthrough,
              children: <Widget>[
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: IgnorePointer(child: background),
                  ),
                ),
                if (child != null) child!,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bridges real vertical scroll direction to the compact bottom-navigation
/// state. This intentionally uses deltas rather than absolute offset: the
/// bar responds to the same "recede while reading, return while looking back"
/// rhythm as iOS 27 and the XHS reference, even when the content is nested.
class LiquidGlassBarMotion extends ValueNotifier<double> {
  LiquidGlassBarMotion() : super(0.0);

  double _lastPixels = 0.0;
  bool _hasLastPixels = false;

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final pixels = notification.metrics.pixels;
    if (notification is ScrollStartNotification) {
      _lastPixels = pixels;
      _hasLastPixels = true;
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      // ExtendedNestedScrollView emits a second, ballistic update stream
      // while it links the outer header and the inner list. Those updates can
      // run in the opposite direction after an upward drag and would reopen
      // the bar immediately. Only direct touch-drag deltas drive the compact
      // state; ScrollEndNotification still handles the top-edge reset.
      if (notification.dragDetails == null) {
        return false;
      }
      final delta = notification.scrollDelta ??
          (_hasLastPixels ? pixels - _lastPixels : 0.0);
      _lastPixels = pixels;
      _hasLastPixels = true;

      if (pixels <= notification.metrics.minScrollExtent + 0.5 && delta <= 0) {
        value = 0.0;
      } else if (delta > 0.0) {
        value = (value + delta / 150.0).clamp(0.0, 1.0);
      } else if (delta < 0.0) {
        value = (value + delta / 105.0).clamp(0.0, 1.0);
      }
    } else if (notification is ScrollEndNotification) {
      // Settle the visual state at the end of a real drag. Without this,
      // NestedScrollView can leave the bar at an in-between progress where
      // the expanded controls are already non-interactive but the compact
      // affordance has not appeared yet.
      if (pixels <= notification.metrics.minScrollExtent + 0.5) {
        value = 0.0;
      } else {
        value = value >= 0.5 ? 1.0 : 0.0;
      }
    }
    return false;
  }

  void reset() {
    _hasLastPixels = false;
    value = 0.0;
  }
}

/// A Cupertino tab bar that keeps Flutter's tab semantics and gestures while
/// placing a native Liquid Glass surface behind the items.
class LiquidGlassTabBar extends CupertinoTabBar {
  const LiquidGlassTabBar({
    super.key,
    required super.items,
    super.onTap,
    this.onSearch,
    this.motion,
    this.followSystemTransparency = true,
    this.hideSearchOnScroll = false,
    this.nativeItems,
    super.currentIndex,
    super.activeColor,
    super.inactiveColor = CupertinoColors.label,
    super.iconSize,
    super.height = 68,
    super.border = const Border(),
  }) : super(backgroundColor: const Color(0x00000000));

  /// The independent search control shown beside the five-item glass rail.
  /// Keeping it outside the tab hit targets matches the Glass Rail prototype
  /// and prevents search from stealing a tab's drag gesture.
  final VoidCallback? onSearch;
  final LiquidGlassBarMotion? motion;
  final bool followSystemTransparency;
  final bool hideSearchOnScroll;
  final List<LiquidGlassTabItem>? nativeItems;

  @override
  bool opaque(BuildContext context) => false;

  @override
  Widget build(BuildContext context) {
    final motion = this.motion;
    if (motion == null) {
      return _buildBar(context, 0.0);
    }
    return ValueListenableBuilder<double>(
      valueListenable: motion,
      builder: (context, progress, child) => _buildBar(context, progress),
    );
  }

  Widget _buildBar(BuildContext context, double rawMinimizeProgress) {
    if (LiquidGlassPlatform.isSupported && nativeItems != null) {
      return _buildNativeBar(context, rawMinimizeProgress);
    }
    return _buildFlutterBar(context, rawMinimizeProgress);
  }

  Widget _buildNativeBar(BuildContext context, double rawMinimizeProgress) {
    final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    return _NativeLiquidGlassTabBar(
      items: nativeItems!,
      selectedIndex: _clampTabIndex(currentIndex, nativeItems!.length),
      collapseProgress: rawMinimizeProgress.clamp(0.0, 1.0),
      hideSearchOnScroll: hideSearchOnScroll,
      followSystemTransparency: followSystemTransparency,
      bottomInset: bottomPadding,
      height: height,
      onTap: onTap,
      onExpand: motion?.reset,
      onSearch: onSearch,
    );
  }

  void _expandCollapsedBar() {
    motion?.reset();
  }

  Widget _buildFlutterBar(BuildContext context, double rawMinimizeProgress) {
    final double minimizeProgress = rawMinimizeProgress.clamp(0.0, 1.0);
    final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // CupertinoTabScaffold positions its tab bar with loose horizontal
        // constraints. Keep the platform view finite even while the scaffold
        // is rebuilding (an infinite UiKitView frame becomes NaN in UIKit).
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final double barHeight = height + bottomPadding;
        final double expandedGlassHeight = math.max(0.0, height - 12.0);
        final double glassHeight = ui.lerpDouble(
              expandedGlassHeight,
              math.min(expandedGlassHeight, 48.0),
              minimizeProgress,
            ) ??
            expandedGlassHeight;
        final double searchInset = onSearch == null ? 12.0 : 76.0;
        final double expandedWidth = math.max(0.0, width - 12.0 - searchInset);
        // The collapsed state is deliberately an icon-only 48x48 control.
        // This leaves a real 44pt+ hit target without carrying the old label
        // and excess capsule width into the reading state.
        final double compactWidth = math.min(48.0, expandedWidth);
        final double shellWidth = ui.lerpDouble(
              expandedWidth,
              compactWidth,
              Curves.easeInOutCubic.transform(minimizeProgress),
            ) ??
            expandedWidth;
        final double shellTop = ui.lerpDouble(
              6.0,
              10.0,
              minimizeProgress,
            ) ??
            6.0;
        final double shellRadius =
            ui.lerpDouble(30.0, 24.0, minimizeProgress) ?? 30.0;
        final int selected = _clampTabIndex(currentIndex, items.length);
        final BottomNavigationBarItem? compactItem =
            items.isEmpty ? null : items[selected];

        Widget expandedTabs = _InteractiveLiquidGlassTabs(
          items: items,
          currentIndex: currentIndex,
          onTap: onTap,
          activeColor: activeColor ?? CupertinoColors.activeBlue,
          inactiveColor: inactiveColor,
          iconSize: iconSize,
          followSystemTransparency: followSystemTransparency,
        );
        if (minimizeProgress >= 0.84) {
          expandedTabs = ExcludeSemantics(child: expandedTabs);
        }
        expandedTabs = IgnorePointer(
          ignoring: minimizeProgress >= 0.70,
          child: Opacity(
            opacity: (1.0 - minimizeProgress).clamp(0.0, 1.0),
            child: expandedTabs,
          ),
        );

        Widget compactTabs = compactItem == null
            ? const SizedBox.shrink()
            : Opacity(
                opacity: Curves.easeInOut.transform(minimizeProgress),
                child: _CompactLiquidGlassTab(
                  item: compactItem,
                  onExpand: _expandCollapsedBar,
                  activeColor: activeColor ?? CupertinoColors.activeBlue,
                  iconSize: iconSize,
                ),
              );
        compactTabs = IgnorePointer(
          ignoring: minimizeProgress < 0.70,
          child: compactTabs,
        );

        return SizedBox(
          width: width.isFinite ? width : 0.0,
          height: barHeight.isFinite ? barHeight : preferredSize.height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: 12,
                width: shellWidth,
                top: shellTop,
                height: glassHeight,
                child: LiquidGlassSurface(
                  enabled: true,
                  borderRadius: BorderRadius.all(Radius.circular(shellRadius)),
                  style: LiquidGlassStyle.regular,
                  interactive: true,
                  followSystemTransparency: followSystemTransparency,
                  // Keep the large shell in Flutter composition. iOS 27 puts
                  // a UiKitView above the Flutter scene, which would hide
                  // the unselected labels even though they remain in the
                  // accessibility tree. Small controls still use native
                  // UIGlassEffect surfaces below.
                  useNativeGlass: false,
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: 12,
                width: shellWidth,
                top: shellTop,
                height: glassHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[expandedTabs, compactTabs],
                ),
              ),
              if (onSearch != null)
                Positioned(
                  right: 12,
                  top: shellTop,
                  width: 56,
                  height: glassHeight,
                  child: IgnorePointer(
                    ignoring: hideSearchOnScroll && minimizeProgress >= 0.70,
                    child: Opacity(
                      opacity: hideSearchOnScroll
                          ? (1.0 - Curves.easeInOut.transform(minimizeProgress))
                              .clamp(0.0, 1.0)
                          : 1.0,
                      child: LiquidGlassSurface(
                        enabled: true,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(28)),
                        style: LiquidGlassStyle.clear,
                        interactive: true,
                        followSystemTransparency: followSystemTransparency,
                        child: Semantics(
                          button: true,
                          label: '搜索',
                          hidden:
                              hideSearchOnScroll && minimizeProgress >= 0.84,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onSearch,
                            child: Center(
                              child: Icon(
                                CupertinoIcons.search,
                                size: 24,
                                color: CupertinoDynamicColor.resolve(
                                  CupertinoColors.label,
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  LiquidGlassTabBar copyWith({
    Key? key,
    List<BottomNavigationBarItem>? items,
    Color? backgroundColor,
    Color? activeColor,
    Color? inactiveColor,
    double? iconSize,
    double? height,
    Border? border,
    int? currentIndex,
    ValueChanged<int>? onTap,
  }) {
    return LiquidGlassTabBar(
      key: key ?? this.key,
      items: items ?? this.items,
      activeColor: activeColor ?? this.activeColor,
      inactiveColor: inactiveColor ?? this.inactiveColor,
      iconSize: iconSize ?? this.iconSize,
      height: height ?? this.height,
      border: border ?? this.border,
      currentIndex: currentIndex ?? this.currentIndex,
      onTap: onTap ?? this.onTap,
      onSearch: onSearch ?? this.onSearch,
      motion: motion,
      followSystemTransparency: followSystemTransparency,
      hideSearchOnScroll: hideSearchOnScroll,
      nativeItems: nativeItems,
    );
  }
}

class _NativeLiquidGlassTabBar extends StatefulWidget {
  const _NativeLiquidGlassTabBar({
    required this.items,
    required this.selectedIndex,
    required this.collapseProgress,
    required this.hideSearchOnScroll,
    required this.followSystemTransparency,
    required this.bottomInset,
    required this.height,
    this.onTap,
    this.onExpand,
    this.onSearch,
  });

  final List<LiquidGlassTabItem> items;
  final int selectedIndex;
  final double collapseProgress;
  final bool hideSearchOnScroll;
  final bool followSystemTransparency;
  final double bottomInset;
  final double height;
  final ValueChanged<int>? onTap;
  final VoidCallback? onExpand;
  final VoidCallback? onSearch;

  @override
  State<_NativeLiquidGlassTabBar> createState() =>
      _NativeLiquidGlassTabBarState();
}

class _NativeLiquidGlassTabBarState extends State<_NativeLiquidGlassTabBar> {
  MethodChannel? _channel;

  Map<String, dynamic> _creationParams() => <String, dynamic>{
        'items': widget.items.map((item) => item.toMap()).toList(),
        'selectedIndex': widget.selectedIndex,
        'collapseProgress': widget.collapseProgress,
        'hideSearchOnScroll': widget.hideSearchOnScroll,
        'followSystemTransparency': widget.followSystemTransparency,
        'bottomInset': widget.bottomInset,
        'height': widget.height,
        'hasSearch': widget.onSearch != null,
      };

  void _sendUpdate() {
    final MethodChannel? channel = _channel;
    if (channel == null) {
      return;
    }
    channel.invokeMethod<void>('update', _creationParams());
  }

  void _handlePlatformViewCreated(int viewId) {
    final MethodChannel channel = MethodChannel(
      'eros/liquid-glass-tab-bar/$viewId',
    );
    _channel = channel;
    channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'select':
        case 'dragCommitted':
          final Object? value = call.arguments;
          if (value is num) {
            widget.onTap?.call(value.toInt());
          }
          return null;
        case 'search':
          widget.onSearch?.call();
          return null;
        case 'expand':
          widget.onExpand?.call();
          return null;
        default:
          return null;
      }
    });
    _sendUpdate();
  }

  @override
  void didUpdateWidget(covariant _NativeLiquidGlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sendUpdate();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double barHeight = widget.height + widget.bottomInset;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return SizedBox(
          width: width.isFinite ? width : 0.0,
          height: barHeight.isFinite ? barHeight : widget.height,
          child: UiKitView(
            viewType: LiquidGlassPlatform.tabBarViewType,
            creationParams: _creationParams(),
            creationParamsCodec: const StandardMessageCodec(),
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            onPlatformViewCreated: _handlePlatformViewCreated,
          ),
        );
      },
    );
  }
}

int _clampTabIndex(int index, int itemCount) {
  if (itemCount <= 0) {
    return 0;
  }
  return index.clamp(0, itemCount - 1);
}

class _CompactLiquidGlassTab extends StatelessWidget {
  const _CompactLiquidGlassTab({
    required this.item,
    required this.onExpand,
    required this.activeColor,
    required this.iconSize,
  });

  final BottomNavigationBarItem item;
  final VoidCallback onExpand;
  final Color activeColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: true,
      label: item.label,
      hint: '点击展开底栏',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onExpand,
        // Compete with the tap recognizer so a long press remains inert.
        onLongPress: () {},
        child: SizedBox(
          key: const ValueKey<String>('liquid-glass-compact-tab'),
          width: 48,
          height: 48,
          child: Center(
            child: IconTheme(
              data: IconThemeData(size: iconSize, color: activeColor),
              child: item.activeIcon,
            ),
          ),
        ),
      ),
    );
  }
}

/// The interactive part of the floating rail. The native surface behind this
/// widget supplies the iOS 26 glass lens; this layer supplies the tab-bar
/// motion contract that a platform view alone cannot provide to Flutter:
/// direct drag preview, a moving selection capsule, and a monotonic settle.
class _InteractiveLiquidGlassTabs extends StatefulWidget {
  const _InteractiveLiquidGlassTabs({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    required this.iconSize,
    required this.followSystemTransparency,
  });

  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final Color activeColor;
  final Color inactiveColor;
  final double iconSize;
  final bool followSystemTransparency;

  @override
  State<_InteractiveLiquidGlassTabs> createState() =>
      _InteractiveLiquidGlassTabsState();
}

class _InteractiveLiquidGlassTabsState
    extends State<_InteractiveLiquidGlassTabs> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  double _dragOffset = 0.0;
  double _visualPosition = 0.0;
  double _dragBasePosition = 0.0;
  bool _dragging = false;
  int? _pointerId;
  double _pointerStartX = 0.0;
  late final AnimationController _settleController;
  double _settleStart = 0.0;
  double _settleTarget = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _clampIndex(widget.currentIndex);
    _visualPosition = _selectedIndex.toDouble();
    _settleController = AnimationController(vsync: this)
      ..addListener(_handleSettleTick);
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _InteractiveLiquidGlassTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && widget.currentIndex != oldWidget.currentIndex) {
      _animateToIndex(_clampIndex(widget.currentIndex), notify: false);
    }
  }

  int _clampIndex(int index) {
    if (widget.items.isEmpty) return 0;
    return index.clamp(0, widget.items.length - 1);
  }

  void _handleSettleTick() {
    if (!mounted) return;
    setState(() {
      _visualPosition = ui.lerpDouble(
            _settleStart,
            _settleTarget,
            _settleController.value,
          ) ??
          _settleTarget;
    });
  }

  void _animateToIndex(int index, {required bool notify}) {
    final target = _clampIndex(index);
    _settleController.stop();
    final start = _visualPosition;
    setState(() {
      _selectedIndex = target;
      _dragOffset = 0.0;
      _dragging = false;
      _settleStart = start;
      _settleTarget = target.toDouble();
    });
    if (notify) {
      widget.onTap?.call(target);
    }
    if ((start - target).abs() < 0.001) {
      return;
    }
    _settleController.value = 0.0;
    // A spring can cross the target and make the glass lens visibly rebound
    // after a successful drag. The selection is already committed above, so
    // use a short, non-overshooting ease-out to settle the visual lens.
    _settleController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _select(int index) {
    _animateToIndex(index, notify: true);
  }

  void _onPointerDown(PointerDownEvent event) {
    _settleController.stop();
    _pointerId = event.pointer;
    _pointerStartX = event.position.dx;
    _dragBasePosition = _visualPosition;
    _dragOffset = 0.0;
  }

  void _onPointerMove(PointerMoveEvent event, double tileWidth) {
    if (_pointerId != event.pointer) return;
    if (tileWidth <= 0.0 || widget.items.length < 2) return;
    final delta = event.position.dx - _pointerStartX;
    if (!_dragging && delta.abs() < 4.0) return;
    // Pointer coordinates increase in the same direction as the finger. The
    // capsule must therefore use the same sign so its preview follows the
    // drag instead of moving against it.
    final position = (_dragBasePosition + delta / tileWidth)
        .clamp(0.0, widget.items.length - 1.0)
        .toDouble();
    setState(() {
      _dragging = true;
      _dragOffset = delta;
      _visualPosition = position;
    });
  }

  void _finishPointerDrag(double tileWidth) {
    if (widget.items.length < 2 || tileWidth <= 0.0) {
      setState(() {
        _dragging = false;
        _dragOffset = 0.0;
      });
      return;
    }

    final target = _dragOffset.abs() >= tileWidth * 0.18
        ? _visualPosition.round()
        : _selectedIndex;
    _animateToIndex(target, notify: true);
  }

  void _onPointerUp(PointerUpEvent event, double tileWidth) {
    if (_pointerId != event.pointer) return;
    final wasDragging = _dragging;
    _pointerId = null;
    if (wasDragging) {
      _finishPointerDrag(tileWidth);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_pointerId != event.pointer) return;
    _pointerId = null;
    if (_dragging) {
      _animateToIndex(_selectedIndex, notify: false);
    }
  }

  Widget _selectionCapsule({
    required double left,
    required double width,
    required double height,
  }) {
    return Positioned(
      key: const ValueKey<String>('liquid-glass-selection-capsule'),
      left: left,
      top: 4,
      width: width,
      height: height - 8,
      child: LiquidGlassSurface(
        enabled: true,
        borderRadius: BorderRadius.circular((height - 8) / 2),
        style: LiquidGlassStyle.clear,
        interactive: true,
        followSystemTransparency: widget.followSystemTransparency,
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildItem(int index, double activePosition) {
    final item = widget.items[index];
    final distance = (activePosition - index).abs().clamp(0.0, 1.0);
    final activeFactor = 1.0 - distance;
    final active = Color.lerp(
          CupertinoDynamicColor.resolve(widget.inactiveColor, context),
          CupertinoDynamicColor.resolve(widget.activeColor, context),
          activeFactor,
        ) ??
        widget.activeColor;
    final fontWeight = activeFactor > 0.65 ? FontWeight.w600 : FontWeight.w400;

    return Expanded(
      child: Semantics(
        button: true,
        selected: activeFactor > 0.98,
        label: item.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _select(index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: widget.iconSize + 4,
                height: 28,
                child: IconTheme(
                  data: IconThemeData(size: widget.iconSize, color: active),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Opacity(
                        opacity: 1.0 - activeFactor,
                        child: item.icon,
                      ),
                      Opacity(
                        opacity: activeFactor,
                        child: item.activeIcon,
                      ),
                    ],
                  ),
                ),
              ),
              if (item.label != null) ...[
                const SizedBox(height: 2),
                SizedBox(
                  height: 16,
                  child: Text(
                    item.label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      color: active,
                      fontWeight: fontWeight,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final height =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        final innerWidth = math.max(0.0, width - 8.0);
        final tileWidth =
            widget.items.isEmpty ? 0.0 : innerWidth / widget.items.length;
        final activePosition = widget.items.isEmpty || tileWidth <= 0.0
            ? 0.0
            : _visualPosition.clamp(0.0, widget.items.length - 1.0).toDouble();

        final capsule = _selectionCapsule(
          left: 4.0 + activePosition * tileWidth,
          width: tileWidth,
          height: height,
        );

        return Listener(
          key: const ValueKey<String>('liquid-glass-tab-bar'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: (event) => _onPointerMove(event, tileWidth),
          onPointerUp: (event) => _onPointerUp(event, tileWidth),
          onPointerCancel: _onPointerCancel,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (widget.items.isNotEmpty) capsule,
              if (widget.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: <Widget>[
                      for (int index = 0; index < widget.items.length; index++)
                        _buildItem(index, activePosition),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
