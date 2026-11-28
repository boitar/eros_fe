import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/controller/favorite_sel_controller.dart';
import 'package:eros_fe/pages/gallery/view/favorite_note_edit_sheet.dart';
import 'package:eros_fe/pages/item/gallery_item.dart';
import 'package:eros_fe/pages/tab/controller/favorite/fav_search_scope.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/fav_note_line.dart';
import 'package:eros_fe/widget/favcat_grid.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// Resolves the localized folder name for [favcat] (`'a'` => "All favorites").
String resolveFavSearchFolderLabel(BuildContext context, String favcat) {
  final l10n = L10n.of(context);
  if (favcat.isEmpty || favcat == 'a') {
    return l10n.sp_all_favcats;
  }
  if (Get.isRegistered<FavoriteSelectorController>()) {
    final match = Get.find<FavoriteSelectorController>()
        .favcatList
        .where((f) => f.favId == favcat)
        .firstOrNull;
    if (match != null && match.favTitle.isNotEmpty) {
      return match.favTitle;
    }
  }
  return 'Favorites $favcat';
}

/// Resolves the localized label for [scope].
String resolveFavSearchScopeLabel(BuildContext context, FavSearchScope scope) {
  final l10n = L10n.of(context);
  return switch (scope) {
    FavSearchScope.all => l10n.fav_scope_all,
    FavSearchScope.title => l10n.fav_scope_title,
    FavSearchScope.tag => l10n.fav_scope_tag,
    FavSearchScope.note => l10n.fav_scope_note,
  };
}

/// Scope segmented control (`全部 / 标题 / 标签 / 备注`) and folder scope row
/// (`在 ♥ {favcat} 中搜索`) placed directly beneath `SearchTextFieldIn` when
/// searching inside favorites.
class FavSearchScopeControls extends StatelessWidget {
  const FavSearchScopeControls({
    super.key,
    required this.controller,
  });

  final SearchPageController controller;

  Future<void> _pickFolder(BuildContext context) async {
    final l10n = L10n.of(context);
    final favcats = Get.isRegistered<FavoriteSelectorController>()
        ? Get.find<FavoriteSelectorController>().favcatList
        : const <Favcat>[];
    final chosen = await showEhSheet<Favcat>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          EhSheetHeader(title: l10n.choose_favcat),
          FavcatGrid(
            favcats: favcats,
            showAllOption: true,
            selectedFavId: controller.favSearchCat.value,
            onSelect: (fav) => Navigator.of(sheetContext).pop(fav),
          ),
        ],
      ),
    );
    if (chosen != null) {
      controller.setFavSearchCat(chosen.favId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    return Obx(() {
      final scope = controller.favSearchScope.value;
      final favcat = controller.favSearchCat.value;
      final folderLabel = resolveFavSearchFolderLabel(context, favcat);
      final isAll = favcat.isEmpty || favcat == 'a';
      final heartColor = isAll
          ? palette.text2.resolveFrom(context)
          : favcatDisplayColor(context, favcat);

      Widget segment(String text) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: palette.text1.resolveFrom(context),
              ),
            ),
          );

      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 44,
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<FavSearchScope>(
                    groupValue: scope,
                    onValueChanged: (value) {
                      if (value != null) {
                        controller.setFavSearchScope(value);
                      }
                    },
                    children: <FavSearchScope, Widget>{
                      FavSearchScope.all: segment(l10n.fav_scope_all),
                      FavSearchScope.title: segment(l10n.fav_scope_title),
                      FavSearchScope.tag: segment(l10n.fav_scope_tag),
                      FavSearchScope.note: segment(l10n.fav_scope_note),
                    },
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: l10n.fav_search_in(folderLabel),
              excludeSemantics: true,
              onTap: () => _pickFolder(context),
              child: EhPressable(
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _pickFolder(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: <Widget>[
                        EhSvgIcon(
                          isAll
                              ? CupertinoIcons.square_grid_2x2
                              : CupertinoIcons.heart_fill,
                          size: 14,
                          color: heartColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.fav_search_in(folderLabel),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: palette.text1.resolveFrom(context),
                            ),
                          ),
                        ),
                        EhSvgIcon(
                          CupertinoIcons.chevron_down,
                          size: 14,
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
      );
    });
  }
}

