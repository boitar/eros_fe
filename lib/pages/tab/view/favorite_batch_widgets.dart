import 'dart:async';
import 'dart:math' as math;

import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/network/favorite_mutation.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/controller/favorite_sel_controller.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_selection_controller.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/favcat_grid.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:oktoast/oktoast.dart' as oktoast;

/// Replaces `FavoriteTabBar` while batch selection is active.
///
/// Shows `已选 N 项`, folder scope subtitle with folder heart color, and
/// right-side `全选` / `取消全选` action. On book-folded iPhone Duo, aligns to
/// the left pane so it never straddles the hinge.
class FavSelectionHeader extends StatelessWidget {
  const FavSelectionHeader({
    super.key,
    required this.selection,
    required this.scopeTitle,
    required this.scopeFavId,
    required this.totalCount,
    required this.loadedItemsProvider,
    this.height,
  });

  final FavoriteSelectionController selection;
  final String scopeTitle;
  final String scopeFavId;
  final int totalCount;
  final List<GalleryProvider> Function() loadedItemsProvider;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final env = AdaptiveEnvironment.maybeOf(context);
    final leftPane = env != null && env.isBookFolded && env.paneRects.length >= 2
        ? env.paneRects.first
        : null;

    return Obx(() {
      final count = selection.count;
      final loaded = loadedItemsProvider();
      final allSelected = selection.isAllLoadedSelected(loaded);
      final heartColor = scopeFavId == 'a'
          ? palette.text2.resolveFrom(context)
          : favcatDisplayColor(context, scopeFavId);

      final row = Padding(
        padding: EdgeInsets.only(
          left: (leftPane != null ? 0 : MediaQuery.paddingOf(context).left) + 16,
          right:
              (leftPane != null ? 0 : MediaQuery.paddingOf(context).right) + 12,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.fav_selected_count(count),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.text1.resolveFrom(context),
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      EhSvgIcon(
                        scopeFavId == 'a'
                            ? CupertinoIcons.square_grid_2x2
                            : CupertinoIcons.heart_fill,
                        size: 11,
                        color: heartColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.fav_selected_scope(scopeTitle, totalCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.text2.resolveFrom(context),
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CupertinoButton(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: loaded.isEmpty
                  ? null
                  : () => selection.toggleSelectAllLoaded(loaded),
              child: Text(
                allSelected ? l10n.fav_deselect_all : l10n.sp_select_all,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: loaded.isEmpty
                      ? palette.text3.resolveFrom(context)
                      : accent,
                ),
              ),
            ),
          ],
        ),
      );

      final content = SizedBox(
        height: height ?? 48,
        child: leftPane != null
            ? Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: leftPane.left),
                  child: SizedBox(width: leftPane.width, child: row),
                ),
              )
            : row,
      );

      return content;
    });
  }
}

/// Flutter glass fallback floating toolbar for batch selection when native
/// UIKit chrome is not active.
///
/// Positioned via [AdaptiveEnvironmentSnapshot.unoccludedControlRect]; flips
/// to a vertical capsule along the trailing bar edge when `hasDuoVerticalBar`
/// is true.
class FavoriteBatchActionBar extends StatelessWidget {
  const FavoriteBatchActionBar({
    super.key,
    required this.selection,
    required this.onMove,
    required this.onRemove,
    this.allowMove = true,
  });

  final FavoriteSelectionController selection;
  final VoidCallback onMove;
  final VoidCallback onRemove;
  final bool allowMove;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final env = AdaptiveEnvironment.maybeOf(context);
    final vertical = env?.hasDuoVerticalBar ?? false;
    final media = MediaQuery.of(context);

