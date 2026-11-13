import 'package:eros_fe/common/controller/gallerycache_controller.dart';
import 'package:eros_fe/common/controller/quicksearch_controller.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/gallery/controller/archiver_controller.dart';
import 'package:eros_fe/pages/gallery/view/archiver_dialog.dart';
import 'package:eros_fe/pages/gallery/view/rate_dialog.dart';
import 'package:eros_fe/widget/eh_buttons.dart';
import 'package:eros_fe/widget/jump_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Debug-only preview of the secondary-page sheets with fixture data.
///
/// Build with `--dart-define=EROS_SHEET_PREVIEW=true` (debug only); the page
/// opens on launch. It shows every sheet over deliberately busy backdrops so
/// glass legibility can be checked without an account or network.
const bool offlineSheetPreviewEnabled =
    kDebugMode && bool.fromEnvironment('EROS_SHEET_PREVIEW');

void scheduleOfflineSheetPreview() {
  if (!offlineSheetPreviewEnabled) {
    return;
  }
  Future<void>.delayed(const Duration(seconds: 4), () {
    Get.to<void>(() => const OfflineSheetPreviewPage());
  });
}

class _FixtureArchiverSource extends ArchiverSheetSource {
  _FixtureArchiverSource({required this.fail, this.delay});

  bool fail;
  final Duration? delay;
  final List<VoidCallback> _listeners = [];
  RxStatus _status = RxStatus.loading();
  ArchiverProvider? _provider;

  void start() {
    Future<void>.delayed(delay ?? Duration.zero, () {
      if (fail) {
        _status = RxStatus.error('offline');
      } else {
        _provider = ArchiverProvider()
          ..gp = '128450'
          ..credits = '9312'
          ..dlItems = [
            ArchiverProviderItem()
              ..dltype = 'org'
              ..size = '412.6 MiB'
              ..price = '1,240 GP',
            ArchiverProviderItem()
              ..dltype = 'res'
              ..size = '186.3 MiB'
              ..price = 'Free',
          ]
          ..hItems = [
            for (final (res, size) in [
              ('780x', '38.2 MiB'),
              ('980x', '61.0 MiB'),
              ('1280x', '98.4 MiB'),
              ('1600x', '142 MiB'),
              ('2400x', '260 MiB'),
              ('Original', '412 MiB'),
            ])
              ArchiverProviderItem()
                ..dltype = 'h'
                ..resolution = res
                ..dlres = res
                ..size = size
                ..price = 'Free',
          ];
        _status = RxStatus.success();
      }
      for (final listener in List.of(_listeners)) {
        listener();
      }
    });
  }

  @override
  RxStatus get status => _status;

  @override
  ArchiverProvider? get provider => _provider;

  @override
  bool get showLocal => true;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  void retry() {
    _status = RxStatus.loading();
    for (final listener in List.of(_listeners)) {
      listener();
    }
    fail = false;
    start();
  }

  @override
  void downloadLocal(String dltype) => showToast('local $dltype');

  @override
  void downloadRemote(String dlres) => showToast('hath $dlres');
}

enum _Backdrop { dark, light, stripes }

class OfflineSheetPreviewPage extends StatefulWidget {
  const OfflineSheetPreviewPage({super.key});

  @override
  State<OfflineSheetPreviewPage> createState() =>
      _OfflineSheetPreviewPageState();
}

class _OfflineSheetPreviewPageState extends State<OfflineSheetPreviewPage> {
  _Backdrop _backdrop = _Backdrop.dark;
  String _last = '-';

  void _report(Object? value) => setState(() => _last = '$value');

