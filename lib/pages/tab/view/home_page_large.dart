import 'dart:math';

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/route_cover.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/route/app_pages.dart';
import 'package:eros_fe/route/eh_observer.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/pages/gallery/controller/taginfo_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'home_page_small.dart';

const kMinWidth = 320.0;

class TabHomeLarge extends StatefulWidget {
  const TabHomeLarge({
    super.key,
    required this.split,
    this.primaryRoot,
    this.destinationBuilder,
  });

  final bool split;
  final Widget? primaryRoot;
  final TabDestinationBuilder? destinationBuilder;

  @override
  State<TabHomeLarge> createState() => _TabHomeLargeState();
}

class _TabHomeLargeState extends State<TabHomeLarge> {
  final LayoutServices _layout = Get.find();
  late final TabNavigationRegistry _navigation;

  @override
  void initState() {
    super.initState();
    _navigation = _layout.mountNavigation(this);
  }

  @override
  Widget build(BuildContext context) {
    final root = widget.primaryRoot;
    if (root == null) {
      return TabHomeSmall(
          split: widget.split, destinationBuilder: widget.destinationBuilder);
    }
    return AdaptiveTabNavigator(
      stack: _navigation.select(EHRoutes.gallery),
      split: widget.split,
      primaryRoot: root,
    );
  }

  @override
  void dispose() {
    _layout.unmountNavigation(this, _navigation);
    super.dispose();
  }
}

/// Each retained destination keeps its own list/search and detail/editor trees.
class AdaptiveTabNavigator extends StatefulWidget {
  const AdaptiveTabNavigator({
    super.key,
    required this.stack,
    required this.split,
    required this.primaryRoot,
  });

  final TabNavigationStack stack;
  final bool split;
  final Widget primaryRoot;

  @override
  State<AdaptiveTabNavigator> createState() => _AdaptiveTabNavigatorState();
}

class _AdaptiveTabNavigatorState extends State<AdaptiveTabNavigator> {
  final LayoutServices _layout = Get.find();
  TabNavigationStack get _stack => widget.stack;
  late final HeroController _primaryHero;
  late final HeroController _detailHero;
  late final Widget _primary;
  late final Widget _detail;

  /// Follows the detail page that slides over the list while the two share
  /// one column.
  final ProxyAnimation _detailCover = ProxyAnimation(kAlwaysDismissedAnimation);

  @override
  void initState() {
    super.initState();
    _primaryHero = HeroController();
    _detailHero = HeroController();
    _primary = HeroControllerScope(
      controller: _primaryHero,
      child: Navigator(
        key: Get.nestedKey(_stack.primaryId),
        observers: [_stack.primaryObserver],
        initialRoute: EHRoutes.home,
        onGenerateInitialRoutes: (_, __) => [_primaryRootRoute()],
        onGenerateRoute: (settings) {
          if (settings.name == EHRoutes.home ||
              settings.name == EHRoutes.root) {
            return _primaryRootRoute();
          }
          return _generateRoute(settings, _stack.primaryObserver);
        },
      ),
    );
    _detail = HeroControllerScope(
      controller: _detailHero,
      child: Navigator(
        key: Get.nestedKey(_stack.detailId),
        observers: [_stack.detailObserver],
        initialRoute: EHRoutes.empty,
        onGenerateInitialRoutes: (_, __) {
          final root = _generateRoute(
              const RouteSettings(name: EHRoutes.empty), _stack.detailObserver);
          _detailCover.parent = _stack.detailObserver.coverOf(root);
          return [root];
        },
        onGenerateRoute: (settings) =>
            _generateRoute(settings, _stack.detailObserver),
      ),
    );
    _detailCover.addStatusListener(_detailCoverChanged);
  }

  /// A detail page is sliding over or off the list. One pushed a moment ago
  /// counts too: it spends its first frame offstage, drawing nothing, while
  /// its animation reads as finished.
  bool get _detailMoving {
    if (_detailCover.isAnimating) return true;
    final cover = _detailCover.parent;
    final route = cover is RouteCoverAnimation ? cover.route : null;
    return route is ModalRoute && route.offstage;
  }

  /// The list stays under a detail page while it slides in or out.
  void _detailCoverChanged(AnimationStatus status) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  Route<dynamic> _primaryRootRoute() => GetPageRoute(
        settings: const RouteSettings(name: EHRoutes.home),
        page: () => CoveredPage(
            observer: _stack.primaryObserver, child: widget.primaryRoot),
        showCupertinoParallax: false,
      );

