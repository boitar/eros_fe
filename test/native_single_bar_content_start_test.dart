// These doubles skip controller startup work so the fixtures stay offline.
// ignore_for_file: must_call_super

import 'package:eros_fe/adaptive/native_single_bar_edge.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/block_controller.dart';
import 'package:eros_fe/common/controller/cache_controller.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/controller/history_controller.dart';
import 'package:eros_fe/common/controller/image_block_controller.dart';
import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/controller/all_thumbnails_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_fav_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/gallery_repository.dart';
import 'package:eros_fe/pages/gallery/view/all_thumbnails_page.dart';
import 'package:eros_fe/pages/gallery/view/gallery_info_page.dart';
import 'package:eros_fe/pages/gallery/view/sliver/gallery_page.dart';
import 'package:eros_fe/pages/setting/controller/eh_mytags_controller.dart';
import 'package:eros_fe/pages/setting/mytags/eh_usertag_page.dart';
import 'package:eros_fe/pages/tab/controller/history_view_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:eros_fe/pages/tab/view/history_page.dart';
import 'package:eros_fe/widget/scroll_edge_effect.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/waterfall_fixture.dart';

const _size = Size(402, 874);
const _inset = 50.0;

const _gallery = GalleryProvider(
  gid: 'neutral-gallery',
  token: 'token',
  url: '/g/neutral-gallery/token',
  englishTitle: 'Neutral gallery',
  category: 'Non-H',
  filecount: '3',
  imgWidth: 200,
  imgHeight: 280,
);

const _images = <GalleryImage>[
  GalleryImage(ser: 1, href: '/s/1', thumbWidth: 200, thumbHeight: 280),
  GalleryImage(ser: 2, href: '/s/2', thumbWidth: 200, thumbHeight: 280),
  GalleryImage(ser: 3, href: '/s/3', thumbWidth: 200, thumbHeight: 280),
];

class _History extends HistoryController {
  @override
  void onInit() {}

  @override
  bool get historiesInitialized => true;

  @override
  List<GalleryProvider> get histories => <GalleryProvider>[_gallery];
}

class _Blocks extends BlockController {
  @override
  void onInit() {}
}

class _HistoryView extends GetxController implements HistoryViewController {
  @override
  String? heroTag = 'history';

  @override
  final sliverAnimatedListKey = GlobalKey<SliverAnimatedListState>();

  @override
  Widget? getLeading(BuildContext context) => const SizedBox.shrink();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tabs extends TabHomeController {
  @override
  void onInit() {}

  @override
  List<NativeNavigationAction> get nativeHiddenTabActions =>
      const <NativeNavigationAction>[];
}

class _GalleryState extends Fake implements GalleryPageState {
  final RxList<GalleryImage> _imageList = _images.obs;

  @override
  GalleryProvider? get galleryProvider => _gallery;

  @override
  String get gid => _gallery.gid!;

  @override
  int get filecount => int.parse(_gallery.filecount!);

  @override
  RxList<GalleryImage> get images => _imageList;

  @override
  Map<int, GalleryImage> get imageMap => <int, GalleryImage>{
    for (final image in _images) image.ser: image,
  };

  @override
  List<GalleryImage> get imagesFromMap => _images;

  @override
  List<GalleryImage> get firstPageImage => _images;

  @override
  int get currentImagePage => 0;

