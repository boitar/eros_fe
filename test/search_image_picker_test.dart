import 'dart:async';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/tag_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/pages/tab/controller/search_image_controller.dart';
import 'package:eros_fe/pages/tab/controller/search_page_controller.dart';
import 'package:eros_fe/pages/tab/controller/tabhome_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Tags extends GetxController implements TagController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected tag operation $invocation');
}

class _Settings extends GetxService implements EhSettingService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting $invocation');
}

class _Home extends GetxController implements TabHomeController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected home operation $invocation');
}

class _Picker extends FilePicker {
  int calls = 0;
  FileType? requestedType;
  Future<FilePickerResult?> Function() choose = () async => null;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) {
    calls++;
    requestedType = type;
    return choose();
  }
}

FilePickerResult _image(String? path) =>
    FilePickerResult([PlatformFile(name: 'cover.png', size: 32, path: path)]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  FilePicker? previousPicker;
  late _Picker picker;
  late SearchImageController controller;
  late List<MethodCall> permissionCalls;

  setUp(() {
    Get.testMode = true;
    Get.put<EhSettingService>(_Settings());
    Get.put<TagController>(_Tags());
    Get.put<TabHomeController>(_Home());
    controller = SearchImageController();
    try {
      previousPicker = FilePicker.platform;
    } catch (_) {
      previousPicker = null;
    }
    picker = _Picker();
    FilePicker.platform = picker;
    permissionCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          permissionCalls.add(call);
          throw PlatformException(code: 'permission-unavailable');
        });
  });

  tearDown(() {
    if (previousPicker != null) {
      FilePicker.platform = previousPicker!;
    }
    PlatformCapabilities.debugHostPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, null);
    Get.reset();
  });

  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return context;
  }

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.iOS,
  ]) {
    testWidgets('$platform picks an image without broad storage permission', (
      tester,
    ) async {
      PlatformCapabilities.debugHostPlatformOverride = platform;
      picker.choose = () async => _image('/selected/cover.png');
      await controller.selectSearchImage(await host(tester));
      expect(picker.requestedType, FileType.image);
      expect(picker.calls, 1);
      expect(permissionCalls, isEmpty);
      expect(controller.imagePath, '/selected/cover.png');
      expect(controller.listType, ListType.init);
    });
  }

  testWidgets(
    'cancel, missing path and picker failure preserve the current image',
    (tester) async {
      final context = await host(tester);
      controller.imagePath = '/existing/cover.png';
      controller.listType = ListType.gallery;
      final previousStatus = controller.status;
      for (final result in [
        null,
        _image(null),
        _image(''),
        const FilePickerResult([]),
      ]) {
        picker.choose = () async => result;
        await controller.selectSearchImage(context);
        expect(controller.imagePath, '/existing/cover.png');
        expect(controller.listType, ListType.gallery);
        expect(controller.status, same(previousStatus));
      }
      picker.choose = () async =>
          throw PlatformException(code: 'picker-failed');
      await controller.selectSearchImage(context);
      expect(controller.imagePath, '/existing/cover.png');
      expect(controller.status, same(previousStatus));

      picker.choose = () async => _image('/selected/retry.png');
      await controller.selectSearchImage(context);
      expect(controller.imagePath, '/selected/retry.png');
      expect(permissionCalls, isEmpty);
    },
  );

  testWidgets(
    'one picker opens at a time and an unmounted page ignores its result',
    (tester) async {
      final context = await host(tester);
      final pending = Completer<FilePickerResult?>();
      picker.choose = () => pending.future;
      controller.imagePath = '/existing/cover.png';
      final picking = controller.selectSearchImage(context);
      await controller.selectSearchImage(context);
      expect(picker.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(_image('/selected/stale.png'));
      await picking;
      expect(controller.imagePath, '/existing/cover.png');
    },
  );
}