/// Flat deletable recent search list for in-favorites search (no chip cloud,
/// no fake "note index").
class FavRecentSearchList extends StatelessWidget {
  const FavRecentSearchList({
    super.key,
    required this.history,
    required this.onTapQuery,
    required this.onRemoveQuery,
    required this.onClearAll,
  });

  final List<String> history;
  final ValueChanged<String> onTapQuery;
  final ValueChanged<String> onRemoveQuery;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final hairline = palette.hairline.resolveFrom(context);
    final items = history.take(20).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.sp_recent_searches,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text2.resolveFrom(context),
                  ),
                ),
              ),
              CupertinoButton(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: onClearAll,
                child: Text(
                  l10n.sp_clear,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: EhPalette.accent.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 44, end: 16),
              child: Container(height: 0.5, color: hairline),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  button: true,
                  label: items[i],
                  excludeSemantics: true,
                  onTap: () => onTapQuery(items[i]),
                  child: EhPressable(
                    onPressed: () => onTapQuery(items[i]),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 16,
                          end: 8,
                        ),
                        child: Row(
                          children: <Widget>[
                            EhSvgIcon(
                              CupertinoIcons.clock,
                              size: 16,
                              color: palette.text3.resolveFrom(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                items[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: palette.text1.resolveFrom(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: l10n.delete,
                excludeSemantics: true,
                onTap: () => onRemoveQuery(items[i]),
                child: CupertinoButton(
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  onPressed: () => onRemoveQuery(items[i]),
                  child: EhSvgIcon(
                    CupertinoIcons.xmark,
                    size: 15,
                    color: palette.text3.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Result summary bar showing `"{scope}中 {count} 个结果"` and a `"选择"` button
/// to enter batch selection directly on favorites search results.
class FavSearchResultHeader extends StatelessWidget {
  const FavSearchResultHeader({
    super.key,
    required this.scopeLabel,
    required this.count,
    required this.selecting,
    required this.onEnterSelection,
  });

  final String scopeLabel;
  final int count;
  final bool selecting;
  final VoidCallback onEnterSelection;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.fav_search_count(count, scopeLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.text2.resolveFrom(context),
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
          if (!selecting)
            CupertinoButton(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: onEnterSelection,
              child: Text(
                l10n.fav_select,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: EhPalette.accent.resolveFrom(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty state for in-favorites search with explicit widening actions.
class FavSearchEmptyState extends StatelessWidget {
  const FavSearchEmptyState({
    super.key,
    required this.scopeLabel,
    required this.query,
    required this.canWidenFields,
    required this.canWidenFolders,
    required this.onSearchAllFields,
    required this.onSearchAllFolders,
  });

  final String scopeLabel;
  final String query;
  final bool canWidenFields;
  final bool canWidenFolders;
  final VoidCallback onSearchAllFields;
  final VoidCallback onSearchAllFolders;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final onAccent = EhPalette.onAccent.resolveFrom(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: EhSvgIcon(
                  CupertinoIcons.search,
                  size: 36,
                  color: palette.text3.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.fav_search_empty(query, scopeLabel),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: palette.text1.resolveFrom(context),
                ),
              ),
              if (canWidenFields) ...<Widget>[
                const SizedBox(height: 20),
                CupertinoButton(
                  color: accent,
                  borderRadius: BorderRadius.circular(22),
                  minSize: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  onPressed: onSearchAllFields,
                  child: Text(
                    l10n.fav_search_all_fields,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: onAccent,
                    ),
                  ),
                ),
              ],
              if (canWidenFolders) ...<Widget>[
                const SizedBox(height: 10),
                CupertinoButton(
                  color: palette.fill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(22),
                  minSize: 44,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  onPressed: onSearchAllFolders,
                  child: Text(
                    l10n.fav_search_all_folders,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: palette.text1.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Right-hand preview pane for unfolded flat iPhone Duo in-favorites search:
/// displays cover, highlighted title, folder badge, full highlighted favorite
/// note, and direct Read / Edit Note actions.
class FavSearchPreviewPane extends StatelessWidget {
  const FavSearchPreviewPane({
    super.key,
    required this.provider,
    required this.highlightQuery,
    this.tabTag,
    this.onNoteUpdated,
  });

  final GalleryProvider? provider;
  final String highlightQuery;
  final dynamic tabTag;
  final ValueChanged<String>? onNoteUpdated;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final l10n = L10n.of(context);
    if (provider == null) {
      return Center(
        child: EhSvgIcon(
          CupertinoIcons.search,
          size: 40,
          color: palette.text3.resolveFrom(context),
        ),
      );
    }

    return Obx(() {
      final overlaid = favoriteStates.overlay(provider!);
      final gid = overlaid.gid ?? '';
      final token = overlaid.token ?? '';
      final favcat = overlaid.favcat ?? '';
      final favTitle = overlaid.favTitle?.isNotEmpty == true
          ? overlaid.favTitle!
          : resolveFavSearchFolderLabel(context, favcat);
      final note = overlaid.favNote?.trim() ?? '';
      final accent = EhPalette.accent.resolveFrom(context);
      final onAccent = EhPalette.onAccent.resolveFrom(context);
      final hairline = palette.hairline.resolveFrom(context);

      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.viewPaddingOf(context).top + 20,
          MediaQuery.viewPaddingOf(context).right + 24,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 156,
                      height: 220,
                      child: CoverImg(
                        imgUrl: overlaid.imgUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  buildHighlightedTextSpan(
                    context: context,
                    text: overlaid.englishTitle ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: palette.text1.resolveFrom(context),
                    ),
                    highlightQuery: highlightQuery,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    EhSvgIcon(
                      CupertinoIcons.heart_fill,
                      size: 13,
                      color: favcatDisplayColor(context, favcat),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        l10n.fav_saved_in(favTitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.text2.resolveFrom(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: CupertinoButton(
                        color: accent,
                        borderRadius: BorderRadius.circular(24),
                        minSize: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () => NavigatorUtil.goGalleryPage(
                          galleryProvider: overlaid,
                          tabTag: tabTag,
                        ),
                        child: Text(
                          l10n.read,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: onAccent,
                          ),
                        ),
                      ),
                    ),
                    if (isNetworkFavoriteCategory(favcat)) ...<Widget>[
                      const SizedBox(width: 10),
                      CupertinoButton(
                        color: palette.fill.resolveFrom(context),
                        borderRadius: BorderRadius.circular(24),
                        minSize: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () async {
                          final updated = await showFavoriteNoteEditSheet(
                            context,
                            gid: gid,
                            token: token,
                            favcat: favcat,
                            favTitle: favTitle,
                            initialNote: note,
                          );
                          if (updated != null) {
                            onNoteUpdated?.call(updated);
                          }
                        },
                        child: Text(
                          note.isEmpty ? l10n.fav_note_add : l10n.fav_note_edit,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: palette.text1.resolveFrom(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Container(height: 0.5, color: hairline),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: note.isNotEmpty
                      ? Text.rich(
                          buildHighlightedTextSpan(
                            context: context,
                            text: note,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
                              color: palette.text1.resolveFrom(context),
                            ),
                            highlightQuery: highlightQuery,
                          ),
                        )
                      : Text(
                          l10n.favorite_note_hint,
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.text3.resolveFrom(context),
                          ),
                        ),
                ),
                Container(height: 0.5, color: hairline),
              ],
            ),
          ),
        ),
      );
    });
  }
}
