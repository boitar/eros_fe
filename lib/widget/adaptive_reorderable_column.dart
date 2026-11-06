import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:flutter/widgets.dart';
import 'package:reorderables/reorderables.dart';

/// Mouse users can drag immediately in the explicit sorting view. Touch
/// platforms retain the long press so a scroll does not reorder an item.
class AdaptiveReorderableColumn extends StatelessWidget {
  const AdaptiveReorderableColumn({
    super.key,
    required this.children,
    required this.onReorder,
  });

  final List<Widget> children;
  final void Function(int, int) onReorder;

  @override
  Widget build(BuildContext context) => ReorderableColumn(
    needsLongPressDraggable: switch (PlatformCapabilities.hostPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => false,
      _ => true,
    },
    onReorder: onReorder,
    children: children,
  );
}
