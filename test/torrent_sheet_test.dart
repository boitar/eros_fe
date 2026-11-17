import 'package:eros_fe/adaptive/native_sheet.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/controller/torrent_controller.dart';
import 'package:eros_fe/pages/gallery/view/torrent_dialog.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
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

class _FakeTorrentSource extends TorrentSheetSource {
  RxStatus _status = RxStatus.loading();
  TorrentProvider? _provider;
  final List<VoidCallback> _listeners = [];

  int retryCount = 0;
  String? downloadedHash;
  String? magnetHash;

  void setState(RxStatus status, [TorrentProvider? provider]) {
    _status = status;
    _provider = provider;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  @override
  RxStatus get status => _status;

  @override
  TorrentProvider? get provider => _provider;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  void retry() => retryCount++;

  @override
  Future<void> downloadTorrent(String token, GalleryTorrent torrent) async {
    downloadedHash = torrent.hash;
  }

  @override
  Future<void> shareMagnet(GalleryTorrent torrent, BuildContext context) async {
    magnetHash = torrent.hash;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Global.profile = kDefProfile;
    Get.put<EhSettingService>(_Settings());
    Get.put(ThemeService());
    NativeSheet.debugAvailable = false;
  });

  tearDown(() {
    NativeSheet.debugAvailable = null;
    Get.reset();
  });

  Widget host(_FakeTorrentSource source) => GetCupertinoApp(
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
              onPressed: () => presentTorrentSheet(context, source),
              child: const Text('open'),
            ),
          ),
        ),
      );

  testWidgets('sorts torrents by seeds desc, promotes top card, handles actions', (
    tester,
  ) async {
    final source = _FakeTorrentSource();
    final provider = TorrentProvider()
      ..torrentToken = 'tok123'
      ..torrents = [
        const GalleryTorrent(
          hash: 'low',
          name: 'low-seed.zip',
          sizeText: '120 MB',
          posted: '2026-10-01',
          seeds: '2',
          peerd: '1',
          downloads: '10',
        ),
        const GalleryTorrent(
          hash: 'high',
          name: 'high-seed.zip',
          sizeText: '512 MB',
          posted: '2026-11-02',
          seeds: '45',
          peerd: '3',
          downloads: '900',
        ),
      ];
    source.setState(RxStatus.success(), provider);

    await tester.pumpWidget(host(source));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('种子 · 2 个'), findsOneWidget);
    final highY = tester.getTopLeft(find.text('high-seed.zip')).dy;
    final lowY = tester.getTopLeft(find.text('low-seed.zip')).dy;
    expect(highY, lessThan(lowY));

    final firstDownload = tester.widget<EhButton>(
      find.byKey(const ValueKey('torrent_download_0')),
    );
    final secondDownload = tester.widget<EhButton>(
      find.byKey(const ValueKey('torrent_download_1')),
    );
    expect(firstDownload.style, EhButtonStyle.prominent);
    expect(secondDownload.style, EhButtonStyle.tonal);

    await tester.tap(find.byKey(const ValueKey('torrent_download_0')));
    await tester.pumpAndSettle();
    expect(source.downloadedHash, 'high');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('torrent_magnet_1')));
    await tester.pumpAndSettle();
    expect(source.magnetHash, 'low');
  });

  testWidgets('error state shows retry button and updates on success/empty', (
    tester,
  ) async {
    final source = _FakeTorrentSource();
    source.setState(RxStatus.error('boom'));

    await tester.pumpWidget(host(source));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('读取失败'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('torrent_retry')));
    await tester.pumpAndSettle();
    expect(source.retryCount, 1);

    final empty = TorrentProvider()
      ..torrentToken = 't'
      ..torrents = const [];
    source.setState(RxStatus.success(), empty);
    await tester.pumpAndSettle();
    expect(find.text('没有可用的种子'), findsOneWidget);
  });
}
