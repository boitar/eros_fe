import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// A hardware-reserved area reported by the native host.
///
/// Division regions split the usable content into panes (for example, a
/// hinge). Occlusion regions only describe an area that must not contain
/// controls (for example, a camera).
enum AdaptiveRegionKind {
  division,
  occlusion,
}

class AdaptiveRegion {
  const AdaptiveRegion({
    required this.frame,
    required this.kind,
    this.active = true,
  });

  final Rect frame;
  final AdaptiveRegionKind kind;
  final bool active;

  factory AdaptiveRegion.fromMap(Map<Object?, Object?> map) {
    final kind = map['kind']?.toString() == 'occlusion'
        ? AdaptiveRegionKind.occlusion
        : AdaptiveRegionKind.division;
    return AdaptiveRegion(
      frame: Rect.fromLTWH(
        _number(map['x']),
        _number(map['y']),
        _number(map['width']),
        _number(map['height']),
      ),
      kind: kind,
      active: map['active'] != false,
    );
  }

  Map<String, Object> toMap() => <String, Object>{
        'x': frame.left,
        'y': frame.top,
        'width': frame.width,
        'height': frame.height,
        'kind': kind == AdaptiveRegionKind.occlusion ? 'occlusion' : 'division',
        'active': active,
      };

  static double _number(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }
}

enum AdaptiveLayoutKind {
  compact,
  expandedGrid,
  split,
  tabletop,
}

/// Stable, serialisable geometry used by both Flutter layouts and tests.
///
/// The snapshot deliberately stores each safe-area edge independently. A
/// vertical system bar on Duo can make only one side unsafe.
class AdaptiveEnvironmentSnapshot {
  const AdaptiveEnvironmentSnapshot({
    required this.size,
    this.safeArea = EdgeInsets.zero,
    this.viewPadding = EdgeInsets.zero,
    this.viewInsets = EdgeInsets.zero,
    this.windowSafeArea,
    this.horizontalSizeClass = 0,
    this.verticalSizeClass = 0,
    this.reservedRegions = const <AdaptiveRegion>[],
    this.systemBarEdge,
    this.layoutVersion = 0,
    this.nativeSupported = false,
  });

  final Size size;
  final EdgeInsets safeArea;
  final EdgeInsets viewPadding;
  final EdgeInsets viewInsets;

  /// Insets of the window itself, without navigation, tool or tab bars.
  /// Null when the native bridge has not reported them.
  final EdgeInsets? windowSafeArea;
  final int horizontalSizeClass;
  final int verticalSizeClass;
  final List<AdaptiveRegion> reservedRegions;
  final String? systemBarEdge;
  final int layoutVersion;
  final bool nativeSupported;

  static const double minimumPaneWidth = 320;
  static const double twoPaneGap = 24;
  static const double splitWidth = 720;
  static const double expandedGridWidth = 600;

