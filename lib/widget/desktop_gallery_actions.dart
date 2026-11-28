import 'dart:async';
import 'dart:math' as math;

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/fav_rule_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/models/fav_rule.dart';
import 'package:eros_fe/models/gallery_provider.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/network/favorite_mutation.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/item/controller/galleryitem_controller.dart';
import 'package:eros_fe/route/navigator_util.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

bool get _mac => PlatformCapabilities.hostPlatform == TargetPlatform.macOS;

SingleActivator _command(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(key, meta: _mac, control: !_mac, shift: shift);

/// The desktop actions a gallery card offers on hover, in its context menu
/// and from the keyboard. Keyboard shortcuts act on the card under the
/// pointer, else on the gallery open in the detail pane.
abstract final class DesktopGalleryActions {
  /// The gallery card under the mouse pointer, if any.
  static final ValueNotifier<String?> hoveredGid = ValueNotifier<String?>(null);

  static SingleActivator get readShortcut => _command(LogicalKeyboardKey.enter);
  static SingleActivator get downloadShortcut =>
      _command(LogicalKeyboardKey.keyD);
  static SingleActivator get copyLinkShortcut =>
      _command(LogicalKeyboardKey.keyC, shift: true);

  /// The menu draws ↩ as an icon: as text, macOS falls back to the emoji.
  static String get readShortcutLabel => _mac ? '⌘↩' : 'Ctrl+Enter';
  static String get downloadShortcutLabel => _mac ? '⌘D' : 'Ctrl+D';
  static String get copyLinkShortcutLabel => _mac ? '⇧⌘C' : 'Ctrl+Shift+C';

  /// Stands in for the gallery page controllers in widget tests.
  @visibleForTesting
  static GalleryPageController? Function(String gid)? debugLivePage;

  /// Stands in for the app's toast in widget tests.
  @visibleForTesting
  static void Function(String message)? debugToast;

  static GalleryItemController? itemFor(String? gid) =>
      gid != null && Get.isRegistered<GalleryItemController>(tag: gid)
      ? Get.find<GalleryItemController>(tag: gid)
      : null;

  /// The open gallery page showing [gid], newest first.
  static GalleryPageController? livePageFor(String gid) {
    if (debugLivePage != null) {
      return debugLivePage!(gid);
    }
    if (!Get.isRegistered<ControllerTagService>()) {
      return null;
    }
    final tags = Get.find<ControllerTagService>().galleryTagsFor(gid).toList();
    for (final tag in tags.reversed) {
      if (Get.isRegistered<GalleryPageController>(tag: tag) &&
          !Get.isPrepared<GalleryPageController>(tag: tag)) {
        final page = Get.find<GalleryPageController>(tag: tag);
        if (page.gState.gid == gid) {
          return page;
        }
      }
    }
    return null;
  }

  /// Opens [provider] beside the list (or over it, in one column) and waits
  /// until its page has loaded what reading and downloading need. Null when
  /// the page failed, was closed meanwhile, or took too long.
  static Future<GalleryPageController?> _openLoaded(
    GalleryProvider provider,
  ) async {
    final gid = provider.gid;
    if (gid == null) {
      return null;
    }
    var page = livePageFor(gid);
    if (page == null) {
      unawaited(NavigatorUtil.goGalleryPage(galleryProvider: provider));
    }
    var seen = page != null;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      page = livePageFor(gid);
      if (page != null) {
        seen = true;
        if (page.gState.enableRead) {
          return page;
        }
        if (page.status.isError) {
          return null;
        }
      } else if (seen) {
        return null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return null;
  }

  static Future<bool> read(GalleryProvider provider, {int? index}) async {
    final page = await _openLoaded(provider);
    if (page == null) return false;
    final count =
        int.tryParse(page.gState.galleryProvider?.filecount ?? '') ?? 0;
    await NavigatorUtil.goGalleryViewPage(
      count > 0
          ? (index ?? page.gState.lastIndex).clamp(0, count - 1)
          : (index ?? page.gState.lastIndex),
      page.gState.gid,
      galleryTag: page.controllerTag,
    );
    return true;
  }

  static Future<void> download(
    BuildContext context,
    GalleryProvider provider,
  ) async {
    final page = await _openLoaded(provider);
    if (page == null || !context.mounted) {
      return;
    }
    await page.downloadGallery(context);
  }

  /// The quick action's heart: add when not a favorite, otherwise move it
  /// to another folder (the context menu also offers removal).
  static Future<void> favorite(GalleryItemController item) =>
      item.isFav ? item.changeFavorite() : item.addFavorite();

  static String linkOf(GalleryProvider provider) {
    final url = provider.url;
    if (url != null && url.startsWith('http')) {
      return url;
    }
    return '${Api.getBaseUrl()}/g/${provider.gid}/${provider.token}/';
  }

  static Future<void> copyLink(
    BuildContext context,
    GalleryProvider provider,
  ) async {
    await Clipboard.setData(ClipboardData(text: linkOf(provider)));
    if (context.mounted) {
      (debugToast ?? showToast)(L10n.of(context).copied_to_clipboard);
    }
  }

  static Future<void> searchUploader(GalleryProvider provider) async {
    final uploader = provider.uploader;
    if (uploader == null || uploader.isEmpty) {
      return;
    }
    await NavigatorUtil.goSearchPageWithParam(
      simpleSearch: 'uploader:$uploader',
    );
  }

  /// Handles the gallery shortcuts; true when [event] was one of them.
  static bool handleShortcut(
    BuildContext context,
    KeyEvent event, {
    required String? detailGid,
  }) {
    final keyboard = HardwareKeyboard.instance;
    final read = readShortcut.accepts(event, keyboard);
    final download = downloadShortcut.accepts(event, keyboard);
    final copy = copyLinkShortcut.accepts(event, keyboard);
    if (!read && !download && !copy) {
      return false;
    }
    final gid = hoveredGid.value ?? detailGid;
    if (gid == null) {
      return false;
    }
    final provider =
        itemFor(gid)?.galleryProvider ??
        livePageFor(gid)?.gState.galleryProvider;
    if (provider == null) {
      return false;
    }
    if (read) {
      unawaited(DesktopGalleryActions.read(provider));
    } else if (download) {
      unawaited(DesktopGalleryActions.download(context, provider));
    } else {
      unawaited(copyLink(context, provider));
    }
    return true;
  }
}

/// One row of [showDesktopGalleryMenu].
@immutable
class DesktopMenuEntry {
  const DesktopMenuEntry({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.subtitle,
    this.accentColor,
    this.shortcut,
    this.destructive = false,
    this.dividerBefore = false,
    this.selected = false,
  });

  final String label;
  final String? subtitle;
  final Color? accentColor;
  final IconData icon;
  final VoidCallback onSelected;
  final String? shortcut;
  final bool destructive;
  final bool dividerBefore;
  final bool selected;
}

/// The context menu entries for the gallery card [item].
List<DesktopMenuEntry> desktopGalleryMenuEntries(
  BuildContext context,
  GalleryItemController item,
) {
  final l10n = L10n.of(context);
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  final provider = item.galleryProvider;
  final uploader = provider.uploader ?? '';
  final networkFavorite = (provider.favcat ?? '').isNotEmpty;

  DesktopMenuEntry? ruleEntry;
  if (Get.isRegistered<FavRuleService>()) {
    final ruleService = Get.find<FavRuleService>();
    if (ruleService.enabled && ruleService.config.enabledRuleCount > 0) {
      if (ruleService.needsAsyncTagFetch(provider)) {
        ruleEntry = DesktopMenuEntry(
          label: l10n.fav_rule_title,
          subtitle: l10n.fav_rule_entry_desc,
          accentColor: EhPalette.accent.resolveFrom(context),
          icon: CupertinoIcons.heart_fill,
          onSelected: () => unawaited(() async {
            try {
              final eval = await ruleService.evaluateGalleryWithFetch(provider);
              await item.applyRuleOrFallback(eval);
            } catch (e) {
              showToast(favoriteMutationMessage(e));
            }
          }()),
        );
      } else {
        final eval = ruleService.evaluateGallerySync(provider);
        final hit = eval.primary;
        if (hit != null) {
          final favTitle = ruleService.favTitleFor(hit.rule.favcat);
          final favColor = CupertinoDynamicColor.resolve(
            ThemeColors.favColorFor(hit.rule.favcat),
            context,
          );
          final tagLabel = hit.primaryTag?.displayLabel() ?? '';
          final ruleName = hit.rule.displayName(zh: zh);
          final sameFolder = item.isFav && item.favCat == hit.rule.favcat;
          final keepExisting = item.isFav &&
              !sameFolder &&
              ruleService.config.existing == FavRuleExisting.keep;
          final curTitle = item.favCat.isNotEmpty
              ? ruleService.favTitleFor(item.favCat)
              : favTitle;
          ruleEntry = DesktopMenuEntry(
            label: sameFolder
                ? l10n.fav_rule_already_in_folder(favTitle)
                : keepExisting
                    ? l10n.fav_rule_kept_in_folder(curTitle)
                    : item.isFav
                        ? l10n.fav_rule_move_to_folder(favTitle)
                        : l10n.fav_rule_save_to_folder(favTitle),
            subtitle: tagLabel.isEmpty
                ? l10n.fav_rule_reason_only(ruleName)
                : l10n.fav_rule_reason_with_tag(ruleName, tagLabel),
            accentColor: favColor,
            icon: CupertinoIcons.heart_fill,
            onSelected: () => unawaited(item.applyRuleFavorite(eval)),
          );
        }
      }
    }
  }

  return <DesktopMenuEntry>[
    if (ruleEntry != null) ruleEntry,
    DesktopMenuEntry(
      dividerBefore: ruleEntry != null,
      label: l10n.read,
      icon: CupertinoIcons.book,
      shortcut: DesktopGalleryActions.readShortcutLabel,
      onSelected: () => DesktopGalleryActions.read(item.galleryProvider),
    ),
    if (!networkFavorite)
      DesktopMenuEntry(
        dividerBefore: true,
        label: l10n.add_to_favorites,
        icon: CupertinoIcons.heart,
        onSelected: item.addFavorite,
      )
    else ...<DesktopMenuEntry>[
      DesktopMenuEntry(
        dividerBefore: true,
        label: l10n.change_to_favorites,
        icon: CupertinoIcons.folder,
        onSelected: item.changeFavorite,
      ),
      DesktopMenuEntry(
        label: l10n.remove_from_favorites,
        icon: CupertinoIcons.heart_slash,
        onSelected: item.removeFavorite,
      ),
    ],
    DesktopMenuEntry(
      label: l10n.download,
      icon: CupertinoIcons.arrow_down_to_line,
      shortcut: DesktopGalleryActions.downloadShortcutLabel,
      onSelected: () => DesktopGalleryActions.download(
        Get.overlayContext ?? context,
        item.galleryProvider,
      ),
    ),
    DesktopMenuEntry(
      dividerBefore: true,
      label: l10n.copy_link,
      icon: CupertinoIcons.link,
      shortcut: DesktopGalleryActions.copyLinkShortcutLabel,
      onSelected: () => DesktopGalleryActions.copyLink(
        Get.overlayContext ?? context,
        item.galleryProvider,
      ),
    ),
    if (uploader.isNotEmpty)
      DesktopMenuEntry(
        label: '${l10n.filter_by_uploader} · $uploader',
        icon: CupertinoIcons.person,
        onSelected: () =>
            DesktopGalleryActions.searchUploader(item.galleryProvider),
      ),
    if (item.isHistoryItem)
      DesktopMenuEntry(
        dividerBefore: true,
        label: l10n.delete,
        icon: CupertinoIcons.trash,
        destructive: true,
        onSelected: item.removeFromHistory,
      ),
  ];
}

/// Shows [entries] as a desktop context menu at [position] (global), kept
/// inside the window. The picked entry runs after the menu has closed.
Future<void> showDesktopGalleryMenu(
  BuildContext context, {
  required Offset position,
  required List<DesktopMenuEntry> entries,
  String? title,
  String? subtitle,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  // The root navigator may sit below a window title bar: lay the menu out in
  // its overlay's coordinates, not the window's.
  final overlay = Navigator.of(
    context,
    rootNavigator: true,
  ).overlay?.context.findRenderObject();
  final local = overlay is RenderBox
      ? overlay.globalToLocal(position)
      : position;
  final picked = await showGeneralDialog<DesktopMenuEntry>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: CupertinoLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 110),
    pageBuilder: (context, _, _) => _DesktopMenuLayout(
      position: local,
      child: DesktopGalleryMenu(
        entries: entries,
        title: title,
        subtitle: subtitle,
      ),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
  if (previousFocus?.context != null) previousFocus!.requestFocus();
  picked?.onSelected();
}

class _DesktopMenuLayout extends StatelessWidget {
  const _DesktopMenuLayout({required this.position, required this.child});

  final Offset position;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomSingleChildLayout(delegate: _MenuPosition(position), child: child);
}

class _MenuPosition extends SingleChildLayoutDelegate {
  const _MenuPosition(this.position);

  final Offset position;
  static const double _edge = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest)
          .deflate(const EdgeInsets.all(_edge));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Open down and right of the pointer; flip where the window ends.
    var x = position.dx;
    var y = position.dy;
    if (x + childSize.width > size.width - _edge) {
      x = position.dx - childSize.width;
    }
    if (y + childSize.height > size.height - _edge) {
      y = position.dy - childSize.height;
    }
    return Offset(
      x.clamp(_edge, math.max(_edge, size.width - childSize.width - _edge)),
      y.clamp(_edge, math.max(_edge, size.height - childSize.height - _edge)),
    );
  }

  @override
  bool shouldRelayout(_MenuPosition oldDelegate) =>
      position != oldDelegate.position;
}

/// The menu panel: glass when popups use glass, otherwise a raised surface.
class DesktopGalleryMenu extends StatefulWidget {
  const DesktopGalleryMenu({
    super.key,
    required this.entries,
    this.title,
    this.subtitle,
  });

  final List<DesktopMenuEntry> entries;
  final String? title, subtitle;
  static const double width = 280;

  @override
  State<DesktopGalleryMenu> createState() => _DesktopGalleryMenuState();
}

class _DesktopGalleryMenuState extends State<DesktopGalleryMenu> {
  late final nodes = [
    for (final entry in widget.entries) FocusNode(debugLabel: entry.label),
  ];

  @override
  void dispose() {
    for (final node in nodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (nodes.isEmpty) return KeyEventResult.ignored;
    final current = nodes.indexWhere((n) => n.hasFocus);
    int? next;
    if (key == LogicalKeyboardKey.arrowDown)
      next = (current + 1) % nodes.length;
    if (key == LogicalKeyboardKey.arrowUp)
      next = (current - 1 + nodes.length) % nodes.length;
    if (key == LogicalKeyboardKey.home) next = 0;
    if (key == LogicalKeyboardKey.end) next = nodes.length - 1;
    if (next == null) return KeyEventResult.ignored;
    nodes[next].requestFocus();
    Scrollable.ensureVisible(nodes[next].context!, alignment: .5);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final glass = liquidGlassPopupsEnabled;
    final radius = BorderRadius.circular(glass ? 14 : 10);
    final rows = <Widget>[
      if (widget.title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Text(
            widget.title!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.text2.resolveFrom(context),
            ),
          ),
        ),
      if (widget.subtitle != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Text(
            widget.subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: palette.text2.resolveFrom(context),
            ),
          ),
        ),
    ];
    for (var index = 0; index < widget.entries.length; index++) {
      final entry = widget.entries[index];
      if (entry.dividerBefore && rows.isNotEmpty) {
        rows.add(
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            color: palette.hairline.resolveFrom(context),
          ),
        );
      }
      rows.add(
        _MenuRow(
          entry: entry,
          glass: glass,
          focusNode: nodes[index],
          autofocus: index == 0,
        ),
      );
    }
    final content = Padding(
      padding: const EdgeInsets.all(5),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      ),
    );
    // The popup glass keeps a denser fill than bars do, so the rows stay
    // readable over the cards behind the menu.
    final Widget panel = glass
        ? LiquidGlassPopupSurface(
            enabled: true,
            borderRadius: radius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: palette.raised
                    .resolveFrom(context)
                    .withValues(alpha: .55),
              ),
              child: content,
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: palette.raised.resolveFrom(context),
              borderRadius: radius,
              border: Border.all(color: palette.hairline.resolveFrom(context)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: content,
          );
    return Semantics(
      key: const ValueKey<String>('desktop-gallery-menu'),
      scopesRoute: true,
      explicitChildNodes: true,
      child: Focus(
        onKeyEvent: _key,
        child: SizedBox(width: DesktopGalleryMenu.width, child: panel),
      ),
    );
  }
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.entry,
    required this.glass,
    required this.focusNode,
    required this.autofocus,
  });

  final FocusNode focusNode;
  final bool autofocus;

  final DesktopMenuEntry entry;
  final bool glass;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final entry = widget.entry;
    final Color foreground = entry.destructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : palette.text1.resolveFrom(context);
    return Semantics(
      button: true,
      label: entry.label,
      selected: entry.selected,
      excludeSemantics: true,
      onTap: () => Navigator.of(context).pop(entry),
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop(entry);
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            key: ValueKey<String>('desktop-menu-${entry.label}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(entry),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              curve: Curves.easeOutQuart,
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: ShapeDecoration(
                color: _hovered || _focused
                    ? (entry.accentColor != null
                        ? entry.accentColor!.withValues(alpha: dark ? .28 : .18)
                        : (dark
                            ? const Color(0x1FFFFFFF)
                            : const Color(0x1214161C)))
                    : (entry.accentColor != null
                        ? entry.accentColor!.withValues(alpha: dark ? .18 : .10)
                        : (dark
                            ? const Color(0x00FFFFFF)
                            : const Color(0x0014161C))),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(widget.glass ? 9 : 6),
                ),
              ),
              child: Row(
                children: <Widget>[
                  EhSvgIcon(
                    entry.icon,
                    size: 16,
                    color: entry.destructive
                        ? foreground
                        : (entry.accentColor ??
                            palette.text2.resolveFrom(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: entry.accentColor != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: foreground,
                          ),
                        ),
                        if (entry.subtitle != null &&
                            entry.subtitle!.isNotEmpty)
                          Text(
                            entry.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.text2.resolveFrom(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (entry.shortcut != null) ...<Widget>[
                    const SizedBox(width: 12),
                    _ShortcutLabel(
                      entry.shortcut!,
                      color: palette.text2.resolveFrom(context),
                    ),
                  ],
                  if (entry.selected)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: EhSvgIcon(
                        CupertinoIcons.check_mark,
                        size: 14,
                        color: foreground,
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

/// A shortcut hint; ↩ becomes an icon so it never renders as an emoji.
class _ShortcutLabel extends StatelessWidget {
  const _ShortcutLabel(this.label, {required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, color: color);
    const returnKey = '↩';
    if (!label.contains(returnKey)) {
      return Text(label, style: style);
    }
    final parts = label.split(returnKey);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (parts.first.isNotEmpty) Text(parts.first, style: style),
        EhSvgIcon(CupertinoIcons.return_icon, size: 13, color: color),
        if (parts.last.isNotEmpty) Text(parts.last, style: style),
      ],
    );
  }
}

/// Read, favorite and download over a card's top-right corner while the
/// pointer is on it.
class DesktopQuickActions extends StatelessWidget {
  const DesktopQuickActions({
    super.key,
    required this.item,
    this.axis = Axis.horizontal,
  });

  final GalleryItemController item;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final gap = axis == Axis.horizontal
        ? const SizedBox(width: 5)
        : const SizedBox(height: 5);
    return Flex(
      direction: axis,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _QuickButton(
          label: l10n.read,
          icon: CupertinoIcons.book_fill,
          onTap: () => DesktopGalleryActions.read(item.galleryProvider),
        ),
        gap,
        Obx(
          () => _QuickButton(
            label: item.isFav
                ? l10n.change_to_favorites
                : l10n.add_to_favorites,
            icon: item.isFav ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            active: item.isFav,
            onTap: () => DesktopGalleryActions.favorite(item),
          ),
        ),
        gap,
        _QuickButton(
          label: l10n.download,
          icon: CupertinoIcons.arrow_down_to_line,
          onTap: () =>
              DesktopGalleryActions.download(context, item.galleryProvider),
        ),
      ],
    );
  }
}

class _QuickButton extends StatefulWidget {
  const _QuickButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  State<_QuickButton> createState() => _QuickButtonState();
}

class _QuickButtonState extends State<_QuickButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            if (!_pressed) {
              setState(() => _pressed = true);
            }
          },
          onPointerUp: (_) {
            if (_pressed) {
              setState(() => _pressed = false);
            }
          },
          onPointerCancel: (_) {
            if (_pressed) {
              setState(() => _pressed = false);
            }
          },
          child: GestureDetector(
            key: ValueKey<String>('desktop-quick-${widget.label}'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: (!disableAnimations && _pressed) ? 0.94 : 1.0,
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 185),
                curve: Curves.easeOutQuart,
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hovered
                      ? const Color(0xEB16181E)
                      : const Color(0xBA16181E),
                  border: Border.all(
                    color: _hovered
                        ? const Color(0x48FFFFFF)
                        : const Color(0x26FFFFFF),
                    width: 0.75,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x36000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: EhSvgIcon(
                  widget.icon,
                  size: 14.5,
                  strokeWidth: 1.65,
                  color: widget.active
                      ? const Color(0xFFFF5A76)
                      : CupertinoColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
