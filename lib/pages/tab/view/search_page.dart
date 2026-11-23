import 'package:blur/blur.dart';
import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:eros_fe/adaptive/native_single_bar_edge.dart';
import 'package:eros_fe/adaptive/native_top_header.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/common/controller/tag_trans_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/debug/offline_glass.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/filter/filter.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/view/gallery_base.dart';
import 'package:eros_fe/pages/tab/view/list/tab_base.dart';
import 'package:eros_fe/pages/tab/view/search_more_sheet.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:eros_fe/widget/tag_suggestions.dart';
import 'package:extended_sliver/extended_sliver.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

const Color _kDefaultNavBarBorderColor = Color(0x4D000000);
const Border _kDefaultNavBarBorder = Border(
  bottom: BorderSide(
    color: _kDefaultNavBarBorderColor,
    width: 0.0, // One physical pixel.
    style: BorderStyle.solid,
  ),
);

enum SearchMenuEnum { filter, quickSearchList, addToQuickSearch }

class GallerySearchPage extends StatefulWidget {
  const GallerySearchPage({super.key});

  @override
  State<GallerySearchPage> createState() => _GallerySearchPageState();
}

class _GallerySearchPageState extends State<GallerySearchPage> {
  late final String _tag;
  late SearchPageController controller;
  final Map<int, double> _keyboardFreeHeights = <int, double>{};
  final GlobalKey _searchFieldKey = GlobalKey();
  final GlobalKey _nativeSearchRowKey = GlobalKey();
  double _nativeSearchRowHeight = 0;
  String? _nativeSearchRowLayoutSignature;
  bool _nativeSearchRowMeasured = false;
  bool _searchRowMeasurePending = false;
  bool _nativeKeyboardVisible = false;
  bool _nativeBarActive = true;
  bool _hasText = false;

  GlobalKey centerKey = GlobalKey();

  String _nativeSearchLayoutSignature(
    BuildContext context, {
    required bool keyboardVisible,
    required bool nativeBar,
  }) {
    final media = MediaQuery.of(context);
    return '${media.size.width}|${media.textScaler}|${media.devicePixelRatio}|'
        '${Localizations.localeOf(context)}|$keyboardVisible|$nativeBar';
  }

