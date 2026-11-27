import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/parser/gallery_stats_parser.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/models/gallery_stats.dart';
import 'package:eros_fe/network/app_dio/exception.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:get/get.dart';

const double _kStatsCardRadius = 20.0;
const List<FontFeature> _kStatsTabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// Refined cool mineral teal paired with [EhPalette.accent] (Ink Indigo) to
/// distinguish Hits from Visits cleanly across light and dark graphite surfaces
/// without warm-orange muddiness.
const CupertinoDynamicColor _kHitsAccent =
    CupertinoDynamicColor.withBrightnessAndContrast(
      debugLabel: 'ehStatsHitsAccent',
      color: Color(0xFF0F766E),
      darkColor: Color(0xFF4FD1C5),
      highContrastColor: Color(0xFF115E59),
      darkHighContrastColor: Color(0xFF76E4DA),
    );

double _statsActionTargetSize() =>
    PlatformCapabilities.hostPlatform == TargetPlatform.android ? 48.0 : 44.0;

typedef GalleryStatsLoader =
    Future<GalleryStats> Function(
      String gid,
      String token, {
      bool refresh,
      CancelToken? cancelToken,
    });

/// Integrated E-Hentai `stats.php` module rendered inside [GalleryInfoPage].
///
/// Uses a single flat surface card with hairline divisions (no nested panels)
/// matching `_MetricsStrip` and `_IdPairRow` in [GalleryInfoPage].
class GalleryStatsSection extends StatefulWidget {
  const GalleryStatsSection({
    super.key,
    required this.gid,
    required this.token,
    this.favoriteCount,
    this.postTime,
    this.hasLineage = false,
    this.initiallyExpanded = false,
    this.statsLoader,
    this.respectUserLoginState = false,
    this.onOpenExternalUrl,
  });

  static const Key sectionKey = ValueKey<String>('galleryInfo.statsSection');
  static const Key chartKey = ValueKey<String>('galleryStats.chart');
  static const Key expandToggleKey = ValueKey<String>(
    'galleryStats.expandToggle',
  );
  static const Key collapseToggleKey = ValueKey<String>(
    'galleryStats.collapseToggle',
  );

  final String gid;
  final String token;
  final int? favoriteCount;
  final String? postTime;

  /// When true, the section header explicitly notes that rankings & trends
  /// belong to the current gallery version `#gid` (separate from parent/newer
  /// lineage versions).
  final bool hasLineage;

  /// Whether the stats panel starts expanded and fetches `stats.php`
  /// immediately. Defaults to `false` so opening [GalleryInfoPage] avoids
  /// eager `stats.php` requests until the user explicitly requests them.
  final bool initiallyExpanded;

  /// Optional override used by tests or callers injecting mock stats loaders.
  final GalleryStatsLoader? statsLoader;

  /// When true, enforces the [UserController.isLogin] gate even when a custom
  /// [statsLoader] is injected (used by widget tests to verify auth recovery).
  final bool respectUserLoginState;

  /// Callback invoked when the user opens `stats.php` in an external browser.
  final ValueChanged<String>? onOpenExternalUrl;

  @override
  State<GalleryStatsSection> createState() => _GalleryStatsSectionState();
}

class _GalleryStatsSectionState extends State<GalleryStatsSection> {
  late bool _expanded;
  GalleryStats? _stats;
  GalleryStatsErrorKind? _errorKind;
  bool _loading = false;
  GalleryStatsGranularity _granularity = GalleryStatsGranularity.monthly;
  GalleryStatsMetric _metric = GalleryStatsMetric.visits;
  int? _selectedIndex;

  CancelToken? _cancelToken;
  Worker? _userWorker;
  String? _lastUserIdentityKey;
  int _requestSeq = 0;

  bool get _shouldEnforceLoginGate =>
      widget.statsLoader == null || widget.respectUserLoginState;