  factory AdaptiveEnvironmentSnapshot.fromMediaQuery(
    BuildContext context, {
    AdaptiveEnvironmentSnapshot? native,
  }) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final base = native ?? const AdaptiveEnvironmentSnapshot(size: Size.zero);
    return base.copyWithGeometry(
      size: size,
      safeArea: media.padding,
      viewPadding: media.viewPadding,
      viewInsets: media.viewInsets,
    );
  }

  AdaptiveEnvironmentSnapshot copyWithGeometry({
    Size? size,
    EdgeInsets? safeArea,
    EdgeInsets? viewPadding,
    EdgeInsets? viewInsets,
  }) {
    return AdaptiveEnvironmentSnapshot(
      size: size ?? this.size,
      safeArea: safeArea ?? this.safeArea,
      viewPadding: viewPadding ?? this.viewPadding,
      viewInsets: viewInsets ?? this.viewInsets,
      windowSafeArea: windowSafeArea,
      horizontalSizeClass: horizontalSizeClass,
      verticalSizeClass: verticalSizeClass,
      reservedRegions: _regionsForSize(size ?? this.size),
      systemBarEdge: systemBarEdge,
      layoutVersion: layoutVersion,
      nativeSupported: nativeSupported,
    );
  }

  /// Projects host-local geometry into a content pane. Insets already consumed
  /// by the parent disappear here instead of being applied a second time.
  AdaptiveEnvironmentSnapshot inRect(Rect rect) {
    EdgeInsets localInsets(EdgeInsets insets) => EdgeInsets.fromLTRB(
          (insets.left - rect.left).clamp(0.0, rect.width),
          (insets.top - rect.top).clamp(0.0, rect.height),
          (rect.right - (size.width - insets.right)).clamp(0.0, rect.width),
          (rect.bottom - (size.height - insets.bottom)).clamp(0.0, rect.height),
        );
    return AdaptiveEnvironmentSnapshot(
      size: rect.size,
      safeArea: localInsets(safeArea),
      viewPadding: localInsets(viewPadding),
      viewInsets: localInsets(viewInsets),
      windowSafeArea:
          windowSafeArea == null ? null : localInsets(windowSafeArea!),
      horizontalSizeClass: horizontalSizeClass,
      verticalSizeClass: verticalSizeClass,
      reservedRegions: reservedRegions
          .where((region) => region.frame.overlaps(rect))
          .map((region) => AdaptiveRegion(
                frame: region.frame.intersect(rect).shift(-rect.topLeft),
                kind: region.kind,
                active: region.active,
              ))
          .toList(growable: false),
      systemBarEdge: systemBarEdge,
      layoutVersion: layoutVersion,
      nativeSupported: nativeSupported,
    );
  }

  /// Region frames already contain Apple's interactive clearance margins.
  Rect unoccludedControlRect(Rect preferred) {
    var candidates = <Rect>[preferred];
    for (final region in activeOcclusionRegions) {
      final next = <Rect>[];
      for (final candidate in candidates) {
        final overlap = region.frame.intersect(candidate);
        if (overlap.isEmpty) {
          next.add(candidate);
          continue;
        }
        next.addAll(<Rect>[
          Rect.fromLTRB(
              candidate.left, candidate.top, overlap.left, candidate.bottom),
          Rect.fromLTRB(
              overlap.right, candidate.top, candidate.right, candidate.bottom),
          Rect.fromLTRB(
              candidate.left, candidate.top, candidate.right, overlap.top),
          Rect.fromLTRB(candidate.left, overlap.bottom, candidate.right,
              candidate.bottom),
        ].where((rect) => !rect.isEmpty));
      }
      candidates = next;
    }
    if (candidates.isEmpty) {
      return Rect.zero;
    }
    candidates
        .sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return candidates.first;
  }

  /// Returns false when a native event belongs to a previous window size.
  bool isCompatibleWith(Size currentSize) {
    return (size.width - currentSize.width).abs() < 2 &&
        (size.height - currentSize.height).abs() < 2;
  }

  List<AdaptiveRegion> _regionsForSize(Size currentSize) {
    if (!isCompatibleWith(currentSize) && size != Size.zero) {
      return const <AdaptiveRegion>[];
    }
    return reservedRegions;
  }

  Rect get contentRect {
    final left = safeArea.left;
    final top = safeArea.top;
    final right = math.max(left, size.width - safeArea.right);
    final bottom = math.max(top, size.height - safeArea.bottom);
    return Rect.fromLTRB(
      left.clamp(0, size.width),
      top.clamp(0, size.height),
      right.clamp(0, size.width),
      bottom.clamp(0, size.height),
    );
  }

  /// Safe area that ignores app bars appearing and disappearing. Content laid
  /// out against it stays put while a reader toggles its native bars.
  EdgeInsets get stableSafeArea {
    final window = windowSafeArea;
    if (window == null) return safeArea;
    return EdgeInsets.fromLTRB(
      math.min(window.left, safeArea.left),
      math.min(window.top, safeArea.top),
      math.min(window.right, safeArea.right),
      math.min(window.bottom, safeArea.bottom),
    );
  }

  List<AdaptiveRegion> get activeDivisionRegions => reservedRegions
      .where((region) =>
          region.active &&
          region.frame.isFinite &&
          !region.frame.isEmpty &&
          region.kind == AdaptiveRegionKind.division)
      .toList(growable: false);

  List<AdaptiveRegion> get activeOcclusionRegions => reservedRegions
      .where((region) =>
          region.active &&
          region.frame.isFinite &&
          !region.frame.isEmpty &&
          region.kind == AdaptiveRegionKind.occlusion)
      .toList(growable: false);

  /// Splits content around active division regions without mirroring insets.
  List<Rect> get paneRects {
    final divisions = activeDivisionRegions;
    if (divisions.isEmpty) {
      return <Rect>[contentRect];
    }

    var panes = <Rect>[contentRect];
    for (final division in divisions) {
      final fold = division.frame.intersect(contentRect);
      if (fold.isEmpty) {
        continue;
      }
      final isVertical = fold.height >= fold.width;
      final next = <Rect>[];
      for (final pane in panes) {
        if (isVertical && fold.overlaps(pane)) {
          final left = Rect.fromLTRB(
            pane.left,
            pane.top,
            math.min(fold.left, pane.right),
            pane.bottom,
          );
          final right = Rect.fromLTRB(
            math.max(fold.right, pane.left),
            pane.top,
            pane.right,
            pane.bottom,
          );
          if (left.width > 0 && left.height > 0) {
            next.add(left);
          }
          if (right.width > 0 && right.height > 0) {
            next.add(right);
          }
        } else if (!isVertical && fold.overlaps(pane)) {
          final top = Rect.fromLTRB(
            pane.left,
            pane.top,
            pane.right,
            math.min(fold.top, pane.bottom),
          );
          final bottom = Rect.fromLTRB(
            pane.left,
            math.max(fold.bottom, pane.top),
            pane.right,
            pane.bottom,
          );
          if (top.width > 0 && top.height > 0) {
            next.add(top);
          }
          if (bottom.width > 0 && bottom.height > 0) {
            next.add(bottom);
          }
        } else {
          next.add(pane);
        }
      }
      panes = next;
    }
    return panes;
  }

  AdaptiveLayoutKind get layoutKind {
    final divisions = activeDivisionRegions
        .where((region) => region.frame.overlaps(contentRect))
        .toList(growable: false);
    final horizontalDivision = divisions.any((region) {
      final frame = region.frame;
      return frame.width > frame.height;
    });
    if (horizontalDivision) {
      return AdaptiveLayoutKind.tabletop;
    }

    final panes = paneRects;
    final hasTwoUsablePanes = panes.length >= 2 &&
        panes.take(2).every((pane) => pane.width >= minimumPaneWidth);
    final available = contentRect.size;
    if (hasTwoUsablePanes ||
        (divisions.isEmpty &&
            available.width >= splitWidth &&
            available.width > available.height * 1.05)) {
      return AdaptiveLayoutKind.split;
    }
    if (available.width >= expandedGridWidth) {
      return AdaptiveLayoutKind.expandedGrid;
    }
    return AdaptiveLayoutKind.compact;
  }

  bool get isCompact => layoutKind == AdaptiveLayoutKind.compact;
  bool get isExpandedGrid => layoutKind == AdaptiveLayoutKind.expandedGrid;
  bool get isSplit => layoutKind == AdaptiveLayoutKind.split;
  bool get isTabletop => layoutKind == AdaptiveLayoutKind.tabletop;
  bool get isBookFolded => activeDivisionRegions.any((region) =>
      region.frame.overlaps(contentRect) &&
      region.frame.height >= region.frame.width);
  bool get isWide => !isCompact;

  bool get canUseReaderDoublePage {
    if (isTabletop) {
      final upperPane = paneRects.first;
      return upperPane.width >= minimumPaneWidth * 2;
    }
    if (isBookFolded) {
      return paneRects.length >= 2 &&
          paneRects.take(2).every((pane) => pane.width >= minimumPaneWidth);
    }
    return contentRect.width >= minimumPaneWidth * 2;
  }

  bool get keyboardVisible => viewInsets.bottom > 0 || viewInsets.right > 0;

  Map<String, Object> toMap() => <String, Object>{
        'width': size.width,
        'height': size.height,
        'safeLeft': safeArea.left,
        'safeTop': safeArea.top,
        'safeRight': safeArea.right,
        'safeBottom': safeArea.bottom,
        if (windowSafeArea != null) ...<String, Object>{
          'windowSafeLeft': windowSafeArea!.left,
          'windowSafeTop': windowSafeArea!.top,
          'windowSafeRight': windowSafeArea!.right,
          'windowSafeBottom': windowSafeArea!.bottom,
        },
        'horizontalSizeClass': horizontalSizeClass,
        'verticalSizeClass': verticalSizeClass,
        'systemBarEdge': systemBarEdge ?? '',
        'layoutVersion': layoutVersion,
        'nativeSupported': nativeSupported,
        'reservedRegions':
            reservedRegions.map((region) => region.toMap()).toList(),
      };

  factory AdaptiveEnvironmentSnapshot.fromMap(Map<Object?, Object?> map) {
    final regions = map['reservedRegions'];
    return AdaptiveEnvironmentSnapshot(
      size: Size(
        AdaptiveRegion._number(map['width']),
        AdaptiveRegion._number(map['height']),
      ),
      safeArea: EdgeInsets.fromLTRB(
        AdaptiveRegion._number(map['safeLeft']),
        AdaptiveRegion._number(map['safeTop']),
        AdaptiveRegion._number(map['safeRight']),
        AdaptiveRegion._number(map['safeBottom']),
      ),
      windowSafeArea: map.containsKey('windowSafeTop')
          ? EdgeInsets.fromLTRB(
              AdaptiveRegion._number(map['windowSafeLeft']),
              AdaptiveRegion._number(map['windowSafeTop']),
              AdaptiveRegion._number(map['windowSafeRight']),
              AdaptiveRegion._number(map['windowSafeBottom']),
            )
          : null,
      horizontalSizeClass: (map['horizontalSizeClass'] as num?)?.toInt() ?? 0,
      verticalSizeClass: (map['verticalSizeClass'] as num?)?.toInt() ?? 0,
      reservedRegions: regions is List
          ? regions
              .whereType<Map>()
              .map((value) =>
                  AdaptiveRegion.fromMap(Map<Object?, Object?>.from(value)))
              .toList(growable: false)
          : const <AdaptiveRegion>[],
      systemBarEdge: map['systemBarEdge']?.toString(),
      layoutVersion: (map['layoutVersion'] as num?)?.toInt() ?? 0,
      nativeSupported: map['nativeSupported'] == true,
    );
  }
}

