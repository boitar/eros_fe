import 'package:eros_fe/common/controller/advance_search_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/filter/gallery_filter_view.dart';
import 'package:eros_fe/pages/tab/controller/gallery_filter_controller.dart';
import 'package:eros_fe/utils/logger.dart';
import 'package:eros_fe/utils/utility.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// Category toggle pill used in [GalleryCatFilter].
class GalleryCatButton extends StatelessWidget {
  const GalleryCatButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.onColor,
    Color? offColor,
    this.onTextColor,
    Color? offTextColor,
    required this.text,
    this.onLongPress,
  })  : offColor = offColor ?? onColor,
        offTextColor = offTextColor ?? onTextColor;

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onLongPress;
  final String text;
  final Color? onColor;
  final Color? offColor;
  final Color? onTextColor;
  final Color? offTextColor;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final catColor = onColor ?? EhPalette.accent.resolveFrom(context);
    final selected = value;
    final bg = selected
        ? catColor
        : palette.fill.resolveFrom(context).withValues(alpha: .55);
    final fg = selected
        ? (onTextColor ?? CupertinoColors.white)
        : palette.text1.resolveFrom(context);
    final border = selected
        ? catColor
        : EhPalette.separator.resolveFrom(context);

    return Semantics(
      button: true,
      selected: selected,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: onLongPress == null
            ? null
            : () {
                vibrateUtil.medium();
                onLongPress!();
              },
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          pressedOpacity: 0.72,
          onPressed: () {
            vibrateUtil.light();
            // GalleryCatFilter stores excluded bits, so onChanged receives the
            // previous/excluded state semantics (`!newValue`).
            onChanged(selected);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border, width: 0.8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!selected) ...[
                    Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: BoxDecoration(
                        color: catColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    text,
                    maxLines: 1,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .textStyle
                        .copyWith(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          letterSpacing: 0,
                          height: 1.15,
                          color: fg,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 10-category filter grid mapped to e-hentai's excluded `f_cats` bitmask.
class GalleryCatFilter extends StatefulWidget {
  const GalleryCatFilter({
    super.key,
    required this.catNum,
    required this.onCatNumChanged,
    this.margin,
    this.padding,
    this.crossAxisCount,
    this.maxCrossAxisExtent,
  }) : assert(!(crossAxisCount == null && maxCrossAxisExtent == null));

  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final int catNum;
  final ValueChanged<int> onCatNumChanged;
  final int? crossAxisCount;
  final double? maxCrossAxisExtent;

  @override
  State<GalleryCatFilter> createState() => _GalleryCatFilterState();
}

class _GalleryCatFilterState extends State<GalleryCatFilter> {
  late int _catNum = widget.catNum;

  @override
  void didUpdateWidget(GalleryCatFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catNum != widget.catNum) {
      _catNum = widget.catNum;
    }
  }

  Map<String, bool> get _catMap => EHUtils.convNumToCatMap(_catNum);

  List<Widget> get _catButtonList => EHConst.cats.keys
      .map(
        (String catName) => GalleryCatButton(
          key: ValueKey('filter_cat_$catName'),
          text: catName,
          onColor: ThemeColors.catColor[catName],
          value: _catMap[catName] ?? true,
          onChanged: (bool wasSelected) {
            logger.t('$catName changed to ${!wasSelected}');
            setState(() {
              final tempMap = _catMap;
              tempMap[catName] = !wasSelected;
              _catNum = EHUtils.convCatMapToNum(tempMap);
              widget.onCatNumChanged(_catNum);
            });
          },
          onLongPress: () {
            final tempMap = _catMap;
            final bool selState = tempMap[catName] ?? true;
            logger.t('onLongPress [$catName] [$selState]');

            tempMap.forEach((key, value) {
              if (key != catName) {
                tempMap[key] = !selState;
              }
            });

            setState(() {
              _catNum = EHUtils.convCatMapToNum(tempMap);
              widget.onCatNumChanged(_catNum);
            });
          },
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    if (widget.crossAxisCount == null && widget.maxCrossAxisExtent == null) {
      throw EhError(
          error: 'crossAxisCount and maxCrossAxisExtent cannot be both null');
    }

    final Widget gridView = widget.crossAxisCount != null
        ? GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: widget.crossAxisCount!,
            childAspectRatio: widget.crossAxisCount! >= 5 ? 2.15 : 3.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 6,
            padding: EdgeInsets.zero,
            children: _catButtonList,
          )
        : GridView.extent(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            maxCrossAxisExtent: widget.maxCrossAxisExtent!,
            childAspectRatio: 3.0,
            mainAxisSpacing: 8,
            crossAxisSpacing: 6,
            padding: EdgeInsets.zero,
            children: _catButtonList,
          );

    return Container(
      margin: widget.margin,
      padding: widget.padding,
      child: gridView,
    );
  }
}

class AdvanceSearchSwitchItem extends StatelessWidget {
  const AdvanceSearchSwitchItem({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.expand = true,
  });

  final String title;
  final bool? value;
  final ValueChanged<bool> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.start,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      color: palette.text1.resolveFrom(context),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoSwitch(
              value: value ?? false,
              activeTrackColor: EhPalette.accent.resolveFrom(context),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Presents the search filter sheet (Flutter [EhSheet] across all platforms).
Future<void> showFilterSetting() {
  final context = Get.overlayContext ?? Get.context!;
  return presentFilterSheet(context);
}

Future<void> presentFilterSheet(BuildContext context) {
  final ehSettingService = Get.find<EhSettingService>();
  final advanceSearchController = Get.find<AdvanceSearchController>();
  final filterController = Get.put(GalleryFilterController());

  void resetAll() {
    vibrateUtil.light();
    ehSettingService.catFilter.value = 0;
    advanceSearchController.enableAdvance = false;
    advanceSearchController.reset();
    filterController.statrPageCtrl.clear();
    filterController.endPageCtrl.clear();
  }

  return showEhSheet<void>(
    context: context,
    builder: (sheetContext) {
      final l10n = L10n.of(sheetContext);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EhSheetHeader(
            title: l10n.sp_filter,
            trailing: EhButton(
              key: const ValueKey('filter_reset'),
              label: l10n.sp_reset,
              style: EhButtonStyle.destructive,
              size: 32,
              onPressed: resetAll,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Obx(
                () => GalleryFilterView(
                  catNum: ehSettingService.catFilter.value,
                  catNumChanged: (int toNum) {
                    ehSettingService.catFilter.value = toNum;
                  },
                  catCrossAxisCount: 5,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: EhButton(
              key: const ValueKey('filter_done'),
              label: l10n.sp_done,
              style: EhButtonStyle.prominent,
              size: 50,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        ],
      );
    },
  );
}
