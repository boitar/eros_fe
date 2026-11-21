import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:eros_fe/adaptive/native_single_bar_edge.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/search_image_controller.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/view/gallery_base.dart';
import 'package:eros_fe/pages/tab/view/list/tab_base.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class SearchImagePage extends StatefulWidget {
  const SearchImagePage({super.key});

  @override
  State<SearchImagePage> createState() => _SearchImagePageState();
}

class _SearchImagePageState extends State<SearchImagePage> {
  static const double _wideWidthThreshold = 700;
  static const double _wideUsableThreshold = 560;
  static const double _wideControlColumnWidth = 320;
  static const double _summaryBarHeight = 56;
  static const double _summaryBarVerticalPadding = 12;

  bool _editingWithResults = false;

  SearchImageController get controller => Get.find<SearchImageController>();

  Future<void> _startSearch() async {
    if (controller.imagePath.isEmpty) {
      return;
    }
    setState(() {
      _editingWithResults = false;
    });
    await controller.startSearch();
  }

  Future<void> _pickImage(BuildContext context) async {
    await controller.selectSearchImage(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final nativeChrome = NativeNavigationScope.isEnabled(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final safeLeft = math.max(media.padding.left, media.viewPadding.left);
        final safeRight = math.max(
          media.padding.right,
          media.viewPadding.right,
        );
        final usableWidth = constraints.maxWidth - safeLeft - safeRight;
        final isWide =
            constraints.maxWidth >= _wideWidthThreshold &&
            usableWidth >= _wideUsableThreshold;

        return Obx(() {
          final hasImage = controller.imagePath.isNotEmpty;
          final hasResults = controller.listType == ListType.gallery;
          final showNarrowSummary =
              !isWide && hasResults && hasImage && !_editingWithResults;

          return SettingScaffold(
            title: l10n.search_by_image,
            nativeBars: nativeChrome && showNarrowSummary
                ? _summaryBarHeight + _summaryBarVerticalPadding
                : 0,
            nativeForeground: nativeChrome && showNarrowSummary
                ? Positioned(
                    top: media.viewPadding.top,
                    left: safeLeft,
                    right: safeRight,
                    child: _buildSummaryBarWrapper(context, l10n),
                  )
                : null,
            child: Builder(
              builder: (innerContext) {
                final innerMedia = MediaQuery.of(innerContext);
                final safeTop = math.max(
                  innerMedia.padding.top,
                  innerMedia.viewPadding.top,
                );
                final safeBottom = math.max(
                  innerMedia.padding.bottom,
                  innerMedia.viewPadding.bottom,
                );
                final innerLeft = math.max(
                  innerMedia.padding.left,
                  innerMedia.viewPadding.left,
                );
                final innerRight = math.max(
                  innerMedia.padding.right,
                  innerMedia.viewPadding.right,
                );

                if (isWide) {
                  return _buildWideLayout(
                    innerContext,
                    l10n: l10n,
                    safeTop: safeTop,
                    safeBottom: safeBottom,
                    safeLeft: innerLeft,
                    safeRight: innerRight,
                    hasResults: hasResults,
                  );
                }

                return _buildNarrowLayout(
                  innerContext,
                  l10n: l10n,
                  nativeChrome: nativeChrome,
                  showSummary: showNarrowSummary,
                  safeTop: safeTop,
                  safeBottom: safeBottom,
                  safeLeft: innerLeft,
                  safeRight: innerRight,
                );
              },
            ),
          );
        });
      },
    );
  }

  Widget _buildWideLayout(
    BuildContext context, {
    required L10n l10n,
    required double safeTop,
    required double safeBottom,
    required double safeLeft,
    required double safeRight,
    required bool hasResults,
  }) {
    final palette = ehTheme.palette;
    return Row(
      key: const ValueKey('search_image_wide_layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: safeLeft + _wideControlColumnWidth + 24,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              safeLeft + 16,
              safeTop + 12,
              12,
              safeBottom + 20,
            ),
            child: _buildControlsColumn(context, l10n),
          ),
        ),
        Container(width: 0.5, color: palette.hairline.resolveFrom(context)),
        Expanded(
          child: hasResults
              ? _buildResultsScrollView(
                  context,
                  topSpacer: safeTop + 8,
                  leftPadding: 8,
                  rightPadding: safeRight + 8,
                  bottomPadding: safeBottom + 16,
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    safeTop + 16,
                    safeRight + 16,
                    safeBottom + 16,
                  ),
                  child: _buildEmptyResultsPlaceholder(context, l10n),
                ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context, {
    required L10n l10n,
    required bool nativeChrome,
    required bool showSummary,
    required double safeTop,
    required double safeBottom,
    required double safeLeft,
    required double safeRight,
  }) {
    if (!showSummary) {
      return SingleChildScrollView(
        key: const ValueKey('search_image_narrow_layout'),
        padding: EdgeInsets.fromLTRB(
          safeLeft + 16,
          safeTop + 12,
          safeRight + 16,
          safeBottom + 24,
        ),
        child: _buildControlsColumn(
          context,
          l10n,
          showCancelEdit:
              _editingWithResults && controller.listType == ListType.gallery,
        ),
      );
    }

    const barTotalHeight = _summaryBarHeight + _summaryBarVerticalPadding;
    final scrollView = _buildResultsScrollView(
      context,
      key: const ValueKey('search_image_narrow_layout'),
      topSpacer: safeTop + barTotalHeight + 4,
      leftPadding: safeLeft,
      rightPadding: safeRight,
      bottomPadding: safeBottom + 16,
    );

    if (nativeChrome) {
      return scrollView;
    }

    return NativeSingleBarEdge(
      enabled: true,
      inset: safeTop,
      bars: barTotalHeight,
      foreground: Positioned(
        top: safeTop,
        left: safeLeft,
        right: safeRight,
        child: _buildSummaryBarWrapper(context, l10n),
      ),
      child: scrollView,
    );
  }