class AdaptiveEnvironmentService extends GetxService {
  static const String methodChannelName = 'eros/adaptive-environment';
  static const String eventChannelName = 'eros/adaptive-environment/events';

  final Rx<AdaptiveEnvironmentSnapshot> snapshot =
      const AdaptiveEnvironmentSnapshot(size: Size.zero).obs;

  EventChannel? _eventChannel;
  StreamSubscription<dynamic>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _startNativeStream();
  }

  Future<void> _startNativeStream() async {
    try {
      _eventChannel = const EventChannel(eventChannelName);
      _subscription = _eventChannel!.receiveBroadcastStream().listen(
        (dynamic value) {
          if (value is Map) {
            acceptNativeSnapshot(Map<Object?, Object?>.from(value));
          }
        },
        onError: (Object error, StackTrace stack) {
          // The native bridge is optional on older iOS and all other
          // platforms. Flutter geometry remains the source of truth.
          snapshot.value = snapshot.value.copyWithGeometry();
        },
      );
    } on MissingPluginException {
      // Expected on Android, desktop, and simulator targets without the
      // optional Runner bridge.
    } catch (_) {
      // Keep the adaptive fallback available if a host cannot create a
      // platform stream.
    }
  }

  /// Reject non-geometry messages and older asynchronous layout publications.
  void acceptNativeSnapshot(Map<Object?, Object?> value) {
    final next = AdaptiveEnvironmentSnapshot.fromMap(value);
    if (next.size.isEmpty ||
        next.layoutVersion < snapshot.value.layoutVersion) {
      return;
    }
    snapshot.value = next;
  }

  Future<void> refreshNativeSnapshot() async {
    try {
      final value = await const MethodChannel(methodChannelName)
          .invokeMethod<dynamic>('getSnapshot');
      if (value is Map) {
        acceptNativeSnapshot(Map<Object?, Object?>.from(value));
      }
    } on MissingPluginException {
      // Optional bridge.
    } catch (_) {
      // The Flutter-derived geometry remains valid.
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _subscription = null;
    super.onClose();
  }
}

