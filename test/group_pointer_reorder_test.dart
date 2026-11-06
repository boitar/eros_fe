import 'dart:ui';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/widget/adaptive_reorderable_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => PlatformCapabilities.debugHostPlatformOverride = null);

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets('$platform sorting uses the appropriate press gesture', (
      tester,
    ) async {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      final items = ['A', 'B', 'C'];
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: AdaptiveReorderableColumn(
                  onReorder: (oldIndex, newIndex) => setState(() {
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                    changes++;
                  }),
                  children: [
                    for (final item in items)
                      SizedBox(
                        key: ValueKey(item),
                        height: 60,
                        width: 300,
                        child: Row(
                          children: [
                            Text(item),
                            const Spacer(),
                            const Icon(Icons.drag_handle),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final desktop =
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows;
      final start =
          tester.getTopRight(find.byKey(const ValueKey('A'))) +
          const Offset(-12, 30);
      final gesture = await tester.startGesture(
        start,
        kind: desktop ? PointerDeviceKind.mouse : PointerDeviceKind.touch,
      );
      if (!desktop) {
        await tester.pump(const Duration(milliseconds: 600));
      }
      await gesture.moveBy(const Offset(0, 130));
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(items, ['B', 'C', 'A']);
    });
  }
}