  static String _userIdentityKey(UserController userCtrl) {
    final user = userCtrl.user.value;
    final memberId = user.memberId?.trim() ?? '';
    final passHash = user.passHash?.trim() ?? '';
    return '${userCtrl.isLogin ? 1 : 0}|$memberId|$passHash';
  }

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _bindUserLoginObserver();
    if (_expanded) {
      unawaited(_loadStats(refresh: false, initial: true));
    }
  }

  void _bindUserLoginObserver() {
    _userWorker?.dispose();
    _userWorker = null;
    if (!Get.isRegistered<UserController>()) {
      _lastUserIdentityKey = null;
      return;
    }
    final userCtrl = Get.find<UserController>();
    _lastUserIdentityKey = _userIdentityKey(userCtrl);
    _userWorker = ever<User>(userCtrl.user, (_) {
      if (!mounted) {
        return;
      }
      final nextKey = _userIdentityKey(userCtrl);
      if (nextKey == _lastUserIdentityKey) {
        return;
      }
      _lastUserIdentityKey = nextKey;

      // Always invalidate in-flight requests and cached stats on logout or
      // account switch (even while collapsed) so stale user data cannot leak.
      _cancelToken?.cancel('User identity changed');
      _cancelToken = null;
      _requestSeq++;

      if (!_expanded) {
        _loading = false;
        _stats = null;
        _errorKind = null;
        _selectedIndex = null;
        return;
      }

      setState(() {
        _loading = false;
        _stats = null;
        _selectedIndex = null;
        _errorKind = !userCtrl.isLogin && _shouldEnforceLoginGate
            ? GalleryStatsErrorKind.loginRequired
            : null;
      });

      if (userCtrl.isLogin || !_shouldEnforceLoginGate) {
        unawaited(_loadStats(refresh: true, initial: true));
      }
    });
  }

  @override
  void didUpdateWidget(covariant GalleryStatsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final identityChanged =
        oldWidget.gid != widget.gid ||
        oldWidget.token != widget.token ||
        oldWidget.statsLoader != widget.statsLoader ||
        oldWidget.respectUserLoginState != widget.respectUserLoginState;
    if (identityChanged) {
      _cancelToken?.cancel('Gallery identity changed');
      _cancelToken = null;
      _requestSeq++;
      _bindUserLoginObserver();
      _loading = false;
      _stats = null;
      _errorKind = null;
      _selectedIndex = null;
      if (_expanded) {
        unawaited(_loadStats(refresh: false, initial: true));
      }
    } else if (!oldWidget.initiallyExpanded &&
        widget.initiallyExpanded &&
        !_expanded) {
      _expanded = true;
      if (_stats == null && !_loading) {
        unawaited(_loadStats(refresh: false, initial: true));
      }
    }
  }

  @override
  void dispose() {
    _userWorker?.dispose();
    _cancelToken?.cancel('GalleryStatsSection disposed');
    super.dispose();
  }

  void _expand() {
    if (_expanded) {
      return;
    }
    vibrateUtil.light();
    setState(() => _expanded = true);
    if (_stats == null && !_loading) {
      unawaited(_loadStats(refresh: false, initial: true));
    }
  }

  void _collapse() {
    if (!_expanded) {
      return;
    }
    _cancelToken?.cancel('GalleryStatsSection collapsed');
    _cancelToken = null;
    _requestSeq++;
    vibrateUtil.light();
    setState(() {
      _loading = false;
      _expanded = false;
    });
  }

  Future<GalleryStats> _defaultLoader(
    String gid,
    String token, {
    bool refresh = false,
    CancelToken? cancelToken,
  }) => getGalleryStats(
    gid: gid,
    token: token,
    refresh: refresh,
    cancelToken: cancelToken,
  );

  Future<void> _loadStats({
    required bool refresh,
    bool initial = false,
  }) async {
    _cancelToken?.cancel('Superseded stats request');
    _cancelToken = null;
    final seq = ++_requestSeq;

    final cleanGid = widget.gid.trim();
    final cleanToken = widget.token.trim();
    final statsUrl = buildGalleryStatsUrl(cleanGid, cleanToken);
    if (statsUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _stats = null;
          _errorKind = GalleryStatsErrorKind.unavailable;
        });
      }
      return;
    }

    if (_shouldEnforceLoginGate) {
      final isLoggedIn =
          Get.isRegistered<UserController>() &&
          Get.find<UserController>().isLogin;
      if (!isLoggedIn) {
        if (mounted) {
          setState(() {
            _loading = false;
            _stats = null;
            _errorKind = GalleryStatsErrorKind.loginRequired;
          });
        }
        return;
      }
    }

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    if (mounted) {
      setState(() {
        _loading = true;
        if (_stats == null || !refresh) {
          _errorKind = null;
        }
      });
    }

    try {
      final loader = widget.statsLoader ?? _defaultLoader;
      final fetched = await loader(
        cleanGid,
        cleanToken,
        refresh: refresh,
        cancelToken: cancelToken,
      );
      if (!mounted || seq != _requestSeq || !_expanded) {
        return;
      }
      if (fetched.isEmpty) {
        setState(() {
          _loading = false;
          _stats = null;
          _errorKind = GalleryStatsErrorKind.unavailable;
          _selectedIndex = null;
        });
        return;
      }
      setState(() {
        _loading = false;
        _stats = fetched;
        _errorKind = null;
        _selectedIndex = null;
        if (initial || fetched.seriesFor(_granularity).isEmpty) {
          _granularity = fetched.defaultGranularity;
        }
      });
    } on CancelException {
      return;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return;
      }
      if (!mounted || seq != _requestSeq || !_expanded) {
        return;
      }
      setState(() {
        _loading = false;
        _stats = null;
        _errorKind = GalleryStatsErrorKind.network;
      });
    } on GalleryStatsException catch (e) {
      if (!mounted || seq != _requestSeq || !_expanded) {
        return;
      }
      setState(() {
        _loading = false;
        _stats = null;
        _errorKind = e.kind;
      });
    } on Object {
      if (!mounted || seq != _requestSeq || !_expanded) {
        return;
      }
      setState(() {
        _loading = false;
        _stats = null;
        _errorKind = GalleryStatsErrorKind.network;
      });
    }
  }

  void _selectMetric(GalleryStatsMetric metric) {
    if (_metric == metric) {
      return;
    }
    vibrateUtil.light();
    setState(() {
      _metric = metric;
      _selectedIndex = null;
    });
  }

  void _selectGranularity(GalleryStatsGranularity granularity) {
    if (_granularity == granularity) {
      return;
    }
    vibrateUtil.light();
    setState(() {
      _granularity = granularity;
      _selectedIndex = null;
    });
  }

  void _selectBucket(int index, {bool haptic = true}) {
    if (_selectedIndex == index) {
      return;
    }
    if (haptic) {
      vibrateUtil.light();
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final cleanGid = widget.gid.trim();
    final statsUrl = buildGalleryStatsUrl(cleanGid, widget.token);
    final headerHint = widget.hasLineage && cleanGid.isNotEmpty
        ? '${l10n.gallery_stats_current_version(cleanGid)} · stats.php'
        : 'stats.php';

    return Column(
      key: GalleryStatsSection.sectionKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatsSectionHeader(
          title: l10n.gallery_stats,
          hint: headerHint,
          collapseLabel: _expanded ? l10n.gallery_stats_collapse : null,
          onCollapse: _expanded ? _collapse : null,
        ),
        _StatsSurfaceCard(
          children: _expanded
              ? _buildCardChildren(context, statsUrl)
              : <Widget>[_StatsCollapsedRow(onExpand: _expand)],
        ),
      ],
    );
  }

  List<Widget> _buildCardChildren(BuildContext context, String statsUrl) {
    final stats = _stats;
    if (stats == null) {
      if (_loading) {
        return <Widget>[const _StatsLoadingSkeleton()];
      }
      return <Widget>[
        _StatsStatusState(
          kind: _errorKind ?? GalleryStatsErrorKind.unavailable,
          statsUrl: statsUrl,
          onRetry: () => unawaited(_loadStats(refresh: true)),
          onOpenExternalUrl: widget.onOpenExternalUrl,
        ),
      ];
    }

    final favRate = stats.favoriteRate(widget.favoriteCount);
    final dailyAvg = stats.averageDailyVisits(widget.postTime);

    return <Widget>[
      _StatsKpiHeader(
        totalVisits: stats.totalVisits,
        favoriteRate: favRate,
        dailyAverage: dailyAvg,
        refreshing: _loading,
        statsUrl: statsUrl,
        onRefresh: () => unawaited(_loadStats(refresh: true)),
        onOpenExternalUrl: widget.onOpenExternalUrl,
      ),
      _StatsRankingsBand(stats: stats),
      if (stats.hasAnyChartData)
        _StatsTrendBand(
          stats: stats,
          metric: _metric,
          granularity: _granularity,
          selectedIndex: _selectedIndex,
          onMetricChanged: _selectMetric,
          onGranularityChanged: _selectGranularity,
          onBucketSelected: _selectBucket,
        ),
    ];
  }
}

class _StatsSectionHeader extends StatelessWidget {
  const _StatsSectionHeader({
    required this.title,
    required this.hint,
    this.collapseLabel,
    this.onCollapse,
  });

