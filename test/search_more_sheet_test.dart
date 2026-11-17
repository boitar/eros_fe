import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/view/search_more_sheet.dart';
import 'package:eros_fe/widget/eh_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('eros/native-sheet');

  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    Get.put<EhSettingService>(_Settings());
    Get.put(ThemeService());
    NativeSheet.debugAvailable = false;
  });

  tearDown(() {
    NativeSheet.debugAvailable = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    Get.reset();
  });

  Widget host(List<NativeNavigationAction> actions) => GetCupertinoApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () => presentSearchMoreSheet(context, actions),
              child: const Text('open'),
            ),
          ),
        ),
      );

  testWidgets('Flutter sheet renders options, blocks disabled tap, runs enabled action',
      (tester) async {
    var imageTapped = 0;
    var addTapped = 0;
    final actions = [
      NativeNavigationAction(
        id: 'imageSearch',
        title: '以图搜图',
        symbol: 'photo.on.rectangle',
        onPressed: () => imageTapped++,
      ),
      NativeNavigationAction(
        id: 'addQuickSearch',
        title: '加入快速搜索',
        symbol: 'plus.circle',
        enabled: false,
        onPressed: () => addTapped++,
      ),
    ];

    await tester.pumpWidget(host(actions));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(EhSheetHeader), findsOneWidget);
    expect(find.text('以图搜图'), findsOneWidget);
    expect(find.text('加入快速搜索'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search.moreOption.addQuickSearch')));
    await tester.pumpAndSettle();
    expect(addTapped, 0);
    expect(find.byType(EhSheetHeader), findsOneWidget);

    await tester.tap(find.byKey(const Key('search.moreOption.imageSearch')));
    await tester.pumpAndSettle();
    expect(imageTapped, 1);
    expect(find.byType(EhSheetHeader), findsNothing);
  });

  testWidgets('native sheet sends actionList payload and triggers action on dismiss',
      (tester) async {
    NativeSheet.debugAvailable = true;
    String? presentedKind;
    Map<Object?, Object?>? presentedConfig;
    int? sheetId;
    var quickTapped = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'present') {
        final args = call.arguments as Map<Object?, Object?>;
        sheetId = args['id'] as int;
        presentedKind = args['kind'] as String;
        presentedConfig = args['config'] as Map<Object?, Object?>;
        return true;
      }
      return null;
    });

    final actions = [
      NativeNavigationAction(
        id: 'quickSearchList',
        title: '快速搜索列表',
        symbol: 'list.bullet',
        onPressed: () => quickTapped++,
      ),
      NativeNavigationAction(
        id: 'top',
        title: '回到顶部',
        symbol: 'arrow.up.to.line',
        enabled: false,
        onPressed: () {},
      ),
    ];

    await tester.pumpWidget(host(actions));
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(presentedKind, 'actionList');
    expect(presentedConfig?['showChevrons'], isTrue);
    final items = (presentedConfig?['items'] as List).cast<Map<Object?, Object?>>();
    expect(items, hasLength(2));
    expect(items[0]['id'], 'quickSearchList');
    expect(items[0]['enabled'], isTrue);
    expect(items[1]['id'], 'top');
    expect(items[1]['enabled'], isFalse);

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMethodCodec();
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall('event', {
        'id': sheetId,
        'name': 'select',
        'value': 'quickSearchList',
      })),
      (_) {},
    );
    expect(quickTapped, 0);

    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall('dismissed', {'id': sheetId})),
      (_) {},
    );
    await tester.pump();
    expect(quickTapped, 1);
  });
}