  Widget _buildControlsColumn(
    BuildContext context,
    L10n l10n, {
    bool showCancelEdit = false,
  }) {
    final hasImage = controller.imagePath.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PickerCard(
          imagePath: controller.imagePath,
          onPick: () => _pickImage(context),
          onClear: () {
            setState(() {
              _editingWithResults = false;
            });
            controller.clearImage();
          },
        ),
        const SizedBox(height: 16),
        EhSheetSectionLabel(l10n.sp_image_search_options),
        EhSheetGroup(
          children: [
            _SwitchRow(
              switchKey: const ValueKey('search_image_similar_switch'),
              title: l10n.sp_similar_scan,
              value: controller.similarScan.value,
              onChanged: (val) => controller.similarScan.value = val,
            ),
            _SwitchRow(
              switchKey: const ValueKey('search_image_covers_switch'),
              title: l10n.sp_only_covers,
              value: controller.onlyCovers.value,
              onChanged: (val) => controller.onlyCovers.value = val,
            ),
            _SwitchRow(
              switchKey: const ValueKey('search_image_expunged_switch'),
              title: l10n.sp_include_expunged,
              value: controller.includeExpunged.value,
              onChanged: (val) => controller.includeExpunged.value = val,
            ),
          ],
        ),
        const SizedBox(height: 20),
        EhButton(
          key: const ValueKey('search_image_start_button'),
          label: l10n.sp_start_search,
          icon: CupertinoIcons.search,
          style: EhButtonStyle.prominent,
          size: 50,
          expand: true,
          onPressed: hasImage ? _startSearch : null,
        ),
        if (showCancelEdit) ...[
          const SizedBox(height: 10),
          EhButton(
            label: l10n.cancel,
            style: EhButtonStyle.tonal,
            size: 44,
            expand: true,
            onPressed: () {
              setState(() {
                _editingWithResults = false;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryBarWrapper(BuildContext context, L10n l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: _ImageSummaryBar(
        key: const ValueKey('search_image_summary_bar'),
        height: _summaryBarHeight,
        imagePath: controller.imagePath,
        summaryText: _activeOptionsSummary(l10n),
        changeLabel: l10n.sp_change_image,
        searchSemanticLabel: l10n.sp_start_search,
        onTapSummary: () {
          setState(() {
            _editingWithResults = true;
          });
        },
        onChangeImage: () => _pickImage(context),
        onSearch: _startSearch,
      ),
    );
  }

  String _activeOptionsSummary(L10n l10n) {
    final parts = <String>[];
    if (controller.similarScan.value) {
      parts.add(l10n.sp_similar_scan);
    }
    if (controller.onlyCovers.value) {
      parts.add(l10n.sp_only_covers);
    }
    if (controller.includeExpunged.value) {
      parts.add(l10n.sp_include_expunged);
    }
    if (parts.isEmpty) {
      return l10n.search_by_image;
    }
    return parts.join(' · ');
  }

  Widget _buildEmptyResultsPlaceholder(BuildContext context, L10n l10n) {
    final palette = ehTheme.palette;
    final hasImage = controller.imagePath.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.photo_on_rectangle,
            size: 44,
            color: palette.text3.resolveFrom(context),
          ),
          const SizedBox(height: 12),
          Text(
            hasImage ? l10n.sp_start_search : l10n.sp_pick_image,
            style: TextStyle(
              fontSize: 15,
              color: palette.text2.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsScrollView(
    BuildContext context, {
    Key? key,
    required double topSpacer,
    required double leftPadding,
    required double rightPadding,
    required double bottomPadding,
  }) {
    return CustomScrollView(
      key: key,
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topSpacer)),
        EhCupertinoSliverRefreshControl(
          onRefresh: () async {
            await controller.fetchData(refresh: true);
          },
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            leftPadding,
            0,
            rightPadding,
            bottomPadding,
          ),
          sliver: GetBuilder<SearchImageController>(
            global: false,
            init: controller,
            id: controller.listViewId,
            builder: (logic) {
              final status = logic.status;

              if (status.isLoading) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.only(bottom: 50),
                    child: const CupertinoActivityIndicator(radius: 14.0),
                  ),
                );
              }

              if (status.isError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 50),
                    child: GalleryErrorPage(
                      onTap: logic.reLoadDataFirst,
                      error: status.errorMessage,
                    ),
                  ),
                );
              }

              if (status.isSuccess) {
                return getGallerySliverList(
                  logic.state,
                  controller.tabIndex,
                  next: logic.next,
                  lastComplete: controller.lastComplete,
                  key: controller.sliverAnimatedListKey,
                  lastTopItemIndex: controller.lastTopitemIndex,
                  anchorController: logic.galleryAnchor,
                );
              }

              return SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  alignment: Alignment.center,
                  child: FaIcon(
                    FontAwesomeIcons.hippo,
                    size: 72,
                    color: CupertinoDynamicColor.resolve(
                      CupertinoColors.systemGrey,
                      context,
                    ),
                  ),
                ).autoCompressKeyboard(context),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.imagePath,
    required this.onPick,
    required this.onClear,
  });