  @override
  set currentImagePage(int value) {}
}

class _GalleryPageController extends GetxController
    implements GalleryPageController {
  @override
  final GalleryPageState gState = _GalleryState();

  @override
  GalleryImage? uptImageBySer({
    required int ser,
    required ImageCallback imageCallback,
  }) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProductionGalleryController extends GetxController
    with StateMixin<GalleryProvider>
    implements GalleryPageController {
  _ProductionGalleryController(this.gState);

  @override
  final GalleryPageState gState;

  @override
  ScrollController? scrollController;

  @override
  void onInit() {
    super.onInit();
    change(gState.galleryProvider, status: RxStatus.success());
  }

  @override
  void scrollControllerLister() {}

  @override
  Future<void> handOnRefresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache extends GetxController implements CacheController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Downloads extends DownloadController {
  @override
  void onInit() {}
}

class _Layout extends LayoutServices {
  @override
  void onInit() {}
}

class _GalleryFavorites extends GalleryFavController {
  _GalleryFavorites() : super(galleryTag: 'native-test');

  @override
  void onInit() {}

  @override
  bool get isFav => false;

  @override
  bool get isLoading => false;
}

class _TagTranslations extends GetxController implements TagTransController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UserTags extends EhMyTagsController {
  @override
  void onInit() {}

  @override
  Future<EhMytags?> loadData({bool refresh = false}) async => ehMyTags;
}

class _ImageBlockController extends GetxController
    implements ImageBlockController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _setPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _size;
}

Widget _host(Widget child) => GetCupertinoApp(
  locale: const Locale('en'),
  supportedLocales: L10n.delegate.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    L10n.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  home: MediaQuery(
    data: const MediaQueryData(
      size: _size,
      padding: EdgeInsets.only(top: _inset),
      viewPadding: EdgeInsets.only(top: _inset),
    ),
    child: NativeNavigationScope(
      child: ControllerTagScope(
        snapshot: const ControllerTagSnapshot(galleryTag: 'native-test'),
        child: child,
      ),
    ),
  ),
);

void main() {
  setUp(() {
    registerWaterfallFixture();
    NativeNavigationBridge.enabled.value = true;
    Get.delete<BlockController>();
    Get.put<BlockController>(_Blocks());
  });

  tearDown(() {
    NativeNavigationBridge.enabled.value = false;
    PlatformCapabilities.debugHostPlatformOverride = null;
    Get.reset();
  });

  Future<void> prepareProductionGallery(WidgetTester tester) async {
    Get.put<LayoutServices>(_Layout());
    Get.put<CacheController>(_Cache());
    Get.put<DownloadController>(_Downloads());
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
    NativeNavigationBridge.enabled.value = true;
    await tester.pumpWidget(
      GetCupertinoApp(
        locale: const Locale('en'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: NativeNavigationScope(child: const SizedBox.expand()),
      ),
    );
    Get.put<GalleryFavController>(_GalleryFavorites(), tag: 'native-test');
  }

  Widget productionGalleryHost({
    required Size size,
    required Size windowSize,
    Widget page = const GalleryPage(),
    bool pageOwnsScaffold = false,
  }) {
    const inset = 50.0;
    final provider = GalleryProvider(
      gid: '600001',
      token: 'neutral',
      url: '/g/600001/neutral',
      englishTitle: 'Non-H neutral gallery with a long title',
      category: 'Non-H',
      filecount: '80',
      imgWidth: 200,
      imgHeight: 280,
      tagGroup: List<TagGroup>.generate(
        48,
        (index) => TagGroup(
          tagType: 'language',
          galleryTags: <GalleryTag>[
            GalleryTag(
              title: 'neutral tag $index',
              type: 'language',
              tagTranslat: 'neutral tag $index',
            ),
          ],
        ),
      ),
    );
    final repository = GalleryRepository(item: provider, tabTag: 'native-test');
    final state = GalleryPageState()
      ..galleryProvider = provider
      ..galleryRepository = repository;
    Get.put<GalleryRepository>(repository, tag: 'native-test');
    Get.put<GalleryPageController>(
      _ProductionGalleryController(state),
      tag: 'native-test',
    );
    return GetCupertinoApp(
      locale: const Locale('en'),
      supportedLocales: L10n.delegate.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        L10n.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(top: inset),
          viewPadding: const EdgeInsets.only(top: inset),
        ),
        child: AdaptiveEnvironmentScope(
          snapshot: AdaptiveEnvironmentSnapshot(
            size: size,
            windowSize: windowSize,
          ),
          child: NativeNavigationScope(
            child: ControllerTagScope(
              snapshot: const ControllerTagSnapshot(galleryTag: 'native-test'),
              child: pageOwnsScaffold
                  ? page
                  : CupertinoPageScaffold(child: page),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('History first row starts below the native bar gap', (
    tester,
  ) async {
    _setPhone(tester);
    Get.delete<HistoryController>();
    Get.put<HistoryController>(_History());
    Get.delete<TabHomeController>();
    Get.put<TabHomeController>(_Tabs());
    Get.put<HistoryViewController>(_HistoryView());
    Get.find<EhSettingService>().listMode.value = ListModeEnum.simpleList;

    await tester.pumpWidget(_host(const HistoryTab()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    final first = tester.getRect(
      find.byKey(
        const ValueKey<String>('history-first-card'),
        skipOffstage: false,
      ),
    );
    expect(
      first.top,
      _inset +
          NativeTopTabHeader.contentGapFor(
            tester.element(find.byType(NativeSingleBarEdge)),
          ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('all thumbnails first grid row starts below the native gap', (
    tester,
  ) async {
    _setPhone(tester);
    Get.find<EhSettingService>().horizontalThumbnails = true;
    Get.put<GalleryPageController>(
      _GalleryPageController(),
      tag: 'native-test',
    );
    Get.put<ImageBlockController>(_ImageBlockController());

    await tester.pumpWidget(_host(const AllThumbnailsPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final thumbnails = Get.find<AllThumbnailsPageController>(
      tag: 'native-test',
    );
    expect(
      tester.getTopLeft(find.byKey(thumbnails.globalKey)).dy,
      _inset +
          NativeTopTabHeader.contentGapFor(
            tester.element(find.byType(NativeSingleBarEdge)),
          ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('my tags measures its native search row before showing rows', (
    tester,
  ) async {
    _setPhone(tester);
    Get.put<TagTransController>(_TagTranslations());
    final controller = Get.put<EhMyTagsController>(_UserTags());
    controller.currSelected = 'non-h-set';
    controller.ehMyTags = const EhMytags(
      tagsets: <EhMytagSet>[EhMytagSet(name: 'Non-H tags', value: 'non-h-set')],
      usertags: <EhUsertag>[
        EhUsertag(title: 'Non-H neutral tag', tagWeight: '10'),
      ],
    );

    await tester.pumpWidget(_host(const EhUserTagsPage()));
    await tester.pumpAndSettle();

    final gap = NativeTopTabHeader.contentGapFor(
      tester.element(find.byType(NativeSingleBarEdge)),
    );
    final section = tester.widget<SliverCupertinoListSection>(
      find.byType(SliverCupertinoListSection).first,
    );
    final sectionTop = section.margin.resolve(TextDirection.ltr).top;
    final firstRow = find.byKey(const ValueKey('Non-H neutral tag'));
    expect(tester.getTopLeft(firstRow).dy, _inset + sectionTop);
    expect(sectionTop, greaterThanOrEqualTo(gap));

    final route = ModalRoute.of(tester.element(find.byType(EhUserTagsPage)))!;
    final chrome = NativeNavigationBridge.chromeFor(route)!;
    chrome.actions
        .singleWhere((action) => action.id == 'userTags.search')
        .onPressed!();
    await tester.pump();

    expect(
      tester
          .widget<Offstage>(
            find.byKey(const ValueKey('userTags.searchResultsVisibility')),
          )
          .offstage,
      isTrue,
    );
    expect(
      tester
          .widget<SoftScrollEdgeEffect>(find.byType(SoftScrollEdgeEffect))
          .bars,
      0,
    );

    await tester.pump();
    expect(
      tester
          .widget<Offstage>(
            find.byKey(const ValueKey('userTags.searchResultsVisibility')),
          )
          .offstage,
      isFalse,
    );
    final measuredEffect = tester.widget<SoftScrollEdgeEffect>(
      find.byType(SoftScrollEdgeEffect),
    );
    expect(measuredEffect.bars, greaterThan(0));
    expect(
      tester.getTopLeft(firstRow).dy,
      _inset + measuredEffect.bars + sectionTop,
    );
    expect(sectionTop, greaterThanOrEqualTo(gap));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('gallery single and split columns align each first item', (
    tester,
  ) async {
    _setPhone(tester);
    final leadingScroll = ScrollController();
    final trailingScroll = ScrollController();
    addTearDown(leadingScroll.dispose);
    addTearDown(trailingScroll.dispose);
    final leading = GlobalKey();
    final trailing = GlobalKey();

    Widget column(ScrollController scroll, Key first) => NativeSingleBarEdge(
      child: CustomScrollView(
        controller: scroll,
        slivers: <Widget>[
          const SliverToBoxAdapter(child: SizedBox(height: _inset)),
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) =>
                  SizedBox(height: NativeTopTabHeader.contentGapFor(context)),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(key: first, height: 80)),
          const SliverToBoxAdapter(child: SizedBox(height: 1000)),
        ],
      ),
    );

    await tester.pumpWidget(
      _host(
        Row(
          children: <Widget>[
            Expanded(child: column(leadingScroll, leading)),
            Expanded(child: column(trailingScroll, trailing)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gap = NativeTopTabHeader.contentGapFor(
      tester.element(find.byType(NativeSingleBarEdge).first),
    );
    expect(tester.getTopLeft(find.byKey(leading)).dy, _inset + gap);
    expect(tester.getTopLeft(find.byKey(trailing)).dy, _inset + gap);
    trailingScroll.jumpTo(16);
    await tester.pump();
    final effects = tester.widgetList<SoftScrollEdgeEffect>(
      find.byType(SoftScrollEdgeEffect),
    );
    expect(effects, hasLength(2));
    expect(effects.map((effect) => effect.strength).toList(), <double>[0, 1]);
  });

  testWidgets('production single-column gallery starts below the native bar', (
    tester,
  ) async {
    _setPhone(tester);
    await prepareProductionGallery(tester);
    await tester.pumpWidget(
      productionGalleryHost(size: _size, windowSize: _size),
    );
    await tester.pumpAndSettle();

    final phoneGap = NativeTopTabHeader.contentGapFor(
      tester.element(find.byType(NativeSingleBarEdge)),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('nativeGalleryDetail.contentStart')),
          )
          .dy,
      _inset + phoneGap,
    );
    expect(find.byType(NativeSingleBarEdge), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery info keeps its existing group gap on phone and iPad', (
    tester,
  ) async {
    _setPhone(tester);
    await prepareProductionGallery(tester);
    await tester.pumpWidget(
      productionGalleryHost(
        size: _size,
        windowSize: _size,
        page: const GalleryInfoPage(),
        pageOwnsScaffold: true,
      ),
    );
    await tester.pumpAndSettle();

    final phoneContext = tester.element(find.byType(NativeSingleBarEdge));
    final phoneGroupTop = tester
        .getTopLeft(find.byKey(GalleryInfoPage.contentStartKey))
        .dy;
    expect(phoneGroupTop, closeTo(_inset + 10, 0.5));
    expect(
      phoneGroupTop,
      greaterThanOrEqualTo(
        _inset + NativeTopTabHeader.contentGapFor(phoneContext),
      ),
    );

    const tabletPane = Size(420, 600);
    const tabletWindow = Size(1024, 768);
    tester.view.physicalSize = tabletPane;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      productionGalleryHost(
        size: tabletPane,
        windowSize: tabletWindow,
        page: const GalleryInfoPage(),
        pageOwnsScaffold: true,
      ),
    );
    await tester.pumpAndSettle();

    final tabletContext = tester.element(find.byType(NativeSingleBarEdge));
    final tabletGap = NativeTopTabHeader.contentGapFor(tabletContext);
    expect(tabletGap, 12);
    expect(
      tester.getTopLeft(find.byKey(GalleryInfoPage.contentStartKey)).dy,
      closeTo(_inset + tabletGap, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('production split gallery gives each pane an independent edge', (
    tester,
  ) async {
    const tabletViewport = Size(1024, 500);
    const tabletWindow = Size(1024, 768);
    tester.view.physicalSize = tabletViewport;
    tester.view.devicePixelRatio = 1;
    await prepareProductionGallery(tester);
    await tester.pumpWidget(
      productionGalleryHost(size: tabletViewport, windowSize: tabletWindow),
    );
    await tester.pumpAndSettle();

    final leadingStart = tester.getTopLeft(
      find.byKey(const ValueKey('nativeGalleryDetail.contentStart')),
    );
    final trailingGap = tester.getRect(
      find.byKey(const ValueKey('nativeGalleryDetail.secondaryContentStart')),
    );
    final tabletGap = NativeTopTabHeader.contentGapFor(
      tester.element(find.byType(NativeSingleBarEdge).first),
    );
    expect(tabletGap, 12);
    expect(leadingStart.dy, _inset + tabletGap);
    expect(trailingGap.bottom, _inset + tabletGap);

    final edgeFinder = find.byType(NativeSingleBarEdge);
    expect(edgeFinder, findsNWidgets(2));
    final effects = tester.widgetList<SoftScrollEdgeEffect>(
      find.byType(SoftScrollEdgeEffect),
    );
    expect(effects, hasLength(2));
    expect(
      tester.getSize(find.byType(SoftScrollEdgeEffect).first).height,
      tester.getSize(find.byType(SoftScrollEdgeEffect).last).height,
    );

    final heroScrollable = find.descendant(
      of: find.byKey(const ValueKey('nativeGalleryDetail.heroScroll')),
      matching: find.byType(Scrollable),
    );
    final contentScrollable = find.descendant(
      of: find.byKey(const ValueKey('nativeGalleryDetail.primaryScroll')),
      matching: find.byType(Scrollable),
    );
    final heroPosition = tester.state<ScrollableState>(heroScrollable).position;
    final contentPosition = tester
        .state<ScrollableState>(contentScrollable)
        .position;
    expect(heroPosition.maxScrollExtent, greaterThanOrEqualTo(16));
    expect(contentPosition.maxScrollExtent, greaterThanOrEqualTo(16));

    contentPosition.jumpTo(16);
    await tester.pump();
    var currentEffects = tester.widgetList<SoftScrollEdgeEffect>(
      find.byType(SoftScrollEdgeEffect),
    );
    expect(currentEffects.map((effect) => effect.strength), <double>[0, 1]);
    heroPosition.jumpTo(16);
    await tester.pump();
    currentEffects = tester.widgetList<SoftScrollEdgeEffect>(
      find.byType(SoftScrollEdgeEffect),
    );
    expect(currentEffects.map((effect) => effect.strength), <double>[1, 1]);
    expect(
      tester.getSize(find.byType(SoftScrollEdgeEffect).first).height,
      tester.getSize(find.byType(SoftScrollEdgeEffect).last).height,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
