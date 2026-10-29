import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// A settings page. With the native shell its title and buttons go to the
/// Liquid Glass bar; otherwise a Flutter navigation bar shows them.
class SettingScaffold extends StatefulWidget {
  const SettingScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <NativeNavigationAction>[],
    this.trailing,
  });

  final String title;

  /// Usually a [CustomScrollView] whose slivers sit in a [SliverSafeArea].
  final Widget child;

  /// Bar buttons for the native shell.
  final List<NativeNavigationAction> actions;

  /// The same buttons for the Flutter bar.
  final Widget? trailing;

  @override
  State<SettingScaffold> createState() => _SettingScaffoldState();
}

class _SettingScaffoldState extends State<SettingScaffold> {
  /// Content has scrolled under the glass bar.
  bool _scrolled = false;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (notification.depth == 0 && metrics.axis == Axis.vertical) {
      final scrolled = metrics.pixels > metrics.minScrollExtent;
      if (scrolled != _scrolled) {
        setState(() => _scrolled = scrolled);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool nativeBar = NativeNavigationScope.isEnabled(context);
    final Widget child = CanvasGrain(child: widget.child);
    return NativeNavigationPage(
      chrome: NativePageChrome(title: widget.title, actions: widget.actions),
      child: nativeBar
          ? CupertinoPageScaffold(child: child)
          : SettingGlassBar.observe(() => CupertinoPageScaffold(
                navigationBar: SettingGlassBar.isActive
                    ? SettingGlassBar(
                        title: widget.title,
                        edgeVisible: _scrolled,
                        trailing: widget.trailing,
                      )
                    : CupertinoNavigationBar(
                        padding: widget.trailing == null
                            ? null
                            : const EdgeInsetsDirectional.only(end: 8),
                        middle: Text(widget.title),
                        trailing: widget.trailing,
                      ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: child,
                ),
              )),
    );
  }
}

/// The Flutter stand-in for the native glass bar on iOS 26–27.0 with Liquid
/// Glass on: a transparent bar over a soft scroll edge, with the back button
/// and the page's buttons on glass.
class SettingGlassBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const SettingGlassBar({
    super.key,
    required this.title,
    this.titleVisible = true,
    this.edgeVisible = true,
    this.trailing,
  });

  static const double barHeight = 44;

  /// Forces the glass bar on or off in tests.
  @visibleForTesting
  static bool? debugActive;

  static bool get _followsSetting =>
      debugActive == null &&
      !kIsWeb &&
      LiquidGlassPlatform.isSupported &&
      Get.isRegistered<EhSettingService>();

  /// Read inside [observe] so the bar follows the Liquid Glass setting.
  static bool get isActive =>
      debugActive ??
      (_followsSetting && Get.find<EhSettingService>().liquidGlass);

  /// Rebuilds [builder] when the Liquid Glass setting changes.
  static Widget observe(Widget Function() builder) =>
      _followsSetting ? Obx(builder) : builder();

  final String title;

  /// A page with its own large title shows the inline one once it scrolls
  /// under the bar.
  final bool titleVisible;

  /// Like the system bar, the soft edge shows once content is under it, so
  /// a page at rest stays sharp.
  final bool edgeVisible;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  /// Content scrolls under the bar and shows through the soft edge.
  @override
  bool shouldFullyObstruct(BuildContext context) => false;

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.paddingOf(context).top;
    final route = ModalRoute.of(context);
    final bool canPop = route?.impliesAppBarDismissal ?? false;
    final bool followSystem = Get.isRegistered<EhSettingService>()
        ? Get.find<EhSettingService>().liquidGlassFollowSystemTransparency
        : true;
    final Color iconColor = ehTheme.palette.text1.resolveFrom(context);
    final TextStyle titleStyle = CupertinoTheme.of(context)
        .textTheme
        .navTitleTextStyle
        .copyWith(color: iconColor);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: edgeVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: SoftScrollEdgeEffect(
                edge: SoftEdge.top,
                inset: safeTop,
                bars: barHeight,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: safeTop),
          child: SizedBox(
            height: barHeight,
            child: NavigationToolbar(
              leading: canPop
                  ? _GlassCircle(
                      followSystemTransparency: followSystem,
                      label: CupertinoLocalizations.of(context).backButtonLabel,
                      onPressed: () => Navigator.maybePop(context),
                      child: Icon(
                        CupertinoIcons.chevron_back,
                        size: 24,
                        color: iconColor,
                      ),
                    )
                  : null,
              middle: AnimatedOpacity(
                opacity: titleVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
              ),
              trailing: trailing == null
                  ? null
                  : _GlassCapsule(
                      followSystemTransparency: followSystem,
                      child: IconTheme.merge(
                        data: IconThemeData(color: iconColor),
                        child: trailing!,
                      ),
                    ),
              middleSpacing: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({
    required this.followSystemTransparency,
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final bool followSystemTransparency;
  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      child: SizedBox.square(
        dimension: SettingGlassBar.barHeight,
        child: LiquidGlassSurface(
          enabled: true,
          borderRadius: BorderRadius.circular(SettingGlassBar.barHeight / 2),
          followSystemTransparency: followSystemTransparency,
          child: Semantics(
            button: true,
            label: label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCapsule extends StatelessWidget {
  const _GlassCapsule({
    required this.followSystemTransparency,
    required this.child,
  });

  final bool followSystemTransparency;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: SettingGlassBar.barHeight,
          minHeight: SettingGlassBar.barHeight,
          maxHeight: SettingGlassBar.barHeight,
        ),
        child: LiquidGlassSurface(
          enabled: true,
          borderRadius: BorderRadius.circular(SettingGlassBar.barHeight / 2),
          followSystemTransparency: followSystemTransparency,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}
