import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:eros_fe/utils/vibrate.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Basic feedback is optional and must not interrupt navigation or previews.
/// Use the existing utility without depending on the enhanced haptics module.
void liquidGlassFeedback(Future<void> Function() action) {
  if (!LiquidGlassPlatform.isSupported) {
    return;
  }
  unawaited(action().catchError((Object _) {}));
}

/// The top obstruction that a portrait iPhone exposes through its safe area.
///
/// We deliberately classify by the runtime safe-area geometry instead of by a
/// model-name list. This keeps the collapse behavior working for new iPhones
/// whose cutout dimensions are not known when this app is built.
enum LiquidGlassCutout { dynamicIsland, notch, none }

/// The two public UIKit Liquid Glass variants available on iOS 26+ and
/// refined by the iOS 27 system appearance.
///
/// `regular` is the legibility-first material used by navigation surfaces.
/// `clear` is reserved for small controls over visually rich content, matching
/// the distinction Apple makes in the HIG and the local XHS reference build.
enum LiquidGlassStyle { regular, clear }

enum LiquidGlassTopBarLayout {
  twoRow,
  inline;

  static LiquidGlassTopBarLayout parse(String? value) =>
      value == 'inline' ? inline : twoRow;

  double categoryHeight(TextScaler scaler) =>
      math.max(44, scaler.scale(18) + 16);
  double expandedHeight(TextScaler scaler, {bool hasCategories = true}) =>
      !hasCategories ? 44 : categoryHeight(scaler) + (this == twoRow ? 50 : 0);
}

@immutable
class LiquidGlassTopLayout {
  const LiquidGlassTopLayout({required this.safeTop, required this.cutout});

