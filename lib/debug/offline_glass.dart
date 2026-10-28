import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_fe/adaptive/gallery_anchor.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/controller/gallerycache_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/comm.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/store/hive/hive.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:html/parser.dart' show parse;
import 'package:path/path.dart' as path;

const offlineGlassAcceptanceEnabled =
    offlineAcceptanceEnabled && bool.fromEnvironment('EROS_GLASS_ACCEPTANCE');
final offlineGlassRequests = ValueNotifier<int>(0);
final _requestsByPage = <String, int>{};

Future<void> initializeOfflineGlass() async {
  if (!offlineGlassAcceptanceEnabled) {
    return;
  }
  final user = Global.profile.user;
  if ((user.memberId?.isNotEmpty ?? false) &&
      user.memberId != 'offline-glass') {
    throw StateError('Glass acceptance requires an isolated fixture account');
  }
  final marker = File(path.join(Global.appDocPath, 'offline-glass-seeded'));
  final seeded = await marker.exists();
  Global.profile = Global.profile.copyWith(
    locale: 'zh_CN',
    theme: 'system',
    user: User(
        memberId: 'offline-glass',
        passHash: 'offline-fixture-only',
        nickName: 'Offline',
        username: 'Offline',
        favcat: [
          for (var index = 0; index < 10; index++)
            Favcat(favId: '$index', favTitle: 'Folder $index', totNum: 48),
        ]),
    ehConfig: Global.profile.ehConfig.copyWith(
        listMode: 'list',
        vibrate: false.oN,
        liquidGlass: seeded ? null : false.oN,
        liquidGlassTopBarLayout: seeded ? null : 'twoRow'.oN),
    customTabConfig: seeded
        ? null
        : const CustomTabConfig(lastIndex: 0, profiles: [
            CustomProfile(
                uuid: 'glass-a',
                name: 'Group A',
                searchText: ['offline_glass_a']),
            CustomProfile(
                uuid: 'glass-b',
                name: 'Group B',
                searchText: ['offline_glass_b']),
          ]).oN,
    tabConfig: TabConfig(
        tabItemList: List<TabItem>.of(const [
      TabItem(name: EHRoutes.gallery, enable: true),
      TabItem(name: EHRoutes.favorite, enable: true),
      TabItem(name: EHRoutes.toplist, enable: true),
      TabItem(name: EHRoutes.download, enable: true),
      TabItem(name: EHRoutes.history, enable: false),
    ])).oN,
  );
  await Hive.box<String>(configBox).put(profileKey, jsonEncode(Global.profile));
  await Hive.box<String>(configBox).flush();
  if (!seeded) {
    await marker.writeAsString('Only this isolated acceptance installation');
  }
}

Future<ResponseBody?> offlineGlassResponse(RequestOptions options) async {
  if (options.method != 'GET') {
    return null;
  }
  final route = options.uri.path;
  if (route == '/gallerypopups.php') {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return ResponseBody.fromString(offlineGlassFavoritePopup(), 200);
  }
  final known = ['/', '/popular', '/watched', '/toplist.php', '/favorites.php'];
  if (!known.contains(route)) {
    return null;
  }
  final group = RegExp(r'offline_glass_([ab])')
          .firstMatch('${options.queryParameters['f_search'] ?? ''}')
          ?.group(1) ??
      'a';
  final category = '${options.queryParameters['favcat'] ?? 'a'}';
  final module = route == '/favorites.php'
      ? 'favorite'
      : route == '/toplist.php'
          ? 'toplist'
          : 'gallery';
  final pageId = module == 'favorite'
      ? category
      : module == 'toplist'
          ? 'toplist'
          : 'glass-$group';
  final key = '$module-$pageId';
  _requestsByPage[key] = (_requestsByPage[key] ?? 0) + 1;
  offlineGlassRequests.value++;
  var html = offlineGalleryList(
    page: int.tryParse('${options.queryParameters['page'] ?? 0}') ?? 0,
    titlePrefix: module == 'gallery'
        ? 'Glass ${group.toUpperCase()} gallery'
        : '$module $pageId gallery',
    gidBase: module == 'gallery'
        ? 9500000 + (group == 'b' ? 1000 : 0)
        : module == 'favorite'
            ? 9600000
            : 9700000,
  );
  if (module == 'favorite') {
    html = offlineGlassFavoriteList(html);
  }
  return ResponseBody.fromString(html, 200, headers: {
    Headers.contentTypeHeader: ['text/html; charset=utf-8'],
  });
}

String offlineGlassFavoritePopup() =>
    '<div id="galpop"><div><div class="nosel">'
    '${List.generate(10, (index) => '<div><div><input type="radio" name="favcat" value="$index" '
        '${index == 0 ? 'checked="checked"' : ''}></div><div>icon</div><div>Folder $index</div></div>').join()}'
    '</div><textarea>Offline server note</textarea></div></div>';

