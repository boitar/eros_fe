import 'dart:math' as math;

import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/debug/offline_glass.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/pages/gallery/comm.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/view/const.dart';
import 'package:eros_fe/pages/gallery/view/gallery_widget.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_hero.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_more_actions.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_page_sliver.dart';
import 'package:eros_fe/pages/gallery/view/thumb_box.dart';
import 'package:eros_fe/utils/gallery_title.dart';
import 'package:eros_fe/utils/share_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'slivers.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late final GalleryPageController _controller;
  late final String _tag;
  ScrollController? _pageScrollController;

  /// Drives the ambient backdrop's parallax without rebuilding the page.
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);
  final ValueNotifier<double> _sideOffset = ValueNotifier<double>(0);

  GalleryPageState get pageState => _controller.gState;
  bool get _isRoot => ModalRoute.of(context)?.isFirst == true;

  @override
  void initState() {
    super.initState();
    _tag = pageCtrlTagOf(context);
    // _controller = Get.put(GalleryPageController(), tag: _tag);
    Get.lazyPut<GalleryPageController>(
      () => GalleryPageController(controllerTag: _tag),
      tag: _tag,
      fenix: true,
    );
    _controller = Get.find(tag: _tag);
    initPageController(tag: _tag);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final next = PrimaryScrollController.of(context);
    if (!identical(_pageScrollController, next)) {
      _pageScrollController?.removeListener(_controller.scrollControllerLister);
      _pageScrollController = next;
      _controller.scrollController = next;
      next.addListener(_controller.scrollControllerLister);
    }
  }

  @override
  void dispose() {
    _pageScrollController?.removeListener(_controller.scrollControllerLister);
    _scrollOffset.dispose();
    _sideOffset.dispose();
    deletePageController(tag: _tag);
    super.dispose();
  }

  Future<void> _shareGallery() async {
    final provider = pageState.galleryProvider;
    final gid = provider?.gid;
    final token = provider?.token;
    if (gid == null || gid.isEmpty || token == null || token.isEmpty) {
      showToast('Gallery link is unavailable');
      return;
    }
    await ShareService.shareText('${Api.getBaseUrl()}/g/$gid/$token',
        context: context);
  }

  /// Follows the layout: a pinned header keeps the bar from taking over the
  /// title, and leaving two columns re-reads the scroll position.
  void _pinHero(bool pinned) {
    if (pageState.heroPinned == pinned) {
      return;
    }
    pageState.heroPinned = pinned;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (pinned) {
        pageState.hideNavigationBtn = true;
      } else {
        _controller.scrollControllerLister();
      }
    });
  }

  /// Pulling past the end opens every thumbnail, as before.
  Widget _refreshable(Widget scrollView) {
    return SizeCacheWidget(
      child: EasyRefresh(
        enableControlFinishRefresh: false,
        enableControlFinishLoad: false,
        onLoad: () async {
          if (pageState.images.isNotEmpty) {
            Get.toNamed(
              EHRoutes.galleryAllThumbnails,
              id: detailNavigatorId,
            );
          }
        },
        footer: BezierBounceFooter(
          backgroundColor: Colors.transparent,
          color: CupertinoColors.inactiveGray,
        ),
        child: scrollView,
      ),
    );
  }

  /// Reports vertical scroll offsets of the scroll view directly inside.
  Widget _trackScroll(ValueNotifier<double> offset, Widget child) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical) {
          offset.value = notification.metrics.pixels;
        }
        return false;
      },
      child: child,
    );
  }

  /// The backdrop runs under the bar, through the cover, and has faded to
  /// the canvas by the time the title starts.
  Widget _backdrop(double topInset, ValueListenable<double> offset) {
    return GetBuilder<GalleryPageController>(
      tag: _tag,
      id: GetIds.PAGE_VIEW_HEADER,
      builder: (logic) {
        final provider = logic.gState.galleryProvider;
        final cover = heroCoverSize(
            heroCoverSource(logic.gState.galleryRepository?.item, provider));
        return GalleryAmbientBackdrop(
          imageUrl: provider?.imgUrl ?? '',
          category: provider?.category,
          height: topInset + 8 + cover.height + 48,
          scrollOffset: offset,
        );
      },
    );
  }

  Widget _singleColumn(BuildContext context,
      {required bool native, required double topInset}) {
    // Outside EasyRefresh: it rebuilds its own scroll view from a ScrollView
    // child and would not accept a wrapper.
    final body = _trackScroll(
      _scrollOffset,
      _refreshable(CustomScrollView(
        cacheExtent: 1000,
        controller: GetPlatform.isDesktop ? _controller.scrollController : null,
        slivers: [
          if (native)
            // UIKit owns the bar, but this custom sliver view still owns its
            // scroll insets. Consume the live top inset once, including after
            // the Duo bar moves from the side to the top.
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).top),
            )
          else
            GalleryNavigationBar(controller: _controller),
          EhCupertinoSliverRefreshControl(onRefresh: _controller.handOnRefresh),
          GalleryHeadTile(controller: _controller),
          GalleryBody(controller: _controller),
        ],
      )),
    );
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _backdrop(topInset, _scrollOffset),
        ),
        Positioned.fill(child: body),
      ],
    );
  }

  /// The header sits in a fixed column with its own backdrop; tags,
  /// thumbnails and comments scroll beside it. On an unfolded Duo the
  /// columns meet at the fold.
  Widget _twoColumns(BuildContext context, GalleryDetailColumns columns,
      {required double topInset}) {
    final dynamic tabTag = pageState.galleryRepository?.tabTag;
    Widget hero() {
      if (pageState.fromUrl) {
        return _controller.obx(
          (state) => state == null
              ? const SizedBox.shrink()
              : GalleryHero(initGalleryProvider: state, tabTag: tabTag),
          onLoading: const SizedBox.shrink(),
          onError: (_) => const SizedBox.shrink(),
        );
      }
      final provider = pageState.galleryProvider;
      return provider == null
          ? const SizedBox.shrink()
          : GalleryHero(initGalleryProvider: provider, tabTag: tabTag);
    }

    final side = Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _backdrop(topInset, _sideOffset),
        ),
        Positioned.fill(
          child: _trackScroll(
            _sideOffset,
            SingleChildScrollView(
              // The content column owns the primary scroll controller.
              primary: false,
              padding: EdgeInsets.only(
                top: topInset,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
              ),
              child: hero(),
            ),
          ),
        ),
      ],
    );

    final content = _refreshable(CustomScrollView(
      cacheExtent: 1000,
      controller: GetPlatform.isDesktop ? _controller.scrollController : null,
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topInset)),
        EhCupertinoSliverRefreshControl(onRefresh: _controller.handOnRefresh),
        GalleryBody(controller: _controller),
      ],
    ));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: columns.leading, child: side),
        if (columns.gap > 0)
          SizedBox(width: columns.gap)
        else
          Container(
            width: 0.5,
            color: CupertinoDynamicColor.resolve(EhPalette.separator, context),
          ),
        Expanded(child: content),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final native = NativeNavigationScope.isEnabled(context);
    final topInset = MediaQuery.paddingOf(context).top + (native ? 0 : 96);

    final Widget body = LayoutBuilder(builder: (context, constraints) {
      // Two columns need the native bar: the Flutter bar lives inside the
      // single scroll view.
      final columns = native
          ? GalleryDetailColumns.resolve(
              width: constraints.maxWidth,
              environment: AdaptiveEnvironment.maybeOf(context),
              split: BrowsePaneScope.isSplit(context),
            )
          : null;
      _pinHero(columns != null);
      return columns == null
          ? _singleColumn(context, native: native, topInset: topInset)
          : _twoColumns(context, columns, topInset: topInset);
    });

    return GetBuilder<GalleryPageController>(
      tag: _tag,
      id: GetIds.PAGE_VIEW_HEADER,
      builder: (logic) => Obx(() => NativeNavigationPage(
            chrome: NativePageChrome(
              title: GalleryTitleParts.parse(pageState.displayTitle).title,
              // The hero shows the title; the bar takes it, and the Read
              // action, once the hero has scrolled away.
              titleVisible: !pageState.hideNavigationBtn,
              actions: [
                if (!pageState.hideNavigationBtn)
                  NativeNavigationAction(
                    id: 'read',
                    title: L10n.of(context).read,
                    symbol: 'book',
                    enabled: pageState.enableRead,
                    onPressed: () => NavigatorUtil.goGalleryViewPage(
                        pageState.lastIndex, pageState.gid,
                        galleryTag: _tag),
                  ),
                NativeNavigationAction(
                  id: 'share',
                  title: L10n.of(context).share,
                  symbol: 'square.and.arrow.up',
                  onPressed: _shareGallery,
                ),
                NativeNavigationAction(
                  id: 'gallery.more',
                  title: L10n.of(context).more_actions,
                  symbol: 'ellipsis.circle',
                  children: [
                    for (final action in galleryMoreActions(
                        context, _controller,
                        isRoot: _isRoot))
                      action.toNative(),
                  ],
                ),
              ],
            ),
            child: offlineDuoRouteProbe(
              id: 'gallery',
              label: () => 'gallery=${pageState.gid};tag=$_tag;'
                  'scope=${pageCtrlTagOf(context)};root=$_isRoot',
              child: CupertinoPageScaffold(child: body),
            ),
          )),
    );
  }
}

