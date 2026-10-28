import 'package:eros_fe/pages/image_view/view/view_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loading status fits at accessibility text sizes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(382, 644);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(382, 644),
            textScaler: TextScaler.linear(3),
          ),
          child: const SizedBox.expand(
            child: ViewLoading(ser: 11, label: '加载图片文件'),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('加载图片文件'), findsOneWidget);
  });
}