  factory LiquidGlassTopLayout.fromMediaQuery(MediaQueryData data) {
    final layout = LiquidGlassTopLayout.fromTopInset(data.viewPadding.top);
    if (data.orientation == Orientation.portrait) {
      return layout;
    }
    // Landscape phones represent their cutout with horizontal insets. Keep
    // cutout docking off, while respecting a window's actual top safe area:
    // iPad retains its status bar in landscape.
    return LiquidGlassTopLayout(
      safeTop: layout.safeTop,
      cutout: LiquidGlassCutout.none,
    );
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

/// Mirrors UIKit's Reduce Transparency setting for Flutter-composed fallback
/// surfaces. Flutter 3.47 does not expose this setting through MediaQuery or
/// AccessibilityFeatures.
class LiquidGlassAccessibilitySettings {
  LiquidGlassAccessibilitySettings._();

  static const EventChannel _channel = EventChannel(
    'eros/accessibility-settings',
  );
  static final ValueNotifier<bool?> _reduceTransparency = ValueNotifier<bool?>(
    null,
  );
  // Retained for the Flutter engine lifetime and explicitly stopped in tests.
  // ignore: cancel_subscriptions
  static StreamSubscription<dynamic>? _subscription;

  static ValueListenable<bool?> get reduceTransparency => _reduceTransparency;

  static void watch() {
    if (_subscription != null) {
      return;
    }
    _subscription = _channel.receiveBroadcastStream().listen(
      (dynamic value) {
        if (value is bool && _reduceTransparency.value != value) {
          _reduceTransparency.value = value;
        }
      },
      onError: (Object _) {
        // Platforms without the iOS accessibility bridge retain the regular
        // Flutter fallback after the initial opaque, accessible frame.
        if (_reduceTransparency.value != false) {
          _reduceTransparency.value = false;
        }
      },
      onDone: () {
        _subscription = null;
      },
    );
  }

  static Future<void> stopWatching() async {
    final StreamSubscription<dynamic>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
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
    this.opacity = 1.0,
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
  final double opacity;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bool usesFlutterFallback =
        enabled && !(useNativeGlass && LiquidGlassPlatform.isSupported);
    final bool readsNativeTransparency =
        usesFlutterFallback && defaultTargetPlatform == TargetPlatform.iOS;
    final Widget surface;
    if (readsNativeTransparency) {
      LiquidGlassAccessibilitySettings.watch();
      surface = ValueListenableBuilder<bool?>(
        valueListenable: LiquidGlassAccessibilitySettings.reduceTransparency,
        builder:
            (BuildContext context, bool? reduceTransparency, Widget? child) =>
                _buildSurface(
          context,
          reduceTransparency: reduceTransparency ?? true,
        ),
      );
    } else {
      surface = _buildSurface(context, reduceTransparency: false);
    }
    final alpha = opacity.clamp(0.0, 1.0).toDouble();
    return alpha >= 1.0 ? surface : Opacity(opacity: alpha, child: surface);
  }

  Widget _buildSurface(
    BuildContext context, {
    required bool reduceTransparency,
  }) {
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
          final double fillAlpha = reduceTransparency
              ? 1.0
              : (isClear
                  ? 0.26
                  : (emphasizeFallbackEdge ? (isDark ? 0.72 : 0.64) : 0.68));
          final double borderAlpha = isClear
              ? 0.14
              : (emphasizeFallbackEdge ? (isDark ? 0.34 : 0.28) : 0.22);
          final Widget fallbackDecoration = Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: fallbackBackground.withValues(alpha: fillAlpha),
                  border: Border.all(
                    color: separator.withValues(alpha: borderAlpha),
                    width: emphasizeFallbackEdge ? 0.8 : 1.0,
                  ),
                  boxShadow: emphasizeFallbackEdge && !reduceTransparency
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
          );
          background = reduceTransparency
              ? fallbackDecoration
              : BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: isClear ? 12.0 : 18.0,
                    sigmaY: isClear ? 12.0 : 18.0,
                  ),
                  child: fallbackDecoration,
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

/// Shared store for the top rail's fade progress. Pages write it only through
/// LiquidGlassTopStateCoordinator, which derives the progress from the same
/// scroll positions as the initial content anchor; the page's real initial
/// position is tracked there, not here.
class LiquidGlassBarMotion extends ValueNotifier<double> {
  LiquidGlassBarMotion() : super(0.0);

  bool _isTopBarVisible = true;

  bool get isTopBarVisible => _isTopBarVisible;

  void setTopBarVisible(bool visible) {
    if (_isTopBarVisible == visible) {
      return;
    }
    _isTopBarVisible = visible;
    notifyListeners();
  }

  /// Restores the fully visible bar, e.g. on tab reselection.
  void reset() {
    value = 0.0;
    setTopBarVisible(true);
  }
}

/// Makes top-rail motion available to nested page scroll views. Cupertino's
/// tab navigators stay below this scope so the active page can drive its rail.
class LiquidGlassBarMotionScope extends InheritedWidget {
  const LiquidGlassBarMotionScope({
    super.key,
    required this.motion,
    required super.child,
  });

  final LiquidGlassBarMotion motion;

  static LiquidGlassBarMotion? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LiquidGlassBarMotionScope>()
      ?.motion;

  @override
  bool updateShouldNotify(LiquidGlassBarMotionScope oldWidget) =>
      motion != oldWidget.motion;
}

/// Builds a top rail from normalized scroll progress. A disabled or unavailable
/// scope leaves it visible.
class LiquidGlassBarMotionBuilder extends StatelessWidget {
  const LiquidGlassBarMotionBuilder({
    super.key,
    required this.enabled,
    required this.builder,
  });
  static const double _reduceMotionCollapseThreshold = 0.72;

  final bool enabled;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  Widget build(BuildContext context) {
    final motion = LiquidGlassBarMotionScope.maybeOf(context);
    if (!enabled || motion == null) {
      return builder(context, 0.0);
    }
    return ValueListenableBuilder<double>(
      valueListenable: motion,
      builder: (context, progress, _) {
        final normalized = progress.clamp(0.0, 1.0).toDouble();
        // Snap the top rail at its terminal state when Reduce Motion is
        // enabled, without adding another animation curve.
        final visibleProgress = MediaQuery.disableAnimationsOf(context)
            ? (normalized >= _reduceMotionCollapseThreshold ? 1.0 : 0.0)
            : normalized;
        return builder(context, visibleProgress);
      },
    );
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
    this.followSystemTransparency = true,
    this.nativeItems,
    this.searchLabel = '搜索',
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
  final bool followSystemTransparency;
  final List<LiquidGlassTabItem>? nativeItems;
  final String searchLabel;

  @override
  bool opaque(BuildContext context) => false;

  @override
  Widget build(BuildContext context) {
    if (LiquidGlassPlatform.isSupported && nativeItems != null) {
      return _buildNativeBar(context);
    }
    return _buildFlutterBar(context);
  }

  Widget _buildNativeBar(BuildContext context) {
    final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    return _NativeLiquidGlassTabBar(
      items: nativeItems!,
      selectedIndex: _clampTabIndex(currentIndex, nativeItems!.length),
      followSystemTransparency: followSystemTransparency,
      searchLabel: searchLabel,
      bottomInset: bottomPadding,
      height: height,
      onTap: onTap,
      onSearch: onSearch,
    );
  }

  Widget _buildFlutterBar(BuildContext context) {
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
        final double glassHeight = expandedGlassHeight;
        const double leftInset = 8.0;
        final double searchInset = onSearch == null ? 12.0 : 72.0;
        final double expandedWidth = math.max(
          0.0,
          width - leftInset - searchInset,
        );
        const double shellTop = 6.0;
        const double shellRadius = 30.0;
        final Widget expandedTabs = _InteractiveLiquidGlassTabs(
          items: items,
          currentIndex: currentIndex,
          onTap: onTap,
          activeColor: activeColor ?? CupertinoColors.activeBlue,
          inactiveColor: inactiveColor,
          iconSize: iconSize,
          followSystemTransparency: followSystemTransparency,
        );

        return SizedBox(
          width: width.isFinite ? width : 0.0,
          height: barHeight.isFinite ? barHeight : preferredSize.height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: leftInset,
                width: expandedWidth,
                top: shellTop,
                height: glassHeight,
                child: LiquidGlassSurface(
                  enabled: true,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(shellRadius)),
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
                left: leftInset,
                width: expandedWidth,
                top: shellTop,
                height: glassHeight,
                child: expandedTabs,
              ),
              if (onSearch != null)
                Positioned(
                  right: 8,
                  top: 6,
                  width: 56,
                  height: glassHeight,
                  child: LiquidGlassSurface(
                    enabled: true,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(28),
                    ),
                    style: LiquidGlassStyle.clear,
                    interactive: true,
                    followSystemTransparency: followSystemTransparency,
                    child: Semantics(
                      button: true,
                      label: searchLabel,
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
    String? searchLabel,
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
      onSearch: onSearch,
      followSystemTransparency: followSystemTransparency,
      nativeItems: nativeItems,
      searchLabel: searchLabel ?? this.searchLabel,
    );
  }
}

class _NativeLiquidGlassTabBar extends StatefulWidget {
  const _NativeLiquidGlassTabBar({
    required this.items,
    required this.selectedIndex,
    required this.followSystemTransparency,
    required this.searchLabel,
    required this.bottomInset,
    required this.height,
    this.onTap,
    this.onSearch,
  });

  final List<LiquidGlassTabItem> items;
  final int selectedIndex;
  final bool followSystemTransparency;
  final String searchLabel;
  final double bottomInset;
  final double height;
  final ValueChanged<int>? onTap;
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
        'followSystemTransparency': widget.followSystemTransparency,
        'searchLabel': widget.searchLabel,
        'bottomInset': widget.bottomInset,
        'height': widget.height,
        'hasSearch': widget.onSearch != null,
        'dark': CupertinoTheme.brightnessOf(context) == Brightness.dark,
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
      if (!mounted) {
        return null;
      }
      switch (call.method) {
        case 'hover':
          liquidGlassFeedback(vibrateUtil.selection);
          return null;
        case 'select':
        case 'dragCommitted':
          final Object? value = call.arguments;
          if (value is num) {
            liquidGlassFeedback(vibrateUtil.tabSwitch);
            widget.onTap?.call(value.toInt());
          }
          return null;
        case 'search':
          liquidGlassFeedback(vibrateUtil.light);
          widget.onSearch?.call();
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
  int _hoverIndex = -1;
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
    if (widget.items.isEmpty) {
      return 0;
    }
    return index.clamp(0, widget.items.length - 1);
  }

  void _handleSettleTick() {
    if (!mounted) {
      return;
    }
    setState(() {
      _visualPosition =
          ui.lerpDouble(_settleStart, _settleTarget, _settleController.value) ??
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
      _hoverIndex = -1;
      _settleStart = start;
      _settleTarget = target.toDouble();
    });
    if (notify) {
      liquidGlassFeedback(vibrateUtil.tabSwitch);
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
    _hoverIndex = _dragBasePosition.round();
  }

  void _onPointerMove(PointerMoveEvent event, double tileWidth) {
    if (_pointerId != event.pointer) {
      return;
    }
    if (tileWidth <= 0.0 || widget.items.length < 2) {
      return;
    }
    final delta = event.position.dx - _pointerStartX;
    if (!_dragging && delta.abs() < 4.0) {
      return;
    }
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
    // 拖动扫过相邻 tab 时给 selection 轻点（路过也震），提交时的 light 由
    // _animateToIndex 统一负责。
    final hoverIndex = position.round();
    if (hoverIndex != _hoverIndex) {
      _hoverIndex = hoverIndex;
      liquidGlassFeedback(vibrateUtil.selection);
    }
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
    if (_pointerId != event.pointer) {
      return;
    }
    final wasDragging = _dragging;
    _pointerId = null;
    if (wasDragging) {
      _finishPointerDrag(tileWidth);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_pointerId != event.pointer) {
      return;
    }
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
                      Opacity(opacity: 1.0 - activeFactor, child: item.icon),
                      Opacity(opacity: activeFactor, child: item.activeIcon),
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
