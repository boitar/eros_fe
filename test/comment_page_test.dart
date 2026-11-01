import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/service/controller_tag_service.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_controller.dart';
import 'package:eros_fe/pages/gallery/controller/gallery_page_state.dart';
import 'package:eros_fe/pages/gallery/view/comment_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  @override
  bool get showComments => true;
  @override
  bool get showOnlyUploaderComment => false;
  @override
  bool get filterCommentsByScore => false;
  @override
  bool get liquidGlass => false;
  @override
  bool get liquidGlassFollowSystemTransparency => true;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting: ${invocation.memberName}');
}

class _Page extends GetxController implements GalleryPageController {
  _Page(this.gState);
  @override
  final GalleryPageState gState;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected page access: ${invocation.memberName}');
}

void main() {
  tearDown(() {
    NativeNavigationBridge.enabled.value = false;
    Get.reset();
  });

  Future<void> mount(WidgetTester tester, {required bool native}) async {
    Get.testMode = true;
    NativeNavigationBridge.enabled.value = native;
    Get.put<EhSettingService>(_Settings());
    Get.put<GalleryPageController>(_Page(GalleryPageState()), tag: '42');
    await tester.pumpWidget(GetCupertinoApp(
      locale: const Locale('en'),
      localizationsDelegates: const [L10n.delegate],
      home: NativeNavigationScope(
        child: const ControllerTagScope(
          snapshot: ControllerTagSnapshot(galleryTag: '42'),
          child: CommentPage(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder sendButton() => find.ancestor(
      of: find.byIcon(CupertinoIcons.arrow_up),
      matching: find.byType(CupertinoButton));

  testWidgets('the comments keep the native bar, with their title on it',
      (tester) async {
    await mount(tester, native: true);
    // Hiding the bar for a page without chrome moved everything by its band.
    expect(find.byType(CupertinoNavigationBar), findsNothing);
    final route = ModalRoute.of(tester.element(find.byType(CommentPage)))!;
    final chrome = NativeNavigationBridge.chromeFor(route)!;
    expect(chrome.title, 'Gallery Comments');
    expect(chrome.navigationBarVisible, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('without the native shell a Flutter bar carries the title',
      (tester) async {
    await mount(tester, native: false);
    expect(
        find.descendant(
            of: find.byType(CupertinoNavigationBar),
            matching: find.text('Gallery Comments')),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the send button waits for something to send', (tester) async {
    await mount(tester, native: true);
    expect(tester.widget<CupertinoButton>(sendButton()).onPressed, isNull);
    await tester.enterText(find.byType(CupertinoTextField), '   ');
    await tester.pump();
    expect(tester.widget<CupertinoButton>(sendButton()).onPressed, isNull);
    await tester.enterText(find.byType(CupertinoTextField), 'Thanks!');
    await tester.pump();
    expect(tester.widget<CupertinoButton>(sendButton()).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
