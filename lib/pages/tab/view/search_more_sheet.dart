import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';

/// Maps a search "…" action identifier to a Cupertino fallback icon.
IconData searchMoreIconFor(String id) => switch (id) {
      'imageSearch' => CupertinoIcons.photo_on_rectangle,
      'quickSearchList' => CupertinoIcons.list_bullet,
      'addQuickSearch' => CupertinoIcons.plus_circle,
      'jump' => CupertinoIcons.arrow_uturn_down_circle,
      _ => CupertinoIcons.arrow_up_to_line,
    };

/// Presents the search page's "…" actions as a unified modern sheet
/// (native UIKit [ErosActionListSheet] on iOS 26 liquid glass, Flutter
/// [showEhSheet] everywhere else).
Future<void> presentSearchMoreSheet(
  BuildContext context,
  List<NativeNavigationAction> actions,
) async {
  final title = L10n.of(context).more_actions;

  if (NativeSheet.available) {
    NativeNavigationAction? picked;
    final session = await NativeSheet.present(
      kind: 'actionList',
      config: <String, Object?>{
        ...NativeSheet.style(context),
        'title': title,
        'showChevrons': true,
        'items': [
          for (final action in actions)
            <String, Object?>{
              'id': action.id,
              'title': action.title,
              'symbol': action.symbol ?? 'ellipsis',
              'enabled': action.enabled && action.onPressed != null,
            },
        ],
      },
      onEvent: (_, name, value) {
        if (name == 'select' && value is String) {
          for (final action in actions) {
            if (action.id == value &&
                action.enabled &&
                action.onPressed != null) {
              picked = action;
              break;
            }
          }
        }
      },
    );
    if (session != null) {
      await session.closed;
      picked?.onPressed?.call();
      return;
    }
  }

  if (!context.mounted) {
    return;
  }

  final picked = await showEhSheet<NativeNavigationAction>(
    context: context,
    builder: (sheetContext) => _SearchMoreSheet(
      title: title,
      actions: actions,
    ),
  );
  picked?.onPressed?.call();
}

class _SearchMoreSheet extends StatelessWidget {
  const _SearchMoreSheet({
    required this.title,
    required this.actions,
  });

  final String title;
  final List<NativeNavigationAction> actions;

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
                for (final action in actions)
                  EhSheetOptionRow(
                    key: Key('search.moreOption.${action.id}'),
                    label: action.title,
                    icon: searchMoreIconFor(action.id),
                    enabled: action.enabled && action.onPressed != null,
                    showChevron: true,
                    onPressed: action.enabled && action.onPressed != null
                        ? () => Navigator.of(context).pop(action)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