  Route<dynamic> _generateRoute(
      RouteSettings settings, EhNavigatorObserver observer) {
    final tags = Get.isRegistered<ControllerTagService>()
        ? Get.find<ControllerTagService>().snapshotFor(_stack.id)
        : const ControllerTagSnapshot();
    final route =
        AppPages.routes.firstWhereOrNull((e) => e.name == settings.name);
    if (route == null) return AppPages.onGenerateRoute(settings)!;
    // GetX runs pages for 300 ms and eases them before the Cupertino
    // transition eases them again, so a page lands almost at once. Slides
    // keep the platform's duration and its single curve.
    final slides =
        (route.transition ?? Get.defaultTransition) == Transition.cupertino;
    return GetPageRoute(
      settings: settings,
      page: () => CoveredPage(
        observer: observer,
        child: ControllerTagScope(snapshot: tags, child: route.page()),
      ),
      binding: settings.name == EHRoutes.addTag
          ? BindingsBuilder(() => Get.lazyPut(
              () => TagInfoController(galleryTag: tags.galleryTag),
              tag: tags.galleryTag))
          : route.binding,
      bindings: route.bindings,
      transition: route.transition,
      transitionDuration: slides
          ? CupertinoRouteTransitionMixin.kTransitionDuration
          : route.transitionDuration ?? Get.defaultTransitionDuration,
      curve: slides ? Curves.linear : null,
      showCupertinoParallax: false,
      popGesture: settings.name != EHRoutes.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final environment = AdaptiveEnvironment.maybeOf(context) ??
        AdaptiveEnvironmentSnapshot.fromMediaQuery(context);
    return Obx(() {
      final proportion = _layout.sideProportion;
      return AnimatedBuilder(
        animation: Listenable.merge(
            [_stack.primaryObserver.revision, _stack.detailObserver.revision]),
        builder: (context, _) {
          final split = widget.split && environment.isSplit;
          final moving = !split && _detailMoving;
          // A page opened in the list column puts the list back on top while
          // the detail page still sits where it covered the list; it covers
          // nothing once it no longer shows.
          final cover =
              split || !(_stack.detailOnTop || moving) ? null : _detailCover;
          return TabNavigationScope(
            stack: _stack,
            child: AdaptiveBrowseLayout(
              environment: environment,
              split: split,
              sideProportion: proportion,
              detailActive: _stack.detailOnTop,
              detailMoving: moving,
              primary: RouteCoverClip(
                cover: cover,
                child: CoveredInsets(cover: cover, child: _primary),
              ),
              detail: _detail,
              divider: const SideControllerbar(child: SizedBox(width: 28)),
            ),
          );
        },
      );
    });
  }

  @override
  void dispose() {
    _detailCover.removeStatusListener(_detailCoverChanged);
    _stack.reset();
    _primaryHero.dispose();
    _detailHero.dispose();
    super.dispose();
  }
}

class SideControllerbar extends StatefulWidget {
  const SideControllerbar({Key? key, required this.child}) : super(key: key);
  final Widget child;

  @override
  _SideControllerbarState createState() => _SideControllerbarState();
}

class _SideControllerbarState extends State<SideControllerbar> {
  bool isTapDown = false;
  final LayoutServices layoutServices = Get.find();

  Widget _normalBar({bool dragging = false}) {
    return AnimatedContainer(
      decoration: BoxDecoration(
        color:
            CupertinoDynamicColor.resolve(CupertinoColors.systemGrey, context)
                .withOpacity(0.7),
        borderRadius: BorderRadius.circular(dragging ? 5.0 : 1.5),
      ),
      margin: EdgeInsets.only(
          left: dragging ? 5.0 : 2.0, right: dragging ? 5.0 : 20.0),
      height: dragging ? 80 : 55,
      width: dragging ? 10 : 3,
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
      child: const SizedBox.expand(),
    );
  }

  Widget getbar() {
    return _normalBar(dragging: isTapDown);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        widget.child,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) {
            setState(() {
              isTapDown = true;
            });
          },
          onPanEnd: (_) {
            setState(() {
              isTapDown = false;
            });
          },
          onPanCancel: () {
            setState(() {
              isTapDown = false;
            });
          },
          onPanUpdate: (details) {
            final available =
                max(1.0, MediaQuery.sizeOf(context).width - 2 * kMinWidth);
            final proportion =
                layoutServices.sideProportion + details.delta.dx / available;

            layoutServices.sideProportion = max(min(1.0, proportion), 0.0);
          },
          child: getbar(),
        ),
      ],
    );
  }
}
