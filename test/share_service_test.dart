import 'dart:async';

import 'package:eros_fe/utils/share_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

const MethodChannel shareChannel =
    MethodChannel('dev.fluttercommunity.plus/share');
const MethodChannel iosShareChannel =
    MethodChannel('cn.honjow.eros/share');

void main() {
  late int calls;
  late Object? lastArguments;
  late Future<Object?> Function(MethodCall call)? onShare;

  setUp(() {
    debugDefaultTargetPlatformOverride = null;
    calls = 0;
    lastArguments = null;
    onShare = null;
    Future<Object?> handleShare(MethodCall call) {
      calls++;
      lastArguments = call.arguments;
      return onShare?.call(call) ?? Future<Object?>.value('shared');
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, handleShare);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosShareChannel, handleShare);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosShareChannel, null);
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
  });

  testWidgets('uses the pressed widget as a non-empty global share origin',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      GetCupertinoApp(
        home: Center(
          child: SizedBox(
            key: key,
            width: 80,
            height: 40,
          ),
        ),
      ),
    );

    final origin = ShareService.positionOrigin(key.currentContext);

    expect(origin.width, 80);
    expect(origin.height, 40);
    expect(origin.left.isFinite, isTrue);
    expect(origin.top.isFinite, isTrue);
  });

  test('serializes native share requests', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final pending = Completer<Object?>();
    onShare = (_) => pending.future;

    final first = ShareService.shareText('https://example.com');
    final second = await ShareService.shareText('https://example.com/2');

    expect(second, isNull);
    expect(calls, 1);

    pending.complete('shared');
    await first;
    expect(calls, 1);
  });

  test('passes a usable origin to the iOS bridge', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await ShareService.shareText(
      'https://example.com',
      sharePositionOrigin: const Rect.fromLTWH(10, 20, 30, 40),
    );

    final arguments = lastArguments! as Map<Object?, Object?>;
    expect(arguments['originX'], 10.0);
    expect(arguments['originY'], 20.0);
    expect(arguments['originWidth'], 30.0);
    expect(arguments['originHeight'], 40.0);
  });

  test('maps a native dismissal to a dismissed result', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    onShare = (_) => Future<Object?>.value('');

    final result = await ShareService.shareText('https://example.com');

    expect(result?.status, ShareResultStatus.dismissed);
  });
}