    return Obx(() {
      if (!selection.selecting.value) {
        return const SizedBox.shrink();
      }
      final enabled = selection.hasSelection && !selection.busy.value;
      final accent = EhPalette.accent.resolveFrom(context);
      final danger = CupertinoColors.systemRed.resolveFrom(context);
      final disabledColor = palette.text3.resolveFrom(context);
      final glassOff = GlassMode.of(context) == GlassMode.off;

      Widget action({
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onPressed,
      }) {
        return Semantics(
          button: true,
          enabled: enabled,
          label: label,
          excludeSemantics: true,
          onTap: enabled ? onPressed : null,
          child: EhPressable(
            borderRadius: BorderRadius.circular(22),
            onPressed: enabled ? onPressed : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: vertical ? 8 : 16,
                  vertical: 8,
                ),
                child: vertical
                    ? EhSvgIcon(
                        icon,
                        size: 21,
                        color: enabled ? color : disabledColor,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          EhSvgIcon(
                            icon,
                            size: 18,
                            color: enabled ? color : disabledColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: enabled ? color : disabledColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      }

      final children = <Widget>[
        if (allowMove)
          action(
            icon: CupertinoIcons.folder,
            label: l10n.fav_move_to,
            color: accent,
            onPressed: onMove,
          ),
        if (allowMove)
          Container(
            width: vertical ? 24 : 0.5,
            height: vertical ? 0.5 : 22,
            color: palette.hairline.resolveFrom(context),
          ),
        action(
          icon: CupertinoIcons.heart_slash,
          label: l10n.remove_from_favorites,
          color: danger,
          onPressed: onRemove,
        ),
      ];

      final capsule = LiquidGlassSurface(
        enabled: !glassOff,
        borderRadius: BorderRadius.circular(28),
        style: LiquidGlassStyle.regular,
        emphasizeFallbackEdge: true,
        child: Container(
          decoration: glassOff
              ? BoxDecoration(
                  color: palette.bar.resolveFrom(context),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: palette.hairline.resolveFrom(context),
                    width: 0.5,
                  ),
                )
              : null,
          padding: const EdgeInsets.all(4),
          child: vertical
              ? Column(mainAxisSize: MainAxisSize.min, children: children)
              : Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );

      if (env != null && vertical) {
        final preferred = Rect.fromLTWH(
          env.size.width - 72,
          math.max(96, (env.size.height - 120) / 2),
          56,
          120,
        );
        final rect = env.unoccludedControlRect(preferred);
        return Positioned(
          left: rect.left,
          top: rect.top,
          child: capsule,
        );
      }

      final bottomPadding = math.max(16.0, media.padding.bottom + 12);
      if (env != null) {
        final preferred = Rect.fromLTWH(
          16,
          math.max(0, env.size.height - bottomPadding - 56),
          math.max(0, env.size.width - 32),
          56,
        );
        final rect = env.unoccludedControlRect(preferred);
        return Positioned(
          left: rect.left,
          right: env.size.width - rect.right,
          bottom: math.max(bottomPadding, env.size.height - rect.bottom),
          child: Center(child: capsule),
        );
      }

      return Positioned(
        left: 16,
        right: 16,
        bottom: bottomPadding,
        child: Center(child: capsule),
      );
    });
  }
}

/// Horizontal swipe-to-select gesture wrapper for favorites lists.
///
/// While [selection.selecting] is true, horizontal drag selects or deselects
/// every card crossed by the pointer (matching the inverted state of the first
/// touched card) and gently auto-scrolls near the top/bottom edges.
class FavoriteSwipeSelectRegion extends StatefulWidget {
  const FavoriteSwipeSelectRegion({
    super.key,
    required this.selection,
    required this.registry,
    required this.child,
    this.scrollControllerProvider,
  });

  final FavoriteSelectionController selection;
  final FavoriteSelectableRegistry registry;
  final Widget child;
  final ScrollController? Function()? scrollControllerProvider;

  @override
  State<FavoriteSwipeSelectRegion> createState() =>
      _FavoriteSwipeSelectRegionState();
}

class _FavoriteSwipeSelectRegionState extends State<FavoriteSwipeSelectRegion> {
  bool? _dragTargetSelected;
  String? _lastTouchedGid;
  Timer? _autoScrollTimer;
  double _autoScrollDelta = 0;

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollDelta = 0;
  }

  void _updateAutoScroll(Offset globalPosition) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox || !renderBox.hasSize) {
      _stopAutoScroll();
      return;
    }
    final local = renderBox.globalToLocal(globalPosition);
    const edgeZone = 68.0;
    double delta = 0;
    if (local.dy < edgeZone) {
      delta = -((edgeZone - local.dy) / edgeZone) * 14.0;
    } else if (local.dy > renderBox.size.height - edgeZone) {
      delta = ((local.dy - (renderBox.size.height - edgeZone)) / edgeZone) * 14.0;
    }
    _autoScrollDelta = delta;
    if (delta == 0) {
      _stopAutoScroll();
      return;
    }
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) {
        if (!mounted || !widget.selection.selecting.value) {
          _stopAutoScroll();
          return;
        }
        final sc = widget.scrollControllerProvider?.call();
        if (sc == null || !sc.hasClients || _autoScrollDelta == 0) {
          return;
        }
        final pos = sc.position;
        final next = (pos.pixels + _autoScrollDelta)
            .clamp(pos.minScrollExtent, pos.maxScrollExtent);
        if (next != pos.pixels) {
          sc.jumpTo(next);
        }
      },
    );
  }

  void _applyHit(Offset globalPosition) {
    final provider = widget.registry.hitTest(globalPosition);
    if (provider == null) {
      return;
    }
    final gid = provider.gid ?? '';
    if (gid.isEmpty || gid == _lastTouchedGid) {
      return;
    }
    _lastTouchedGid = gid;
    _dragTargetSelected ??= !widget.selection.isSelected(gid);
    widget.selection.setSelected(provider, _dragTargetSelected!);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selecting = widget.selection.selecting.value;
      if (!selecting) {
        _stopAutoScroll();
        return widget.child;
      }
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          _dragTargetSelected = null;
          _lastTouchedGid = null;
          _applyHit(details.globalPosition);
        },
        onHorizontalDragUpdate: (details) {
          _applyHit(details.globalPosition);
          _updateAutoScroll(details.globalPosition);
        },
        onHorizontalDragEnd: (_) {
          _dragTargetSelected = null;
          _lastTouchedGid = null;
          _stopAutoScroll();
        },
        onHorizontalDragCancel: () {
          _dragTargetSelected = null;
          _lastTouchedGid = null;
          _stopAutoScroll();
        },
        child: widget.child,
      );
    });
  }
}

