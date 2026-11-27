import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/pages/tab/controller/favorite/fav_search_scope.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:flutter/cupertino.dart';

/// Builds a [TextSpan] highlighting all case-insensitive occurrences of search
/// terms extracted from [highlightQuery] using [EhPalette.accentSoft] +
/// [EhPalette.accent].
TextSpan buildHighlightedTextSpan({
  required BuildContext context,
  required String text,
  required TextStyle style,
  String highlightQuery = '',
}) {
  final terms = extractFavoriteHighlightTerms(highlightQuery);
  if (terms.isEmpty || text.isEmpty) {
    return TextSpan(text: text, style: style);
  }
  final escaped = terms.map(RegExp.escape).join('|');
  final pattern = RegExp(escaped, caseSensitive: false);
  final matches = pattern.allMatches(text);
  if (matches.isEmpty) {
    return TextSpan(text: text, style: style);
  }

  final highlightBg = EhPalette.accentSoft.resolveFrom(context);
  final highlightFg = EhPalette.accent.resolveFrom(context);
  final highlightStyle = style.copyWith(
    color: highlightFg,
    backgroundColor: highlightBg,
    fontWeight: FontWeight.w600,
  );

  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(
      TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyle,
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(style: style, children: spans);
}

/// Flat single- or two-line favorite note indicator for favorites list and
/// favorites search cards.
///
/// Intentionally carries no colored vertical bar or card border: gray body text
/// paired with a subtle note icon keeps cards calm and lets folder colors stay
/// exclusively on folder hearts.
class FavNoteLine extends StatelessWidget {
  const FavNoteLine({
    super.key,
    required this.note,
    this.maxLines = 1,
    this.highlightQuery = '',
    this.fontSize = 12.5,
  });

  final String? note;
  final int maxLines;
  final String highlightQuery;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final trimmed = note?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }
    final palette = ehTheme.palette;
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: 1.35,
      color: palette.text2.resolveFrom(context),
    );
    final iconColor = palette.text3.resolveFrom(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2.5),
          child: EhSvgIcon(
            CupertinoIcons.text_alignleft,
            size: 12,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text.rich(
            buildHighlightedTextSpan(
              context: context,
              text: trimmed,
              style: textStyle,
              highlightQuery: highlightQuery,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
