import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/pages/tab/controller/favorite/favorite_selection_controller.dart';
import 'package:eros_fe/widget/eh_svg_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// Registers a card with the enclosing [FavoriteListScope.registry] so
/// horizontal swipe-to-select can hit-test rendered items.
class FavoriteSelectableCard extends StatefulWidget {
  const FavoriteSelectableCard({
    super.key,
    required this.provider,
    required this.child,
  });

  final GalleryProvider provider;
  final Widget child;

  @override
  State<FavoriteSelectableCard> createState() => _FavoriteSelectableCardState();
}

class _FavoriteSelectableCardState extends State<FavoriteSelectableCard> {
  FavoriteSelectableRegistry? _registry;
  String _registeredGid = '';

  void _syncRegistration() {
    final nextRegistry = FavoriteListScope.maybeOf(context)?.registry;
    final nextGid = widget.provider.gid ?? '';
    if (_registry != null && (_registry != nextRegistry || nextGid.isEmpty)) {
      _registry!.unregister(_registeredGid, context);
    }
    _registry = nextRegistry;
    _registeredGid = nextGid;
    if (_registry != null && _registeredGid.isNotEmpty) {
      _registry!.register(_registeredGid, context, widget.provider);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  @override
  void didUpdateWidget(FavoriteSelectableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRegistration();
  }

  @override
  void dispose() {
    if (_registry != null && _registeredGid.isNotEmpty) {
      _registry!.unregister(_registeredGid, context);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Applies the redesign's selection chrome directly to a cover/card:
/// - Selected: scales down to `0.94`, draws a `3px` [EhPalette.accent] ring,
///   and places a filled accent checkmark circle at top-right.
/// - Unselected in selection mode: stays at full brightness (no dimming) with
///   a subtle hollow ring indicator at top-right.
class FavoriteCoverSelectionChrome extends StatelessWidget {
  const FavoriteCoverSelectionChrome({
    super.key,
    required this.gid,
    required this.radius,
    required this.child,
    this.badgeInset = 7,
  });

  final String? gid;
  final BorderRadius radius;
  final Widget child;
  final double badgeInset;

  @override
  Widget build(BuildContext context) {
    final selection = FavoriteListScope.maybeOf(context)?.selection;
    if (selection == null) {
      return child;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Obx(() {
      final selecting = selection.selecting.value;
      if (!selecting) {
        return child;
      }
      final selected = selection.isSelected(gid);
      final accent = EhPalette.accent.resolveFrom(context);
      final onAccent = EhPalette.onAccent.resolveFrom(context);

      return AnimatedScale(
        scale: selected ? 0.94 : 1.0,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            child,
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: accent, width: 3),
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
              top: badgeInset,
              end: badgeInset,
              child: IgnorePointer(
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? accent : const Color(0x66000000),
                    border: Border.all(
                      color: selected ? onAccent : const Color(0xCCFFFFFF),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? EhSvgIcon(
                          CupertinoIcons.checkmark,
                          size: 13,
                          color: onAccent,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