String offlineGlassFavoriteList(String html) {
  final folders = List.generate(
          10,
          (index) =>
              '<div><div>48</div><div>icon</div><div>Folder $index</div></div>')
      .join();
  html = html.replaceFirst('<body>',
      '<body><div class="ido"><div class="nosel">$folders</div></div>');
  final document = parse(html);
  for (final cell in document.querySelectorAll('td.gl2c')) {
    // Master reads rating/time from CSS selectors but file counts by child
    // positions. Populate both legacy metadata slots without changing parser code.
    cell.children[1].innerHtml = cell.children.last.innerHtml;
    for (final rating in cell.querySelectorAll('.ir')) {
      rating.innerHtml = '<div></div><div><div></div><div>20 pages</div></div>';
    }
  }
  return document.outerHtml;
}

Widget offlineGlassControl(String name, Widget child) =>
    !offlineAcceptanceEnabled
        ? child
        : Semantics(identifier: 'offline-glass-control-$name', child: child);

List<NativeNavigationAction> offlineDuoRootNavigationActions() {
  if (!offlineGlassAcceptanceEnabled ||
      !const bool.fromEnvironment('EROS_DUO_ACCEPTANCE')) return const [];
  return [
    NativeNavigationAction(
      id: 'offline-root-gallery',
      title: '离线根路由测试',
      symbol: 'arrow.up.forward.app',
      onPressed: () => NavigatorUtil.goGalleryPage(
        forceReplace: true,
        galleryProvider: _offlineRootGallery(),
      ),
    ),
  ];
}

GalleryProvider _offlineRootGallery() {
  const fixture = GalleryProvider(
    gid: '9500001',
    token: '0000000000',
    url: 'https://e-hentai.org/g/9500001/0000000000/',
    englishTitle: 'Offline root replacement fixture',
    filecount: '20',
    category: 'Non-H',
  );
  Get.find<GalleryCacheController>()
      .setGalleryProviderCache(fixture.gid, fixture);
  return fixture;
}

Widget offlineDuoRouteProbe({
  required String id,
  required String Function() label,
  Listenable? listenable,
  required Widget child,
}) {
  if (!offlineGlassAcceptanceEnabled ||
      !const bool.fromEnvironment('EROS_DUO_ACCEPTANCE')) return child;
  Widget probe(Widget? child) => LayoutBuilder(builder: (_, constraints) {
        return Semantics(
          container: true,
          explicitChildNodes: true,
          identifier: 'offline-duo-$id-probe',
          label: '${label()};'
              'width=${constraints.maxWidth};height=${constraints.maxHeight}',
          child: child,
        );
      });
  return listenable == null
      ? probe(child)
      : AnimatedBuilder(
          animation: listenable,
          builder: (_, child) => probe(child),
          child: child);
}

Widget offlineDuoNavigationProbe({required Widget child}) {
  if (!offlineAcceptanceEnabled ||
      !const bool.fromEnvironment('EROS_DUO_ACCEPTANCE')) {
    return child;
  }
  final layout = Get.find<LayoutServices>();
  return AnimatedBuilder(
    animation: layout.tabNavigation,
    child: child,
    builder: (_, child) {
      final stack = layout.tabNavigation.selected;
      final tags = Get.find<ControllerTagService>();
      return Semantics(
        identifier: 'offline-duo-navigation-probe',
        label: 'tab=${stack?.id};'
            'primary=${stack?.primaryObserver.history.lastOrNull?.settings.name};'
            'primaryDepth=${stack?.primaryObserver.history.length};'
            'detail=${stack?.detailObserver.history.lastOrNull?.settings.name};'
            'detailDepth=${stack?.detailObserver.history.length};'
            'gallery=${tags.currGid};search=${tags.snapshot.searchTag};'
            'viewport=${layout.isLayoutLarge ? 'split' : 'single'}',
        child: child,
      );
    },
  );
}

Widget offlineGlassPageProbe(
    {required String route,
    required String Function() page,
    Object? controllerOwner,
    required ScrollController scrollController,
    Iterable<ScrollPosition> Function()? innerPositions,
    required double? Function() firstCardTop,
    required Widget child}) {
  if (!offlineGlassAcceptanceEnabled) {
    return child;
  }
  return OfflineGlassProbe(
      route: route,
      page: page,
      controllerOwner: controllerOwner,
      scrollController: scrollController,
      innerPositions: innerPositions,
      firstCardTop: firstCardTop,
      child: child);
}

