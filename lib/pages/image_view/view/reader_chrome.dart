import 'dart:math' as math;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/gallery_title.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
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

/// Android's glass reader: the page fills the screen and the controls float
/// above it as glass capsules, instead of sitting on a blurred black slab.
bool usesGlassReaderChrome(BuildContext context) =>
    PlatformCapabilities.topSearchCapsule &&
    GlassMode.of(context) != GlassMode.off;

const Color _kGlassReaderIcon = Color(0xFFF2F3F6);

Widget _glass({
  required double radius,
  required Widget child,
  Key? key,
}) =>
    LiquidGlassSurface(
      key: key,
      enabled: true,
      useNativeGlass: false,
      // Media controls: clear glass shows more of the page beneath.
      style: LiquidGlassStyle.clear,
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );

Widget _glassIconButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) =>
    Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          vibrateUtil.light();
          onTap();
        },
        child: SizedBox.square(
          dimension: kTopBarButtonHeight + 4,
          child: Icon(icon, size: 22, color: _kGlassReaderIcon),
        ),
      ),
    );

/// Back · title and page · share and more, each on its own glass.
class ReaderGlassTopBar extends GetView<ViewExtController> {
  const ReaderGlassTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final adaptive = AdaptiveEnvironment.maybeOf(context);
    final wide = adaptive?.isWide ?? MediaQuery.sizeOf(context).width >= 600;
    final padding = MediaQuery.paddingOf(context);
    const double size = kTopBarButtonHeight + 4;
    final l10n = L10n.of(context);
    return SizedBox(
      height: padding.top + kTopBarHeight,
      width: MediaQuery.sizeOf(context).width,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(padding.left + 12, padding.top + 4, padding.right + 12, 4),
        child: Row(
          children: [
            _glass(
              key: const ValueKey<String>('reader-glass-back'),
              radius: size / 2,
              child: _glassIconButton(
                icon: Icons.arrow_back,
                label: l10n.back,
                onTap: Get.back,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _glass(
                key: const ValueKey<String>('reader-glass-title'),
                radius: size / 2,
                child: SizedBox(
                  height: size,
                  child: GetBuilder<ViewExtController>(
                    id: idViewTopBar,
                    builder: (logic) {
                      final state = logic.vState;
                      final title = GalleryTitleParts.parse(
                              state.pageState?.displayTitle ?? '')
                          .title;
                      final page =
                          '${state.currentItemIndex + 1} / ${state.fileCount}';
                      return MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (title.isNotEmpty)
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _kGlassReaderIcon,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              Text(
                                page,
                                style: TextStyle(
                                  color: _kGlassReaderIcon.withValues(
                                    alpha: title.isEmpty ? 1 : 0.78,
                                  ),
                                  fontSize: title.isEmpty ? 15 : 11,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _glass(
              key: const ValueKey<String>('reader-glass-actions'),
              radius: size / 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (wide) ...[
                    ControllerButtonBar(
                      controller: controller,
                      mainAxisSize: MainAxisSize.min,
                      buttonHeight: size,
                    ),
                    _glassIconButton(
                      icon: CupertinoIcons.square_split_1x2,
                      label: l10n.reader_page_layout,
                      onTap: controller.cycleSurfacePreference,
                    ),
                  ],
                  _glassIconButton(
                    icon: Icons.share_outlined,
                    label: l10n.share,
                    onTap: () => controller.tapShare(context),
                  ),
                  _glassIconButton(
                    icon: Icons.more_vert,
                    label: l10n.read_setting,
                    onTap: () async {
                      controller.cancelVolumeKeydownListen();
                      await Get.toNamed(EHRoutes.readSetting);
                      controller.addVolumeKeydownListen();
                    },
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

/// A glass panel with the optional filmstrip and the page scrubber, and on
/// narrow screens a glass toolbar below it.
class ReaderGlassBottomBar extends GetView<ViewExtController> {
  const ReaderGlassBottomBar({super.key});

  static const double sliderHeight = 44;
  static const double panelPadding = 10;
  static const double toolbarHeight = 60;
  static const double gap = 10;
  static const double margin = 12;

  static double heightFor({required bool thumbnails, required bool wide}) =>
      panelPadding * 2 +
      sliderHeight +
      (thumbnails ? kThumbListViewHeight + panelPadding : 0) +
      (wide ? 0 : gap + toolbarHeight) +
      margin;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ViewExtController>(
      id: idViewBottomBar,
      builder: (logic) {
        final adaptive = AdaptiveEnvironment.maybeOf(context);
        final wide =
            adaptive?.isWide ?? MediaQuery.sizeOf(context).width >= 600;
        final padding = MediaQuery.paddingOf(context);
        return Container(
          width: MediaQuery.sizeOf(context).width,
          padding: EdgeInsets.fromLTRB(
              padding.left + 12, 0, padding.right + 12, margin),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: ReaderDock.maxScrubberWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _glass(
                    key: const ValueKey<String>('reader-glass-panel'),
                    radius: 26,
                    child: Padding(
                      padding: const EdgeInsets.all(panelPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (logic.vState.showThumbList) ...[
                            const SizedBox(
                              height: kThumbListViewHeight,
                              child: ThumbnailListView(),
                            ),
                            const SizedBox(height: panelPadding),
                          ],
                          GetBuilder<ViewExtController>(
                            id: idViewPageSlider,
                            builder: (logic) {
                              final count = logic.vState.fileCount;
                              return SizedBox(
                                height: sliderHeight,
                                child: count <= 1
                                    ? const SizedBox.shrink()
                                    : ViewPageSlider(
                                        max: count - 1.0,
                                        sliderValue: math.min(
                                            logic.vState.sliderValue,
                                            count - 1.0),
                                        onChangedEnd:
                                            logic.handOnSliderChangedEnd,
                                        onChanged: logic.handOnSliderChanged,
                                        reverse: logic.vState.viewMode ==
                                            ViewMode.rightToLeft,
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!wide) ...[
                    const SizedBox(height: gap),
                    _glass(
                      key: const ValueKey<String>('reader-glass-tools'),
                      radius: toolbarHeight / 2,
                      child: SizedBox(
                        height: toolbarHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: GetBuilder<ViewExtController>(
                            id: idIconBar,
                            builder: (logic) => ControllerButtonBar(
                              controller: logic,
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              buttonHeight: toolbarHeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
