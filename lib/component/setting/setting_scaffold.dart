import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_single_bar_edge.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/appkit_glass.dart';
import 'package:eros_fe/widget/canvas_grain.dart';
import 'package:eros_fe/widget/cupertino/sliver_list_section.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// In a desktop two-pane settings window a category page is the root of the
/// detail pane: the list beside it navigates, there is nothing to go back to.
bool isDesktopSettingPaneRoot(ModalRoute<dynamic>? route, {bool? split}) {
  if (route == null ||
      !PlatformCapabilities.isDesktop ||
      !Get.isRegistered<LayoutServices>()) {
    return false;
  }
  final layout = Get.find<LayoutServices>();
  final stack = layout.tabNavigation.selected;
  if (!(split ?? layout.isLayoutLarge) || stack?.id != EHRoutes.setting) {
    return false;
  }
  final history = stack!.detailObserver.history;
  return history.length >= 2 && identical(history[1], route);
}

/// A settings page. With the native shell its title and buttons go to the
/// Liquid Glass bar; otherwise a Flutter navigation bar shows them.
class SettingScaffold extends StatefulWidget {
  const SettingScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <NativeNavigationAction>[],
    this.trailing,
    this.nativeChrome = true,
    this.nativeBars = 0,
    this.nativeForeground,
  });

  final String title;

  /// Usually a [CustomScrollView] whose slivers sit in a [SliverSafeArea].
  final Widget child;

  /// Bar buttons for the native shell.
  final List<NativeNavigationAction> actions;

  /// The same buttons for the Flutter bar.
  final Widget? trailing;

  /// False keeps the Flutter bar under the native shell too, for pages that
  /// sit beside another page with its own buttons; the native shell has only
  /// one bar. The native bar then stays empty for this page.
  final bool nativeChrome;

  /// Flutter-owned bar height between the native row and scroll content.
  final double nativeBars;

  /// Native-only content that must stay sharp above the scroll edge.
  final Widget? nativeForeground;

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
    final split = context
        .dependOnInheritedWidgetOfExactType<BrowsePaneScope>()
        ?.split;
    final bool splitPane =
        (split ?? false) &&
        PlatformCapabilities.hostPlatform != TargetPlatform.android;
    final bool rootPane = isDesktopSettingPaneRoot(
      ModalRoute.of(context),
      split: split,
    );
    final bool nativeBar =
        widget.nativeChrome && NativeNavigationScope.isEnabled(context);
    final Color? splitCanvas = splitPane
        ? ehTheme.palette.canvas.resolveFrom(context)
        : null;
    final Widget themedChild = splitCanvas == null
        ? widget.child
        : CupertinoTheme(
            data: CupertinoTheme.of(
              context,
            ).copyWith(scaffoldBackgroundColor: splitCanvas),
            child: widget.child,
          );
    final Widget child = CanvasGrain(child: themedChild);
    final Widget body = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: child,
    );
    final Widget page = nativeBar
        ? CupertinoPageScaffold(
            backgroundColor: splitCanvas,
            child: NativeSingleBarEdge(
              bars: widget.nativeBars,
              foreground: widget.nativeForeground,
              child: child,
            ),
          )
        : (rootPane && widget.trailing == null)
        ? CupertinoPageScaffold(backgroundColor: splitCanvas, child: body)
        : SettingGlassBar.observe(
            () => CupertinoPageScaffold(
              backgroundColor: splitCanvas,
              navigationBar: SettingGlassBar.isActive
                  ? SettingGlassBar(
                      title: widget.title,
                      edgeVisible: _scrolled,
                      trailing: widget.trailing,
                    )
                  : CupertinoNavigationBar(
                      automaticallyImplyLeading: !rootPane,
                      padding: widget.trailing == null
                          ? null
                          : const EdgeInsetsDirectional.only(end: 8),
                      middle: Text(widget.title),
                      trailing: widget.trailing,
                    ),
              child: body,
            ),
          );
    if (!widget.nativeChrome) {
      return NativeNavigationPage(
        chrome: NativePageChrome(
          title: widget.title,
          navigationBarVisible: false,
          ownBar: true,
        ),
        child: _OwnBarInsets(child: page),
      );
    }
    return NativeNavigationPage(
      chrome: NativePageChrome(title: widget.title, actions: widget.actions),
      child: page,
    );
  }
}