class GalleryNavigationBar extends StatelessWidget {
  const GalleryNavigationBar({
    super.key,
    required this.controller,
  });
  final GalleryPageController controller;

  GalleryPageState get pageState => controller.gState;

  @override
  Widget build(BuildContext context) {
    final GalleryProvider? provider = pageState.galleryProvider;
    return CupertinoSliverNavigationBar(
      leading: ModalRoute.of(context)?.isFirst == true
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Get.offNamed<void>(EHRoutes.home),
              child: Semantics(
                label: L10n.of(context).tab_gallery,
                child: const Icon(CupertinoIcons.house),
              ),
            )
          : null,
      padding: const EdgeInsetsDirectional.only(end: 10),
      largeTitle: SelectionArea(
        child: GetBuilder<GalleryPageController>(
          id: GetIds.PAGE_VIEW_HEADER,
          tag: controller.controllerTag,
          builder: (logic) {
            return Text(
              logic.gState.subTitle,
              textAlign: TextAlign.start,
              maxLines: 3,
              // minLines: 1,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                color: CupertinoDynamicColor.resolve(
                    CupertinoColors.secondaryLabel, context),
                fontWeight: FontWeight.normal,
                fontStyle: FontStyle.italic,
              ),
            );
          },
        ),
      ),
      middle: Obx(
        () {
          Widget coverOpacity = AnimatedOpacity(
            opacity: pageState.hideNavigationBtn ? 0.0 : 1.0,
            duration: 300.milliseconds,
            curve: Curves.ease,
            child: GetBuilder<GalleryPageController>(
              id: GetIds.PAGE_VIEW_HEADER,
              tag: controller.controllerTag,
              builder: (logic) {
                return NavigationBarImage(
                  imageUrl: logic.gState.galleryProvider?.imgUrl ?? '',
                  scrollController: logic.scrollController,
                );
              },
            ),
          );

          return coverOpacity;
        },
      ),
      trailing: Obx(() {
        bool isRefresh = false;
        Widget buttons = Row(
          key: const ValueKey('buttons'),
          mainAxisSize: MainAxisSize.min,
          children: [
            // Refresh button
            if (GetPlatform.isDesktop)
              StatefulBuilder(builder: (context, setState) {
                return CupertinoButton(
                  padding: const EdgeInsets.all(0),
                  minSize: 40,
                  child: isRefresh
                      ? const CupertinoActivityIndicator(
                          radius: 12,
                        )
                      : const MouseRegionClick(
                          child: Icon(
                            CupertinoIcons.arrow_clockwise,
                            size: 24,
                          ),
                        ),
                  onPressed: () async {
                    setState(() {
                      isRefresh = true;
                    });
                    try {
                      await controller.handOnRefresh();
                    } finally {
                      setState(() {
                        isRefresh = false;
                      });
                    }
                  },
                );
              }),

            CupertinoButton(
              padding: const EdgeInsets.all(0),
              minimumSize: const Size(38, 38),
              child: MouseRegionClick(
                child: Semantics(
                  label: L10n.of(context).more_actions,
                  child: const Icon(CupertinoIcons.ellipsis_circle, size: 26),
                ),
              ),
              onPressed: () => showGalleryMoreSheet(context, controller,
                  isRoot: ModalRoute.of(context)?.isFirst == true),
            ),
            Builder(
              builder: (buttonContext) {
                return CupertinoButton(
                  padding: const EdgeInsets.only(bottom: 4),
                  minSize: 38,
                  child: const MouseRegionClick(
                    child: Icon(CupertinoIcons.share, size: 26),
                  ),
                  onPressed: () async {
                    // Read the state at tap time. The navigation bar itself
                    // can outlive the initial loading state.
                    final currentProvider = controller.gState.galleryProvider;
                    if (currentProvider == null) {
                      showToast('Gallery is not ready');
                      return;
                    }
                    final gid = currentProvider.gid;
                    final token = currentProvider.token;
                    if (gid == null ||
                        gid.isEmpty ||
                        token == null ||
                        token.isEmpty) {
                      showToast('Gallery link is unavailable');
                      return;
                    }
                    final String url = '${Api.getBaseUrl()}/g/$gid/$token';
                    logger.d('share gallery gid=$gid');
                    await ShareService.shareText(
                      url,
                      context: buttonContext,
                    );
                  },
                );
              },
            ),
          ],
        );

        Widget gt = GalleryTrailing(
          firstChild: buttons,
          secondChild: Row(
            key: const ValueKey('ReadButton'),
            mainAxisSize: MainAxisSize.min,
            children: [
              ReadButton(gid: provider?.gid ?? '0').paddingOnly(right: 4),
            ],
          ),
          crossFadeState: pageState.hideNavigationBtn
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: 300.milliseconds,
        );

        return gt;
      }),
    );
  }
}

