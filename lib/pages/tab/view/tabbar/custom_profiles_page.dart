import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/webdav_controller.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/component/setting/setting_scaffold.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/debug/offline_group_index.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/group/custom_tabbar_controller.dart';
import 'package:eros_fe/pages/tab/fetch_list.dart';
import 'package:eros_fe/widget/adaptive_reorderable_column.dart';
import 'package:eros_fe/widget/desktop_browse_style.dart';
import 'package:eros_fe/widget/desktop_control.dart';
import 'package:eros_fe/widget/desktop_gallery_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

class CustomProfilesPage extends GetView<CustomTabbarController> {
  const CustomProfilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!PlatformCapabilities.isDesktop) {
      return _buildMobile(context);
    }
    return _buildDesktop(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          controller.reorderable = false;
        }
      },
      child: NativeNavigationPage(
        chrome: NativePageChrome(
          title: l10n.group_management,
          navigationBarVisible: false,
          ownBar: true,
        ),
        child: CupertinoPageScaffold(
          backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              DesktopPaneHeader(
                title: l10n.group_management,
                leading: [
                  DesktopControl(
                    key: const ValueKey('desktop-groups-back'),
                    label: l10n.back,
                    minSize: 30,
                    radius: 8,
                    padding: const EdgeInsets.all(6),
                    onPressed: () {
                      controller.reorderable = false;
                      Navigator.maybePop(context);
                    },
                    child: const EhSvgIcon(CupertinoIcons.chevron_back, size: 16),
                  ),
                ],
                badge: Obx(
                  () => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.fill.resolveFrom(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${controller.profiles.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: palette.text2.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
                trailing: [
                  Obx(() {
                    final reorderable = controller.reorderable;
                    final showSync =
                        !reorderable &&
                        Get.isRegistered<WebdavController>() &&
                        Get.find<WebdavController>().syncGroupProfile;
                    if (reorderable) {
                      return offlineGroupControl(
                        'reorder',
                        DesktopToolbarPill(
                          key: const ValueKey('desktop-groups-reorder-done'),
                          label: l10n.done,
                          icon: CupertinoIcons.checkmark,
                          iconSize: 13,
                          tone: DesktopPillTone.prominent,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          onPressed: () => controller.reorderable = false,
                        ),
                      );
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showSync) ...[
                          DesktopControl(
                            key: const ValueKey('desktop-groups-sync'),
                            label: l10n.sync_group,
                            minSize: 30,
                            radius: 8,
                            padding: const EdgeInsets.all(6),
                            onPressed: controller.syncProfiles,
                            child: const EhSvgIcon(
                              CupertinoIcons.arrow_2_circlepath,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 2),
                        ],
                        offlineGroupControl(
                          'reorder',
                          DesktopControl(
                            key: const ValueKey('desktop-groups-reorder'),
                            label: l10n.tab_sort,
                            minSize: 30,
                            radius: 8,
                            padding: const EdgeInsets.all(6),
                            onPressed: () => controller.reorderable = true,
                            child: const EhSvgIcon(
                              CupertinoIcons.arrow_up_arrow_down,
                              size: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        DesktopToolbarPill(
                          key: const ValueKey('desktop-groups-add'),
                          label: l10n.newGroup,
                          icon: CupertinoIcons.add,
                          tone: DesktopPillTone.tonal,
                          onPressed: controller.toEditPage,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              Expanded(
                child: Obx(() {
                  final profiles = controller.profiles.toList();
                  final reorderable = controller.reorderable;
                  final currentUuid = controller.currProfileUuid;
                  final editingUuid = controller.editingProfileUuid;

                  if (profiles.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EhSvgIcon(
                              CupertinoIcons.folder,
                              size: 28,
                              color: palette.text3.resolveFrom(context),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.desktop_no_groups,
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.text2.resolveFrom(context),
                              ),
                            ),
                            const SizedBox(height: 14),
                            DesktopToolbarPill(
                              key: const ValueKey('desktop-groups-add-empty'),
                              label: l10n.newGroup,
                              icon: CupertinoIcons.add,
                              tone: DesktopPillTone.tonal,
                              onPressed: controller.toEditPage,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    child: reorderable
                        ? AdaptiveReorderableColumn(
                            onReorder: controller.onReorder,
                            children: [
                              for (var i = 0; i < profiles.length; i++)
                                Padding(
                                  key: ValueKey(profiles[i].uuid),
                                  padding: EdgeInsets.only(
                                    bottom: i == profiles.length - 1 ? 0 : 6,
                                  ),
                                  child: _DesktopGroupCard(
                                    profile: profiles[i],
                                    current: profiles[i].uuid == currentUuid,
                                    editing: profiles[i].uuid == editingUuid,
                                    reorderable: true,
                                    index: i,
                                    totalCount: profiles.length,
                                    onMoveUp: i > 0
                                        ? () => controller.onReorder(i, i - 1)
                                        : null,
                                    onMoveDown: i < profiles.length - 1
                                        ? () => controller.onReorder(i, i + 1)
                                        : null,
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < profiles.length; i++) ...[
                                _DesktopGroupCard(
                                  profile: profiles[i],
                                  current: profiles[i].uuid == currentUuid,
                                  editing: profiles[i].uuid == editingUuid,
                                  reorderable: false,
                                  index: i,
                                  totalCount: profiles.length,
                                  onTap: () => controller.toEditPage(
                                    uuid: profiles[i].uuid,
                                  ),
                                  onSecondaryTap: (position) =>
                                      _showGroupContextMenu(
                                        context,
                                        profiles[i],
                                        position,
                                      ),
                                  onEdit: () => controller.toEditPage(
                                    uuid: profiles[i].uuid,
                                  ),
                                  onDelete: () => controller.confirmDeleteGroup(
                                    context,
                                    profiles[i],
                                  ),
                                ),
                                if (i < profiles.length - 1)
                                  const SizedBox(height: 6),
                              ],
                              const SizedBox(height: 8),
                              _DesktopGhostAddButton(
                                key: const ValueKey(
                                  'desktop-groups-add-footer',
                                ),
                                label: l10n.newGroup,
                                onPressed: controller.toEditPage,
                              ),
                            ],
                          ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGroupContextMenu(
    BuildContext context,
    CustomProfile profile,
    Offset position,
  ) {
    final l10n = L10n.of(context);
    return showDesktopGalleryMenu(
      context,
      position: position,
      title: profile.name,
      entries: [
        DesktopMenuEntry(
          label: l10n.edit,
          icon: CupertinoIcons.pencil,
          onSelected: () => controller.toEditPage(uuid: profile.uuid),
        ),
        DesktopMenuEntry(
          dividerBefore: true,
          destructive: true,
          label: l10n.delete,
          icon: CupertinoIcons.trash,
          onSelected: () => controller.confirmDeleteGroup(context, profile),
        ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    final Widget shortDivider = Container(
      margin: const EdgeInsetsDirectional.only(start: 20),
      color: CupertinoColors.separator.resolveFrom(context),
      height: 0.5,
    );

    Widget buildNormalItem(CustomProfile element, {bool isLast = false}) {
      Widget buildTile({Key? key}) => EhCupertinoListTile(
        key: key,
        title: Text(element.name),
        trailing: const CupertinoListTileChevron(),
        onTap: () {
          controller.toEditPage(uuid: element.uuid);
        },
      );

      return Slidable(
        key: ValueKey(element.uuid),
        endActionPane: ActionPane(
          extentRatio: 0.25,
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => controller.deleteProfile(uuid: element.uuid),
              backgroundColor: CupertinoDynamicColor.resolve(
                CupertinoColors.systemRed,
                context,
              ),
              foregroundColor: Colors.white,
              icon: CupertinoIcons.delete,
              // label: L10n.of(context).delete,
            ),
          ],
        ),
        child: isLast
            ? buildTile(key: ValueKey(element.uuid))
            : Column(
                key: ValueKey(element.uuid),
                children: [buildTile(), shortDivider],
              ),
      );
    }

    Widget buildReorderableItem(CustomProfile element, {bool isLast = false}) {
      Widget _tile({Key? key}) => EhCupertinoListTile(
        key: key,
        trailing: const EhSvgIcon(CupertinoIcons.bars),
        title: Text(element.name),
      );

      if (isLast) {
        return _tile(key: ValueKey(element.uuid));
      } else {
        return Column(
          key: ValueKey(element.uuid),
          children: [_tile(), shortDivider],
        );
      }
    }

    Widget normalView = Obx(() {
      return Column(
        children: () {
          final List<Widget> _list = <Widget>[];
          for (var i = 0; i < controller.profiles.length; i++) {
            _list.add(
              buildNormalItem(
                controller.profiles[i],
                isLast: i == controller.profiles.length - 1,
              ),
            );
          }
          return _list;
        }(),
      );
    });

    Widget reorderableView = Obx(() {
      return AdaptiveReorderableColumn(
        onReorder: controller.onReorder,
        children: () {
          final List<Widget> _list = <Widget>[];
          for (var i = 0; i < controller.profiles.length; i++) {
            _list.add(
              buildReorderableItem(
                controller.profiles[i],
                isLast: i == controller.profiles.length - 1,
              ),
            );
          }
          return _list;
        }(),
      );
    });

    return WillPopScope(
      onWillPop: () async {
        controller.reorderable = false;
        return true;
      },
      child: SettingScaffold(
        title: L10n.of(context).group,
        // Beside an open group the list keeps its own buttons.
        nativeChrome: false,
        trailing: Obx(() {
          final reorderable = controller.reorderable;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (Get.find<WebdavController>().syncGroupProfile && !reorderable)
                CupertinoButton(
                  minSize: 40,
                  padding: EdgeInsets.zero,
                  onPressed: controller.syncProfiles,
                  child: const EhSvgIcon(
                    CupertinoIcons.arrow_2_circlepath,
                    size: 22,
                  ),
                ),
              offlineGroupControl(
                'reorder',
                CupertinoButton(
                  minSize: 40,
                  padding: EdgeInsets.zero,
                  onPressed: () => controller.reorderable = !reorderable,
                  child: EhSvgIcon(
                    reorderable
                        ? CupertinoIcons.checkmark
                        : CupertinoIcons.arrow_up_arrow_down,
                    size: 22,
                  ),
                ),
              ),
              if (!reorderable)
                CupertinoButton(
                  minSize: 40,
                  padding: EdgeInsets.zero,
                  onPressed: controller.toEditPage,
                  child: const EhSvgIcon(CupertinoIcons.add, size: 22),
                ),
            ],
          );
        }),
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              sliver: SliverCupertinoListSection.listInsetGrouped(
                children: [
                  Obx(() {
                    return Column(
                      children: [
                        AnimatedCrossFade(
                          secondChild: normalView,
                          firstChild: reorderableView,
                          crossFadeState: controller.reorderable
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: 300.milliseconds,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopGroupCard extends StatefulWidget {
  const _DesktopGroupCard({
    required this.profile,
    required this.current,
    required this.editing,
    required this.reorderable,
    required this.index,
    required this.totalCount,
    this.onTap,
    this.onSecondaryTap,
    this.onEdit,
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  final CustomProfile profile;
  final bool current;
  final bool editing;
  final bool reorderable;
  final int index;
  final int totalCount;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onSecondaryTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  State<_DesktopGroupCard> createState() => _DesktopGroupCardState();
}

class _DesktopGroupCardState extends State<_DesktopGroupCard> {
  bool _hover = false;
  bool _focus = false;

  IconData _iconFor(GalleryListType type) => switch (type) {
    GalleryListType.popular => CupertinoIcons.flame,
    GalleryListType.watched => CupertinoIcons.eye,
    _ => CupertinoIcons.collections,
  };

  String _listTypeLabel(L10n l10n, GalleryListType type) => switch (type) {
    GalleryListType.popular => l10n.tab_popular,
    GalleryListType.watched => l10n.tab_watched,
    _ => l10n.tab_gallery,
  };

  List<Widget> _buildMetadata(BuildContext context, L10n l10n) {
    final palette = ehTheme.palette;
    final profile = widget.profile;
    final listType = profile.listType;
    final items = <Widget>[
      Text(
        _listTypeLabel(l10n, listType),
        style: TextStyle(fontSize: 11.5, color: palette.text2.resolveFrom(context)),
      ),
    ];

    if (profile.listMode != ListModeEnum.global) {
      final labels = desktopListModeLabels(l10n, includeDebug: true);
      final modeLabel = labels[profile.listMode];
      if (modeLabel != null) {
        items.add(
          Text(
            '· $modeLabel',
            style: TextStyle(
              fontSize: 11.5,
              color: palette.text2.resolveFrom(context),
            ),
          ),
        );
      }
    }

    if (listType != GalleryListType.popular) {
      final cats = profile.cats ?? 0;
      if (cats != 0) {
        final selectedCats = EHUtils.convNumToCatMap(cats)
            .entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();
        final catSummary = selectedCats.length == 1
            ? selectedCats.first
            : '${l10n.sp_category} ${selectedCats.length}/${EHConst.cats.length}';
        items.add(_MetaChip(label: catSummary));
      }

      final keywords = (profile.searchText ?? const <dynamic>[])
          .map((e) => '$e'.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      for (final keyword in keywords.take(2)) {
        items.add(_MetaChip(label: keyword));
      }
      if (keywords.length > 2) {
        items.add(_MetaChip(label: '+${keywords.length - 2}'));
      }

      if (profile.enableAdvance ?? false) {
        items.add(_MetaChip(label: l10n.s_Advanced_Options));
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final surface = palette.surface.resolveFrom(context);
    final accent = EhPalette.accent.resolveFrom(context);
    final radius = DesktopBrowseStyle.cardRadius;
    final editing = !widget.reorderable && widget.editing;

    final Color fill = editing
        ? EhPalette.accentSoft
              .resolveFrom(context)
              .withValues(alpha: dark ? .28 : .55)
        : _hover
        ? Color.alphaBlend(palette.fill.resolveFrom(context), surface)
        : DesktopBrowseStyle.cardSurface(context);

    final Color borderColor = _focus
        ? accent
        : editing
        ? accent.withValues(alpha: dark ? .65 : .55)
        : _hover
        ? palette.text1.resolveFrom(context).withValues(alpha: dark ? .16 : .14)
        : palette.hairline.resolveFrom(context);

    final showActions =
        !widget.reorderable && (_hover || _focus || editing);
    final borderRadius = BorderRadius.circular(radius);

    return KeyedSubtree(
      key: ValueKey('desktop-group-card-${widget.profile.uuid}'),
      child: FocusableActionDetector(
        enabled: !widget.reorderable,
        mouseCursor: widget.reorderable
            ? SystemMouseCursors.grab
            : SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hover = value),
        onShowFocusHighlight: (value) => setState(() => _focus = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.reorderable ? null : widget.onTap,
          onSecondaryTapDown: widget.reorderable || widget.onSecondaryTap == null
              ? null
              : (event) => widget.onSecondaryTap!(event.globalPosition),
          child: AnimatedContainer(
            duration: DesktopBrowseStyle.motion(context, 120),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor,
                width: _focus
                    ? 1.5
                    : editing
                    ? 1.25
                    : 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: editing
                                ? accent.withValues(alpha: .16)
                                : palette.fill.resolveFrom(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: EhSvgIcon(
                            widget.reorderable
                                ? CupertinoIcons.line_horizontal_3
                                : _iconFor(widget.profile.listType),
                            size: 15,
                            color: widget.reorderable
                                ? palette.text3.resolveFrom(context)
                                : editing
                                ? accent
                                : palette.text2.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.profile.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: palette.text1.resolveFrom(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.current) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: EhPalette.accentSoft.resolveFrom(
                                          context,
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        l10n.desktop_current_group,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (widget.profile.hideTab ?? false) ...[
                                    const SizedBox(width: 6),
                                    _MetaChip(label: l10n.hide),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: _buildMetadata(context, l10n),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.reorderable)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#${widget.index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: palette.text3.resolveFrom(context),
                                ),
                              ),
                              const SizedBox(width: 6),
                              DesktopControl(
                                key: ValueKey(
                                  'desktop-group-up-${widget.profile.uuid}',
                                ),
                                label: '${widget.profile.name} ↑',
                                minSize: 26,
                                radius: 7,
                                padding: const EdgeInsets.all(4),
                                onPressed: widget.onMoveUp,
                                child: const EhSvgIcon(
                                  CupertinoIcons.chevron_up,
                                  size: 13,
                                ),
                              ),
                              const SizedBox(width: 2),
                              DesktopControl(
                                key: ValueKey(
                                  'desktop-group-down-${widget.profile.uuid}',
                                ),
                                label: '${widget.profile.name} ↓',
                                minSize: 26,
                                radius: 7,
                                padding: const EdgeInsets.all(4),
                                onPressed: widget.onMoveDown,
                                child: const EhSvgIcon(
                                  CupertinoIcons.chevron_down,
                                  size: 13,
                                ),
                              ),
                            ],
                          )
                        else if (showActions)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DesktopControl(
                                key: ValueKey(
                                  'desktop-group-edit-${widget.profile.uuid}',
                                ),
                                label: l10n.edit,
                                minSize: 28,
                                radius: 7,
                                padding: const EdgeInsets.all(5),
                                onPressed: widget.onEdit,
                                child: const EhSvgIcon(
                                  CupertinoIcons.pencil,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 2),
                              DesktopControl(
                                key: ValueKey(
                                  'desktop-group-delete-${widget.profile.uuid}',
                                ),
                                label: l10n.delete,
                                minSize: 28,
                                radius: 7,
                                padding: const EdgeInsets.all(5),
                                onPressed: widget.onDelete,
                                child: EhSvgIcon(
                                  CupertinoIcons.trash,
                                  size: 14,
                                  color: CupertinoDynamicColor.resolve(
                                    CupertinoColors.systemRed,
                                    context,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          EhSvgIcon(
                            CupertinoIcons.chevron_right,
                            size: 13,
                            color: palette.text3.resolveFrom(context),
                          ),
                      ],
                    ),
                  ),
                  if (editing)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: ColoredBox(color: accent),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: palette.fill.resolveFrom(context),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: palette.text2.resolveFrom(context)),
      ),
    );
  }
}

class _DesktopGhostAddButton extends StatefulWidget {
  const _DesktopGhostAddButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_DesktopGhostAddButton> createState() => _DesktopGhostAddButtonState();
}

class _DesktopGhostAddButtonState extends State<_DesktopGhostAddButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final accent = EhPalette.accent.resolveFrom(context);
    final radius = DesktopBrowseStyle.cardRadius;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hover = value),
        onShowFocusHighlight: (value) => setState(() => _focus = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: DesktopBrowseStyle.motion(context, 120),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover
                  ? palette.fill.resolveFrom(context)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: _focus
                    ? accent
                    : _hover
                    ? palette.text1.resolveFrom(context).withValues(
                        alpha: dark ? .16 : .14,
                      )
                    : palette.hairline.resolveFrom(context),
                width: _focus ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                EhSvgIcon(
                  CupertinoIcons.add,
                  size: 14,
                  color: palette.text2.resolveFrom(context),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: palette.text2.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