/// Across the top the native bar hides for a page with its own bar only once
/// that page is on its way in, and returns as soon as it leaves. Laid out
/// against the window's own inset, the page doesn't follow it mid-slide.
/// Beside the vertical bar the native bar's band stays put anyway.
class _OwnBarInsets extends StatelessWidget {
  const _OwnBarInsets({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final environment = AdaptiveEnvironment.maybeOf(context);
    final double? top =
        environment == null ||
            environment.hasVerticalBar ||
            !NativeNavigationScope.isEnabled(context)
        ? null
        : environment.stableSafeArea.top;
    return MediaQuery(
      data: top == null
          ? media
          : media.copyWith(
              padding: media.padding.copyWith(top: top),
              viewPadding: media.viewPadding.copyWith(top: top),
            ),
      child: child,
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
      (GlassMode.resolve(enabled: true)
              .forComponent(flutterImplemented: true) !=
          GlassMode.off) &&
      Get.isRegistered<EhSettingService>();

  /// Read inside [observe] so the bar follows the Liquid Glass setting.
  static bool get isActive =>
      debugActive ??
      (_followsSetting &&
          GlassMode.resolve(enabled: Get.find<EhSettingService>().liquidGlass)
                  .forComponent(flutterImplemented: true) !=
              GlassMode.off);

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
    final bool canPop =
        (route?.impliesAppBarDismissal ?? false) &&
        !isDesktopSettingPaneRoot(
          route,
          split: context
              .dependOnInheritedWidgetOfExactType<BrowsePaneScope>()
              ?.split,
        );
    final bool followSystem =
        !Get.isRegistered<EhSettingService>() ||
        Get.find<EhSettingService>().liquidGlassMaterial;
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
            child: _toolbarSurface(
              context,
              NavigationToolbar(
                leading: canPop
                    ? _GlassCircle(
                        followSystemTransparency: followSystem,
                        label: CupertinoLocalizations.of(context)
                            .backButtonLabel,
                        onPressed: () => Navigator.maybePop(context),
                        child: EhSvgIcon(
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
        ),
      ],
    );
  }

  // Keep the scroll-edge effect outside the clipped glass toolbar.
  Widget _toolbarSurface(BuildContext context, Widget child) {
    final mode = GlassMode.of(context).forComponent(
      flutterImplemented: true,
      nativeBackends: const {
        NativeGlassBackend.uiKit,
        NativeGlassBackend.appKit,
      },
    );
    if (mode != GlassMode.off &&
        PlatformCapabilities.hostPlatform != TargetPlatform.iOS) {
      // Android, macOS and Windows keep only the soft scroll edge: a
      // full-width glass slab reads as a stray mask band and smears the
      // large title under it. The back button and actions stay on their own
      // glass.
      return child;
    }
    if (mode == GlassMode.native && PlatformCapabilities.appKitGlass) {
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: AppKitGlassView(
                  kind: 'surface',
                  configuration: {
                    'dark':
                        CupertinoTheme.brightnessOf(context) == Brightness.dark,
                    'followSystemTransparency':
                        !Get.isRegistered<EhSettingService>() ||
                        Get.find<EhSettingService>().liquidGlassMaterial,
                  },
                ),
              ),
            ),
          ),
          // AppKit owns this bar's material; controls must not add another
          // Flutter refraction layer above it.
          GlassPreference(enabled: false, child: child),
        ],
      );
    }
    if (mode == GlassMode.flutter) {
      // A page at rest shows no bar; the glass fades in once content scrolls
      // under it, like the soft edge above.
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                key: const ValueKey<String>('setting-glass-bar-surface'),
                opacity: edgeVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const LiquidGlassSurface(
                  enabled: true,
                  useNativeGlass: false,
                  borderRadius: BorderRadius.zero,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
          child,
        ],
      );
    }
    return child;
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
            // Glass bars stay monochrome like the native ones; buttons
            // otherwise take the accent colour.
            child: CupertinoTheme(
              data: CupertinoTheme.of(context).copyWith(
                primaryColor: ehTheme.palette.text1.resolveFrom(context),
              ),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS 27 split-view detail header card: 24px continuous-corner white card
/// displaying the category's monochrome SVG badge, title, and overview.
class SettingCategoryHeroCard extends StatelessWidget {
  const SettingCategoryHeroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final text1 = palette.text1.resolveFrom(context);
    final text2 = palette.text2.resolveFrom(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surface.resolveFrom(context),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(kInsetGroupedSectionRadius),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xFF262830)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: palette.hairline.resolveFrom(context),
                ),
              ),
              alignment: Alignment.center,
              child: EhSvgIcon(icon, size: 25, color: text1),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inserts a [SettingCategoryHeroCard] at the top of a desktop split-pane