class GalleryHeadTile extends StatelessWidget {
  const GalleryHeadTile({Key? key, required this.controller}) : super(key: key);

  final GalleryPageController controller;

  GalleryPageState get pageState => controller.gState;

  @override
  Widget build(BuildContext context) {
    final GalleryProvider? provider = pageState.galleryProvider;
    final dynamic tabTag = pageState.galleryRepository?.tabTag;
    return MultiSliver(children: [
      if (pageState.fromUrl)
        GallerySliverSafeArea(
          child: GalleryObxSliver(
            (state) => GalleryHeroSliver(
              initGalleryProvider: state,
              tabTag: tabTag,
            ),
            pageController: controller,
          ),
        )
      else if (provider != null)
        GallerySliverSafeArea(
          child: GalleryHeroSliver(
            initGalleryProvider: provider,
            tabTag: tabTag,
          ),
        ),
    ]);
  }
}

class GalleryBody extends StatelessWidget {
  const GalleryBody({super.key, required this.controller});

  final GalleryPageController controller;

  EhSettingService get _ehSettingService => Get.find();

  GalleryPageState get pageState => controller.gState;

  @override
  Widget build(BuildContext context) {
    return GalleryObxSliver(
      (GalleryProvider state) {
        return GallerySliverSafeArea(
          child: MultiSliver(children: [
            if (_ehSettingService.showGalleryTags)
              TagTile(provider: state, pageController: controller),
            ChapterTile(controller: controller, provider: state),
            if (_ehSettingService.showComments)
              CommentTile(controller: controller, provider: state),
            if (!_ehSettingService.hideGalleryThumbnails)
              ThumbTile(
                controller: controller,
                provider: state,
                horizontal: _ehSettingService.horizontalThumbnails,
              )
            else
              const MorePreviewButton(hasMorePreview: true),
          ]),
        );
      },
      showLoading: true,
      pageController: controller,
    );
  }
}