  Widget _backdropLayer() {
    switch (_backdrop) {
      case _Backdrop.dark:
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF000000), Color(0xFF1B1030), Color(0xFF000000)],
            ),
          ),
        );
      case _Backdrop.light:
        return const ColoredBox(color: Color(0xFFFFFFFF));
      case _Backdrop.stripes:
        return CustomPaint(painter: _StripesPainter());
    }
  }

  @override
  Widget build(BuildContext context) {
    final setting = Get.find<EhSettingService>();
    final buttons = <(String, Future<void> Function())>[
      (
        'rate',
        () async => _report(await presentRateSheet(context,
            initial: 3.5, summary: L10n.of(context).sp_rating_summary('4.21', '318')))
      ),
      (
        'page',
        () async => _report(await showPageJumpSheet(context,
            title: L10n.of(context).jump_to_page,
            subtitle: L10n.of(context).sp_page_total(1284),
            current: 642,
            max: 1284))
      ),
      (
        'thumbs',
        () async => _report(await showPageJumpSheet(context,
            title: L10n.of(context).sp_thumbs_jump,
            subtitle: L10n.of(context).sp_thumbs_per_page(12, 40),
            current: 5,
            max: 12,
            autofocus: false))
      ),
      (
        'seek',
        () async {
          final r = await showSeekSheet(context,
              text: '2024-05-01',
              gid: '',
              pickerVisible: true,
              pickerDate: DateTime(2024, 5, 1),
              prevGid: '2741230',
              nextGid: '2740988');
          _report(r == null ? null : '${r.direction.name} ${r.text} ${r.gid}');
        }
      ),
      (
        'archiver',
        () async {
          final source = _FixtureArchiverSource(
              fail: false, delay: const Duration(milliseconds: 1200))
            ..start();
          await presentArchiverSheet(context, source);
          _report('archiver closed');
        }
      ),
      (
        'archiverError',
        () async {
          final source = _FixtureArchiverSource(
              fail: true, delay: const Duration(milliseconds: 800))
            ..start();
          await presentArchiverSheet(context, source);
          _report('archiver closed');
        }
      ),
      (
        'search',
        () async {
          // Seed history and quick searches so the start view has content
          // without submitting a real search.
          await hiveHelper.setSearchHistory(const [
            'language:chinese',
            'artist:offline',
            'full color',
            '"blue sky"',
            'parody:fixture',
            'group:circle',
          ]);
          final quick = Get.find<QuickSearchController>();
          quick.addText('language:chinese -translated', silent: true);
          quick.addText('female:glasses full color', silent: true);
          NavigatorUtil.goSearchPage();
        }
      ),
      (
        'gallery',
        () async {
          const fixture = GalleryProvider(
            gid: '9500001',
            token: '0000000000',
            url: 'https://e-hentai.org/g/9500001/0000000000/',
            englishTitle: 'Offline sheet preview fixture',
            filecount: '20',
            category: 'Non-H',
            rating: 4.21,
            ratingCount: '318',
            apiuid: '1',
            apikey: 'offline',
          );
          Get.find<GalleryCacheController>()
              .setGalleryProviderCache(fixture.gid, fixture);
          await NavigatorUtil.goGalleryPage(galleryProvider: fixture);
        }
      ),
    ];
    return CupertinoPageScaffold(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _backdropLayer(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ehTheme.palette.surface.resolveFrom(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sheet preview · last: $_last',
                          key: const ValueKey('sheetPreview.last')),
                      const SizedBox(height: 8),
                      Obx(() => Row(children: [
                            const Expanded(child: Text('liquidGlass')),
                            CupertinoSwitch(
                              value: setting.liquidGlass,
                              onChanged: (v) => setting.liquidGlass = v,
                            ),
                          ])),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final b in _Backdrop.values)
                          EhButton(
                            label: b.name,
                            size: 32,
                            style: EhButtonStyle.tonal,
                            selected: _backdrop == b,
                            onPressed: () => setState(() => _backdrop = b),
                          ),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final (label, action) in buttons)
                          Semantics(
                            identifier: 'sheetPreview.$label',
                            child: EhButton(
                              label: label,
                              size: 36,
                              style: EhButtonStyle.prominent,
                              onPressed: action,
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFF000000),
      Color(0xFFFFFFFF),
      Color(0xFFE5484D),
      Color(0xFF0E0F12),
      Color(0xFFF0A030),
      Color(0xFF4A5BD8),
    ];
    const band = 22.0;
    for (var i = 0; i * band < size.height + size.width; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      final path = Path()
        ..moveTo(i * band, 0)
        ..lineTo(i * band + band, 0)
        ..lineTo(i * band + band - size.height, size.height)
        ..lineTo(i * band - size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
