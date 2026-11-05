import 'package:eros_fe/adaptive/adaptive_environment.dart';
import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/common/controller/archiver_download_controller.dart';
import 'package:eros_fe/common/controller/download_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/models/download_archiver_task_info.dart';
import 'package:eros_fe/pages/tab/controller/download_view_controller.dart';
import 'package:eros_fe/pages/tab/view/download_page.dart';
import 'package:eros_fe/pages/tab/view/home_page_large.dart';
import 'package:eros_fe/route/app_pages.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:eros_fe/utils/toast.dart';
import 'package:eros_fe/widget/app_modal.dart';
import 'package:eros_fe/widget/appkit_glass.dart';
import 'package:eros_fe/widget/appkit_interaction.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _DownloadBackend extends GetxController implements DownloadController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DesktopDownloads extends GetxController
    implements DownloadViewController {
  final delegate = DownloadViewController();
  @override
  final animatedArchiverListKey = GlobalKey<AnimatedListState>();
  @override
  List<DownloadArchiverTaskInfo> get archiverTasks => delegate.archiverTasks;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ArchiverBackend extends GetxController
    implements ArchiverDownloadController {
  @override
  final Map<String, DownloadArchiverTaskInfo> archiverTaskMap = {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LifecycleLayout extends LayoutServices {
  @override
  // Fixture deliberately bypasses storage and platform initialization.
  // ignore: must_call_super
  void onInit() {}
}

class _LifecycleSettings extends EhSettingService {
  @override
  // Fixture deliberately bypasses storage and platform initialization.
  // ignore: must_call_super
  void onInit() {}
}

class _LifecycleTheme extends ThemeService {
  @override
  // Fixture deliberately bypasses storage and platform initialization.
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <bool>[];
  setUp(() {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.macOS;
    calls.clear();
    messenger.setMockMethodCallHandler(AppKitInteraction.channel, (call) async {
      if (call.method == 'setInteractive') {
        calls.add(call.arguments as bool);
      }
      return null;
    });
  });
  tearDown(() async {
    expect(AppKitInteraction.blocked, isFalse);
    PlatformCapabilities.debugHostPlatformOverride = null;
    messenger.setMockMethodCallHandler(AppKitInteraction.channel, null);
    Get.reset();
  });

  testWidgets('root modal disables native input until pop barrier disappears', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigator,
        navigatorObservers: [AppKitModalObserver(root: true)],
        home: const SizedBox(),
      ),
    );
    navigator.currentState!.push(
      CupertinoDialogRoute<void>(
        context: navigator.currentContext!,
        builder: (_) => const Text('Modal'),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, [false]);
    navigator.currentState!.pop();
    await tester.pump();
    expect(AppKitInteraction.blocked, isTrue);
    await tester.pumpAndSettle();
    expect(calls, [false, true]);
  });

  testWidgets('nested dialogs block input but ordinary nested pages do not', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigator,
        navigatorObservers: [AppKitModalObserver()],
        home: const SizedBox(),
      ),
    );
    navigator.currentState!.push(
      CupertinoPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    navigator.currentState!.push(
      CupertinoDialogRoute<void>(
        context: navigator.currentContext!,
        builder: (_) => const Text('Nested'),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, [false]);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls, [false, true]);
  });

  testWidgets('root reader covers native chrome and restores input on return', (
    tester,
  ) async {
    expect(
      AppPages.routes
          .singleWhere((page) => page.name == EHRoutes.galleryViewExt)
          .opaque,
      isTrue,
    );
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigator,
        navigatorObservers: [AppKitModalObserver(root: true)],
        home: const Text('Home'),
      ),
    );
    navigator.currentState!.push(
      CupertinoPageRoute<void>(builder: (_) => const Text('Reader')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsNothing);
    expect(calls, [false]);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls, [false, true]);
  });

  testWidgets(
    'overlay content leases nest and repeated values do not send updates',
    (tester) async {
      await tester.pumpWidget(
        const AppKitModalContent(child: AppKitModalContent(child: SizedBox())),
      );
      expect(calls, [false]);
      await tester.pumpWidget(const SizedBox());
      expect(calls, [false, true]);
    },
  );

  test('iOS is never sent AppKit input messages', () async {
    PlatformCapabilities.debugHostPlatformOverride = TargetPlatform.iOS;
    final owner = Object();
    AppKitInteraction.setBlocked(owner, true);
    AppKitInteraction.setBlocked(owner, false);
    expect(calls, isEmpty);
  });

  testWidgets(
    'bridge failure falls back rather than leaving native input enabled',
    (tester) async {
      PlatformCapabilities.appKitAvailable.value = true;
      messenger.setMockMethodCallHandler(AppKitInteraction.channel, (_) async {
        throw PlatformException(code: 'bridge-failed');
      });
      final owner = Object();
      AppKitInteraction.setBlocked(owner, true);
      await tester.pump();
      expect(PlatformCapabilities.appKitAvailable.value, isFalse);
      AppKitInteraction.setBlocked(owner, false);
      await tester.pump();
    },
  );

  testWidgets('queued native actions cannot bypass a Flutter modal', (
    tester,
  ) async {
    int? id;
    var actions = 0;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        id = (call.arguments as Map)['id'] as int;
        messenger.setMockMethodCallHandler(
          MethodChannel('eros/appkit-glass/$id'),
          (_) async => null,
        );
      }
      return null;
    });
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          height: 80,
          child: AppKitGlassView(
            kind: 'tabs',
            configuration: const {},
            onAction: (_, _) {
              actions++;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(id, isNotNull);
    final owner = Object();
    AppKitInteraction.setBlocked(owner, true);
    Future<void> action() async {
      await messenger.handlePlatformMessage(
        'eros/appkit-glass/$id',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('select', 1),
        ),
        (_) {},
      );
    }

    await action();
    expect(actions, 0);
    AppKitInteraction.setBlocked(owner, false);
    await action();
    expect(actions, 1);
    await tester.pumpWidget(const SizedBox());
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    messenger.setMockMethodCallHandler(
      MethodChannel('eros/appkit-glass/$id'),
      null,
    );
  });

  testWidgets(
    'desktop archive without mobile plugin renders without ErrorWidget',
    (tester) async {
      Get.put<DownloadController>(_DownloadBackend());
      final controller = _DesktopDownloads();
      Get.put<DownloadViewController>(controller);
      expect(controller.archiverTasks, isEmpty);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: const DownloadArchiverView(),
          ),
        );
        expect(find.byType(AnimatedList), findsOneWidget);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('production nested Navigator releases its modal when unmounted', (
    tester,
  ) async {
    Get.testMode = true;
    Get.put<LocaleService>(LocaleService());
    Get.put<EhSettingService>(_LifecycleSettings());
    Get.put<ThemeService>(_LifecycleTheme());
    Get.put<LayoutServices>(_LifecycleLayout());
    final geometry = ValueNotifier(const Size(900, 650));
    addTearDown(geometry.dispose);
    await tester.pumpWidget(
      GetCupertinoApp(
        home: ValueListenableBuilder<Size>(
          valueListenable: geometry,
          builder: (_, size, _) => AdaptiveEnvironmentScope(
            snapshot: AdaptiveEnvironmentSnapshot(size: size),
            child: TabHomeLarge(
              split: size.width > 700,
              primaryRoot: const CupertinoPageScaffold(child: Text('List')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final navigator = Get.nestedKey(1)!.currentState!;
    navigator.push(
      CupertinoDialogRoute<void>(
        context: navigator.context,
        builder: (_) => const Text('Modal on retained navigator'),
      ),
    );
    await tester.pumpAndSettle();
    expect(AppKitInteraction.blocked, isTrue);
    geometry.value = const Size(540, 650);
    await tester.pumpAndSettle();
    expect(AppKitInteraction.blocked, isTrue);
    geometry.value = const Size(900, 650);
    await tester.pumpAndSettle();
    expect(AppKitInteraction.blocked, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(AppKitInteraction.blocked, isFalse);
    expect(calls, [false, true]);
  });

  testWidgets('route replacement transfers modal lease atomically', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final observer = AppKitModalObserver();
    addTearDown(observer.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: const SizedBox(),
      ),
    );
    final first = CupertinoDialogRoute<void>(
      context: navigator.currentContext!,
      builder: (_) => const Text('First'),
    );
    navigator.currentState!.push(first);
    await tester.pumpAndSettle();
    final second = CupertinoDialogRoute<void>(
      context: navigator.currentContext!,
      builder: (_) => const Text('Second'),
    );
    navigator.currentState!.replace(oldRoute: first, newRoute: second);
    await tester.pumpAndSettle();
    expect(calls, [false]);
    final page = CupertinoPageRoute<void>(builder: (_) => const Text('Page'));
    navigator.currentState!.replace(oldRoute: second, newRoute: page);
    await tester.pumpAndSettle();
    expect(calls, [false, true]);
    final third = PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, _, _) => const Text('Transparent overlay'),
    );
    navigator.currentState!.replace(oldRoute: page, newRoute: third);
    await tester.pumpAndSettle();
    expect(calls, [false, true, false]);
    observer.dispose();
    await tester.pump();
    expect(calls, [false, true, false, true]);
    await tester.pumpWidget(const SizedBox());
  });

  for (final host in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$host requires the mobile archive backend', () {
      PlatformCapabilities.debugHostPlatformOverride = host;
      Get.put<DownloadController>(_DownloadBackend());
      final controller = DownloadViewController();
      expect(
        () => controller.archiverTasks,
        throwsA(
          predicate(
            (error) => error.toString().contains('ArchiverDownloadController'),
          ),
        ),
      );
    });
    test('$host returns the real archive queue when registered', () {
      PlatformCapabilities.debugHostPlatformOverride = host;
      Get.put<DownloadController>(_DownloadBackend());
      final archive = _ArchiverBackend();
      const first = DownloadArchiverTaskInfo(tag: 'first', gid: '1');
      const second = DownloadArchiverTaskInfo(tag: 'second', gid: '2');
      archive.archiverTaskMap.addAll({'first': first, 'second': second});
      Get.put<ArchiverDownloadController>(archive);
      expect(DownloadViewController().archiverTasks, [second, first]);
    });
  }

  test('only desktop hosts may omit the archive backend', () {
    Get.put<DownloadController>(_DownloadBackend());
    for (final host in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      PlatformCapabilities.debugHostPlatformOverride = host;
      expect(DownloadViewController().archiverTasks, isEmpty);
    }
  });

  test(
    'reader opacity is limited to iOS and macOS hosts, never theme platform',
    () {
      for (final host in [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.android,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        PlatformCapabilities.debugHostPlatformOverride = host;
        final expected =
            host == TargetPlatform.iOS || host == TargetPlatform.macOS;
        for (final available in [true, false]) {
          PlatformCapabilities.appKitAvailable.value = available;
          expect(
            AppPages.readerRouteOpaque,
            expected,
            reason: '$host appKit=$available',
          );
        }
      }
      PlatformCapabilities.appKitAvailable.value = false;
    },
  );

  testWidgets(
    'central loading entry blocks through dismiss; action toast does not',
    (tester) async {
      Get.put<LocaleService>(LocaleService());
      Get.put<EhSettingService>(_LifecycleSettings());
      Get.put<ThemeService>(_LifecycleTheme());
      final target = GlobalKey();
      await tester.pumpWidget(
        GetCupertinoApp(
          builder: FlutterSmartDialog.init(),
          home: Center(child: SizedBox(key: target, width: 80, height: 40)),
        ),
      );
      await tester.pumpAndSettle();
      final loading = AppModal.showLoading<void>(
        builder: (_) => const Text('Working'),
      );
      await tester.pumpAndSettle();
      expect(AppKitInteraction.blocked, isTrue);
      SmartDialog.dismiss(status: SmartStatus.loading);
      await tester.pumpAndSettle();
      await loading;
      expect(AppKitInteraction.blocked, isFalse);
      final attached = AppModal.showAttach<void>(
        targetContext: target.currentContext!,
        tag: 'lease-test',
        builder: (_) => const Text('Attached modal'),
      );
      await tester.pumpAndSettle();
      expect(AppKitInteraction.blocked, isTrue);
      SmartDialog.dismiss(tag: 'lease-test');
      await tester.pumpAndSettle();
      await attached;
      expect(AppKitInteraction.blocked, isFalse);
      expect(calls, [false, true, false, true]);
      showActionToast('Nonmodal notification');
      await tester.pumpAndSettle();
      expect(AppKitInteraction.blocked, isFalse);
      SmartDialog.dismiss();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