class TagTile extends StatelessWidget {
  const TagTile({super.key, required this.provider, this.pageController});
  final GalleryProvider provider;
  final GalleryPageController? pageController;

  EhSettingService get _ehSettingService => Get.find();

  @override
  Widget build(BuildContext context) {
    final groups = provider.tagGroup ?? [];
    return Obx(() {
      final labelWidth = tagNamespaceColumnWidth(context, groups,
          translate: _ehSettingService.isTagTranslate);
      return MultiSliver(children: [
        MiniTitle(title: L10n.of(context).tags),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: kPadding + 4),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => TagGroupItem(
                tagGroupData: groups[index],
                labelWidth: labelWidth,
              ),
              childCount: groups.length,
            ),
          ),
        ),
        if (pageController != null)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                kPadding + 4 + labelWidth + 10, 6, kPadding + 4, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AddTagChip(onPressed: pageController!.addTag),
            ),
          ),
      ]);
    });
  }
}

class ChapterTile extends StatelessWidget {
  const ChapterTile({
    super.key,
    required this.provider,
    required this.controller,
  });

  final GalleryProvider provider;
  final GalleryPageController controller;

  @override
  Widget build(BuildContext context) {
    return MultiSliver(children: [
      if (provider.chapter?.isNotEmpty ?? false)
        MiniTitle(title: L10n.of(context).chapter),
      Container(
        padding: EdgeInsets.only(
            bottom: (provider.chapter?.isNotEmpty ?? false) ? 20 : 0),
        child: ChapterGridView(
          controller: controller,
          chapter: provider.chapter,
          maxLine: 3,
        ),
      ),
    ]);
  }
}

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.provider,
    required this.controller,
  });
  final GalleryProvider provider;
  final GalleryPageController controller;

  void _openComments() =>
      Get.toNamed(EHRoutes.galleryComment, id: detailNavigatorId);

  @override
  Widget build(BuildContext context) {
    final comments = controller.gState.comments;
    return MultiSliver(children: [
      Obx(() => MiniTitle(
            title: L10n.of(context).gallery_comments,
            count: comments.isEmpty
                ? null
                : L10n.of(context).comment_count(comments.length),
            onTap: _openComments,
          )),
      Padding(
        padding: const EdgeInsets.fromLTRB(kPadding + 4, 0, kPadding + 4, 8),
        child: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: _openComments,
          child: Obx(() {
            if (comments.isEmpty) {
              return const SizedBox.shrink();
            }
            return DecoratedBox(
              decoration: ShapeDecoration(
                color: CupertinoDynamicColor.resolve(
                    ehTheme.palette.surface, context),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TopCommentEx(
                  key: ValueKey(comments.map((e) => e.id).join('')),
                  comments: comments,
                  uploader: controller.gState.galleryProvider?.uploader,
                  max: 3,
                  grouped: true,
                ),
              ),
            );
          }),
        ),
      ),
    ]);
  }
}

