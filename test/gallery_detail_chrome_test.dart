import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/gallery/view/gallery_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => CupertinoApp(
        locale: const Locale('en'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: CupertinoPageScaffold(
          child: Center(child: SizedBox(width: 240, child: child)),
        ),
      );

  testWidgets('long header titles end with an ellipsis', (tester) async {
    await tester.pumpWidget(host(GalleryTitle(title: 'Long title ' * 40)));
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 6);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('tapping the title offers both titles in full', (tester) async {
    await tester.pumpWidget(host(const GalleryTitle(
      title: '(C108) Main title',
      alternateTitle: 'Alternate title',
    )));
    await tester.tap(find.text('(C108) Main title'));
    await tester.pumpAndSettle();
    expect(find.text('Full Title'), findsOneWidget);
    expect(find.text('(C108) Main title\n\nAlternate title'), findsOneWidget);
    expect(find.textContaining('Copy'), findsNWidgets(2));
  });

  testWidgets('a title without an alternate offers one copy action',
      (tester) async {
    await tester.pumpWidget(host(const GalleryTitle(
      title: 'Only title',
      alternateTitle: '',
    )));
    await tester.tap(find.text('Only title'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
  });
}