class AdaptiveEnvironmentScope extends InheritedWidget {
  const AdaptiveEnvironmentScope({
    super.key,
    required this.snapshot,
    required super.child,
  });

  final AdaptiveEnvironmentSnapshot snapshot;

  static AdaptiveEnvironmentSnapshot? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdaptiveEnvironmentScope>()
        ?.snapshot;
  }

  static AdaptiveEnvironmentSnapshot of(BuildContext context) {
    return maybeOf(context) ??
        const AdaptiveEnvironmentSnapshot(size: Size.zero);
  }

  @override
  bool updateShouldNotify(AdaptiveEnvironmentScope oldWidget) =>
      snapshot != oldWidget.snapshot;
}

/// Supplies local geometry to a child already positioned in [rect].
class AdaptivePane extends StatelessWidget {
  const AdaptivePane({
    super.key,
    required this.environment,
    required this.rect,
    required this.child,
  });

  final AdaptiveEnvironmentSnapshot environment;
  final Rect rect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final local = environment.inRect(rect);
    return AdaptiveEnvironmentScope(
      snapshot: local,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: local.size,
          padding: local.safeArea,
          viewPadding: local.viewPadding,
          viewInsets: local.viewInsets,
        ),
        child: child,
      ),
    );
  }
}

/// Convenience accessors used by feature widgets.
class AdaptiveEnvironment {
  const AdaptiveEnvironment._();