class ThumbTile extends StatelessWidget {
  const ThumbTile({
    super.key,
    required this.provider,
    required this.controller,
    this.horizontal = false,
  });
  final GalleryProvider provider;
  final GalleryPageController controller;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final pageState = controller.gState;

    if (horizontal) {
      return MultiSliver(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Get.toNamed(
                EHRoutes.galleryAllThumbnails,
                id: detailNavigatorId,
              );
            },
            child: Row(
              children: [
                MiniTitle(title: L10n.of(context).thumbnails),
                const Spacer(),
              ],
            ),
          ),
          ThumbHorizontalList(
            images: pageState.firstPageImage,
            gid: provider.gid ?? '',
            referer: controller.gState.url,
          ),
        ],
      );
    } else {
      // The first rows only; "See All" and pulling past the end open every
      // thumbnail.
      return MultiSliver(children: [
        MiniTitle(
          title: L10n.of(context).thumbnails,
          count: L10n.of(context).page_count(pageState.filecount),
          onTap: () => Get.toNamed(
            EHRoutes.galleryAllThumbnails,
            id: detailNavigatorId,
          ),
        ),
        LayoutBuilder(builder: (context, constraints) {
          const gap = 8.0;
          const inset = kPadding + 4;
          final width = constraints.maxWidth - inset * 2;
          final columns = math.max(3, ((width + gap) / (120 + gap)).floor());
          final rows = math.max(2, (9 / columns).ceil());
          final images = pageState.firstPageImage;
          final shown = math.min(images.length, columns * rows);
          final cell = (width - gap * (columns - 1)) / columns;
          return Padding(
            padding: const EdgeInsets.fromLTRB(inset, 0, inset, 28),
            child: Wrap(
              spacing: gap,
              runSpacing: 12,
              children: [
                for (var index = 0; index < shown; index++)
                  SizedBox(
                    width: cell,
                    height: cell * 1.42 + 22,
                    child: ThumbBox(
                      galleryImageList: images,
                      index: index,
                      gid: provider.gid ?? '',
                      referer: controller.gState.url,
                    ),
                  ),
              ],
            ),
          );
        }),
      ]);
    }
  }
}