/// settings category page. Single-column mobile pages collapse to empty.
class SliverSettingCategoryHero extends StatelessWidget {
  const SliverSettingCategoryHero({
    super.key,
    required this.route,
    this.forceVisible = false,
  });

  final String route;
  final bool forceVisible;

  @override
  Widget build(BuildContext context) {
    final split = context
        .dependOnInheritedWidgetOfExactType<BrowsePaneScope>()
        ?.split;
    final show =
        forceVisible ||
        isDesktopSettingPaneRoot(ModalRoute.of(context), split: split);
    if (!show) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final l10n = L10n.of(context);
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final (IconData icon, String title, String description) = switch (route) {
      EHRoutes.layoutSetting => (
        CupertinoIcons.square_grid_2x2,
        l10n.appearance_and_layout,
        zh
            ? '管理画廊列表排布密度、浅色/深色/纯黑主题、Liquid Glass 材质质感与标签显示偏好。'
            : 'Customize gallery layout density, Light/Dark/OLED themes, Liquid Glass materials, and tag display preferences.',
      ),
      EHRoutes.readSetting => (
        CupertinoIcons.book,
        l10n.read,
        zh
            ? '自定义阅读翻页方向、双页智能拼接、预加载页数与屏幕控制选项，适配桌面与触控操作。'
            : 'Configure reading direction, double-page spread pairing, preloading, and viewer controls.',
      ),
      EHRoutes.searchSetting => (
        CupertinoIcons.search,
        l10n.search,
        zh
            ? '配置快速搜索条目、常用检索组合与搜索过滤习惯。'
            : 'Manage quick search presets, saved queries, and search filtering shortcuts.',
      ),
      EHRoutes.ehSetting => (
        CupertinoIcons.globe,
        l10n.setting_site,
        zh
            ? '切换 E-Hentai 与 ExHentai 访问站点、同步个人标签组（MyTags）与站点内偏好配置。'
            : 'Switch between E-Hentai and ExHentai, sync MyTags, and manage site preferences.',
      ),
      EHRoutes.downloadSetting => (
        CupertinoIcons.arrow_down_to_line,
        l10n.download,
        zh
            ? '设置本地下载存储目录、并发任务数、原图下载策略与媒体库扫描选项。'
            : 'Configure download directory, concurrent task limits, original image behavior, and storage options.',
      ),
      EHRoutes.securitySetting => (
        CupertinoIcons.shield,
        l10n.security,
        zh
            ? '配置应用启动锁定保护、生物识别验证与隐私防窥选项。'
            : 'Configure auto-lock timeout, biometric authentication, and privacy safeguards.',
      ),
      EHRoutes.advancedSetting => (
        CupertinoIcons.slider_horizontal_3,
        l10n.advanced,
        zh
            ? '调整应用语言、屏蔽规则、网络域名前置与代理、WebDAV 同步及缓存清理。'
            : 'Adjust app language, content blockers, network proxy/DoH, WebDAV sync, and cache storage.',
      ),
      EHRoutes.about => (
        CupertinoIcons.info_circle,
        l10n.about,
        zh
            ? '查看客户端版本构建信息、检查更新与开源组件许可协议。'
            : 'View client version details, check for updates, and inspect open-source licenses.',
      ),
      _ => (
        CupertinoIcons.settings,
        l10n.tab_setting,
        zh ? '自定义应用偏好设置。' : 'Customize application preferences.',
      ),
    };

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      sliver: SliverToBoxAdapter(
        child: SettingCategoryHeroCard(
          icon: icon,
          title: title,
          description: description,
        ),
      ),
    );
  }
}
