import 'dart:async';

import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/utils/export_progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Completer<String?> work;
  late GlobalKey<NavigatorState> navigator;
  late List<Object> errors;
  String? result;
  var cancellations = 0;

  Future<void> mount(WidgetTester tester) async {
    work = Completer<String?>();
    navigator = GlobalKey<NavigatorState>();
    errors = [];
    result = 'pending';
    cancellations = 0;
    await tester.pumpWidget(CupertinoApp(
      navigatorKey: navigator,
      locale: const Locale('en'),
      localizationsDelegates: const [L10n.delegate],
      home: Builder(builder: (context) {
        return CupertinoPageScaffold(
          child: CupertinoButton(
            child: const Text('Export'),
            onPressed: () async {
              result = await showExportProgress(context, () => work.future,
                  onCancel: () => cancellations++,
                  onError: (error, stack) => errors.add(error));
            },
          ),
        );
      }),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
  }

  testWidgets('progress closes only after the file future completes',
      (tester) async {
    await mount(tester);
    expect(result, 'pending');
    work.complete('/ready/fixture.zip');
    await tester.pumpAndSettle();
    expect(result, '/ready/fixture.zip');
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(errors, isEmpty);
  });

  testWidgets('file creation failure closes progress and reports the error',
      (tester) async {
    await mount(tester);
    final failure = StateError('Cannot create archive');
    work.completeError(failure);
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(errors, hasLength(1));
    expect(errors.single, same(failure));
    expect(tester.takeException(), isNull);
  });

  testWidgets('late completion after cancel cannot pop a later page',
      (tester) async {
    await mount(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    unawaited(navigator.currentState!.push<void>(CupertinoPageRoute(
        builder: (_) => const CupertinoPageScaffold(
            child: Text('Unrelated page')))));
    work.complete('/late/fixture.zip');
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(cancellations, 1);
    expect(find.text('Unrelated page'), findsOneWidget);
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
