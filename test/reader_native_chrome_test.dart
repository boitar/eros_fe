import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/const/const.dart';
import 'package:eros_fe/generated/l10n.dart';
import 'package:eros_fe/pages/image_view/common.dart';
import 'package:eros_fe/pages/image_view/controller/view_controller.dart';
import 'package:eros_fe/pages/image_view/controller/view_state.dart';
import 'package:eros_fe/pages/image_view/view/reader_chrome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  Future<NativePageChrome> chromeFor(
      WidgetTester tester, _Reader reader) async {
    late NativePageChrome chrome;
    await tester.pumpWidget(CupertinoApp(
      locale: const Locale('en'),
      localizationsDelegates: const [L10n.delegate],
      supportedLocales: L10n.delegate.supportedLocales,
      home: Builder(builder: (context) {
        chrome = ReaderNativeChrome.readerChrome(context, reader);
        return const SizedBox();
      }),
    ));
    return chrome;
  }

  List<String> ids(List<NativeNavigationAction> actions) =>
      actions.map((action) => action.id).toList();

  NativeNavigationAction find(List<NativeNavigationAction> actions, String id) {
    for (final action in actions) {
      if (action.id == id) return action;
      for (final child in action.children) {
        if (child.id == id) return child;
        final nested = child.children.where((e) => e.id == id);
        if (nested.isNotEmpty) return nested.single;
      }
    }
    throw StateError('missing $id');
  }

  late _Reader reader;
  late _State state;

  setUp(() {
    Get.testMode = true;
    state = _State(_Settings());
    reader = _Reader(state);
  });

  tearDown(() {
    reader.photoViewController.dispose();
    reader.photoViewScaleStateController.dispose();
    Get.reset();
  });

  testWidgets('bars carry the page counter, share and the reading menu',
      (tester) async {
    final chrome = await chromeFor(tester, reader);
    expect(chrome.title, '8 / 43');
    expect(chrome.titleMonospacedDigits, isTrue);
    expect(chrome.barStyle, NativeBarStyle.dark);
    expect(chrome.animateBars, isTrue);
    expect(chrome.navigationBarVisible, isTrue);
    expect(ids(chrome.actions), ['reader.share', 'reader.more']);
    expect(ids(chrome.toolbarActions), [
      'reader.save',
      'reader.columns',
      'reader.autoRead',
      'reader.thumbnails',
    ]);
    // Save stands apart from the view toggles.
    expect(chrome.toolbarActions.first.group,
        isNot(chrome.toolbarActions.last.group));
    expect(find(chrome.actions, 'reader.direction.rightToLeft').checked,
        isTrue);
    expect(find(chrome.actions, 'reader.direction.leftToRight').checked,
        isFalse);
    expect(find(chrome.actions, 'reader.surface.automatic').checked, isTrue);
  });

  testWidgets('toolbar toggles show their state and run the reader actions',
      (tester) async {
    final chrome = await chromeFor(tester, reader);
    final thumbs = find(chrome.toolbarActions, 'reader.thumbnails');
    expect(thumbs.selected, isTrue);
    expect(thumbs.priority, NativeBarItemPriority.high);
    thumbs.onPressed!();
    expect(reader.thumbToggles, 1);

    final autoRead = find(chrome.toolbarActions, 'reader.autoRead');
    expect(autoRead.primaryWithMenu, isTrue);
    expect(autoRead.selected, isFalse);
    expect(find(chrome.toolbarActions, 'reader.autoRead.3000').checked, isTrue);
    find(chrome.toolbarActions, 'reader.autoRead.5000').onPressed!();
    expect(reader.autoReadIntervals, [5000]);
    autoRead.onPressed!();
    expect(reader.autoReadIntervals, [5000, 3000]);

    find(chrome.toolbarActions, 'reader.columns.evenLeft').onPressed!();
    expect(reader.columnPreferences, [ReaderColumnPreference.evenLeft]);
  });

  testWidgets('page layout is unavailable while scrolling vertically',
      (tester) async {
    state.viewMode = ViewMode.topToBottom;
    state.showBar = false;
    final chrome = await chromeFor(tester, reader);
    expect(find(chrome.toolbarActions, 'reader.columns').enabled, isFalse);
    expect(chrome.navigationBarVisible, isFalse);
  });
}

class _Reader extends ViewExtController {
  _Reader(_State state) : super(state: state);

  int thumbToggles = 0;
  final autoReadIntervals = <int>[];
  final columnPreferences = <ReaderColumnPreference>[];

  @override
  Future<void> switchShowThumbList() async => thumbToggles++;

  @override
  void startAutoReadWithInterval(int interval) =>
      autoReadIntervals.add(interval);

  @override
  void setColumnPreference(ReaderColumnPreference preference) =>
      columnPreferences.add(preference);

  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onReady() {}
  @override
  // ignore: must_call_super
  void onClose() {}
}

class _Settings extends Fake implements EhSettingService {
  @override
  Rx<ViewMode> viewMode = ViewMode.rightToLeft.obs;
  @override
  ReaderColumnPreference get readerColumnPreference =>
      ReaderColumnPreference.automatic;
  @override
  int get turnPageInv => 3000;
}

class _State extends Fake implements ViewExtState {
  _State(this.ehSettingService);

  @override
  final EhSettingService ehSettingService;
  @override
  int currentItemIndex = 7;
  @override
  ViewMode viewMode = ViewMode.rightToLeft;
  @override
  int get fileCount => 43;
  @override
  bool showBar = true;
  @override
  bool get showThumbList => true;
  @override
  bool get autoRead => false;
  @override
  ReaderSurfacePreference surfacePreference =
      ReaderSurfacePreference.automatic;
}