/// Opens the two-column folder picker sheet for batch moving. Single tap
/// returns the chosen [Favcat] immediately without a confirmation button.
Future<Favcat?> showBatchMoveSheet(
  BuildContext context, {
  required List<Favcat> favcats,
  String? currentFavcat,
  int? selectedCount,
}) {
  final l10n = L10n.of(context);
  return showEhSheet<Favcat>(
    context: context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EhSheetHeader(
          title: l10n.fav_move_to,
          subtitle: selectedCount != null
              ? l10n.fav_selected_count(selectedCount)
              : null,
        ),
        FavcatGrid(
          favcats: favcats,
          disabledFavId:
              currentFavcat != null && currentFavcat != 'a' && currentFavcat != 'l'
                  ? currentFavcat
                  : null,
          onSelect: (fav) => Navigator.of(sheetContext).pop(fav),
        ),
      ],
    ),
  );
}

/// Confirmation sheet for batch removing favorites. No undo is offered.
Future<bool> showBatchRemoveConfirm(
  BuildContext context, {
  required int count,
  required int noteCount,
}) async {
  final l10n = L10n.of(context);
  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (sheetContext) => EhActionSheet(
      title: Text(l10n.fav_remove_title(count)),
      message: Text(
        noteCount > 0
            ? l10n.fav_remove_note_warn(noteCount)
            : l10n.fav_remove_irreversible,
      ),
      actions: <Widget>[
        EhActionSheetAction(
          isDestructiveAction: true,
          icon: CupertinoIcons.heart_slash,
          systemIcon: 'heart.slash',
          onPressed: () => Navigator.of(sheetContext).pop(true),
          child: Text(l10n.remove_from_favorites),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(false),
        child: Text(l10n.cancel),
      ),
    ),
  );
  return confirmed == true;
}