  static AdaptiveEnvironmentSnapshot? maybeOf(BuildContext context) =>
      AdaptiveEnvironmentScope.maybeOf(context);

  static AdaptiveEnvironmentSnapshot of(BuildContext context) =>
      AdaptiveEnvironmentScope.of(context);
}

/// Injects Flutter's live constraints and MediaQuery geometry into the
/// platform snapshot. This host is intentionally constraint-driven: it never
/// uses a device model or a cached launch-time size.
class AdaptiveEnvironmentHost extends StatelessWidget {
  const AdaptiveEnvironmentHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final service = Get.isRegistered<AdaptiveEnvironmentService>()
        ? Get.find<AdaptiveEnvironmentService>()
        : null;
    if (service == null) {
      return _buildWithSnapshot(
        context,
        const AdaptiveEnvironmentSnapshot(size: Size.zero),
      );
    }
    return Obx(
      () => _buildWithSnapshot(context, service.snapshot.value),
    );
  }

  Widget _buildWithSnapshot(
    BuildContext context,
    AdaptiveEnvironmentSnapshot native,
  ) {
    final media = MediaQuery.maybeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = media?.size ?? Size.zero;
        final size = constraints.hasBoundedWidth && constraints.hasBoundedHeight
            ? constraints.biggest
            : mediaSize;
        final snapshot = native.copyWithGeometry(
          size: size,
          safeArea: media?.padding ?? EdgeInsets.zero,
          viewPadding: media?.viewPadding ?? EdgeInsets.zero,
          viewInsets: media?.viewInsets ?? EdgeInsets.zero,
        );
        return AdaptiveEnvironmentScope(
          snapshot: snapshot,
          child: child,
        );
      },
    );
  }
}
