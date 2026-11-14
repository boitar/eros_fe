import 'package:eros_fe/common/controller/advance_search_controller.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/index.dart';
import 'package:eros_fe/pages/filter/filter.dart';
import 'package:eros_fe/pages/tab/controller/gallery_filter_controller.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/utility.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// Filter controls rendered inside [presentFilterSheet].
class GalleryFilterView extends StatelessWidget {
  GalleryFilterView({
    super.key,
    required this.catNum,
    required this.catNumChanged,
    this.catCrossAxisCount = 5,
  }) : filterController = Get.put(GalleryFilterController())!;

  final int catNum;
  final ValueChanged<int> catNumChanged;
  final GalleryFilterController filterController;
  final AdvanceSearchController advanceSearchController = Get.find();
  final int catCrossAxisCount;

  SearchPageController? get _searchPageController {
    if (!Get.isRegistered<ControllerTagService>()) {
      return null;
    }
    final depth = int.tryParse(searchPageCtrlTag) ?? 0;
    if (depth > 0 &&
        Get.isRegistered<SearchPageController>(tag: searchPageCtrlTag)) {
      logger.t('searchPageCtrlDepth $searchPageCtrlTag');
      return Get.find<SearchPageController>(tag: searchPageCtrlTag);
    }
    return null;
  }

  void _invertCategories() {
    final map = EHUtils.convNumToCatMap(catNum);
    map.updateAll((_, selected) => !selected);
    catNumChanged(EHUtils.convCatMapToNum(map));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final searchCtrl = _searchPageController;

    return Obx(() {
      final advRx = advanceSearchController.advanceSearch;
      final adv = advRx.value;
      final isFavorite = searchCtrl?.searchType == SearchType.favorite;
      final showAdvance =
          advanceSearchController.enableAdvance && !isFavorite;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (searchCtrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: CupertinoSlidingSegmentedControl<SearchType>(
                children: <SearchType, Widget>{
                  SearchType.normal: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(l10n.tab_gallery),
                  ),
                  SearchType.watched: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(l10n.tab_watched),
                  ),
                  SearchType.favorite: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(l10n.tab_favorite),
                  ),
                },
                groupValue: searchCtrl.searchType,
                onValueChanged: (SearchType? value) {
                  searchCtrl.searchType = value ?? SearchType.normal;
                },
              ),
            ),
          if (!isFavorite) ...[
            EhSheetSectionLabel(
              l10n.sp_category,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EhButton(
                    key: const ValueKey('filter_select_all'),
                    label: l10n.sp_select_all,
                    style: EhButtonStyle.tonal,
                    selected: catNum != 0,
                    size: 28,
                    onPressed: catNum == 0 ? null : () => catNumChanged(0),
                  ),
                  const SizedBox(width: 6),
                  EhButton(
                    key: const ValueKey('filter_invert'),
                    label: l10n.sp_invert_selection,
                    style: EhButtonStyle.fill,
                    size: 28,
                    onPressed: _invertCategories,
                  ),
                ],
              ),
            ),
            GalleryCatFilter(
              catNum: catNum,
              onCatNumChanged: catNumChanged,
              crossAxisCount: catCrossAxisCount,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            const SizedBox(height: 16),
            EhSheetGroup(
              children: [
                AdvanceSearchSwitchItem(
                  title: l10n.s_Advanced_Options,
                  value: advanceSearchController.enableAdvance,
                  onChanged: (bool value) {
                    advanceSearchController.enableAdvance = value;
                  },
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: showAdvance
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        EhSheetGroup(
                          children: [
                            AdvanceSearchSwitchItem(
                              title: l10n.s_Only_Show_Galleries_With_Torrents,
                              value: adv.requireGalleryTorrent,
                              onChanged: (bool value) {
                                advRx(adv.copyWith(
                                    requireGalleryTorrent: value.oN));
                              },
                            ),
                            AdvanceSearchSwitchItem(
                              title: l10n.s_Show_Expunged_Galleries,
                              value: adv.browseExpungedGalleries,
                              onChanged: (bool value) {
                                advRx(adv.copyWith(
                                    browseExpungedGalleries: value.oN));
                              },
                            ),
                            _buildMinRatingRow(context, l10n, advRx, adv),
                            _buildPageRangeRow(
                                context, l10n, palette, advRx, adv),
                          ],
                        ),
                        EhSheetSectionLabel(l10n.s_Disable_default_filters),
                        EhSheetGroup(
                          children: [
                            AdvanceSearchSwitchItem(
                              title: l10n.language,
                              value: adv.disableCustomFilterLanguage,
                              onChanged: (bool value) {
                                advRx(adv.copyWith(
                                    disableCustomFilterLanguage: value.oN));
                              },
                            ),
                            AdvanceSearchSwitchItem(
                              title: l10n.uploader,
                              value: adv.disableCustomFilterUploader,
                              onChanged: (bool value) {
                                advRx(adv.copyWith(
                                    disableCustomFilterUploader: value.oN));
                              },
                            ),
                            AdvanceSearchSwitchItem(
                              title: l10n.tags,
                              value: adv.disableCustomFilterTags,
                              onChanged: (bool value) {
                                advRx(adv.copyWith(
                                    disableCustomFilterTags: value.oN));
                              },
                            ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildMinRatingRow(
    BuildContext context,
    L10n l10n,
    Rx<AdvanceSearch> advRx,
    AdvanceSearch adv,
  ) {
    final enabled = adv.searchWithMinRating ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdvanceSearchSwitchItem(
          title: l10n.s_Minimum_Rating,
          value: enabled,
          onChanged: (bool value) {
            advRx(adv.copyWith(searchWithMinRating: value.oN));
          },
        ),
        AnimatedCrossFade(
          alignment: Alignment.center,
          crossFadeState:
              enabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                children: <int, Widget>{
                  for (final star in [2, 3, 4, 5])
                    star: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(l10n.s_stars('$star')),
                    ),
                },
                groupValue: adv.minRating ?? 2,
                onValueChanged: (int? value) {
                  advRx(adv.copyWith(minRating: value.oN));
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageRangeRow(
    BuildContext context,
    L10n l10n,
    EhPalette palette,
    Rx<AdvanceSearch> advRx,
    AdvanceSearch adv,
  ) {
    final enabled = adv.searchBetweenPage ?? false;
    final fieldStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 15,
          letterSpacing: 0,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: palette.text1.resolveFrom(context),
        );
    Widget pageBox(TextEditingController ctrl) => SizedBox(
          width: 72,
          height: 34,
          child: CupertinoTextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            enabled: enabled,
            style: fieldStyle,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: palette.fill.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdvanceSearchSwitchItem(
          title: l10n.s_pages,
          expand: false,
          value: enabled,
          onChanged: (bool value) {
            advRx(adv.copyWith(searchBetweenPage: value.oN));
          },
        ),
        AnimatedCrossFade(
          alignment: Alignment.center,
          crossFadeState:
              enabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                pageBox(filterController.statrPageCtrl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    l10n.s_and,
                    style: fieldStyle.copyWith(
                      fontSize: 14,
                      color: palette.text2.resolveFrom(context),
                    ),
                  ),
                ),
                pageBox(filterController.endPageCtrl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
