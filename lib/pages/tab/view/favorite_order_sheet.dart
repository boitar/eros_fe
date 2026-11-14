import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';

/// Presents the favorites sort order sheet (native UIKit on iOS 26 liquid
/// glass, Flutter [showEhSheet] otherwise).
Future<FavoriteOrder?> presentFavoriteOrderSheet(
  BuildContext context, {
  required FavoriteOrder current,
}) async {
  final l10n = L10n.of(context);
  final options = <(FavoriteOrder order, String title, IconData icon, String symbol)>[
    (
      FavoriteOrder.posted,
      l10n.favorites_order_Use_posted,
      CupertinoIcons.clock,
      'clock',
    ),
    (
      FavoriteOrder.fav,
      l10n.favorites_order_Use_favorited,
      CupertinoIcons.heart,
      'heart',
    ),
  ];

  if (NativeSheet.available) {
    FavoriteOrder? picked;
    final session = await NativeSheet.present(
      kind: 'favoriteOrder',
      config: <String, Object?>{
        ...NativeSheet.style(context),
        'title': l10n.favorites_order,
        'selected': current.name,
        'items': [
          for (final (order, title, _, symbol) in options)
            <String, Object?>{
              'id': order.name,
              'title': title,
              'symbol': symbol,
            },
        ],
      },
      onEvent: (_, name, value) {
        if (name == 'select' && value is String) {
          for (final (order, _, _, _) in options) {
            if (order.name == value) {
              picked = order;
              break;
            }
          }
        }
      },
    );
    if (session != null) {
      await session.closed;
      return picked;
    }
  }

  if (!context.mounted) {
    return null;
  }

  return showEhSheet<FavoriteOrder>(
    context: context,
    builder: (sheetContext) => _FavoriteOrderSheet(
      title: l10n.favorites_order,
      current: current,
      options: options,
    ),
  );
}

class _FavoriteOrderSheet extends StatelessWidget {
  const _FavoriteOrderSheet({
    required this.title,
    required this.current,
    required this.options,
  });

  final String title;
  final FavoriteOrder current;
  final List<(FavoriteOrder, String, IconData, String)> options;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EhSheetHeader(title: title),
            const SizedBox(height: 8),
            EhSheetGroup(
              dividerIndent: 58,
              children: [
                for (final (order, label, icon, _) in options)
                  _FavoriteOrderRow(
                    key: Key('favoriteOrder.option.${order.name}'),
                    label: label,
                    icon: icon,
                    selected: order == current,
                    onPressed: () => Navigator.of(context).pop(order),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteOrderRow extends StatelessWidget {
  const _FavoriteOrderRow({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final base = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          letterSpacing: 0,
        );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: EhPressable(
        onPressed: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? EhPalette.accentSoft.resolveFrom(context)
                        : palette.fill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: selected ? accent : palette.text2.resolveFrom(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: base.copyWith(
                      fontSize: 15.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: palette.text1.resolveFrom(context),
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 20,
                    color: accent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
