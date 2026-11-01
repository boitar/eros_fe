import 'package:eros_fe/index.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/view/archiver_dialog.dart';
import 'package:eros_fe/pages/gallery/view/rate_dialog.dart';
import 'package:eros_fe/pages/gallery/view/torrent_dialog.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// One entry of the detail page's "…" menu. Occasional actions live here
/// rather than as a row of equal-weight buttons in the content.
class GalleryMoreAction {
  const GalleryMoreAction({
    required this.id,
    required this.title,
    required this.symbol,
    required this.icon,
    this.onPressed,
    this.enabled = true,
    this.children = const <GalleryMoreAction>[],
  });

  final String id;
  final String title;

  /// SF Symbol for the native menu.
  final String symbol;

  /// Icon for the Flutter action sheet fallback.
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;

  /// Non-empty makes this a submenu.
  final List<GalleryMoreAction> children;

  NativeNavigationAction toNative() => NativeNavigationAction(
        id: 'gallery.$id',
        title: title,
        symbol: symbol,
        enabled: enabled,
        onPressed: onPressed,
        children: [for (final child in children) child.toNative()],
      );

  /// Submenus flattened to "Parent · Child" rows for the action sheet.
  Iterable<GalleryMoreAction> get flattened sync* {
    if (children.isEmpty) {
      yield this;
      return;
    }
    for (final child in children) {
      yield GalleryMoreAction(
        id: child.id,
        title: '$title · ${child.title}',
        symbol: child.symbol,
        icon: icon,
        enabled: enabled && child.enabled,
        onPressed: child.onPressed,
      );
    }
  }
}

void _copy(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  showToast(L10n.of(context).copied_to_clipboard);
}

List<GalleryMoreAction> galleryMoreActions(
  BuildContext context,
  GalleryPageController controller, {
  required bool isRoot,
}) {
  final l10n = L10n.of(context);
  final provider = controller.gState.galleryProvider;
  final torrents = provider?.torrentcount ?? '0';
  final japanese = provider?.japaneseTitle?.trim() ?? '';
  final english = provider?.englishTitle?.trim() ?? '';

  String? link() {
    final gid = provider?.gid;
    final token = provider?.token;
    if (gid == null || gid.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return '${Api.getBaseUrl()}/g/$gid/$token';
  }

  return <GalleryMoreAction>[
    if (isRoot)
      GalleryMoreAction(
        id: 'home',
        title: l10n.tab_gallery,
        symbol: 'house',
        icon: CupertinoIcons.house,
        onPressed: () => Get.offNamed<void>(EHRoutes.home),
      ),
    GalleryMoreAction(
      id: 'addTag',
      title: l10n.add_tags,
      symbol: 'tag',
      icon: CupertinoIcons.tag,
      onPressed: controller.addTag,
    ),
    GalleryMoreAction(
      id: 'rate',
      title: l10n.p_Rate,
      symbol: 'star',
      icon: CupertinoIcons.star,
      enabled: provider?.apiuid?.isNotEmpty ?? false,
      onPressed: () => showRateDialog(context),
    ),
    GalleryMoreAction(
      id: 'torrent',
      title: '${l10n.p_Torrent} ($torrents)',
      symbol: 'arrow.down.doc',
      icon: CupertinoIcons.arrow_down_doc,
      enabled: torrents != '0',
      onPressed: showTorrentDialog,
    ),
    GalleryMoreAction(
      id: 'archiver',
      title: l10n.p_Archiver,
      symbol: 'archivebox',
      icon: CupertinoIcons.archivebox,
      onPressed: showArchiverDialog,
    ),
    GalleryMoreAction(
      id: 'similar',
      title: l10n.p_Similar,
      symbol: 'square.on.square',
      icon: CupertinoIcons.square_on_square,
      onPressed: () {
        final title = (provider?.englishTitle ?? '').shortTitle;
        NavigatorUtil.goSearchPageWithParam(simpleSearch: 'title:"$title"');
      },
    ),
    GalleryMoreAction(
      id: 'copyTitle',
      title: l10n.copy_title,
      symbol: 'doc.on.doc',
      icon: CupertinoIcons.doc_on_doc,
      enabled: japanese.isNotEmpty || english.isNotEmpty,
      children: <GalleryMoreAction>[
        if (japanese.isNotEmpty)
          GalleryMoreAction(
            id: 'copyTitle.japanese',
            title: l10n.japanese_title,
            symbol: 'character.ja',
            icon: CupertinoIcons.doc_on_doc,
            onPressed: () => _copy(context, japanese),
          ),
        if (english.isNotEmpty)
          GalleryMoreAction(
            id: 'copyTitle.english',
            title: l10n.english_title,
            symbol: 'character',
            icon: CupertinoIcons.doc_on_doc,
            onPressed: () => _copy(context, english),
          ),
      ],
    ),
    GalleryMoreAction(
      id: 'copyLink',
      title: l10n.copy_link,
      symbol: 'link',
      icon: CupertinoIcons.link,
      enabled: link() != null,
      onPressed: () {
        final url = link();
        if (url != null) {
          _copy(context, url);
        }
      },
    ),
  ];
}

/// Flutter bar fallback for the native "…" menu.
Future<void> showGalleryMoreSheet(
  BuildContext context,
  GalleryPageController controller, {
  required bool isRoot,
}) {
  final actions = [
    for (final action
        in galleryMoreActions(context, controller, isRoot: isRoot))
      ...action.flattened,
  ];
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => EhActionSheet(
      actions: <Widget>[
        for (final action in actions)
          CupertinoActionSheetAction(
            onPressed: action.enabled
                ? () {
                    Navigator.of(sheetContext).pop();
                    action.onPressed?.call();
                  }
                : () {},
            child: Opacity(
              opacity: action.enabled ? 1 : 0.4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(action.icon, size: 20),
                  const SizedBox(width: 8),
                  Text(action.title),
                ],
              ),
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: Text(L10n.of(context).cancel),
      ),
    ),
  );
}
