import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/controller/tabview_controller.dart';
import 'package:eros_fe/pages/tab/fetch_list.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/jump_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Settings extends GetxService implements EhSettingService {
  @override
  bool get liquidGlass => false;
  @override
  final RxBool vibrate = false.obs;
  @override
  bool get isPureDarkTheme => false;
  @override
  RxBool get pureDarkThemeObs => false.obs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting $invocation');
}

class _FakeTagController extends GetxController implements TagController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _RecordedFetchCall {
  const _RecordedFetchCall({
    this.gid,
    this.pageType,
    this.jump,
    this.seek,
    this.page,
  });

  final String? gid;
  final PageType? pageType;
  final String? jump;
  final String? seek;
  final int? page;
}

class _FakeTabViewController extends TabViewController {
  final List<_RecordedFetchCall> fetchCalls = [];
  GalleryList? nextResult;

  @override
  void onReady() {}

  @override
  Future<GalleryList?> fetchDataFrom({
    String? gid,
    PageType? pageType,
    String? jump,
    String? seek,
    int? page,
  }) async {
    fetchCalls.add(
      _RecordedFetchCall(
        gid: gid,
        pageType: pageType,
        jump: jump,
        seek: seek,
        page: page,
      ),
    );
    return nextResult ??
        const GalleryList(
          gallerys: [],
          nextGid: '200',
          prevGid: '100',
        );
  }
}

Widget _app(Widget child, {Size? size}) {
  final app = GetCupertinoApp(
    locale: const Locale('zh', 'CN'),
    supportedLocales: L10n.delegate.supportedLocales,
    localizationsDelegates: const [
      L10n.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: CupertinoPageScaffold(child: child),
  );
  if (size == null) return app;
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: app,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    Get.put<EhSettingService>(_Settings());
    Get.put(ThemeService());
    Get.put<TagController>(_FakeTagController());
    NativeSheet.debugAvailable = false;
  });

  tearDown(() {
    NativeSheet.debugAvailable = null;
    Get.reset();
  });

  testWidgets('page jump sheet disables first/prev on page 1 and next/last on maxPage', (
    tester,
  ) async {
    PageJumpResult? result;
    var current = 1;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              result = await showPageJumpSheet(
                context,
                title: '跳到页面',
                subtitle: '共 10 页',
                current: current,
                max: 10,
                autofocus: false,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('中间'), findsNothing);
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_first'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_prev'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_next'))).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_last'))).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('jump_nav_last')));
    await tester.pumpAndSettle();
    expect(result, isA<PageJumpNav>());
    expect(result!.nav, JumpNavAction.last);
    expect(result!.page, 10);

    current = 10;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_first'))).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_prev'))).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_next'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_last'))).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('jump_nav_prev')));
    await tester.pumpAndSettle();
    expect(result!.nav, JumpNavAction.prev);
    expect(result!.page, 9);
  });

  testWidgets('seek sheet disables nav buttons from cursors and maps newer/older', (
    tester,
  ) async {
    SeekRequest? result;
    var prevGid = '';
    var nextGid = '2740988';

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async {
              result = await showSeekSheet(
                context,
                text: '2024-05-01',
                gid: '',
                pickerVisible: false,
                pickerDate: DateTime(2024, 5, 1),
                prevGid: prevGid,
                nextGid: nextGid,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('按日期或 GID 定位'), findsOneWidget);
    expect(find.text('看更新的'), findsOneWidget);
    expect(find.text('看更早的'), findsOneWidget);
    expect(find.text('2740988'), findsNothing);

    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_first'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_prev'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_next'))).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_last'))).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('seek_newer')));
    await tester.pumpAndSettle();
    expect(result, isA<SeekTargetRequest>());
    expect(result!.direction, SeekDirection.prev);
    expect(result!.text, '2024-05-01');

    prevGid = '2741230';
    nextGid = '';
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_first'))).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_next'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<EhButton>(find.byKey(const ValueKey('jump_nav_last'))).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('seek_older')));
    await tester.pumpAndSettle();
    expect(result, isA<SeekTargetRequest>());
    expect(result!.direction, SeekDirection.next);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('jump_nav_first')));
    await tester.pumpAndSettle();
    expect(result, isA<SeekNavRequest>());
    expect(result!.nav, JumpNavAction.first);
  });

  testWidgets('TabViewController cursor nav wires first/prev/next/last and afterJump', (
    tester,
  ) async {
    final controller = _FakeTabViewController()
      ..prevGid = '3000'
      ..nextGid = '2000'
      ..afterJump = true;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => controller.showJumpDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    // Tap Last -> ?prev=1
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('jump_nav_last')));
    await tester.pumpAndSettle();
    expect(controller.fetchCalls.last.gid, '1');
    expect(controller.fetchCalls.last.pageType, PageType.prev);
    expect(controller.afterJump, isTrue);

    // Tap First -> fresh load with afterJump=false
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('jump_nav_first')));
    await tester.pumpAndSettle();
    expect(controller.fetchCalls.last.gid, isNull);
    expect(controller.fetchCalls.last.pageType, isNull);
    expect(controller.afterJump, isFalse);
  });
}