  void _scheduleNativeSearchRowMeasure() {
    if (_searchRowMeasurePending) {
      return;
    }
    _searchRowMeasurePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchRowMeasurePending = false;
      if (!mounted) {
        return;
      }
      final rowContext = _nativeSearchRowKey.currentContext;
      final height = rowContext?.size?.height;
      if (rowContext == null || height == null) {
        return;
      }
      final signature = _nativeSearchLayoutSignature(
        rowContext,
        keyboardVisible: _nativeKeyboardVisible,
        nativeBar: _nativeBarActive,
      );
      if (_nativeSearchRowMeasured &&
          (height - _nativeSearchRowHeight).abs() < 0.5 &&
          signature == _nativeSearchRowLayoutSignature) {
        return;
      }
      setState(() {
        _nativeSearchRowHeight = height;
        _nativeSearchRowLayoutSignature = signature;
        _nativeSearchRowMeasured = true;
      });
    });
  }

  void _onNativeSearchTextChanged() {
    if (!mounted) {
      return;
    }
    final hasText = controller.searchTextController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    if (_nativeSearchRowMeasured) {
      setState(() => _nativeSearchRowMeasured = false);
    }
    _scheduleNativeSearchRowMeasure();
  }

  @override
  void initState() {
    super.initState();
    _tag = searchPageCtrlTagOf(context);

    if (Get.isRegistered<SearchPageController>(tag: _tag)) {
      logger.d('find SearchPageController $_tag');
      controller = Get.find<SearchPageController>(tag: _tag);
    } else {
      logger.d('put SearchPageController $_tag');
      controller = Get.put(
        SearchPageController(
          controllerTag: _tag,
          repository: SearchRepository(),
        ),
        tag: _tag,
      );
    }
    controller.searchTextController.addListener(_onNativeSearchTextChanged);
    _hasText = controller.searchTextController.text.trim().isNotEmpty;

    // controller.initStateAddPostFrameCallback(context);
  }

  @override
  void dispose() {
    controller.searchTextController.removeListener(_onNativeSearchTextChanged);
    super.dispose();
    Get.delete<SearchPageController>(tag: _tag);
  }

  CupertinoNavigationBar getNavigationBar(
    BuildContext context, {
    bool keyboardVisible = false,
  }) {
    return CupertinoNavigationBar(
      padding: const EdgeInsetsDirectional.only(end: 10),
      border: null,
      middle: Obx(() {
        return Text(controller.placeholderText);
      }),
      transitionBetweenRoutes: false,
      trailing: _buildTrailing(context, keyboardVisible: keyboardVisible),
    );
  }

  bool _softwareKeyboardVisible(
    BuildContext context,
    bool reportedKeyboardVisible,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final widthKey = size.width.round();

    // The plugin can retain a stale value while Duo changes panes. Remember
    // each pane's keyboard-free height and require a real viewport reduction.
    if (!reportedKeyboardVisible) {
      final previous = _keyboardFreeHeights[widthKey];
      if (previous == null || size.height > previous) {
        _keyboardFreeHeights[widthKey] = size.height;
      }
      return false;
    }
    if (mediaQuery.viewInsets.bottom > 0) return true;

    final keyboardFreeHeight = _keyboardFreeHeights[widthKey];
    return keyboardFreeHeight != null && size.height < keyboardFreeHeight - 40;
  }

  @override
  Widget build(BuildContext context) {
    final hasVerticalBar =
        AdaptiveEnvironment.maybeOf(context)?.hasVerticalBar ?? false;
    final native =
        NativeNavigationScope.isEnabled(context) &&
        (!BrowsePaneScope.isSplit(context) || hasVerticalBar);

    return KeyboardVisibilityBuilder(
      builder: (context, keyboardVisible) {
        final softwareKeyboardVisible = _softwareKeyboardVisible(
          context,
          keyboardVisible,
        );
        return RetainedDraft(
          controller: controller.searchTextController,
          child: Obx(
            () => NativeNavigationPage(
              chrome: NativePageChrome(
                title: controller.placeholderText,
                navigationBarVisible: native,
                ownBar: !native,
                actions: [
                  if (softwareKeyboardVisible)
                    NativeNavigationAction(
                      id: 'dismissKeyboard',
                      title: L10n.of(context).sp_hide_keyboard,
                      symbol: 'keyboard.chevron.compact.down',
                      onPressed: controller.searchFocusNode.unfocus,
                    ),
                  NativeNavigationAction(
                    id: 'filter',
                    title: L10n.of(context).sp_filter,
                    symbol: 'line.3.horizontal.decrease',
                    onPressed: showFilterSetting,
                  ),
                  NativeNavigationAction(
                    id: 'search.more',
                    title: L10n.of(context).more_actions,
                    symbol: 'ellipsis',
                    children: _moreActions(context),
                  ),
                ],
              ),
              child: offlineDuoRouteProbe(
                id: 'search',
                listenable: controller.searchTextController,
                label: () =>
                    'native=$native;'
                    'split=${BrowsePaneScope.isSplit(context)};tag=$_tag;'
                    'draft=${controller.searchTextController.text}',
                child: CupertinoPageScaffold(
                  child: _buildFloatingBody(
                    context,
                    nativeBar: native,
                    keyboardVisible: softwareKeyboardVisible,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingBody(
    BuildContext context, {
    required bool nativeBar,
    required bool keyboardVisible,
  }) {
    _nativeKeyboardVisible = keyboardVisible;
    _nativeBarActive = nativeBar;
    _scheduleNativeSearchRowMeasure();
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    final contentTopGap = NativeTopTabHeader.contentGapFor(context);
    final layoutSignature = _nativeSearchLayoutSignature(
      context,
      keyboardVisible: keyboardVisible,
      nativeBar: nativeBar,
    );
    return NativeSingleBarEdge(
      enabled: true,
      inset: safeTop,
      bars: _nativeSearchRowHeight,
      foreground: Positioned(
        top: safeTop,
        // Duo's outer display keeps a side bar region; stay clear of it.
        left: MediaQuery.viewPaddingOf(context).left,
        right: MediaQuery.viewPaddingOf(context).right,
        child: NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            _scheduleNativeSearchRowMeasure();
            return false;
          },
          child: SizeChangedLayoutNotifier(
            key: _nativeSearchRowKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!nativeBar)
                  _buildFloatingTopBar(
                    context,
                    keyboardVisible: keyboardVisible,
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(14, nativeBar ? 4 : 2, 14, 4),
                  child: SearchTextFieldIn(
                    key: _searchFieldKey,
                    iconOpacity: 1,
                    multiline: true,
                    keyboardVisible: keyboardVisible,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: _buildSearchResult(
        context,
        topPadding: safeTop + _nativeSearchRowHeight + contentTopGap,
        visible:
            _nativeSearchRowMeasured &&
            _nativeSearchRowLayoutSignature == layoutSignature &&
            _nativeSearchRowHeight > 0,
      ),
    );
  }

  bool get _followSystemTransparency =>
      !Get.isRegistered<EhSettingService>() ||
      Get.find<EhSettingService>().liquidGlassMaterial;

  Widget _buildFloatingTopBar(
    BuildContext context, {
    required bool keyboardVisible,
  }) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final backLabel = CupertinoLocalizations.of(context).backButtonLabel;
    final palette = ehTheme.palette;
    final glassOff = GlassMode.of(context) == GlassMode.off;
    final followSystemTransparency = _followSystemTransparency;
    return Padding(
      key: const ValueKey('search.floatingTopBar'),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: SizedBox(
        height: 44,
        child: NavigationToolbar(
          leading: canPop
              ? (glassOff
                    ? EhButton(
                        key: const ValueKey('search.splitBack'),
                        icon: CupertinoIcons.chevron_back,
                        style: EhButtonStyle.glass,
                        size: 44,
                        semanticLabel: backLabel,
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    : SizedBox.square(
                        key: const ValueKey('search.splitBack'),
                        dimension: 44,
                        child: LiquidGlassSurface(
                          enabled: true,
                          borderRadius: BorderRadius.circular(22),
                          style: LiquidGlassStyle.regular,
                          interactive: false,
                          followSystemTransparency: followSystemTransparency,
                          child: Semantics(
                            button: true,
                            label: backLabel,
                            child: EhPressable(
                              borderRadius: BorderRadius.circular(22),
                              onPressed: () {
                                liquidGlassFeedback(vibrateUtil.light);
                                Navigator.of(context).maybePop();
                              },
                              child: Center(
                                child: EhSvgIcon(
                                  CupertinoIcons.chevron_back,
                                  size: 22,
                                  color: palette.text1.resolveFrom(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ))
              : null,
          middle: Text(
            controller.placeholderText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle
                .copyWith(color: palette.text1.resolveFrom(context)),
          ),
          trailing: _buildTrailing(context, keyboardVisible: keyboardVisible),
        ),
      ),
    );
  }

  Widget _buildSearchResult(
    BuildContext context, {
    double? topPadding,
    bool visible = true,
  }) {
    return Offstage(
      key: const ValueKey('search.nativeResultsVisibility'),
      offstage: !visible,
      child: CustomScrollView(
        // cacheExtent: context.height * 2,
        slivers: <Widget>[
          if (topPadding != null)
            SliverToBoxAdapter(
              child: SizedBox(
                key: const ValueKey('search.nativeContentStart'),
                height: topPadding,
              ),
            ),
          // todo android上会有一次删除多个字符的问题
          // if (GetPlatform.isIOS)
          //   SliverFloatingPinnedPersistentHeader(
          //     delegate: SliverFloatingPinnedPersistentHeaderBuilder(
          //       minExtentProtoType: SizedBox(
          //         height: context.mediaQueryPadding.top,
          //       ),
          //       maxExtentProtoType: _maxExtentProtoTypeBar(context),
          //       builder: (_, __, maxExtent) =>
          //           _buildSearchBar(_, __, maxExtent),
          //     ),
          //   ),
          Obx(() {
            return EhCupertinoSliverRefreshControl(
              // onRefresh: controller.listType == ListType.gallery
              //     ? () => controller.onEditingComplete(clear: false)
              //     : null);
              onRefresh: controller.listType == ListType.gallery
                  ? () => controller.onRefresh()
                  : null,
            );
          }),
          SliverPadding(padding: EdgeInsets.zero, key: centerKey),
          Obx(
            () => SliverSafeArea(
              // key: UniqueKey(),
              bottom: false,
              top: false,
              sliver: () {
                switch (controller.listType) {
                  case ListType.gallery:
                    return _buildListView(context);
                  case ListType.tag:
                    logger.d('tag list');
                    return _getTagQryList();
                  case ListType.init:
                    return _getInitView();
                }
              }(),
            ),
          ),
          Obx(() {
            if (controller.listType != ListType.tag) {
              return EndIndicator(
                pageState: controller.pageState,
                loadDataMore: controller.loadDataMore,
              );
            } else {
              return SliverSafeArea(
                bottom: false,
                top: false,
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: _SearchForRow(
                      text: controller.searchText,
                      onPressed: controller.onEditingComplete,
                    ),
                  ).autoCompressKeyboard(context),
                ),
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    double offset,
    double maxExtentCallBackValue,
  ) {
    // logger.t('offset $offset');
    double iconOpacity = 0.0;
    final transparentOffset = maxExtentCallBackValue - 60;
    if (offset < transparentOffset) {
      iconOpacity = 1 - offset / transparentOffset;
    }
    final barHeight =
        kMinInteractiveDimensionCupertino + context.mediaQueryPadding.top;
    return SizedBox(
      height: maxExtentCallBackValue,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // const SizedBox(),
          Expanded(flex: barHeight ~/ 1, child: getNavigationBar(context)),
          Expanded(
            flex: (maxExtentCallBackValue - barHeight) ~/ 1,
            child: Stack(
              // fit: StackFit.expand,
              alignment: Alignment.topCenter,
              children: [
                ClipRect(
                  child:
                      Container(
                        decoration: const BoxDecoration(
                          border: _kDefaultNavBarBorder,
                        ),
                        padding: EdgeInsets.only(
                          left: 8 + context.mediaQueryPadding.left,
                          right: 8 + context.mediaQueryPadding.right,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: SearchTextFieldIn(
                                  multiline: true,
                                  iconOpacity: iconOpacity,
                                ),
                                // child: getSearchTextField(
                                //   multiline: true,
                                // ),
                              ),
                            ),
                          ],
                        ),
                      ).frosted(
                        blur: 8,
                        frostColor: CupertinoTheme.of(context)
                            .barBackgroundColor
                            .withOpacity(1),
                        frostOpacity: 0.55,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _maxExtentProtoTypeBar(BuildContext context) {
    // logger.t(' _maxExtentProtoTypeBar');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(),
        getNavigationBar(context),
        Container(
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(
              ehTheme.themeData!.barBackgroundColor,
              context,
            ).withOpacity(1),
            border: _kDefaultNavBarBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 4, top: 4, bottom: 4),
                  child: SearchTextFieldIn(multiline: true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// tag匹配view
  Widget _getTagQryList() {
    return SliverPadding(
      padding: EdgeInsets.zero,
      sliver: SliverTagSuggestions(
        // Read inside the enclosing Obx so new completions rebuild the list.
        tags: controller.qryTags.toList(),
        query: controller.currQryText,
        showTranslation: controller.isTagTranslat,
        onSelected: controller.addQryTag,
      ),
    );
  }

  Future<String?> _getTextTranslate(String text) async {
    final String? tranText = await Get.find<TagTransController>()
        .getTranTagWithNameSpaseAuto(text);
    if (tranText != null && tranText.trim() != text) {
      return tranText;
    } else {
      return null;
    }
  }

  Future<void> _confirmRemoveHistory(
    String text,
    String? translation,
    VoidCallback removeHistory,
  ) async {
    vibrateUtil.light();
    final l10n = L10n.of(context);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => EhActionSheet(
        title: Text(text),
        message: translation == null ? null : Text(translation),
        actions: [
          EhActionSheetAction(
            isDestructiveAction: true,
            icon: CupertinoIcons.delete,
            systemIcon: 'trash',
            onPressed: () {
              Navigator.of(sheetContext).pop();
              removeHistory();
            },
            child: Text(l10n.delete),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  Widget _historyChip(String text, VoidCallback removeHistory, bool translate) {
    if (!translate) {
      return SearchHistoryChip(
        text: text,
        onPressed: () => controller.appendTextToSearch(text),
        onLongPress: () async => _confirmRemoveHistory(
          text,
          await _getTextTranslate(text),
          removeHistory,
        ),
      );
    }
    return FutureBuilder<String?>(
      future: _getTextTranslate(text),
      builder: (context, snapshot) => SearchHistoryChip(
        text: text,
        translation: snapshot.data,
        onPressed: () => controller.appendTextToSearch(text),
        onLongPress: () =>
            _confirmRemoveHistory(text, snapshot.data, removeHistory),
      ),
    );
  }

  Widget _getInitView() {
    return GetBuilder<SearchPageController>(
      tag: _tag,
      id: GetIds.SEARCH_INIT_VIEW,
      builder: (SearchPageController sPageController) {
        final l10n = L10n.of(context);
        final history = sPageController.searchHistory;
        final translate =
            sPageController.isTagTranslat &&
            sPageController.translateSearchHistory;
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (history.isNotEmpty) ...[
                EhSectionHeader(
                  title: l10n.sp_recent_searches,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    NativeNavigationScope.isEnabled(context) ? 6 : 12,
                    16,
                    10,
                  ),
                  actions: [
                    if (sPageController.isTagTranslat)
                      EhButton(
                        icon: CupertinoIcons.globe,
                        label: l10n.sp_translate,
                        size: 28,
                        style: EhButtonStyle.tonal,
                        selected: sPageController.translateSearchHistory,
                        onPressed: sPageController.switchTranslateHistory,
                      ),
                    EhButton(
                      label: l10n.sp_clear,
                      size: 28,
                      style: EhButtonStyle.fill,
                      semanticLabel: l10n.clear_search_history,
                      onPressed: sPageController.clearHistory,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final text in history.take(30))
                          _historyChip(
                            text,
                            () => sPageController.removeHistory(text),
                            translate,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              Obx(() {
                final quick = sPageController
                    .quickSearchController
                    .searchTextList
                    .where((e) => e.trim().isNotEmpty)
                    .take(3)
                    .toList();
                if (quick.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EhSectionHeader(
                      title: l10n.quick_search,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        history.isEmpty ? 12 : 26,
                        16,
                        10,
                      ),
                      actions: [
                        EhButton(
                          label: l10n.sp_all,
                          size: 28,
                          style: EhButtonStyle.fill,
                          semanticLabel: l10n.sp_quick_search_list,
                          onPressed: sPageController.quickSearchList,
                        ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: ehCardDecoration(context),
                      child: Column(
                        children: [
                          for (var i = 0; i < quick.length; i++)
                            _QuickSearchRow(
                              text: quick[i].trim(),
                              divider: i > 0,
                              onPressed: () => sPageController.applyQuickSearch(
                                quick[i].trim(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView(BuildContext context) {
    return GetBuilder<SearchPageController>(
      global: false,
      init: controller,
      id: controller.listViewId,
      builder: (logic) {
        final status = logic.status;

        if (status.isLoading) {
          return SliverFillRemaining(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(bottom: 50),
              child: const CupertinoActivityIndicator(radius: 14.0),
            ),
          );
        }

        if (status.isError) {
          return SliverFillRemaining(
            child: Container(
              padding: const EdgeInsets.only(bottom: 50),
              child: GalleryErrorPage(
                onTap: () => controller.onEditingComplete(),
              ),
            ).autoCompressKeyboard(Get.context!),
          );
        }

        if (status.isSuccess) {
          logger.t(
            '>>>>>>> controller.keepPosition ${controller.keepPosition}',
          );
          return getGallerySliverList(
            logic.state,
            controller.heroTag,
            next: logic.next,
            lastComplete: controller.lastComplete,
            // centerKey: centerKey,
            key: controller.sliverAnimatedListKey,
            lastTopItemIndex: controller.lastTopitemIndex,
            anchorController: logic.galleryAnchor,
            keepPosition: controller.keepPosition,
          );
        }

        return SliverFillRemaining(
          child: Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EhSvgFaIcon(
                  FontAwesomeIcons.hippo,
                  size: 100,
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.systemGrey,
                    context,
                  ),
                ),
                Text(''),
              ],
            ),
          ).autoCompressKeyboard(context),
        );
      },
    );
  }

  /// The occasional actions, shared by the native "…" menu and the Flutter
  /// bar's pull-down.
  List<NativeNavigationAction> _moreActions(BuildContext context) {
    final l10n = L10n.of(context);
    return [
      NativeNavigationAction(
        id: 'imageSearch',
        title: l10n.sp_image_search,
        symbol: 'photo.on.rectangle',
        onPressed: () => Get.toNamed<void>(EHRoutes.searchImage),
      ),
      NativeNavigationAction(
        id: 'quickSearchList',
        title: l10n.sp_quick_search_list,
        symbol: 'list.bullet',
        onPressed: controller.quickSearchList,
      ),
      NativeNavigationAction(
        id: 'addQuickSearch',
        title: l10n.sp_add_quick_search,
        symbol: 'plus.circle',
        enabled: _hasText && !controller.textIsGalleryUrl,
        onPressed: controller.addToQuickSearch,
      ),
      NativeNavigationAction(
        id: 'jump',
        title: l10n.jump_or_seek,
        symbol: 'arrow.uturn.down.circle',
        enabled: controller.next.isNotEmpty || controller.prev.isNotEmpty,
        onPressed: () => controller.showJumpDialog(context),
      ),
      NativeNavigationAction(
        id: 'top',
        title: l10n.back_to_top,
        symbol: 'arrow.up.to.line',
        enabled: controller.afterJump,
        onPressed: controller.jumpToTop,
      ),
    ];
  }

  Widget _buildTrailing(BuildContext context, {bool keyboardVisible = false}) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final color = palette.text1.resolveFrom(context);
    final dividerColor = palette.hairline.resolveFrom(context);
    final glassOff = GlassMode.of(context) == GlassMode.off;

    Widget actionButton(
      IconData data,
      String label,
      VoidCallback onPressed, {
      Key? key,
    }) => CupertinoButton(
      key: key,
      minimumSize: const Size(38, 44),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onPressed: onPressed,
      child: Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        onTap: onPressed,
        child: EhSvgIcon(data, size: 20, color: color),
      ),
    );

    Widget hairline() => Container(width: 0.5, height: 18, color: dividerColor);

    return ConstrainedBox(
      key: const ValueKey('search.trailingCapsule'),
      constraints: const BoxConstraints(
        minWidth: 44,
        minHeight: 44,
        maxHeight: 44,
      ),
      child: LiquidGlassSurface(
        enabled: !glassOff,
        style: LiquidGlassStyle.regular,
        followSystemTransparency: _followSystemTransparency,
        emphasizeFallbackEdge: true,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: glassOff
              ? BoxDecoration(
                  color: palette.bar.resolveFrom(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: dividerColor, width: 0.5),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (keyboardVisible) ...[
                  actionButton(
                    CupertinoIcons.keyboard_chevron_compact_down,
                    l10n.sp_hide_keyboard,
                    controller.searchFocusNode.unfocus,
                    key: const ValueKey('search.hideKeyboard'),
                  ),
                  hairline(),
                ],
                actionButton(
                  CupertinoIcons.line_horizontal_3_decrease,
                  l10n.sp_filter,
                  showFilterSetting,
                  key: const ValueKey('search.filterAction'),
                ),
                hairline(),
                actionButton(
                  CupertinoIcons.ellipsis,
                  l10n.more_actions,
                  () => presentSearchMoreSheet(context, _moreActions(context)),
                  key: const ValueKey('search.moreAction'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SearchTextFieldIn extends StatelessWidget {
  const SearchTextFieldIn({
    super.key,
    this.multiline = false,
    this.iconOpacity = 0.0,
    this.keyboardVisible,
  });

  final bool multiline;
  final double iconOpacity;
  final bool? keyboardVisible;

  @override
  Widget build(BuildContext context) {
    final tag = searchPageCtrlTagOf(context);
    SearchPageController controller;
    if (Get.isRegistered<SearchPageController>(tag: tag)) {
      controller = Get.find(tag: tag);
    } else {
      controller = Get.put(SearchPageController(), tag: tag);
    }
    final l10n = L10n.of(context);

    return Obx(() {
      ehTheme.isDarkMode;
      final palette = ehTheme.palette;
      final base = CupertinoTheme.of(context).textTheme.textStyle
          .copyWith(letterSpacing: 0, fontVariations: const []);
      final iconColor = palette.text2
          .resolveFrom(context)
          .withValues(alpha: iconOpacity.clamp(0, 1));
      return KeyboardVisibilityBuilder(
        builder: (context, pluginKeyboardVisible) {
          final expanded =
              (keyboardVisible ?? pluginKeyboardVisible) && multiline;
          return CupertinoTextField(
            style: base.copyWith(
              fontSize: 16,
              height: 1.3,
              color: palette.text1.resolveFrom(context),
            ),
            cursorColor: EhPalette.accent.resolveFrom(context),
            decoration: BoxDecoration(
              color: palette.field.resolveFrom(context),
              borderRadius: BorderRadius.circular(expanded ? 16 : 21),
            ),
            placeholder: l10n.sp_search_placeholder,
            placeholderStyle: base.copyWith(
              fontSize: 16,
              height: 1.3,
              color: palette.text3.resolveFrom(context),
            ),
            // Decorative magnifier; the field itself is the control.
            prefix: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 13, end: 2),
                child: EhSvgIcon(CupertinoIcons.search, size: 18, color: iconColor),
              ),
            ),
            suffix: GetBuilder<SearchPageController>(
              id: GetIds.SEARCH_CLEAR_BTN,
              tag: tag,
              builder: (SearchPageController controller) {
                Widget circle({
                  required IconData icon,
                  required String label,
                  required VoidCallback onPressed,
                  bool prominent = false,
                }) => Semantics(
                  button: true,
                  label: label,
                  excludeSemantics: true,
                  onTap: onPressed,
                  child: EhPressable(
                    onPressed: onPressed,
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(
                        child: prominent
                            ? Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: EhPalette.accent.resolveFrom(context),
                                  shape: BoxShape.circle,
                                ),
                                child: EhSvgIcon(
                                  CupertinoIcons.arrow_right,
                                  size: 15,
                                  color: EhPalette.onAccent.resolveFrom(
                                    context,
                                  ),
                                ),
                              )
                            : EhSvgIcon(icon, size: 19, color: iconColor),
                      ),
                    ),
                  ),
                );
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (GetPlatform.isDesktop)
                        _DesktopRefreshButton(
                          color: iconColor,
                          label: l10n.sp_refresh,
                          onPressed: controller.reloadData,
                        ),
                      if (controller.textIsGalleryUrl)
                        circle(
                          icon: CupertinoIcons.arrow_right,
                          label: l10n.sp_open_link,
                          prominent: true,
                          onPressed: controller.jumpToGallery,
                        ),
                      if (controller.textIsNotEmpty)
                        circle(
                          icon: CupertinoIcons.xmark_circle_fill,
                          label: l10n.sp_clear_text,
                          onPressed: controller.clearText,
                        ),
                    ],
                  ),
                );
              },
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(6, 11, 6, 11),
            controller: controller.searchTextController,
            autofocus: controller.autofocus,
            onEditingComplete: controller.onEditingComplete,
            focusNode: controller.searchFocusNode,
            onTapOutside: (_) => controller.searchFocusNode.unfocus(),
            maxLines: expanded ? null : 1,
            textInputAction: TextInputAction.search,
          );
        },
      );
    });
  }
}

class _DesktopRefreshButton extends StatefulWidget {
  const _DesktopRefreshButton({
    required this.color,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final String label;
  final Future<void> Function() onPressed;

  @override
  State<_DesktopRefreshButton> createState() => _DesktopRefreshButtonState();
}

class _DesktopRefreshButtonState extends State<_DesktopRefreshButton> {
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: _busy ? null : _refresh,
      child: EhPressable(
        onPressed: _busy ? null : _refresh,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: _busy
                ? const CupertinoActivityIndicator(radius: 8)
                : EhSvgIcon(
                    CupertinoIcons.arrow_clockwise,
                    size: 18,
                    color: widget.color,
                  ),
          ),
        ),
      ),
    );
  }
}

/// "Search “…”" at the end of the tag completions.
class _SearchForRow extends StatelessWidget {
  const _SearchForRow({required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = EhPalette.accent.resolveFrom(context);
    final label = L10n.of(context).sp_search_for(text.trim());
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: EhPressable(
        onPressed: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: EhPalette.accentSoft.resolveFrom(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              EhSvgIcon(CupertinoIcons.search, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CupertinoTheme.of(context).textTheme.textStyle
                      .copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: accent,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickSearchRow extends StatelessWidget {
  const _QuickSearchRow({
    required this.text,
    required this.onPressed,
    this.divider = false,
  });

  final String text;
  final VoidCallback onPressed;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      onTap: onPressed,
      child: EhPressable(
        onPressed: onPressed,
        child: Column(
          children: [
            if (divider)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 14),
                child: Container(
                  height: .5,
                  color: EhPalette.separator.resolveFrom(context),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CupertinoTheme.of(context).textTheme.textStyle
                          .copyWith(
                            fontSize: 15,
                            letterSpacing: 0,
                            color: palette.text1.resolveFrom(context),
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  EhSvgIcon(
                    CupertinoIcons.arrow_up_left,
                    size: 16,
                    color: palette.text2.resolveFrom(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchSliverPinnedPersistentHeaderDelegate
    extends SliverPinnedPersistentHeaderDelegate {
  SearchSliverPinnedPersistentHeaderDelegate({
    required this.child,
    required super.minExtentProtoType,
    required super.maxExtentProtoType,
  });
  final Widget child;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    double? minExtent,
    double maxExtent,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(
    covariant SliverPinnedPersistentHeaderDelegate oldDelegate,
  ) {
    return false;
  }
}
