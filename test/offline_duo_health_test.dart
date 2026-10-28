import 'package:eros_fe/debug/offline_duo_health.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('acceptance health reports errors without swallowing the handler',
      (tester) async {
    final original = FlutterError.onError;
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: OfflineDuoHealth(child: SizedBox.expand()),
    ));
    FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('Synthetic QA failure')));
    expect(tester.takeException(), isA<StateError>());
    await tester.pump();
    await tester.pump();
    final probe = tester.widget<Semantics>(find.byType(Semantics).first);
    expect(probe.properties.label, 'framework=1;platform=0');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(FlutterError.onError, same(original));
  });
}
