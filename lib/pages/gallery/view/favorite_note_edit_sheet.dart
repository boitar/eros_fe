import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/network/favorite_mutation.dart';
import 'package:eros_fe/pages/controller/fav_controller.dart';
import 'package:eros_fe/pages/gallery/view/favorite_form_widgets.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:eros_fe/widget/favcat_grid.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// E-Hentai's live `gallerypopups.php?act=addfav` limit (`Note (Max 200 Characters)`).
const int kFavoriteNoteMaxLength = 200;

/// Threshold at which the remaining-character counter appears (`< 20` left).
const int kFavoriteNoteCounterThreshold = 20;

/// Presents the flat bottom sheet for adding or editing a gallery's favorite
/// note without leaving the detail or preview surface.
Future<String?> showFavoriteNoteEditSheet(
  BuildContext context, {
  required String gid,
  required String token,
  required String favcat,
  required String favTitle,
  required String initialNote,
}) {
  return showEhSheet<String>(
    context: context,
    builder: (sheetContext) => _FavoriteNoteEditSheet(
      gid: gid,
      token: token,
      favcat: favcat,
      favTitle: favTitle,
      initialNote: initialNote,
    ),
  );
}

class _FavoriteNoteEditSheet extends StatefulWidget {
  const _FavoriteNoteEditSheet({
    required this.gid,
    required this.token,
    required this.favcat,
    required this.favTitle,
    required this.initialNote,
  });

  final String gid;
  final String token;
  final String favcat;
  final String favTitle;
  final String initialNote;

  @override
  State<_FavoriteNoteEditSheet> createState() => _FavoriteNoteEditSheetState();
}

class _FavoriteNoteEditSheetState extends State<_FavoriteNoteEditSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialNote,
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    final note = _controller.text.trim();
    try {
      await Get.find<FavController>().updateFavoriteNote(
        widget.gid,
        widget.token,
        favcat: widget.favcat,
        favnote: note,
      );
      await vibrateUtil.success();
      if (mounted) {
        Navigator.of(context).pop(note);
      }
    } catch (e) {
      await vibrateUtil.error();
      showToast(favoriteMutationMessage(e));
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final accent = EhPalette.accent.resolveFrom(context);
    final length = _controller.text.characters.length;
    final remaining = kFavoriteNoteMaxLength - length;
    final showCounter = remaining < kFavoriteNoteCounterThreshold;
    final title = widget.initialNote.trim().isEmpty
        ? l10n.fav_note_add
        : l10n.fav_note_edit;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EhSheetHeader(
          title: title,
          onClose: _saving ? () {} : null,
          trailing: CupertinoButton(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const CupertinoActivityIndicator(radius: 9)
                : Text(
                    l10n.save,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FavoriteNoteField(
                controller: _controller,
                minLines: 4,
                maxLines: 5,
                maxLength: kFavoriteNoteMaxLength,
                autofocus: true,
                showLabel: false,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  EhSvgIcon(
                    CupertinoIcons.heart_fill,
                    size: 12,
                    color: favcatDisplayColor(context, widget.favcat),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      l10n.fav_saved_in(widget.favTitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.text2.resolveFrom(context),
                      ),
                    ),
                  ),
                  if (showCounter)
                    Text(
                      '$length/$kFavoriteNoteMaxLength',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: remaining <= 0
                            ? CupertinoColors.systemRed.resolveFrom(context)
                            : accent,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
