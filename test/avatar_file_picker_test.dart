import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/setting/avatar_manage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class FlowUser extends GetxController implements UserController {
  @override
  AvatarAccountToken captureAvatarAccount() =>
      const AvatarAccountToken('offline', 1);
  @override
  void checkAvatarAccount(AvatarAccountToken account) {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('$invocation');
}

class DocumentPicker extends FilePicker {
  FileType? requestedType;
  List<String>? extensions;
  @override
  Future<FilePickerResult?> pickFiles(
      {String? dialogTitle,
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
      bool readSequential = false}) async {
    requestedType = type;
    extensions = allowedExtensions;
    return null;
  }
}

void main() {
  tearDown(Get.reset);
  testWidgets(
      'Files opens the document picker with image extensions, not the iOS photo route',
      (tester) async {
    Get.testMode = true;
    Get.put<UserController>(FlowUser());
    FilePicker? previous;
    try {
      previous = FilePicker.platform;
    } catch (_) {}
    final picker = DocumentPicker();
    FilePicker.platform = picker;
    try {
      await tester.pumpWidget(GetCupertinoApp(
        locale: const Locale('en'),
        supportedLocales: L10n.delegate.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate
        ],
        home: Builder(
            builder: (context) => CupertinoPageScaffold(
                child: Center(
                    child: CupertinoButton(
                        onPressed: () => showAvatarManageFlow(context),
                        child: const Text('Choose'))))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle();
      expect(picker.requestedType, FileType.custom);
      expect(picker.extensions, ['jpg', 'jpeg', 'png', 'gif', 'webp']);
      expect(find.text('Where to use this avatar?'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      if (previous != null) {
        FilePicker.platform = previous;
      }
    }
  });
}