/// Observe the actual page's controller, render anchor and HTTP request counts.
/// No replacement navigation or refresh callbacks are installed.
class OfflineGlassProbe extends StatefulWidget {
  const OfflineGlassProbe(
      {super.key,
      required this.route,
      required this.page,
      this.controllerOwner,
      required this.scrollController,
      this.innerPositions,
      required this.firstCardTop,
      required this.child});
  final String route;
  final String Function() page;
  final Object? controllerOwner;
  final ScrollController scrollController;
  final Iterable<ScrollPosition> Function()? innerPositions;
  final double? Function() firstCardTop;
  final Widget child;
  @override
  State<OfflineGlassProbe> createState() => _OfflineGlassProbeState();
}

class _OfflineGlassProbeState extends State<OfflineGlassProbe> {
  bool _scheduled = false;
  bool _active = true;
  String? _label;
  Timer? _sampleTimer;
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_schedule);
    offlineGlassRequests.addListener(_schedule);
    // Sliver layout corrections can change pixels without a scroll event.
    // Sample the settled frame as well as notification-driven updates, only in
    // this offline verifier; inactive cached pages do not request frames.
    _sampleTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_active) {
        // Timer callbacks run between frames. A stable page must remain idle;
        // schedule a render frame only when the observation actually changes.
        _sample();
      }
    });
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cupertino tabs keep inactive pages mounted. Observe their TickerMode
    // so reactivation remeasures the anchor after the Offstage layout changes,
    // even when neither scroll dimensions nor offsets changed.
    _active = TickerMode.valuesOf(context).enabled;
    if (_active) {
      _schedule();
    }
  }

  void _schedule() {
    if (_scheduled || !mounted) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        _sample();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _sample() {
    final next = _measure();
    if (mounted && next != _label) {
      setState(() => _label = next);
    }
  }

  String _measure() {
    final media = MediaQuery.of(context);
    final page = widget.page();
    final top = widget.firstCardTop();
    final pixels = widget.scrollController.positions
        .map((position) => position.pixels.toStringAsFixed(1))
        .join(',');
    final inner = (widget.innerPositions?.call() ?? const <ScrollPosition>[])
        .map((position) => position.pixels.toStringAsFixed(1))
        .join(',');
    final glass = Get.find<EhSettingService>().liquidGlass &&
        LiquidGlassPlatform.isSupported;
    final requests = _requestsByPage['${widget.route}-$page'] ?? 0;
    EhTabController? target;
    GalleryScrollAnchor? anchor;
    var ownership = '';
    if (widget.route == 'gallery' &&
        Get.isRegistered<CustomTabbarController>()) {
      final registered = Get.find<CustomTabbarController>();
      target = registered.currentPageScrollController;
      anchor = registered
          .subControllerMap[registered.currProfileUuid]?.galleryAnchor.anchor;
    } else if (widget.route == 'favorite' &&
        Get.isRegistered<FavoriteTabBarController>()) {
      final registered = Get.find<FavoriteTabBarController>();
      target = registered.currentPageScrollController;
      anchor = registered
          .subControllerMap[
              registered.userController.isLogin ? registered.currFavcat : 'l']
          ?.galleryAnchor
          .anchor;
      final owner = widget.controllerOwner;
      ownership =
          ';ownerMatches=${identical(owner, registered)};registeredPages=${registered.subControllerMap.keys.join(",")};loggedIn=${registered.userController.isLogin}'
          ';ownerPages=${owner is FavoriteTabBarController ? owner.subControllerMap.keys.join(",") : "missing"}';
    } else if (widget.route == 'toplist') {
      target = tabPages.scrollControllerMap[EHRoutes.toplist];
    }
    return 'route=${widget.route};page=$page;glass=$glass;requests=$requests;'
        'first=${top?.toStringAsFixed(1) ?? "offscreen"};outer=$pixels;inner=$inner;'
        'targetLive=${target?.hasScrollClients};targetCallback=${target?.scrollToTopAndRefreshCall != null};'
        'systemTop=${media.viewPadding.top.toStringAsFixed(1)};orientation=${media.orientation.name};'
        'size=${media.size.width}x${media.size.height};'
        'anchor=${anchor?.id ?? "none"};'
        'anchorFraction=${anchor == null ? "none" : (anchor.leading / anchor.extent).toStringAsFixed(3)}$ownership';
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    widget.scrollController.removeListener(_schedule);
    offlineGlassRequests.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            _schedule();
          }
          return false;
        },
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              _schedule();
            }
            return false;
          },
          child: widget.child,
        ),
      ),
      Positioned(
          top: 0,
          left: 0,
          child: Obx(() {
            final page = widget.page();
            final glass = Get.find<EhSettingService>().liquidGlass;
            _schedule();
            final label = _label ??
                'route=${widget.route};page=$page;glass=$glass;first=offscreen';
            return Semantics(
                key: ValueKey(label),
                container: true,
                identifier: 'offline-glass-probe-${widget.route}',
                label: label,
                child: const SizedBox(width: 1, height: 1));
          }))
    ]);
  }
}
