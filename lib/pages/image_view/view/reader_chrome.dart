import 'dart:math' as math;

import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../common.dart';
import '../controller/view_controller.dart';
import 'view_widget.dart';

/// Intervals offered directly in the auto page turn menu, in milliseconds.
const List<int> kReaderAutoReadIntervals = <int>[1000, 2000, 3000, 5000, 10000];

/// Publishes the reader's controls to the system navigation bar and toolbar
/// of the native shell. On iPhone Duo's outer display UIKit moves both into
/// the vertical bar; Flutter keeps only content controls in [ReaderDock].
class ReaderNativeChrome extends StatelessWidget {
  const ReaderNativeChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Each id below changes something the bars show.
    Widget listen(String id, Widget Function() builder) =>
        GetBuilder<ViewExtController>(id: id, builder: (_) => builder());
    return listen(
      idViewBar,
      () => listen(
        idViewTopBar,
        () => listen(
          idAutoReadIcon,
          () => listen(
            idShowThumbListIcon,
            () => listen(
              idViewColumnModeIcon,
              () => Obx(() => NativeNavigationPage(
                    chrome: readerChrome(context, Get.find()),
                    child: child,
                  )),
            ),
          ),
        ),
      ),
    );
  }

  static NativePageChrome readerChrome(
      BuildContext context, ViewExtController controller) {
    final l10n = L10n.of(context);
    final vState = controller.vState;
    final settings = vState.ehSettingService;
    final viewMode = vState.viewMode;
    final columnPreference = settings.readerColumnPreference;
    final interval = settings.turnPageInv;

    NativeNavigationAction option(
      String id,
      String title, {
      required bool checked,
      required VoidCallback onPressed,
    }) =>
        NativeNavigationAction(
          id: id,
          title: title,
          checked: checked,
          onPressed: onPressed,
        );

    void setViewMode(ViewMode mode) {
      if (settings.viewMode.value == mode) return;
      settings.viewMode.value = mode;
      controller.handOnViewModeChanged(mode);
    }

    void setSurface(ReaderSurfacePreference preference) {
      vState.surfacePreference = preference;
      controller.update([idViewBar]);
    }

    return NativePageChrome(
      title: '${vState.currentItemIndex + 1} / ${vState.fileCount}',
      titleMonospacedDigits: true,
      navigationBarVisible: vState.showBar,
      barStyle: NativeBarStyle.dark,
      animateBars: true,
      actions: [
        NativeNavigationAction(
          id: 'reader.share',
          title: l10n.share,
          symbol: 'square.and.arrow.up',
          onPressed: () => controller.tapShare(context),
        ),
        NativeNavigationAction(
          id: 'reader.more',
          title: l10n.read_setting,
          symbol: 'ellipsis.circle',
          children: [
            NativeNavigationAction(
              id: 'reader.direction',
              title: l10n.reading_direction,
              inline: true,
              children: [
                for (final entry in <ViewMode, String>{
                  ViewMode.leftToRight: l10n.left_to_right,
                  ViewMode.rightToLeft: l10n.right_to_left,
                  ViewMode.topToBottom: l10n.top_to_bottom,
                }.entries)
                  option(
                    'reader.direction.${entry.key.name}',
                    entry.value,
                    checked: viewMode == entry.key,
                    onPressed: () => setViewMode(entry.key),
                  ),
              ],
            ),
            NativeNavigationAction(
              id: 'reader.surface',
              title: l10n.reader_page_layout,
              inline: true,
              children: [
                for (final entry in <ReaderSurfacePreference, String>{
                  ReaderSurfacePreference.automatic: l10n.automatic,
                  ReaderSurfacePreference.tabletop: l10n.reader_surface_tabletop,
                  ReaderSurfacePreference.standard: l10n.reader_surface_standard,
                }.entries)
                  option(
                    'reader.surface.${entry.key.name}',
                    entry.value,
                    checked: vState.surfacePreference == entry.key,
                    onPressed: () => setSurface(entry.key),
                  ),
              ],
            ),
            NativeNavigationAction(
              id: 'reader.settings',
              title: '${l10n.read_setting}…',
              symbol: 'gearshape',
              onPressed: () async {
                controller.cancelVolumeKeydownListen();
                await Get.toNamed(EHRoutes.readSetting);
                controller.addVolumeKeydownListen();
              },
            ),
          ],
        ),
      ],
      toolbarActions: [
        NativeNavigationAction(
          id: 'reader.save',
          title: l10n.save,
          symbol: 'square.and.arrow.down',
          priority: NativeBarItemPriority.high,
          group: 'save',
          onPressed: () => controller.tapSave(context),
        ),
        NativeNavigationAction(
          id: 'reader.columns',
          title: l10n.double_page_model,
          symbol: 'book',
          enabled: viewMode != ViewMode.topToBottom,
          group: 'view',
          children: [
            for (final entry in <ReaderColumnPreference, String>{
              ReaderColumnPreference.automatic: l10n.automatic,
              ReaderColumnPreference.single: l10n.reader_single_page,
              ReaderColumnPreference.oddLeft: l10n.reader_double_odd_left,
              ReaderColumnPreference.evenLeft: l10n.reader_double_even_left,
            }.entries)
              option(
                'reader.columns.${entry.key.name}',
                entry.value,
                checked: columnPreference == entry.key,
                onPressed: () => controller.setColumnPreference(entry.key),
              ),
          ],
        ),
        NativeNavigationAction(
          id: 'reader.autoRead',
          title: l10n.reader_auto_read,
          symbol: 'timer',
          selected: vState.autoRead,
          primaryWithMenu: true,
          priority: NativeBarItemPriority.low,
          group: 'view',
          onPressed: () => vState.autoRead
              ? controller.cancelAutoRead()
              : controller.startAutoReadWithInterval(interval),
          children: [
            NativeNavigationAction(
              id: 'reader.autoRead.intervals',
              title: l10n.reader_auto_read_interval,
              inline: true,
              children: [
                for (final ms in kReaderAutoReadIntervals)
                  option(
                    'reader.autoRead.$ms',
                    l10n.reader_interval_seconds(ms ~/ 1000),
                    checked: interval == ms,
                    onPressed: () => controller.startAutoReadWithInterval(ms),
                  ),
                option(
                  'reader.autoRead.custom',
                  l10n.reader_custom_interval,
                  checked: !kReaderAutoReadIntervals.contains(interval),
                  onPressed: () => controller.pickAutoReadInterval(context),
                ),
              ],
            ),
          ],
        ),
        NativeNavigationAction(
          id: 'reader.thumbnails',
          title: l10n.thumbnails,
          symbol: 'photo.stack',
          selected: vState.showThumbList,
          priority: NativeBarItemPriority.high,
          group: 'view',
          onPressed: controller.switchShowThumbList,
        ),
      ],
    );
  }
}

