import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/store/db/entity/tag_translat.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:flutter/cupertino.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';

/// Card decoration of the secondary pages, matching the gallery cards.
BoxDecoration ehCardDecoration(BuildContext context, {double radius = 16}) {
  final palette = ehTheme.palette;
  final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
  return BoxDecoration(
    color: palette.surface.resolveFrom(context),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: dark ? null : EhPalette.lightCardShadows,
    border: dark
        ? Border(top: BorderSide(color: palette.edgeLight.resolveFrom(context)))
        : null,
  );
}

/// Highlights every case-insensitive occurrence of [query] in [text].
List<TextSpan> highlightSpans(
  String text,
  String query, {
  required TextStyle style,
  required TextStyle highlight,
}) {
  if (query.isEmpty) {
    return [TextSpan(text: text, style: style)];
  }
  final spans = <TextSpan>[];
  final lower = text.toLowerCase();
  final needle = query.toLowerCase();
  var start = 0;
  while (true) {
    final index = lower.indexOf(needle, start);
    if (index < 0) {
      spans.add(TextSpan(text: text.substring(start), style: style));
      break;
    }
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: style));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + needle.length),
        style: highlight,
      ),
    );
    start = index + needle.length;
  }
  return spans;
}

/// Tag completions as one card: namespace badge, the key with the typed
/// part in accent, the translation below, and a "+" affordance.
class SliverTagSuggestions extends StatelessWidget {
  const SliverTagSuggestions({
    super.key,
    required this.tags,
    required this.query,
    required this.onSelected,
    this.showTranslation = true,
  });

  final List<TagTranslat> tags;
  final String query;
  final ValueChanged<int> onSelected;
  final bool showTranslation;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      sliver: DecoratedSliver(
        decoration: ehCardDecoration(context),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => TagSuggestionTile(
              tag: tags[index],
              query: query,
              showTranslation: showTranslation,
              divider: index > 0,
              onTap: () => onSelected(index),
            ),
            childCount: tags.length,
          ),
        ),
      ),
    );
  }
}

class TagSuggestionTile extends StatelessWidget {
  const TagSuggestionTile({
    super.key,
    required this.tag,
    required this.query,
    required this.onTap,
    this.showTranslation = true,
    this.divider = false,
  });

  final TagTranslat tag;
  final String query;
  final VoidCallback onTap;
  final bool showTranslation;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle
        .copyWith(letterSpacing: 0, fontVariations: const []);
    final accent = EhPalette.accent.resolveFrom(context);
    final keyStyle = base.copyWith(
      fontSize: 15.5,
      height: 1.3,
      color: palette.text1.resolveFrom(context),
    );
    final subStyle = base.copyWith(
      fontSize: 13,
      height: 1.3,
      color: palette.text2.resolveFrom(context),
    );
    final namespace = tag.namespace.trim();
    final translatedNamespace = showTranslation
        ? (EHConst.translateTagType[namespace] ?? namespace)
        : namespace;
    final translation = showTranslation ? tag.nameNotMD : null;
    final highlightedQuery = query.contains(':')
        ? query.split(':').last
        : query;

    return Semantics(
      button: true,
      label: L10n.of(context).sp_add_tag(tag.fullTagText ?? tag.key),
      hint: translation,
      excludeSemantics: true,
      onTap: onTap,
      child: EhPressable(
        onPressed: onTap,
        child: ColoredBox(
          color: const Color(0x00000000),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (divider)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14),
                  child: Container(
                    height: .5,
                    color: EhPalette.separator.resolveFrom(context),
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 12, 11),
                child: Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.fill.resolveFrom(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        translatedNamespace,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: base.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.text2.resolveFrom(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: highlightSpans(
                                tag.key,
                                highlightedQuery,
                                style: keyStyle,
                                highlight: keyStyle.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (translation != null &&
                              translation.isNotEmpty &&
                              translation != tag.key)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text.rich(
                                TextSpan(
                                  children: highlightSpans(
                                    translation,
                                    highlightedQuery,
                                    style: subStyle,
                                    highlight: subStyle.copyWith(
                                      color: accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: EhPalette.accentSoft.resolveFrom(context),
                        shape: BoxShape.circle,
                      ),
                      child: EhSvgIcon(CupertinoIcons.plus, size: 15, color: accent),
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

/// A recent search as a white capsule; the translation sits on a second line.
class SearchHistoryChip extends StatelessWidget {
  const SearchHistoryChip({
    super.key,
    required this.text,
    this.translation,
    required this.onPressed,
    this.onLongPress,
  });

  final String text;
  final String? translation;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = ehTheme.palette;
    final base = CupertinoTheme.of(context).textTheme.textStyle
        .copyWith(letterSpacing: 0, fontVariations: const []);
    final hasTranslation = translation != null && translation!.isNotEmpty;
    return Semantics(
      button: true,
      label: text,
      hint: hasTranslation ? translation : null,
      excludeSemantics: true,
      onTap: onPressed,
      onLongPress: onLongPress,
      child: EhPressable(
        onPressed: onPressed,
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: ehCardDecoration(context, radius: 17),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: base.copyWith(
                  fontSize: 14,
                  height: 1.25,
                  color: palette.text1.resolveFrom(context),
                ),
              ),
              if (hasTranslation)
                Text(
                  translation!,
                  style: base.copyWith(
                    fontSize: 11.5,
                    height: 1.25,
                    color: palette.text2.resolveFrom(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section caption with trailing actions, e.g. "Recent  [Translate] [Clear]".
class EhSectionHeader extends StatelessWidget {
  const EhSectionHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 20, 16, 10),
  });

  final String title;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: ehTheme.palette.text2.resolveFrom(context),
                ),
              ),
            ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// Comma-separated tag input that shows finished tags in accent while the
/// segment being typed stays plain. The text itself is unchanged.
class TagTokenTextEditingController extends TextEditingController {
  TagTokenTextEditingController({super.text});

  Color? tokenColor;

  /// Finished tags: every non-empty segment before the last comma.
  static List<String> finishedTags(String text) {
    final parts = text.split(RegExp(r'[,，]'));
    if (parts.length < 2) {
      return const [];
    }
    return parts
        .sublist(0, parts.length - 1)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final color = tokenColor;
    // Leave IME composition to the framework so its underline stays right.
    if (color == null || (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final lastComma = text.lastIndexOf(RegExp(r'[,，]'));
    if (lastComma < 0) {
      return TextSpan(style: style, text: text);
    }
    final done = text.substring(0, lastComma + 1);
    final tail = text.substring(lastComma + 1);
    final children = <TextSpan>[];
    final tokenStyle = style?.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    );
    final pattern = RegExp(r'[,，]');
    var start = 0;
    for (final match in pattern.allMatches(done)) {
      children.add(
        TextSpan(text: done.substring(start, match.start), style: tokenStyle),
      );
      children.add(TextSpan(text: match.group(0), style: style));
      start = match.end;
    }
    children.add(TextSpan(text: tail, style: style));
    return TextSpan(style: style, children: children);
  }
}
