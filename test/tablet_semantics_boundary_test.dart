import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  for (final scoped in [false, true]) {
    testWidgets('sibling navigator semantics: scoped=$scoped', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          GetMaterialApp(
            home: Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: scoped,
                    explicitChildNodes: true,
                    child: Navigator(
                      onGenerateRoute: (_) => GetPageRoute<void>(
                        page: () => CupertinoPageScaffold(
                          child: CupertinoButton(
                            onPressed: () {},
                            child: const Text('Left action'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    container: scoped,
                    explicitChildNodes: true,
                    child: Navigator(
                      onGenerateRoute: (_) => GetPageRoute<void>(
                        page: () => const CupertinoPageScaffold(
                          child: SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Left action'),
            scoped ? findsOneWidget : findsNothing);
        await tester.pumpWidget(const SizedBox());
      } finally {
        handle.dispose();
      }
    });
  }
}
