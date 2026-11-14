import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/tab/view/favorite_order_sheet.dart';
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

  Widget host({
    required FavoriteOrder Function() current,
    required ValueChanged<FavoriteOrder?> onResult,
  }) =>
      GetCupertinoApp(
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
              onPressed: () async {
                onResult(
                  await presentFavoriteOrderSheet(context, current: current()),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

  testWidgets('flutter sheet shows selected order and returns tapped option', (
    tester,
  ) async {
    var current = FavoriteOrder.fav;
    FavoriteOrder? lastResult;

    await tester.pumpWidget(
      host(
        current: () => current,
        onResult: (value) => lastResult = value,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('收藏夹排序'), findsOneWidget);
    expect(find.text('按照发布时间'), findsOneWidget);
    expect(find.text('按照收藏时间'), findsOneWidget);

    final favOption = find.byKey(const Key('favoriteOrder.option.fav'));
    final postedOption = find.byKey(const Key('favoriteOrder.option.posted'));
    expect(
      find.descendant(
        of: favOption,
        matching: find.byIcon(CupertinoIcons.checkmark_circle_fill),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: postedOption,
        matching: find.byIcon(CupertinoIcons.checkmark_circle_fill),
      ),
      findsNothing,
    );

    await tester.tap(postedOption);
    await tester.pumpAndSettle();
    expect(lastResult, FavoriteOrder.posted);

    current = FavoriteOrder.posted;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: postedOption,
        matching: find.byIcon(CupertinoIcons.checkmark_circle_fill),
      ),
      findsOneWidget,
    );

    // Close button dismisses with null.
    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    await tester.pumpAndSettle();
    expect(lastResult, isNull);
  });

  testWidgets('native sheet emits config, selection and falls back when false', (
    tester,
  ) async {
    NativeSheet.debugAvailable = true;
    Map<Object?, Object?>? presentedArgs;
    var presentShouldSucceed = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'present') {
        presentedArgs = call.arguments as Map<Object?, Object?>;
        if (!presentShouldSucceed) {
          return false;
        }
        final id = presentedArgs!['id'];
        Future<void>.microtask(() async {
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          await messenger.handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              MethodCall('event', {'id': id, 'name': 'select', 'value': 'posted'}),
            ),
            (_) {},
          );
          await messenger.handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              MethodCall('dismissed', {'id': id}),
            ),
            (_) {},
          );
        });
        return true;
      }
      return null;
    });

    FavoriteOrder? lastResult;
    await tester.pumpWidget(
      host(
        current: () => FavoriteOrder.fav,
        onResult: (value) => lastResult = value,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(presentedArgs?['kind'], 'favoriteOrder');
    final config = presentedArgs?['config'] as Map<Object?, Object?>?;
    expect(config?['title'], '收藏夹排序');
    expect(config?['selected'], 'fav');
    final items = config?['items'] as List<Object?>?;
    expect(items, hasLength(2));
    expect(lastResult, FavoriteOrder.posted);

    // When native present returns false, falls back to Flutter sheet.
    presentShouldSucceed = false;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('按照收藏时间'), findsOneWidget);
    await tester.tap(find.byKey(const Key('favoriteOrder.option.fav')));
    await tester.pumpAndSettle();
    expect(lastResult, FavoriteOrder.fav);
  });
}
