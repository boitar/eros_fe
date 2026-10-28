import 'package:eros_fe/widget/cupertino/list_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('additional info wraps at accessibility text sizes',
      (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(3),
          ),
          child: const SizedBox(
            width: 308,
            child: EhCupertinoListTile(
              title: Text('双页模式'),
              additionalInfo: Text('自动（宽屏双页）'),
              trailing: CupertinoListTileChevron(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('自动（宽屏双页）'), findsOneWidget);
  });
}