/// Content controls the system bars cannot hold: the page scrubber and the
/// optional thumbnail filmstrip, floating above the toolbar without a slab.
class ReaderDock extends GetView<ViewExtController> {
  const ReaderDock({super.key});

  static const double scrubberHeight = 44;
  static const double margin = 8;
  static const double maxScrubberWidth = 640;

  static double heightFor({required bool thumbnails}) =>
      scrubberHeight +
      margin * 2 +
      (thumbnails ? kThumbListViewHeight + margin : 0);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ViewExtController>(
      id: idViewBottomBar,
      // The dock sits in a scroll view inside its pane; size it to the pane.
      builder: (logic) => Container(
        width: MediaQuery.sizeOf(context).width,
        padding: const EdgeInsets.fromLTRB(16, margin, 16, margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logic.vState.showThumbList) ...[
              const SizedBox(
                height: kThumbListViewHeight,
                child: ThumbnailListView(),
              ),
              const SizedBox(height: margin),
            ],
            GetBuilder<ViewExtController>(
              id: idViewPageSlider,
              builder: (logic) {
                final count = logic.vState.fileCount;
                if (count <= 1) {
                  return const SizedBox(height: scrubberHeight);
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: maxScrubberWidth,
                    minHeight: scrubberHeight,
                    maxHeight: scrubberHeight,
                  ),
                  child: LiquidGlassSurface(
                    enabled: true,
                    // A wide shell stays in Flutter composition; the slider
                    // and labels are drawn above it.
                    useNativeGlass: false,
                    borderRadius:
                        BorderRadius.circular(scrubberHeight / 2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ViewPageSlider(
                        max: count - 1.0,
                        sliderValue:
                            math.min(logic.vState.sliderValue, count - 1.0),
                        onChangedEnd: logic.handOnSliderChangedEnd,
                        onChanged: logic.handOnSliderChanged,
                        reverse: logic.vState.viewMode == ViewMode.rightToLeft,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