  final String imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final hasImage = imagePath.isNotEmpty;

    if (!hasImage) {
      return Semantics(
        key: const ValueKey('search_image_picker_card'),
        button: true,
        label: l10n.sp_pick_image,
        excludeSemantics: true,
        onTap: onPick,
        child: EhPressable(
          onPressed: onPick,
          borderRadius: BorderRadius.circular(18),
          child: CustomPaint(
            painter: _DashedRRectPainter(
              color: palette.hairline.resolveFrom(context),
              strokeWidth: 1.5,
              radius: 18,
            ),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: palette.surface.resolveFrom(context),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        CupertinoIcons.photo,
                        size: 40,
                        color: EhPalette.accent.resolveFrom(context),
                      ),
                      Positioned(
                        right: -6,
                        bottom: -4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: EhPalette.accent.resolveFrom(context),
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              CupertinoIcons.plus,
                              size: 13,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.sp_pick_image,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: palette.text1.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('search_image_picker_card'),
      constraints: const BoxConstraints(minHeight: 150, maxHeight: 240),
      decoration: BoxDecoration(
        color: palette.surface.resolveFrom(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: palette.hairline.resolveFrom(context),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Image.file(
                File(imagePath),
                key: const ValueKey('search_image_preview'),
                fit: BoxFit.contain,
                errorBuilder: (context, _, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.photo,
                      size: 36,
                      color: palette.text3.resolveFrom(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      imagePath.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.text2.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                EhButton(
                  key: const ValueKey('search_image_change'),
                  label: l10n.sp_change_image,
                  icon: CupertinoIcons.photo,
                  style: EhButtonStyle.glass,
                  size: 32,
                  onPressed: onPick,
                ),
                const SizedBox(width: 6),
                EhButton(
                  key: const ValueKey('search_image_clear'),
                  icon: CupertinoIcons.xmark,
                  style: EhButtonStyle.glass,
                  size: 32,
                  semanticLabel: l10n.delete,
                  onPressed: onClear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSummaryBar extends StatelessWidget {
  const _ImageSummaryBar({
    super.key,
    required this.height,
    required this.imagePath,
    required this.summaryText,
    required this.changeLabel,
    required this.searchSemanticLabel,
    required this.onTapSummary,
    required this.onChangeImage,
    required this.onSearch,
  });

  final double height;
  final String imagePath;
  final String summaryText;
  final String changeLabel;
  final String searchSemanticLabel;
  final VoidCallback onTapSummary;
  final VoidCallback onChangeImage;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final glassOff = GlassMode.of(context) == GlassMode.off;

    return SizedBox(
      height: height,
      child: LiquidGlassSurface(
        enabled: true,
        useNativeGlass: false,
        emphasizeFallbackEdge: true,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: glassOff
              ? BoxDecoration(
                  color: palette.raised.resolveFrom(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: palette.hairline.resolveFrom(context),
                    width: 0.5,
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: L10n.of(context).sp_image_search_options,
                  onTap: onTapSummary,
                  child: EhPressable(
                    key: const ValueKey('search_image_edit_options'),
                    onPressed: onTapSummary,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Image.file(
                              File(imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, _) => ColoredBox(
                                color: palette.fill.resolveFrom(context),
                                child: Icon(
                                  CupertinoIcons.photo,
                                  size: 18,
                                  color: palette.text3.resolveFrom(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            summaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: palette.text1.resolveFrom(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              EhButton(
                key: const ValueKey('search_image_summary_change'),
                label: changeLabel,
                style: EhButtonStyle.tonal,
                size: 32,
                onPressed: onChangeImage,
              ),
              const SizedBox(width: 6),
              EhButton(
                key: const ValueKey('search_image_summary_search'),
                icon: CupertinoIcons.search,
                style: EhButtonStyle.prominent,
                size: 32,
                semanticLabel: searchSemanticLabel,
                onPressed: onSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.switchKey,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: palette.text1.resolveFrom(context),
              ),
            ),
          ),
          CupertinoSwitch(key: switchKey, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dashLength = 6.0;
    const gapLength = 5.0;

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}
