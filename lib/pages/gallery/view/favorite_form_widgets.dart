import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';

/// Inset content on the form's glass surface, without another blur layer.
class FavoriteFormGroup extends StatelessWidget {
  const FavoriteFormGroup({
    super.key,
    required this.child,
    this.focusColor,
    this.enabled = true,
  });

  final Widget child;
  final Color? focusColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return ValueListenableBuilder<bool?>(
      valueListenable: LiquidGlassAccessibilitySettings.reduceTransparency,
      builder: (context, reduceTransparency, _) {
        final opaque =
            reduceTransparency != false || MediaQuery.highContrastOf(context);
        final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
        final fill = CupertinoDynamicColor.resolve(
          CupertinoColors.secondarySystemGroupedBackground,
          context,
        );
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: fill.withValues(alpha: opaque ? 1 : (dark ? .6 : .68)),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(
              color: focusColor ??
                  CupertinoDynamicColor.resolve(
                    CupertinoColors.separator,
                    context,
                  ).withValues(alpha: opaque ? .45 : .16),
              width: focusColor != null ? 1.5 : .5,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

class FavoriteCategoryList extends StatelessWidget {
  const FavoriteCategoryList({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Expand folders; only the whole form scrolls when the viewport is too small.
    return FavoriteFormGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 48, end: 16),
                child: Container(
                  height: .5,
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.separator,
                    context,
                  ).withValues(alpha: .35),
                ),
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

class FavoriteNoteField extends StatefulWidget {
  const FavoriteNoteField({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  State<FavoriteNoteField> createState() => _FavoriteNoteFieldState();
}

class _FavoriteNoteFieldState extends State<FavoriteNoteField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusChanged);
  }

  void _focusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_focusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = L10n.of(context).favorite_note_hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 7),
            child: Text(label,
                style: EhPopupTextStyles.secondary(context).copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                )),
          ),
        ),
        FavoriteFormGroup(
          focusColor: _focusNode.hasFocus
              ? CupertinoDynamicColor.resolve(
                  CupertinoTheme.of(context).primaryColor, context)
              : null,
          child: Semantics(
            label: label,
            child: CupertinoTextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              minLines: 1,
              maxLines: 3,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              style: EhPopupTextStyles.body(context),
              decoration: null,
              prefix: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14),
                child: ExcludeSemantics(
                  child: Icon(CupertinoIcons.pencil,
                      size: 17,
                      color: EhPopupTextStyles.secondary(context).color),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
