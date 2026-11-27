import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Tracks multi-select state for favorites lists and favorites search results.
class FavoriteSelectionController extends GetxController {
  final RxBool selecting = false.obs;
  final RxMap<String, GalleryProvider> selected = <String, GalleryProvider>{}.obs;
  final RxBool busy = false.obs;

  int get count => selected.length;
  bool get hasSelection => selected.isNotEmpty;
  List<GalleryProvider> get selectedItems => selected.values.toList(growable: false);

  bool isSelected(String? gid) => gid != null && gid.isNotEmpty && selected.containsKey(gid);

  void enter({GalleryProvider? initialItem}) {
    selecting.value = true;
    if (initialItem != null && (initialItem.gid?.isNotEmpty ?? false)) {
      selected[initialItem.gid!] = initialItem;
    }
    vibrateUtil.selection();
  }

  void toggle(GalleryProvider item) {
    final gid = item.gid;
    if (gid == null || gid.isEmpty) {
      return;
    }
    if (selected.containsKey(gid)) {
      selected.remove(gid);
    } else {
      selected[gid] = item;
    }
    vibrateUtil.selection();
  }

  /// Sets selection state for [item] without toggling; returns true if changed.
  bool setSelected(GalleryProvider item, bool value) {
    final gid = item.gid;
    if (gid == null || gid.isEmpty) {
      return false;
    }
    final currently = selected.containsKey(gid);
    if (currently == value) {
      return false;
    }
    if (value) {
      selected[gid] = item;
    } else {
      selected.remove(gid);
    }
    vibrateUtil.selection();
    return true;
  }

  /// Selects every currently loaded item in [items]. Never fetches extra pages.
  void selectAllLoaded(Iterable<GalleryProvider> items) {
    for (final item in items) {
      final gid = item.gid;
      if (gid != null && gid.isNotEmpty) {
        selected[gid] = item;
      }
    }
    vibrateUtil.selection();
  }

  bool isAllLoadedSelected(Iterable<GalleryProvider> items) {
    var loadedCount = 0;
    for (final item in items) {
      final gid = item.gid;
      if (gid == null || gid.isEmpty) {
        continue;
      }
      loadedCount++;
      if (!selected.containsKey(gid)) {
        return false;
      }
    }
    return loadedCount > 0;
  }

  void toggleSelectAllLoaded(Iterable<GalleryProvider> items) {
    if (isAllLoadedSelected(items)) {
      clear();
    } else {
      selectAllLoaded(items);
    }
  }

  /// Retains only entries whose gid is in [gids] (used after partial failures).
  void keepOnly(Iterable<String> gids) {
    final keep = gids.toSet();
    selected.removeWhere((gid, _) => !keep.contains(gid));
  }

  void clear() {
    selected.clear();
    vibrateUtil.selection();
  }

  void exit() {
    selected.clear();
    selecting.value = false;
  }
}

/// Entry registered by rendered cards so horizontal swipe-to-select can hit-test
/// cards across list, waterfall, and grid layouts without coupling to sliver
/// internals.
class FavoriteSelectableCardRef {
  const FavoriteSelectableCardRef({
    required this.context,
    required this.provider,
  });

  final BuildContext context;
  final GalleryProvider provider;
}

class FavoriteSelectableRegistry {
  final Map<BuildContext, FavoriteSelectableCardRef> _entries =
      <BuildContext, FavoriteSelectableCardRef>{};

  void register(String gid, BuildContext context, GalleryProvider provider) {
    if (gid.isEmpty) {
      return;
    }
    _entries[context] = FavoriteSelectableCardRef(
      context: context,
      provider: provider,
    );
  }

  void unregister(String gid, BuildContext context) {
    _entries.remove(context);
  }

  GalleryProvider? hitTest(Offset globalPosition) {
    for (final entry in _entries.values) {
      if (!entry.context.mounted) {
        continue;
      }
      final renderObject = entry.context.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.hasSize ||
          !renderObject.attached) {
        continue;
      }
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final rect = topLeft & renderObject.size;
      if (rect.contains(globalPosition)) {
        return entry.provider;
      }
    }
    return null;
  }
}

/// Scopes favorites-only behaviors (batch selection, `FavNoteLine`, waterfall
/// tag omission, search highlighting, and unfolded preview selection) cleanly
/// to favorites lists and favorites search results.
class FavoriteListScope extends InheritedWidget {
  const FavoriteListScope({
    super.key,
    required super.child,
    this.selection,
    this.registry,
    this.showFavNote = false,
    this.hideTagsInWaterfall = false,
    this.favNoteMaxLines = 1,
    this.highlightQuery = '',
    this.onPreviewSelect,
    this.activePreviewGid,
  });

  final FavoriteSelectionController? selection;
  final FavoriteSelectableRegistry? registry;
  final bool showFavNote;
  final bool hideTagsInWaterfall;
  final int favNoteMaxLines;
  final String highlightQuery;
  final void Function(GalleryProvider provider)? onPreviewSelect;
  final String? activePreviewGid;

  static FavoriteListScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FavoriteListScope>();

  @override
  bool updateShouldNotify(FavoriteListScope oldWidget) =>
      selection != oldWidget.selection ||
      registry != oldWidget.registry ||
      showFavNote != oldWidget.showFavNote ||
      hideTagsInWaterfall != oldWidget.hideTagsInWaterfall ||
      favNoteMaxLines != oldWidget.favNoteMaxLines ||
      highlightQuery != oldWidget.highlightQuery ||
      onPreviewSelect != oldWidget.onPreviewSelect ||
      activePreviewGid != oldWidget.activePreviewGid;
}
