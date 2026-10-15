import 'dart:async';
import 'dart:io';

import 'package:eros_fe/utils/share_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

const MethodChannel shareChannel =
    MethodChannel('dev.fluttercommunity.plus/share');
const MethodChannel iosShareChannel = MethodChannel('cn.honjow.eros/share');

void main() {
  late int calls;
  late Object? lastArguments;
  late Future<Object?> Function(MethodCall call)? onShare;
  String? copiedText;

  setUp(() {
    debugDefaultTargetPlatformOverride = null;
    calls = 0;
    lastArguments = null;
    onShare = null;
    copiedText = null;
    Future<Object?> handleShare(MethodCall call) {
      calls++;
      lastArguments = call.arguments;
      return onShare?.call(call) ?? Future<Object?>.value('shared');
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, handleShare);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosShareChannel, handleShare);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosShareChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
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
    expect(copiedText, isNull);
  });

  test(
      'plain text and URL payloads preserve their native presentation metadata',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    for (final text in [
      'Neutral shared text',
      'https://example.invalid/gallery'
    ]) {
      await ShareService.shareText(text,
          subject: 'Fixture subject', title: 'Fixture title');
      final args = lastArguments! as Map<Object?, Object?>;
      expect(args['text'], text);
      expect(args['subject'], 'Fixture subject');
      expect(args['title'], 'Fixture title');
    }
    final uri = Uri.parse('https://example.invalid/uri');
    await ShareService.share(ShareParams(uri: uri));
    expect((lastArguments! as Map)['uri'], uri.toString());
  });

  test(
      'image and ordinary files reach the native bridge with exact paths and MIME types',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final root = await Directory.systemTemp.createTemp('eros-share-payload-');
    try {
      final image = File('${root.path}/neutral.png');
      final document = File('${root.path}/neutral.txt');
      await image.writeAsBytes([137, 80, 78, 71]);
      await document.writeAsString('Neutral local fixture');
      await ShareService.shareFiles([
        XFile(image.path, mimeType: 'image/png'),
        XFile(document.path, mimeType: 'text/plain'),
      ], subject: 'Offline files');
      final args = lastArguments! as Map<Object?, Object?>;
      expect(args['paths'], [image.path, document.path]);
      expect(args['mimeTypes'], ['image/png', 'text/plain']);
      expect(args['subject'], 'Offline files');
    } finally {
      await root.delete(recursive: true);
    }
  });

  for (final rect in [
    Rect.zero,
    const Rect.fromLTWH(double.nan, 0, 1, 1),
    const Rect.fromLTWH(0, 0, double.infinity, 1)
  ]) {
    test('invalid iPad anchor falls back to finite positive bounds: $rect',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await ShareService.shareText('Fixture', sharePositionOrigin: rect);
      final args = lastArguments! as Map<Object?, Object?>;
      for (final name in [
        'originX',
        'originY',
        'originWidth',
        'originHeight'
      ]) {
        expect((args[name]! as double).isFinite, isTrue);
      }
      expect(args['originWidth'], greaterThan(0));
      expect(args['originHeight'], greaterThan(0));
    });
  }

  test(
      'platform failure copies the fallback link and releases the repeated-tap guard',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    onShare = (_) async => throw PlatformException(code: 'fixture-unavailable');
    expect(await ShareService.shareText('https://example.invalid/fallback'),
        isNull);
    expect(copiedText, 'https://example.invalid/fallback');
    expect(ShareService.isSharing, isFalse);
    onShare = (_) async => 'shared';
    expect((await ShareService.shareText('Next request'))?.status,
        ShareResultStatus.success);
    expect(calls, 2);
  });

  test('unavailable native result is distinct from user cancellation',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    onShare = (_) async => null;
    final result =
        await ShareService.shareText('https://example.invalid/unavailable');
    expect(result?.status, ShareResultStatus.unavailable);
    expect(copiedText, 'https://example.invalid/unavailable');
    expect(ShareService.isSharing, isFalse);
  });

  testWidgets('a detached button context cannot produce an invalid iPad anchor',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
        CupertinoApp(home: SizedBox(key: key, width: 80, height: 40)));
    final oldContext = key.currentContext!;
    await tester.pumpWidget(const SizedBox());
    expect(oldContext.mounted, isFalse);
    final origin = ShareService.positionOrigin(oldContext);
    expect(origin.width, greaterThan(0));
    expect(origin.height, greaterThan(0));
    expect(origin.left.isFinite && origin.top.isFinite, isTrue);
  });

  testWidgets('sharing after dismissing a modal waits for its transition',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(GetCupertinoApp(home: Builder(builder: (context) {
      return CupertinoPageScaffold(
          child: CupertinoButton(
        child: const Text('Open fixture sheet'),
        onPressed: () => showCupertinoModalPopup<void>(
            context: context,
            builder: (sheetContext) => CupertinoActionSheet(actions: [
                  CupertinoActionSheetAction(
                      child: const Text('Share fixture'),
                      onPressed: () async {
                        final origin =
                            ShareService.positionOrigin(sheetContext);
                        Get.back();
                        await ShareService.waitForModalDismissal();
                        await ShareService.shareText('Fixture',
                            sharePositionOrigin: origin);
                      }),
                ])),
      ));
    })));
    await tester.tap(find.text('Open fixture sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share fixture'));
    await tester.pump();
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 299));
    expect(calls, 0);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(CupertinoActionSheet), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