  final String title;
  final String hint;
  final String? collapseLabel;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final hasCollapse = onCollapse != null && collapseLabel != null;
    final target = _statsActionTargetSize();

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        12,
        hasCollapse ? 8 : 20,
        hasCollapse ? 4 : 12,
        hasCollapse ? 0 : 8,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 8,
          runSpacing: 2,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.text2.resolveFrom(context),
                ),
              ),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    fontFeatures: _kStatsTabularFigures,
                    color: palette.text3.resolveFrom(context),
                  ),
                ),
                if (hasCollapse)
                  Semantics(
                    button: true,
                    expanded: true,
                    label: collapseLabel,
                    excludeSemantics: true,
                    onTap: onCollapse,
                    child: EhPressable(
                      key: GalleryStatsSection.collapseToggleKey,
                      onPressed: onCollapse,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: target,
                          minHeight: target,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                collapseLabel!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: palette.text2.resolveFrom(context),
                                ),
                              ),
                              const SizedBox(width: 3),
                              EhSvgIcon(
                                CupertinoIcons.chevron_up,
                                size: 11.5,
                                color: palette.text3.resolveFrom(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCollapsedRow extends StatelessWidget {
  const _StatsCollapsedRow({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final target = _statsActionTargetSize();

    return Semantics(
      button: true,
      expanded: false,
      label: l10n.gallery_stats_expand_action,
      hint: l10n.gallery_stats_expand_hint,
      excludeSemantics: true,
      onTap: onExpand,
      child: EhPressable(
        key: GalleryStatsSection.expandToggleKey,
        onPressed: onExpand,
        borderRadius: BorderRadius.circular(_kStatsCardRadius),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: target,
            minHeight: math.max(target, 56),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                EhSvgIcon(
                  CupertinoIcons.chart_bar,
                  size: 17,
                  color: accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        l10n.gallery_stats_expand_action,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: palette.text1.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.gallery_stats_expand_hint,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: palette.text3.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                EhSvgIcon(
                  CupertinoIcons.chevron_down,
                  size: 13.5,
                  color: palette.text3.resolveFrom(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsSurfaceCard extends StatelessWidget {
  const _StatsSurfaceCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final columnChildren = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        columnChildren.add(const GalleryLuminousDivider.horizontal());
      }
      columnChildren.add(children[i]);
    }

    return GalleryLuminousCardFrame(
      radius: _kStatsCardRadius,
      child: AnimatedSize(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: columnChildren,
        ),
      ),
    );
  }
}

/// Shared tactile surface card frame used across [GalleryInfoPage] and
/// [GalleryStatsSection]. Adds subtle directional top rim sheen, soft edge
/// luminescence, theme-tuned ambient elevation shadows, and High Contrast
/// outline reinforcement.
class GalleryLuminousCardFrame extends StatelessWidget {
  const GalleryLuminousCardFrame({
    super.key,
    required this.child,
    this.radius = _kStatsCardRadius,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final hairlineColor = palette.hairline.resolveFrom(context);

    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: highContrast
            ? hairlineColor
            : (isDark ? const Color(0x1FFFFFFF) : hairlineColor),
        width: highContrast ? 1.0 : 0.6,
      ),
    );

    final shadows = isDark
        ? const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              spreadRadius: -4,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Color(0x38000000),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
            BoxShadow(
              color: Color(0x14B8C4FF),
              blurRadius: 14,
              spreadRadius: -3,
              offset: Offset(0, -1),
            ),
          ]
        : const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A101828),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
            BoxShadow(
              color: Color(0x12101828),
              blurRadius: 24,
              spreadRadius: -4,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color(0x0A4A5BD8),
              blurRadius: 18,
              spreadRadius: -6,
              offset: Offset(0, 4),
            ),
          ];

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surface.resolveFrom(context),
        shape: shape,
        shadows: shadows,
      ),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: <Widget>[
            child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CardRimSheenPainter(
                    radius: radius,
                    isDark: isDark,
                    highContrast: highContrast,
                    highContrastBorderColor: hairlineColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a soft overhead rim highlight and delicate perimeter sheen along the
/// card's inner edges so the flat card sits with subtle tactile depth.
class _CardRimSheenPainter extends CustomPainter {
  const _CardRimSheenPainter({
    required this.radius,
    required this.isDark,
    required this.highContrast,
    required this.highContrastBorderColor,
  });

  final double radius;
  final bool isDark;
  final bool highContrast;
  final Color highContrastBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final insetRect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final rrect = RRect.fromRectAndRadius(
      insetRect,
      Radius.circular(math.max(0, radius - 0.5)),
    );

    // 1. Soft directional border sheen (or crisp perimeter in High Contrast).
    if (highContrast) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = highContrastBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    } else {
      final rimGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const <Color>[
                Color(0x38EEF2FF),
                Color(0x14FFFFFF),
                Color(0x06FFFFFF),
                Color(0x16FFFFFF),
              ]
            : const <Color>[
                Color(0xE6FFFFFF),
                Color(0x20FFFFFF),
                Color(0x0614161A),
                Color(0x0A14161A),
              ],
        stops: const <double>[0.0, 0.22, 0.78, 1.0],
      );
      final rimPaint = Paint()
        ..shader = rimGradient.createShader(insetRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(rrect, rimPaint);
    }

    // 2. Feathered horizontal top specular bloom (subtle overhead light).
    final topBloomRect = Rect.fromLTWH(
      size.width * 0.08,
      0,
      size.width * 0.84,
      1.5,
    );
    final topGlowShader = LinearGradient(
      colors: isDark
          ? const <Color>[
              Color(0x00EEF2FF),
              Color(0x4DEEF2FF),
              Color(0x4DEEF2FF),
              Color(0x00EEF2FF),
            ]
          : const <Color>[
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
      stops: const <double>[0.0, 0.28, 0.72, 1.0],
    ).createShader(topBloomRect);

    canvas.drawLine(
      Offset(topBloomRect.left, 1.0),
      Offset(topBloomRect.right, 1.0),
      Paint()
        ..shader = topGlowShader
        ..strokeWidth = isDark ? 4.5 : 3.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 5.0 : 3.0),
    );
    canvas.drawLine(
      Offset(topBloomRect.left, 0.6),
      Offset(topBloomRect.right, 0.6),
      Paint()
        ..shader = topGlowShader
        ..strokeWidth = 1.0,
    );

    // 3. Whisper-soft bottom edge light / grounding sheen.
    if (isDark && !highContrast) {
      final bottomRect = Rect.fromLTWH(
        size.width * 0.14,
        size.height - 2,
        size.width * 0.72,
        2,
      );
      final bottomShader = const LinearGradient(
        colors: <Color>[
          Color(0x00B8C4FF),
          Color(0x1EB8C4FF),
          Color(0x00B8C4FF),
        ],
        stops: <double>[0.0, 0.5, 1.0],
      ).createShader(bottomRect);
      canvas.drawLine(
        Offset(bottomRect.left, size.height - 0.8),
        Offset(bottomRect.right, size.height - 0.8),
        Paint()
          ..shader = bottomShader
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CardRimSheenPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.isDark != isDark ||
      oldDelegate.highContrast != highContrast ||
      oldDelegate.highContrastBorderColor != highContrastBorderColor;
}

/// Edge-feathered micro-luminous hairline divider shared across metadata cards
/// on [GalleryInfoPage]. Fades gently at both ends with a subtle diffused glow,
/// and switches to a crisp high-contrast rule when Increase Contrast is active.
class GalleryLuminousDivider extends StatelessWidget {
  const GalleryLuminousDivider.horizontal({
    super.key,
    this.startInset = 0.0,
    this.endInset = 0.0,
  }) : axis = Axis.horizontal,
       extent = null;

  const GalleryLuminousDivider.vertical({
    super.key,
    double inset = 6.0,
    this.extent,
  }) : axis = Axis.vertical,
       startInset = inset,
       endInset = inset;

  final Axis axis;
  final double startInset;
  final double endInset;
  final double? extent;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final separatorColor = EhPalette.separator.resolveFrom(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final textDirection = Directionality.of(context);
    if (axis == Axis.horizontal) {
      return SizedBox(
        width: double.infinity,
        height: 3,
        child: CustomPaint(
          painter: _LuminousDividerPainter(
            axis: Axis.horizontal,
            isDark: isDark,
            highContrast: highContrast,
            separatorColor: separatorColor,
            startInset: startInset,
            endInset: endInset,
            textDirection: textDirection,
            pixelWidth: 1.0 / dpr,
          ),
        ),
      );
    }
    return SizedBox(
      width: 3,
      height: extent,
      child: CustomPaint(
        painter: _LuminousDividerPainter(
          axis: Axis.vertical,
          isDark: isDark,
          highContrast: highContrast,
          separatorColor: separatorColor,
          startInset: startInset,
          endInset: endInset,
          textDirection: textDirection,
          pixelWidth: 1.0 / dpr,
        ),
      ),
    );
  }
}

class _LuminousDividerPainter extends CustomPainter {
  const _LuminousDividerPainter({
    required this.axis,
    required this.isDark,
    required this.highContrast,
    required this.separatorColor,
    required this.startInset,
    required this.endInset,
    required this.textDirection,
    required this.pixelWidth,
  });

  final Axis axis;
  final bool isDark;
  final bool highContrast;
  final Color separatorColor;
  final double startInset;
  final double endInset;
  final TextDirection textDirection;
  final double pixelWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final isHorizontal = axis == Axis.horizontal;
    final leftInset = textDirection == TextDirection.rtl
        ? endInset
        : startInset;
    final rightInset = textDirection == TextDirection.rtl
        ? startInset
        : endInset;

    final start = isHorizontal
        ? Offset(leftInset, size.height / 2)
        : Offset(size.width / 2, startInset);
    final end = isHorizontal
        ? Offset(math.max(leftInset, size.width - rightInset), size.height / 2)
        : Offset(size.width / 2, math.max(startInset, size.height - endInset));

    if (highContrast) {
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = separatorColor
          ..strokeWidth = math.max(1.0, pixelWidth),
      );
      return;
    }

    final spanRect = Rect.fromPoints(start, end).inflate(1);

    final glowColors = isDark
        ? const <Color>[
            Color(0x00C8D2FF),
            Color(0x28C8D2FF),
            Color(0x30EEF2FF),
            Color(0x28C8D2FF),
            Color(0x00C8D2FF),
          ]
        : const <Color>[
            Color(0x004A5BD8),
            Color(0x144A5BD8),
            Color(0x1A14161A),
            Color(0x144A5BD8),
            Color(0x004A5BD8),
          ];
    final coreColors = isDark
        ? const <Color>[
            Color(0x00FFFFFF),
            Color(0x28FFFFFF),
            Color(0x38FFFFFF),
            Color(0x28FFFFFF),
            Color(0x00FFFFFF),
          ]
        : const <Color>[
            Color(0x0014161A),
            Color(0x1E14161A),
            Color(0x2814161A),
            Color(0x1E14161A),
            Color(0x0014161A),
          ];
    const stops = <double>[0.0, 0.16, 0.5, 0.84, 1.0];

    final glowShader = LinearGradient(
      begin: isHorizontal ? Alignment.centerLeft : Alignment.topCenter,
      end: isHorizontal ? Alignment.centerRight : Alignment.bottomCenter,
      colors: glowColors,
      stops: stops,
    ).createShader(spanRect);

    final coreShader = LinearGradient(
      begin: isHorizontal ? Alignment.centerLeft : Alignment.topCenter,
      end: isHorizontal ? Alignment.centerRight : Alignment.bottomCenter,
      colors: coreColors,
      stops: stops,
    ).createShader(spanRect);

    canvas.drawLine(
      start,
      end,
      Paint()
        ..shader = glowShader
        ..strokeWidth = isDark ? 2.6 : 2.2
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 2.8 : 2.2),
    );

    canvas.drawLine(
      start,
      end,
      Paint()
        ..shader = coreShader
        ..strokeWidth = math.max(0.75, pixelWidth),
    );

    if (!isDark) {
      final offset = isHorizontal
          ? Offset(0, math.max(0.8, pixelWidth))
          : Offset(math.max(0.8, pixelWidth), 0);
      final bevelShader = LinearGradient(
        begin: isHorizontal ? Alignment.centerLeft : Alignment.topCenter,
        end: isHorizontal ? Alignment.centerRight : Alignment.bottomCenter,
        colors: const <Color>[
          Color(0x00FFFFFF),
          Color(0xC0FFFFFF),
          Color(0xE0FFFFFF),
          Color(0xC0FFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: stops,
      ).createShader(spanRect.shift(offset));
      canvas.drawLine(
        start + offset,
        end + offset,
        Paint()
          ..shader = bevelShader
          ..strokeWidth = math.max(0.75, pixelWidth),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LuminousDividerPainter oldDelegate) =>
      oldDelegate.axis != axis ||
      oldDelegate.isDark != isDark ||
      oldDelegate.highContrast != highContrast ||
      oldDelegate.separatorColor != separatorColor ||
      oldDelegate.startInset != startInset ||
      oldDelegate.endInset != endInset ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.pixelWidth != pixelWidth;
}

class _StatsLoadingSkeleton extends StatelessWidget {
  const _StatsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final fill = palette.fill.resolveFrom(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget bar(double width, double height, {double radius = 4}) =>
        DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: SizedBox(width: width, height: height),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (reduceMotion)
                    EhSvgIcon(
                      CupertinoIcons.chart_bar,
                      size: 14,
                      color: palette.text3.resolveFrom(context),
                    )
                  else
                    const CupertinoActivityIndicator(radius: 7.5),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.gallery_stats_loading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.text2.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        bar(56, 10),
                        const SizedBox(height: 8),
                        bar(112, 22, radius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      bar(48, 10),
                      const SizedBox(height: 8),
                      bar(52, 16, radius: 5),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const GalleryLuminousDivider.horizontal(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: SizedBox(
            height: 88,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final factor in const <double>[
                  0.3,
                  0.56,
                  0.84,
                  0.64,
                  0.46,
                  0.92,
                  0.52,
                  0.38,
                ]) ...<Widget>[
                  Expanded(
                    child: FractionallySizedBox(
                      heightFactor: factor,
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ]..removeLast(),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsStatusState extends StatelessWidget {
  const _StatsStatusState({
    required this.kind,
    required this.statsUrl,
    required this.onRetry,
    this.onOpenExternalUrl,
  });

  final GalleryStatsErrorKind kind;
  final String statsUrl;
  final VoidCallback onRetry;
  final ValueChanged<String>? onOpenExternalUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final accentSoft = EhPalette.accentSoft.resolveFrom(context);

    final IconData icon;
    final String title;
    final String? subtitle;
    final bool emphasizeRetry;
    final String retryLabel;

    switch (kind) {
      case GalleryStatsErrorKind.loginRequired:
        icon = CupertinoIcons.lock;
        title = l10n.gallery_stats_login_required;
        subtitle = null;
        emphasizeRetry = false;
        retryLabel = l10n.gallery_stats_retry;
      case GalleryStatsErrorKind.unavailable:
        icon = CupertinoIcons.chart_bar;
        title = l10n.gallery_stats_empty_title;
        subtitle = l10n.gallery_stats_empty_body;
        emphasizeRetry = true;
        retryLabel = l10n.gallery_stats_refresh;
      case GalleryStatsErrorKind.network:
        icon = CupertinoIcons.exclamationmark_circle;
        title = l10n.gallery_stats_load_failed;
        subtitle = null;
        emphasizeRetry = true;
        retryLabel = l10n.gallery_stats_retry;
    }

    final canOpenExternal = statsUrl.isNotEmpty && onOpenExternalUrl != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(top: subtitle == null ? 0 : 2),
                child: EhSvgIcon(
                  icon,
                  size: 16,
                  color: palette.text3.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: palette.text1.resolveFrom(context),
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: palette.text2.resolveFrom(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 22),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _StatsInlineAction(
                  icon: CupertinoIcons.refresh,
                  label: retryLabel,
                  foregroundColor: emphasizeRetry
                      ? accent
                      : palette.text2.resolveFrom(context),
                  backgroundColor: emphasizeRetry ? accentSoft : null,
                  onPressed: onRetry,
                ),
                if (canOpenExternal)
                  _StatsInlineAction(
                    icon: CupertinoIcons.globe,
                    label: l10n.gallery_stats_open_web,
                    foregroundColor: palette.text2.resolveFrom(context),
                    onPressed: () => onOpenExternalUrl!(statsUrl),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsInlineAction extends StatelessWidget {
  const _StatsInlineAction({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.onPressed,
    this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color? backgroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final target = _statsActionTargetSize();
    final hasFill = backgroundColor != null;

    final innerContent = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: hasFill ? 12 : 6,
        vertical: 7,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          EhSvgIcon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: EhPressable(
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: target, minHeight: target),
          child: Align(
            widthFactor: 1,
            alignment: Alignment.center,
            child: hasFill
                ? DecoratedBox(
                    decoration: ShapeDecoration(
                      color: backgroundColor,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: innerContent,
                  )
                : innerContent,
          ),
        ),
      ),
    );
  }
}

class _StatsKpiHeader extends StatelessWidget {
  const _StatsKpiHeader({
    required this.totalVisits,
    required this.favoriteRate,
    required this.dailyAverage,
    required this.refreshing,
    required this.statsUrl,
    required this.onRefresh,
    this.onOpenExternalUrl,
  });

  final int? totalVisits;
  final double? favoriteRate;
  final double? dailyAverage;
  final bool refreshing;
  final String statsUrl;
  final VoidCallback onRefresh;
  final ValueChanged<String>? onOpenExternalUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final text1 = palette.text1.resolveFrom(context);
    final canOpenExternal = statsUrl.isNotEmpty && onOpenExternalUrl != null;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 6, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: <Widget>[
                  _KpiMetricItem(
                    label: l10n.gallery_stats_total_visits,
                    value: totalVisits != null
                        ? _formatIntWithCommas(totalVisits!)
                        : '—',
                    valueColor: text1,
                    primary: true,
                  ),
                  if (favoriteRate != null)
                    _KpiMetricItem(
                      label: l10n.gallery_stats_fav_rate,
                      value: '${(favoriteRate! * 100).toStringAsFixed(1)}%',
                      valueColor: text1,
                    ),
                  if (dailyAverage != null)
                    _KpiMetricItem(
                      label: l10n.gallery_stats_daily_avg,
                      value: _formatCompactStat(dailyAverage!),
                      valueColor: text1,
                    ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _StatsIconButton(
                icon: CupertinoIcons.refresh,
                semanticLabel: l10n.gallery_stats_refresh,
                loading: refreshing,
                onPressed: refreshing ? null : onRefresh,
              ),
              if (canOpenExternal)
                _StatsIconButton(
                  icon: CupertinoIcons.globe,
                  semanticLabel: l10n.gallery_stats_open_web,
                  onPressed: () => onOpenExternalUrl!(statsUrl),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiMetricItem extends StatelessWidget {
  const _KpiMetricItem({
    required this.label,
    required this.value,
    required this.valueColor,
    this.primary = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: palette.text2.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: primary ? 22 : 16,
            fontWeight: FontWeight.w600,
            height: 1.15,
            letterSpacing: primary ? -0.4 : 0,
            fontFeatures: _kStatsTabularFigures,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _StatsIconButton extends StatelessWidget {
  const _StatsIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final target = _statsActionTargetSize();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: EhPressable(
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: target,
          height: target,
          child: Center(
            child: loading && !reduceMotion
                ? const CupertinoActivityIndicator(radius: 7.5)
                : EhSvgIcon(
                    icon,
                    size: 15,
                    color: onPressed == null
                        ? palette.text3.resolveFrom(context)
                        : palette.text2.resolveFrom(context),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Flush hairline-divided ranking grid rendered directly on the parent card's
/// surface (no nested bordered sub-cards).
class _StatsRankingsBand extends StatelessWidget {
  const _StatsRankingsBand({required this.stats});

  final GalleryStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;

    if (!stats.hasAnyRanking) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            EhSvgIcon(
              CupertinoIcons.chart_bar,
              size: 14,
              color: palette.text3.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.gallery_stats_no_rankings,
                style: TextStyle(
                  fontSize: 12.5,
                  color: palette.text2.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget hLine() =>
        const GalleryLuminousDivider.horizontal(startInset: 8, endInset: 8);

    Widget vLine() => const GalleryLuminousDivider.vertical(inset: 8);

    final rankings = stats.rankings;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (textScale >= 1.8 || constraints.maxWidth < 250) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < rankings.length; i++) ...<Widget>[
                if (i > 0) hLine(),
                _RankingCell(entry: rankings[i]),
              ],
            ],
          );
        }
        if (constraints.maxWidth >= 480 && textScale < 1.35) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < rankings.length; i++) ...<Widget>[
                  if (i > 0) vLine(),
                  Expanded(child: _RankingCell(entry: rankings[i])),
                ],
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: _RankingCell(entry: rankings[0])),
                  vLine(),
                  Expanded(child: _RankingCell(entry: rankings[1])),
                ],
              ),
            ),
            hLine(),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: _RankingCell(entry: rankings[2])),
                  vLine(),
                  Expanded(child: _RankingCell(entry: rankings[3])),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RankingCell extends StatelessWidget {
  const _RankingCell({required this.entry});

  final GalleryRankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final isTop50 = entry.isRanked && entry.ranking! <= 50;

    final Color rankColor;
    if (isTop50) {
      rankColor = accent;
    } else if (entry.isRanked) {
      rankColor = palette.text1.resolveFrom(context);
    } else {
      rankColor = palette.text3.resolveFrom(context);
    }

    final periodLabel = _periodLabel(l10n, entry.period);
    final rankLabel = entry.isRanked
        ? '#${_formatIntWithCommas(entry.ranking!)}'
        : l10n.gallery_stats_unranked;
    final scoreLabel = entry.score != null
        ? l10n.gallery_stats_score(_formatIntWithCommas(entry.score!))
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            periodLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: palette.text2.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rankLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: entry.isRanked ? 16 : 13.5,
              fontWeight: entry.isRanked ? FontWeight.w600 : FontWeight.w400,
              fontFeatures: _kStatsTabularFigures,
              color: rankColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            scoreLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontFeatures: _kStatsTabularFigures,
              color: entry.score != null
                  ? palette.text2.resolveFrom(context)
                  : palette.text3.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  String _periodLabel(L10n l10n, GalleryStatsPeriod period) {
    switch (period) {
      case GalleryStatsPeriod.allTime:
        return l10n.gallery_stats_all_time;
      case GalleryStatsPeriod.year:
        return l10n.gallery_stats_past_year;
      case GalleryStatsPeriod.month:
        return l10n.gallery_stats_past_month;
      case GalleryStatsPeriod.day:
        return l10n.gallery_stats_yesterday;
    }
  }
}

class _StatsTrendBand extends StatelessWidget {
  const _StatsTrendBand({
    required this.stats,
    required this.metric,
    required this.granularity,
    required this.selectedIndex,
    required this.onMetricChanged,
    required this.onGranularityChanged,
    required this.onBucketSelected,
  });

  final GalleryStats stats;
  final GalleryStatsMetric metric;
  final GalleryStatsGranularity granularity;
  final int? selectedIndex;
  final ValueChanged<GalleryStatsMetric> onMetricChanged;
  final ValueChanged<GalleryStatsGranularity> onGranularityChanged;
  final void Function(int index, {bool haptic}) onBucketSelected;

  static const double _leftAxisWidth = 42.0;
  static const double _rightPadding = 6.0;
  static const double _topPadding = 12.0;
  static const double _bottomAxisHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final locale = Localizations.localeOf(context);
    final palette = ehTheme.palette;
    final visitsColor = EhPalette.accent.resolveFrom(context);
    final hitsColor = _kHitsAccent.resolveFrom(context);
    final metricColor = metric == GalleryStatsMetric.visits
        ? visitsColor
        : hitsColor;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final target = _statsActionTargetSize();

    final series = stats.seriesFor(granularity);
    final values = series
        .map((item) {
          final raw = item.valueFor(metric);
          return raw.isFinite && raw > 0 ? raw : 0.0;
        })
        .toList(growable: false);

    var total = 0.0;
    var peakIndex = 0;
    var peakValue = 0.0;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      total += v;
      if (i == 0 || v > peakValue) {
        peakValue = v;
        peakIndex = i;
      }
    }

    final activeIndex = series.isEmpty
        ? -1
        : (selectedIndex ?? (series.length - 1)).clamp(0, series.length - 1);
    final activeStat = activeIndex >= 0 ? series[activeIndex] : null;
    final activeValue = activeIndex >= 0 ? values[activeIndex] : 0.0;
    final sharePercent = total > 0
        ? (activeValue / total * 100).toStringAsFixed(1)
        : '0.0';
    final avgValue = series.isEmpty ? 0.0 : total / series.length;
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final metricLabel = metric == GalleryStatsMetric.visits
        ? l10n.gallery_stats_visits
        : l10n.gallery_stats_hits;

    final neutralBar = highContrast
        ? (isDark ? const Color(0x66ECEDF0) : const Color(0x5214161A))
        : (isDark ? const Color(0x24ECEDF0) : const Color(0x1814161A));
    final neutralPeakBar = highContrast
        ? (isDark ? const Color(0x99ECEDF0) : const Color(0x7A14161A))
        : (isDark ? const Color(0x38ECEDF0) : const Color(0x2A14161A));

    String bucketSemanticValue(int index) {
      final periodText = _localizePeriodLabel(
        series[index].period,
        locale,
        short: false,
      );
      return '$periodText: ${_formatExactStat(values[index])}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _UnderlineTabGroup<GalleryStatsMetric>(
                  value: metric,
                  onChanged: onMetricChanged,
                  items: <_UnderlineTabItem<GalleryStatsMetric>>[
                    _UnderlineTabItem<GalleryStatsMetric>(
                      value: GalleryStatsMetric.visits,
                      label: l10n.gallery_stats_visits,
                      indicatorColor: visitsColor,
                    ),
                    _UnderlineTabItem<GalleryStatsMetric>(
                      value: GalleryStatsMetric.hits,
                      label: l10n.gallery_stats_hits,
                      indicatorColor: hitsColor,
                    ),
                  ],
                ),
                _FlatTabGroup<GalleryStatsGranularity>(
                  value: granularity,
                  onChanged: onGranularityChanged,
                  items: <_FlatTabItem<GalleryStatsGranularity>>[
                    _FlatTabItem<GalleryStatsGranularity>(
                      value: GalleryStatsGranularity.yearly,
                      label: l10n.gallery_stats_yearly,
                      muted: stats.yearlyStats.isEmpty,
                    ),
                    _FlatTabItem<GalleryStatsGranularity>(
                      value: GalleryStatsGranularity.monthly,
                      label: l10n.gallery_stats_monthly,
                      muted: stats.monthlyStats.isEmpty,
                    ),
                    _FlatTabItem<GalleryStatsGranularity>(
                      value: GalleryStatsGranularity.daily,
                      label: l10n.gallery_stats_daily,
                      muted: stats.dailyStats.isEmpty,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (series.isEmpty)
            SizedBox(
              height: 124,
              child: Center(
                child: Text(
                  l10n.gallery_stats_no_series_data,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.text3.resolveFrom(context),
                  ),
                ),
              ),
            )
          else ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _formatExactStat(activeValue),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          letterSpacing: -0.3,
                          fontFeatures: _kStatsTabularFigures,
                          color: palette.text1.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.gallery_stats_period_share(
                          _localizePeriodLabel(
                            activeStat!.period,
                            locale,
                            short: false,
                          ),
                          sharePercent,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: _kStatsTabularFigures,
                          color: palette.text2.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                  Semantics(
                    button: true,
                    label: l10n.gallery_stats_peak(
                      _formatCompactStat(peakValue),
                    ),
                    excludeSemantics: true,
                    onTap: () => onBucketSelected(peakIndex, haptic: true),
                    child: EhPressable(
                      onPressed: () =>
                          onBucketSelected(peakIndex, haptic: true),
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: target,
                          minHeight: target,
                        ),
                        child: Align(
                          widthFactor: 1,
                          alignment: AlignmentDirectional.centerEnd,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Text(
                              l10n.gallery_stats_peak(
                                _formatCompactStat(peakValue),
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: activeIndex == peakIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontFeatures: _kStatsTabularFigures,
                                color: activeIndex == peakIndex
                                    ? metricColor
                                    : palette.text2.resolveFrom(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final axisStyle = TextStyle(
                  fontSize: 10,
                  fontFamily: defaultTextStyle.fontFamily,
                  fontFamilyFallback: defaultTextStyle.fontFamilyFallback,
                  fontFeatures: _kStatsTabularFigures,
                );
                final maxY = _niceMaxY(peakValue);
                var measuredTickWidth = 0.0;
                var measuredTickHeight = 0.0;
                for (final fraction in const <double>[0.0, 0.5, 1.0]) {
                  final tp = TextPainter(
                    text: TextSpan(
                      text: _formatCompactStat(maxY * fraction),
                      style: axisStyle,
                    ),
                    textDirection: textDirection,
                    textScaler: textScaler,
                    maxLines: 1,
                  )..layout();
                  measuredTickWidth = math.max(measuredTickWidth, tp.width);
                  measuredTickHeight = math.max(measuredTickHeight, tp.height);
                }
                var measuredXHeight = measuredTickHeight;
                if (series.isNotEmpty) {
                  final sampleLabel = _localizePeriodLabel(
                    series.last.period,
                    locale,
                    short: true,
                  );
                  final xTp = TextPainter(
                    text: TextSpan(
                      text: sampleLabel,
                      style: axisStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    textDirection: textDirection,
                    textScaler: textScaler,
                    maxLines: 1,
                  )..layout();
                  measuredXHeight = math.max(measuredXHeight, xTp.height);
                }

                final maxLeftAxis = math.max(_leftAxisWidth, width * 0.34);
                final leftAxisWidth = math
                    .max(_leftAxisWidth, measuredTickWidth + 10.0)
                    .clamp(_leftAxisWidth, maxLeftAxis)
                    .toDouble();
                final topPadding = math.max(
                  _topPadding,
                  measuredTickHeight / 2 + 4.0,
                );
                final bottomAxisHeight = math.max(
                  _bottomAxisHeight,
                  measuredXHeight + 10.0,
                );
                final chartHeight = topPadding + 132.0 + bottomAxisHeight;

                int hitIndex(double dx) {
                  final plotWidth = math.max(
                    1.0,
                    width - leftAxisWidth - _rightPadding,
                  );
                  final relX = (dx - leftAxisWidth).clamp(
                    0.0,
                    plotWidth - 0.0001,
                  );
                  return (relX / plotWidth * series.length).floor().clamp(
                    0,
                    series.length - 1,
                  );
                }

                final canStepPrev = activeIndex > 0;
                final canStepNext = activeIndex < series.length - 1;

                return Semantics(
                  label: '${l10n.gallery_stats} $metricLabel',
                  value: bucketSemanticValue(activeIndex),
                  increasedValue: canStepNext
                      ? bucketSemanticValue(activeIndex + 1)
                      : null,
                  decreasedValue: canStepPrev
                      ? bucketSemanticValue(activeIndex - 1)
                      : null,
                  onIncrease: canStepNext
                      ? () => onBucketSelected(activeIndex + 1, haptic: true)
                      : null,
                  onDecrease: canStepPrev
                      ? () => onBucketSelected(activeIndex - 1, haptic: true)
                      : null,
                  child: MouseRegion(
                    onHover: (event) => onBucketSelected(
                      hitIndex(event.localPosition.dx),
                      haptic: false,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => onBucketSelected(
                        hitIndex(details.localPosition.dx),
                        haptic: true,
                      ),
                      onHorizontalDragStart: (details) => onBucketSelected(
                        hitIndex(details.localPosition.dx),
                        haptic: true,
                      ),
                      onHorizontalDragUpdate: (details) => onBucketSelected(
                        hitIndex(details.localPosition.dx),
                        haptic: true,
                      ),
                      child: SizedBox(
                        key: GalleryStatsSection.chartKey,
                        height: chartHeight,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: GalleryStatsChartPainter(
                            series: series,
                            values: values,
                            activeIndex: activeIndex,
                            peakIndex: peakIndex,
                            metricColor: metricColor,
                            inactiveBarColor: neutralBar,
                            peakBarColor: neutralPeakBar,
                            gridColor: EhPalette.separator.resolveFrom(context),
                            baselineFillColor: palette.fill.resolveFrom(
                              context,
                            ),
                            labelColor: palette.text3.resolveFrom(context),
                            activeLabelColor: palette.text1.resolveFrom(
                              context,
                            ),
                            locale: locale,
                            textDirection: textDirection,
                            textScaler: textScaler,
                            fontFamily: defaultTextStyle.fontFamily,
                            fontFamilyFallback:
                                defaultTextStyle.fontFamilyFallback,
                            leftAxisWidth: leftAxisWidth,
                            rightPadding: _rightPadding,
                            topPadding: topPadding,
                            bottomAxisHeight: bottomAxisHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    l10n.gallery_stats_period_total(_formatCompactStat(total)),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFeatures: _kStatsTabularFigures,
                      color: palette.text2.resolveFrom(context),
                    ),
                  ),
                  Text(
                    l10n.gallery_stats_period_avg(_formatCompactStat(avgValue)),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFeatures: _kStatsTabularFigures,
                      color: palette.text2.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnderlineTabItem<T> {
  const _UnderlineTabItem({
    required this.value,
    required this.label,
    required this.indicatorColor,
  });

  final T value;
  final String label;
  final Color indicatorColor;
}

class _UnderlineTabGroup<T> extends StatelessWidget {
  const _UnderlineTabGroup({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<_UnderlineTabItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final target = _statsActionTargetSize();
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: <Widget>[
        for (final item in items)
          Builder(
            builder: (context) {
              final selected = item.value == value;
              return Semantics(
                button: true,
                selected: selected,
                label: item.label,
                excludeSemantics: true,
                onTap: () => onChanged(item.value),
                child: EhPressable(
                  onPressed: () => onChanged(item.value),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: target,
                      minHeight: target,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 5,
                          ),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: selected
                                  ? palette.text1.resolveFrom(context)
                                  : palette.text3.resolveFrom(context),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 2,
                          width: 24,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: selected
                                  ? item.indicatorColor
                                  : const Color(0x00000000),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _FlatTabItem<T> {
  const _FlatTabItem({
    required this.value,
    required this.label,
    this.muted = false,
  });

  final T value;
  final String label;
  final bool muted;
}

class _FlatTabGroup<T> extends StatelessWidget {
  const _FlatTabGroup({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<_FlatTabItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final target = _statsActionTargetSize();
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: <Widget>[
        for (final item in items)
          Builder(
            builder: (context) {
              final selected = item.value == value;
              final foreground = selected
                  ? palette.text1.resolveFrom(context)
                  : (item.muted
                        ? palette.text3.resolveFrom(context)
                        : palette.text2.resolveFrom(context));
              return Semantics(
                button: true,
                selected: selected,
                label: item.label,
                excludeSemantics: true,
                onTap: () => onChanged(item.value),
                child: EhPressable(
                  onPressed: () => onChanged(item.value),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: target,
                      minHeight: target,
                    ),
                    child: Align(
                      widthFactor: 1,
                      alignment: Alignment.center,
                      child: DecoratedBox(
                        decoration: selected
                            ? ShapeDecoration(
                                color: palette.fill.resolveFrom(context),
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              )
                            : const BoxDecoration(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: foreground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

@visibleForTesting
class GalleryStatsChartPainter extends CustomPainter {
  const GalleryStatsChartPainter({
    required this.series,
    required this.values,
    required this.activeIndex,
    required this.peakIndex,
    required this.metricColor,
    required this.inactiveBarColor,
    required this.peakBarColor,
    required this.gridColor,
    required this.baselineFillColor,
    required this.labelColor,
    required this.activeLabelColor,
    required this.locale,
    required this.textDirection,
    this.textScaler = TextScaler.noScaling,
    this.fontFamily,
    this.fontFamilyFallback,
    required this.leftAxisWidth,
    required this.rightPadding,
    required this.topPadding,
    required this.bottomAxisHeight,
  });

  final List<GalleryVisitStat> series;
  final List<double> values;
  final int activeIndex;
  final int peakIndex;
  final Color metricColor;
  final Color inactiveBarColor;
  final Color peakBarColor;
  final Color gridColor;
  final Color baselineFillColor;
  final Color labelColor;
  final Color activeLabelColor;
  final Locale locale;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final double leftAxisWidth;
  final double rightPadding;
  final double topPadding;
  final double bottomAxisHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final plotLeft = leftAxisWidth;
    final plotRight = math.max(plotLeft + 1, size.width - rightPadding);
    final plotWidth = plotRight - plotLeft;
    final plotTop = topPadding;
    final plotBottom = math.max(plotTop + 1, size.height - bottomAxisHeight);
    final plotHeight = plotBottom - plotTop;

    final rawMax = values.fold<double>(
      0,
      (prev, value) => value.isFinite && value > prev ? value : prev,
    );
    final maxY = _niceMaxY(rawMax);

    // 1. Quiet horizontal hairlines & Y-axis ticks (0, mid, max).
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.75;
    const tickFractions = <double>[0.0, 0.5, 1.0];
    for (final fraction in tickFractions) {
      final y = plotBottom - plotHeight * fraction;
      if (fraction == 0.0) {
        canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      } else {
        _drawHorizontalDashedLine(
          canvas,
          startX: plotLeft,
          endX: plotRight,
          y: y,
          paint: gridPaint,
        );
      }

      final tickValue = maxY * fraction;
      final tp = TextPainter(
        text: TextSpan(
          text: _formatCompactStat(tickValue),
          style: TextStyle(
            fontSize: 10,
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontFeatures: _kStatsTabularFigures,
            color: labelColor,
          ),
        ),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(1.0, leftAxisWidth - 6));
      tp.paint(
        canvas,
        Offset(leftAxisWidth - 6 - tp.width, y - tp.height / 2),
      );
    }

    // 2. Neutral bars + single accent highlight on the active bar.
    final slotWidth = plotWidth / series.length;
    final barWidth = (slotWidth * 0.54).clamp(3.0, 24.0);
    final barRadius = Radius.circular(math.min(4.0, barWidth / 2));

    final inactiveBarPaint = Paint()..color = inactiveBarColor;
    final peakBarPaint = Paint()..color = peakBarColor;
    final activeBarPaint = Paint()..color = metricColor;
    final zeroTickPaint = Paint()..color = baselineFillColor;

    final barTops = <Offset>[];
    for (var i = 0; i < series.length; i++) {
      final v = values[i].isFinite && values[i] > 0 ? values[i] : 0.0;
      final ratio = maxY > 0 ? (v / maxY).clamp(0.0, 1.0) : 0.0;
      final barHeight = ratio * plotHeight;
      final cx = plotLeft + slotWidth * (i + 0.5);
      final effectiveHeight = barHeight <= 0.5 ? 2.0 : math.max(3.0, barHeight);
      final topY = plotBottom - effectiveHeight;
      barTops.add(Offset(cx, topY));

      if (barHeight <= 0.5) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barWidth / 2, plotBottom - 2, barWidth, 2),
          topLeft: const Radius.circular(1),
          topRight: const Radius.circular(1),
        );
        canvas.drawRRect(rect, zeroTickPaint);
      } else {
        final Paint paint;
        if (i == activeIndex) {
          paint = activeBarPaint;
        } else if (i == peakIndex) {
          paint = peakBarPaint;
        } else {
          paint = inactiveBarPaint;
        }
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            cx - barWidth / 2,
            topY,
            barWidth,
            effectiveHeight,
          ),
          topLeft: barRadius,
          topRight: barRadius,
        );
        canvas.drawRRect(rect, paint);
      }
    }

    // 3. Quiet peak dot above peak bar when another bucket is active.
    if (peakIndex >= 0 &&
        peakIndex < barTops.length &&
        peakIndex != activeIndex &&
        values[peakIndex] > 0) {
      final peakTop = barTops[peakIndex];
      canvas.drawCircle(
        Offset(peakTop.dx, math.max(plotTop - 4, peakTop.dy - 6)),
        2.2,
        Paint()..color = metricColor.withValues(alpha: 0.72),
      );
    }

    // 4. Subtle vertical hairline guide above the active bar.
    if (activeIndex >= 0 && activeIndex < barTops.length) {
      final activeTop = barTops[activeIndex];
      if (activeTop.dy > plotTop + 4) {
        _drawVerticalDashedLine(
          canvas,
          x: activeTop.dx,
          startY: plotTop,
          endY: activeTop.dy - 3,
          paint: Paint()
            ..color = metricColor.withValues(alpha: 0.35)
            ..strokeWidth = 1.0,
        );
      }
    }

    // 5. Auto-thinned X-axis labels preventing horizontal overlap.
    _paintXAxisLabels(
      canvas,
      plotLeft: plotLeft,
      plotRight: plotRight,
      plotBottom: plotBottom,
      slotWidth: slotWidth,
    );
  }

  void _paintXAxisLabels(
    Canvas canvas, {
    required double plotLeft,
    required double plotRight,
    required double plotBottom,
    required double slotWidth,
  }) {
    final count = series.length;
    final scaledAxisFont = textScaler.scale(10.0);
    final scaleRatio = math.max(1.0, scaledAxisFont / 10.0);
    final sampleMaxChars = series.fold<int>(
      1,
      (prev, item) => math.max(
        prev,
        _localizePeriodLabel(item.period, locale, short: true).length,
      ),
    );
    final minSpacing = math.max(
      32.0 * scaleRatio,
      sampleMaxChars * 7.2 * scaleRatio + 10.0,
    );
    final stride = math.max(1, (minSpacing / slotWidth).ceil());

    final candidateIndices = <int>{};
    if (activeIndex >= 0 && activeIndex < count) {
      candidateIndices.add(activeIndex);
    }
    candidateIndices.add(0);
    candidateIndices.add(count - 1);
    for (var i = 0; i < count; i += stride) {
      candidateIndices.add(i);
    }

    final ordered = <int>[
      if (activeIndex >= 0 && activeIndex < count) activeIndex,
      if (0 != activeIndex) 0,
      if (count - 1 != activeIndex && count - 1 != 0) count - 1,
      ...candidateIndices
          .where((i) => i != activeIndex && i != 0 && i != count - 1)
          .toList()
        ..sort(),
    ];

    final maxLabelWidth = math.max(1.0, plotRight - plotLeft);
    final occupiedRanges = <(double, double)>[];
    for (final index in ordered) {
      final isActive = index == activeIndex;
      final label = _localizePeriodLabel(
        series[index].period,
        locale,
        short: true,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontFeatures: _kStatsTabularFigures,
            color: isActive ? activeLabelColor : labelColor,
          ),
        ),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxLabelWidth);

      final cx = plotLeft + slotWidth * (index + 0.5);
      final left = (cx - tp.width / 2)
          .clamp(plotLeft, math.max(plotLeft, plotRight - tp.width))
          .toDouble();
      final right = left + tp.width;

      var collides = false;
      for (final range in occupiedRanges) {
        if (left < range.$2 + 4 && right > range.$1 - 4) {
          collides = true;
          break;
        }
      }
      if (collides) {
        continue;
      }
      occupiedRanges.add((left, right));
      tp.paint(canvas, Offset(left, plotBottom + 6));
    }
  }

  void _drawHorizontalDashedLine(
    Canvas canvas, {
    required double startX,
    required double endX,
    required double y,
    required Paint paint,
  }) {
    const dash = 3.0;
    const gap = 3.0;
    var x = startX;
    while (x < endX) {
      final nextX = math.min(x + dash, endX);
      canvas.drawLine(Offset(x, y), Offset(nextX, y), paint);
      x += dash + gap;
    }
  }

  void _drawVerticalDashedLine(
    Canvas canvas, {
    required double x,
    required double startY,
    required double endY,
    required Paint paint,
  }) {
    const dash = 3.0;
    const gap = 3.0;
    var y = startY;
    while (y < endY) {
      final nextY = math.min(y + dash, endY);
      canvas.drawLine(Offset(x, y), Offset(x, nextY), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant GalleryStatsChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.values != values ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.peakIndex != peakIndex ||
        oldDelegate.metricColor != metricColor ||
        oldDelegate.inactiveBarColor != inactiveBarColor ||
        oldDelegate.peakBarColor != peakBarColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.baselineFillColor != baselineFillColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.activeLabelColor != activeLabelColor ||
        oldDelegate.locale != locale ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.textScaler != textScaler ||
        oldDelegate.leftAxisWidth != leftAxisWidth ||
        oldDelegate.rightPadding != rightPadding ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.bottomAxisHeight != bottomAxisHeight ||
        oldDelegate.fontFamily != fontFamily ||
        !listEquals(oldDelegate.fontFamilyFallback, fontFamilyFallback);
  }
}

double _niceMaxY(double rawMax) {
  if (!rawMax.isFinite || rawMax <= 0) {
    return 10;
  }
  final logVal = math.log(rawMax) / math.ln10;
  if (!logVal.isFinite) {
    return 10;
  }
  final exponent = logVal.floor();
  final magnitude = math.pow(10, exponent).toDouble();
  if (!magnitude.isFinite || magnitude <= 0) {
    return 10;
  }
  final normalized = rawMax / magnitude;
  final double niceFactor;
  if (normalized <= 1.0) {
    niceFactor = 1.0;
  } else if (normalized <= 2.0) {
    niceFactor = 2.0;
  } else if (normalized <= 2.5) {
    niceFactor = 2.5;
  } else if (normalized <= 5.0) {
    niceFactor = 5.0;
  } else {
    niceFactor = 10.0;
  }
  final result = niceFactor * magnitude;
  return result.isFinite && result > 0 ? result : rawMax;
}

const Map<String, int> _kEnglishMonthIndex = <String, int>{
  'january': 1,
  'jan': 1,
  'february': 2,
  'feb': 2,
  'march': 3,
  'mar': 3,
  'april': 4,
  'apr': 4,
  'may': 5,
  'june': 6,
  'jun': 6,
  'july': 7,
  'jul': 7,
  'august': 8,
  'aug': 8,
  'september': 9,
  'sep': 9,
  'sept': 9,
  'october': 10,
  'oct': 10,
  'november': 11,
  'nov': 11,
  'december': 12,
  'dec': 12,
};

const List<String> _kEnMonthsShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _kEnMonthsFull = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _kRuMonthsShort = <String>[
  'Янв',
  'Фев',
  'Мар',
  'Апр',
  'Май',
  'Июн',
  'Июл',
  'Авг',
  'Сен',
  'Окт',
  'Ноя',
  'Дек',
];

const List<String> _kRuMonthsFull = <String>[
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

/// Localizes E-Hentai's English month names (`January`..`December`) across the
/// app's supported locales while passing non-month labels (`2025`, `14th`)
/// through unchanged.
String _localizePeriodLabel(
  String raw,
  Locale locale, {
  required bool short,
}) {
  final trimmed = raw.trim();
  final monthNum = _kEnglishMonthIndex[trimmed.toLowerCase()];
  if (monthNum == null) {
    return trimmed;
  }
  switch (locale.languageCode) {
    case 'zh':
    case 'ja':
      return '$monthNum月';
    case 'ko':
      return '$monthNum월';
    case 'ru':
      return short
          ? _kRuMonthsShort[monthNum - 1]
          : _kRuMonthsFull[monthNum - 1];
    default:
      return short
          ? _kEnMonthsShort[monthNum - 1]
          : _kEnMonthsFull[monthNum - 1];
  }
}

String _formatIntWithCommas(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

String _formatExactStat(double value) {
  if (!value.isFinite || value <= 0) {
    return '0';
  }
  if (value >= 1000000) {
    return _formatCompactStat(value);
  }
  return _formatIntWithCommas(value.round());
}

String _formatCompactStat(double value) {
  if (!value.isFinite || value <= 0) {
    return '0';
  }
  if (value >= 1000000000) {
    return '${_trimTrailingZero(value / 1000000000)}B';
  }
  if (value >= 1000000) {
    return '${_trimTrailingZero(value / 1000000)}M';
  }
  if (value >= 1000) {
    return '${_trimTrailingZero(value / 1000)}K';
  }
  if (value < 10 && value != value.roundToDouble()) {
    return value.toStringAsFixed(1);
  }
  return value.round().toString();
}

String _trimTrailingZero(double value) {
  final fixed = value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}