/// Runs a batch move with >1s slow-loading indicator, optimistic removal from
/// current view, 5s Undo toast (grouped by original folder), and partial-failure
/// retry while keeping failed items selected.
Future<void> runBatchMoveFlow({
  required BuildContext context,
  required FavoriteSelectionController selection,
  required String currentFavcat,
  required void Function(Set<String> removedGids) onRemoveFromCurrentView,
  VoidCallback? onRefreshCurrentView,
}) async {
  if (!selection.hasSelection || selection.busy.value) {
    return;
  }
  final selector = Get.find<FavoriteSelectorController>();
  final selectedItems = selection.selectedItems;
  final target = await showBatchMoveSheet(
    context,
    favcats: selector.favcatList,
    currentFavcat: currentFavcat,
    selectedCount: selectedItems.length,
  );
  if (target == null || !context.mounted) {
    return;
  }
  await _executeBatchMoveItems(
    context: context,
    selection: selection,
    items: selectedItems,
    target: target,
    currentFavcat: currentFavcat,
    onRemoveFromCurrentView: onRemoveFromCurrentView,
    onRefreshCurrentView: onRefreshCurrentView,
  );
}

Future<void> _executeBatchMoveItems({
  required BuildContext context,
  required FavoriteSelectionController selection,
  required List<GalleryProvider> items,
  required Favcat target,
  required String currentFavcat,
  required void Function(Set<String> removedGids) onRemoveFromCurrentView,
  VoidCallback? onRefreshCurrentView,
}) async {
  final l10n = L10n.of(context);
  final favController = Get.find<FavController>();
  final originByGid = <String, String>{
    for (final item in items)
      if ((item.gid ?? '').isNotEmpty)
        item.gid!: () {
          final overlaid = favoriteStates.overlay(item).favcat ?? '';
          if (isNetworkFavoriteCategory(overlaid)) {
            return overlaid;
          }
          return isNetworkFavoriteCategory(currentFavcat) ? currentFavcat : '';
        }(),
  };
  selection.busy.value = true;
  oktoast.ToastFuture? loadingToast;
  final slowTimer = Timer(const Duration(seconds: 1), () {
    if (context.mounted) {
      loadingToast = showActionToast(
        l10n.fav_batch_working,
        loading: true,
        context: context,
      );
    }
  });
  try {
    final result = await favController.batchMove(
      items,
      target.favId,
      currentFavcat: currentFavcat,
    );
    slowTimer.cancel();
    loadingToast?.dismiss();

    final succeededSet = result.succeededGids.toSet();
    if (succeededSet.isNotEmpty &&
        currentFavcat != 'a' &&
        currentFavcat != target.favId) {
      onRemoveFromCurrentView(succeededSet);
    }

    if (!result.hasFailures) {
      selection.exit();
      await vibrateUtil.success();
      if (!context.mounted) {
        return;
      }
      // Group moved items by pre-move original favcat for Undo.
      final byOrigin = <String, List<GalleryProvider>>{};
      for (final item in items) {
        if (!succeededSet.contains(item.gid)) {
          continue;
        }
        final origin = originByGid[item.gid] ?? '';
        if (origin.isNotEmpty && origin != target.favId) {
          byOrigin.putIfAbsent(origin, () => <GalleryProvider>[]).add(item);
        }
      }
      showActionToast(
        l10n.fav_moved_to(target.favTitle),
        actionLabel: byOrigin.isNotEmpty ? l10n.undo : null,
        onAction: byOrigin.isNotEmpty
            ? () async {
                var anyUndoFailed = false;
                for (final entry in byOrigin.entries) {
                  try {
                    final undoResult = await favController.batchMove(
                      entry.value,
                      entry.key,
                      currentFavcat: target.favId,
                    );
                    if (undoResult.hasFailures) {
                      anyUndoFailed = true;
                    }
                  } catch (e) {
                    anyUndoFailed = true;
                    showToast(favoriteMutationMessage(e));
                  }
                }
                if (anyUndoFailed) {
                  await vibrateUtil.error();
                  showToast(l10n.fav_partial_failed(0, items.length));
                }
                onRefreshCurrentView?.call();
              }
            : null,
        context: context,
      );
    } else {
      selection.keepOnly(result.failedGids);
      await vibrateUtil.error();
      if (!context.mounted) {
        return;
      }
      final failedSet = result.failedGids.toSet();
      final retryItems =
          items.where((i) => failedSet.contains(i.gid)).toList(growable: false);
      showActionToast(
        l10n.fav_partial_failed(
          result.succeededGids.length,
          result.failedGids.length,
        ),
        actionLabel: l10n.retry,
        onAction: () {
          if (context.mounted) {
            unawaited(_executeBatchMoveItems(
              context: context,
              selection: selection,
              items: retryItems,
              target: target,
              currentFavcat: currentFavcat,
              onRemoveFromCurrentView: onRemoveFromCurrentView,
              onRefreshCurrentView: onRefreshCurrentView,
            ));
          }
        },
        context: context,
      );
    }
  } catch (e) {
    slowTimer.cancel();
    loadingToast?.dismiss();
    await vibrateUtil.error();
    showToast(favoriteMutationMessage(e));
  } finally {
    selection.busy.value = false;
  }
}

