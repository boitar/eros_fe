import 'package:eros_fe/adaptive/browse_layout.dart';
import 'package:flutter/widgets.dart';

/// Route-local opt-in to drawing below desktop window chrome.
class DetailWindowBackdrop extends StatefulWidget {
  const DetailWindowBackdrop({
    super.key,
    required this.enabled,
    required this.child,
  });
  final bool enabled;
  final Widget child;
  static final active = ValueNotifier(false);
  @override
  State<DetailWindowBackdrop> createState() => _DetailWindowBackdropState();
}

class _DetailWindowBackdropState extends State<DetailWindowBackdrop> {
  static final _owners = <Object>{};
  void _update(bool enabled) {
    if (enabled) {
      _owners.add(this);
    } else {
      _owners.remove(this);
    }
    DetailWindowBackdrop.active.value = _owners.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        widget.enabled &&
        !BrowsePaneScope.isSplit(context) &&
        TickerMode.of(context) &&
        identical(
          Navigator.maybeOf(context),
          Navigator.maybeOf(context, rootNavigator: true),
        ) &&
        (ModalRoute.of(context)?.isCurrent ?? false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _update(enabled);
      }
    });
    return widget.child;
  }

  @override
  void dispose() {
    _owners.remove(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DetailWindowBackdrop.active.value = _owners.isNotEmpty;
    });
    super.dispose();
  }
}
