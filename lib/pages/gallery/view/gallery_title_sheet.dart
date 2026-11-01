import 'dart:async';

import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/utils/vibrate.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Sheet with the gallery's titles in full, each selectable and copyable,
/// the one on screen first. Opened by tapping the detail page title.
Future<void> showGalleryTitleSheet(
  BuildContext context, {
  required String englishTitle,
  required String japaneseTitle,
  required bool showingJapanese,
  VoidCallback? onToggleLanguage,
  VoidCallback? onSearch,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => GalleryTitleSheet(
      englishTitle: englishTitle,
      japaneseTitle: japaneseTitle,
      showingJapanese: showingJapanese,
      onToggleLanguage: onToggleLanguage,
      onSearch: onSearch,
    ),
  );
}

class GalleryTitleSheet extends StatelessWidget {
  const GalleryTitleSheet({
    super.key,
    required this.englishTitle,
    required this.japaneseTitle,
    required this.showingJapanese,
    this.onToggleLanguage,
    this.onSearch,
  });

  final String englishTitle;
  final String japaneseTitle;
  final bool showingJapanese;
  final VoidCallback? onToggleLanguage;
  final VoidCallback? onSearch;

  /// Sheet corner; the cards inside sit 12pt in at 16pt, sharing its centre.
  static const double radius = 28;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final palette = ehTheme.palette;
    final english = englishTitle.trim();
    final japanese = japaneseTitle.trim();
    final bothTitles = english.isNotEmpty && japanese.isNotEmpty;

    final cards = <Widget>[
      if (japanese.isNotEmpty)
        _TitleCard(
          label: l10n.japanese_title,
          text: japanese,
          showing: showingJapanese || english.isEmpty,
        ),
      if (english.isNotEmpty)
        _TitleCard(
          label: l10n.english_title,
          text: english,
          showing: !showingJapanese || japanese.isEmpty,
        ),
    ];
    // The title already on screen comes first.
    if (!showingJapanese && cards.length == 2) {
      cards.insert(0, cards.removeLast());
    }

    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: media.size.height * 0.86,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: CupertinoDynamicColor.resolve(palette.raised, context),
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: media.padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 6),
              Container(
                width: 36,
                height: 5,
                decoration: ShapeDecoration(
                  color: CupertinoDynamicColor.resolve(palette.text3, context)
                      .withValues(alpha: 0.45),
                  shape: const StadiumBorder(),
                ),
              ),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Text(
                      l10n.full_title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CupertinoDynamicColor.resolve(
                            palette.text1, context),
                      ),
                    ),
                    PositionedDirectional(
                      end: 12,
                      child: _CloseButton(label: l10n.done),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                  child: Column(
                    children: <Widget>[
                      for (var i = 0; i < cards.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(height: 10),
                        cards[i],
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                child: _ActionRow(
                  children: <Widget>[
                    if (bothTitles && onToggleLanguage != null)
                      _SheetButton(
                        label: showingJapanese
                            ? l10n.show_english_title
                            : l10n.show_japanese_title,
                        icon: CupertinoIcons.textformat,
                        tinted: true,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onToggleLanguage!();
                        },
                      ),
                    if (onSearch != null)
                      _SheetButton(
                        label: l10n.search_title,
                        icon: CupertinoIcons.search,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onSearch!();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Side by side, or stacked once accessibility text sizes would squeeze
/// the labels.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final stacked = MediaQuery.textScalerOf(context).scale(15) > 22;
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
    }
    return Row(
      children: <Widget>[
        for (var i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _TitleCard extends StatefulWidget {
  const _TitleCard({
    required this.label,
    required this.text,
    required this.showing,
  });

  final String label;
  final String text;
  final bool showing;

  @override
  State<_TitleCard> createState() => _TitleCardState();
}

class _TitleCardState extends State<_TitleCard> {
  bool _copied = false;
  Timer? _reset;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    vibrateUtil.light();
    if (!mounted) {
      return;
    }
    final message = L10n.of(context).copied_to_clipboard;
    SemanticsService.sendAnnouncement(
        View.of(context), message, Directionality.of(context));
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final l10n = L10n.of(context);
    final accent = CupertinoDynamicColor.resolve(EhPalette.accent, context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: CupertinoDynamicColor.resolve(palette.fill, context),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                // Label and badge wrap under large text instead of pushing
                // the copy button off the card.
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CupertinoDynamicColor.resolve(
                              palette.text2, context),
                        ),
                      ),
                      if (widget.showing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: ShapeDecoration(
                            color: CupertinoDynamicColor.resolve(
                                EhPalette.accentSoft, context),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            l10n.title_showing,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: '${l10n.copy} ${widget.label}',
                  excludeSemantics: true,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: _copy,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: Tween<double>(begin: 0.6, end: 1)
                            .animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Icon(
                        _copied
                            ? CupertinoIcons.checkmark_alt
                            : CupertinoIcons.doc_on_doc,
                        key: ValueKey<bool>(_copied),
                        size: 19,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: SelectableText(
                widget.text,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: CupertinoDynamicColor.resolve(palette.text1, context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tinted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final foreground = tinted
        ? CupertinoDynamicColor.resolve(EhPalette.accent, context)
        : CupertinoDynamicColor.resolve(palette.text1, context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: tinted
              ? CupertinoDynamicColor.resolve(EhPalette.accentSoft, context)
              : CupertinoDynamicColor.resolve(palette.fill, context),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 17, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: () => Navigator.of(context).pop(),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: CupertinoDynamicColor.resolve(palette.fillPressed, context),
            shape: const CircleBorder(),
          ),
          child: Icon(
            CupertinoIcons.xmark,
            size: 13,
            weight: 700,
            color: CupertinoDynamicColor.resolve(palette.text2, context),
          ),
        ),
      ),
    );
  }
}