/// Runs a batch remove with destructive confirmation, >1s slow-loading toast,
/// optimistic removal, and partial-failure retry. No undo is offered.
Future<void> runBatchRemoveFlow({
  required BuildContext context,
  required FavoriteSelectionController selection,
  required String currentFavcat,
  required void Function(Set<String> removedGids) onRemoveFromCurrentView,
}) async {
  if (!selection.hasSelection || selection.busy.value) {
    return;
  }
  final items = selection.selectedItems;
  final noteCount = items
      .where((item) =>
          (favoriteStates.overlay(item).favNote?.trim() ?? '').isNotEmpty)
      .length;
  final confirmed = await showBatchRemoveConfirm(
    context,
    count: items.length,
    noteCount: noteCount,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await _executeBatchRemoveItems(
    context: context,
    selection: selection,
    items: items,
    currentFavcat: currentFavcat,
    onRemoveFromCurrentView: onRemoveFromCurrentView,
  );
}

Future<void> _executeBatchRemoveItems({
  required BuildContext context,
  required FavoriteSelectionController selection,
  required List<GalleryProvider> items,
  required String currentFavcat,
  required void Function(Set<String> removedGids) onRemoveFromCurrentView,
}) async {
  final l10n = L10n.of(context);
  final favController = Get.find<FavController>();
  selection.busy.value = true;
  oktoast.ToastFuture? loadingToast;
  final slowTimer = Timer(const Duration(seconds: 1), () {
    if (context.mounted) {
      loadingToast = showActionToast(
        l10n.fav_batch_working,
        loading: true,
        context: context,
      );
    }
  });
  try {
    final result = await favController.batchRemove(
      items,
      currentFavcat: currentFavcat,
    );
    slowTimer.cancel();
    loadingToast?.dismiss();

    final succeededSet = result.succeededGids.toSet();
    if (succeededSet.isNotEmpty) {
      onRemoveFromCurrentView(succeededSet);
    }

    if (!result.hasFailures) {
      selection.exit();
      await vibrateUtil.success();
      if (context.mounted) {
        showActionToast(
          l10n.fav_removed_count(result.succeededGids.length),
          context: context,
        );
      }
    } else {
      selection.keepOnly(result.failedGids);
      await vibrateUtil.error();
      if (!context.mounted) {
        return;
      }
      final failedSet = result.failedGids.toSet();
      final retryItems =
          items.where((i) => failedSet.contains(i.gid)).toList(growable: false);
      showActionToast(
        l10n.fav_partial_remove_failed(
          result.succeededGids.length,
          result.failedGids.length,
        ),
        actionLabel: l10n.retry,
        onAction: () {
          if (context.mounted) {
            unawaited(_executeBatchRemoveItems(
              context: context,
              selection: selection,
              items: retryItems,
              currentFavcat: currentFavcat,
              onRemoveFromCurrentView: onRemoveFromCurrentView,
            ));
          }
        },
        context: context,
      );
    }
  } catch (e) {
    slowTimer.cancel();
    loadingToast?.dismiss();
    await vibrateUtil.error();
    showToast(favoriteMutationMessage(e));
  } finally {
    selection.busy.value = false;
  }
}
