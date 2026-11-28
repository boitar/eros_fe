import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/favcat.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:flutter/cupertino.dart';

/// Resolves the heart color for [favId], lightening `fav0` (`#5F5F5F`) to
/// `#8E8E93` in dark mode so it remains clearly legible against dark surfaces.
Color favcatDisplayColor(BuildContext context, String? favId) {
  final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
  if (favId == '0' && dark) {
    return const Color(0xFF8E8E93);
  }
  return ThemeColors.favColorFor(favId);
}

/// Two-column color-coded favorite folder grid shared by the batch-move sheet
/// and the in-favorites search folder picker.
///
/// All 10 network folders (`0`–`9`) fit on a single screen in 5 rows × 2
/// columns at 50pt row height without nested boxes.
class FavcatGrid extends StatelessWidget {
  const FavcatGrid({
    super.key,
    required this.favcats,
    required this.onSelect,
    this.disabledFavId,
    this.selectedFavId,
    this.showAllOption = false,
    this.allTotalCount,
  });

  final List<Favcat> favcats;
  final ValueChanged<Favcat> onSelect;
  final String? disabledFavId;
  final String? selectedFavId;
  final bool showAllOption;
  final int? allTotalCount;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final networkFolders = favcats
        .where((f) => f.favId != 'a' && f.favId != 'l')
        .toList(growable: false);
    final allFolder = favcats.cast<Favcat?>().firstWhere(
          (f) => f?.favId == 'a',
          orElse: () => null,
        );
    final totalCount = allTotalCount ??
        allFolder?.totNum ??
        networkFolders.fold<int>(0, (sum, f) => sum + (f.totNum ?? 0));

    final rows = <Widget>[];
    for (var i = 0; i < networkFolders.length; i += 2) {
      final left = networkFolders[i];
      final right = i + 1 < networkFolders.length ? networkFolders[i + 1] : null;
      if (i > 0) {
        rows.add(const SizedBox(height: 8));
      }
      rows.add(
        Row(
          children: <Widget>[
            Expanded(
              child: _FavcatTile(
                favcat: left,
                disabled: disabledFavId == left.favId,
                selected: selectedFavId == left.favId,
                onTap: () => onSelect(left),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: right != null
                  ? _FavcatTile(
                      favcat: right,
                      disabled: disabledFavId == right.favId,
                      selected: selectedFavId == right.favId,
                      onTap: () => onSelect(right),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showAllOption) ...<Widget>[
            _FavcatTile(
              favcat: Favcat(
                favId: 'a',
                favTitle: l10n.sp_all_favcats,
                totNum: totalCount,
              ),
              disabled: disabledFavId == 'a',
              selected: selectedFavId == 'a',
              isAllOption: true,
              onTap: () => onSelect(
                allFolder ??
                    Favcat(
                      favId: 'a',
                      favTitle: l10n.sp_all_favcats,
                      totNum: totalCount,
                    ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...rows,
        ],
      ),
    );
  }
}

class _FavcatTile extends StatelessWidget {
  const _FavcatTile({
    required this.favcat,
    required this.disabled,
    required this.selected,
    required this.onTap,
    this.isAllOption = false,
  });

  final Favcat favcat;
  final bool disabled;
  final bool selected;
  final VoidCallback onTap;
  final bool isAllOption;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final l10n = L10n.of(context);
    final heartColor = isAllOption
        ? palette.text2.resolveFrom(context)
        : favcatDisplayColor(context, favcat.favId);
    final bgColor = selected
        ? heartColor.withValues(alpha: 0.14)
        : palette.fill.resolveFrom(context);
    final borderColor = selected ? heartColor : CupertinoColors.transparent;
    final trailingText = disabled
        ? l10n.fav_current
        : (favcat.totNum != null ? '${favcat.totNum}' : '');

    final content = Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: selected ? 1.5 : 0.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            EhSvgIcon(
              isAllOption
                  ? CupertinoIcons.square_grid_2x2
                  : CupertinoIcons.heart_fill,
              size: 15,
              color: heartColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                favcat.favTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: palette.text1.resolveFrom(context),
                ),
              ),
            ),
            if (trailingText.isNotEmpty) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: disabled ? FontWeight.w500 : FontWeight.w400,
                  color: palette.text2.resolveFrom(context),
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      selected: selected,
      label: disabled
          ? '${favcat.favTitle}, ${l10n.fav_current}'
          : favcat.favTitle,
      excludeSemantics: true,
      onTap: disabled ? null : onTap,
      child: EhPressable(
        borderRadius: BorderRadius.circular(12),
        onPressed: disabled ? null : onTap,
        child: content,
      ),
    );
  }
}
