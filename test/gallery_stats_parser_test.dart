// ignore_for_file: must_call_super

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/parser/gallery_stats_parser.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/locale_service.dart';
import 'package:eros_fe/models/gallery_stats.dart';
import 'package:eros_fe/network/app_dio/app_dio.dart';
import 'package:eros_fe/network/app_dio/dio_http_cli.dart';
import 'package:eros_fe/network/app_dio/exception.dart';
import 'package:eros_fe/network/request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeSettings extends EhSettingService {
  @override
  void onInit() {}
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(
    RequestOptions options,
    Future<void>? cancelFuture,
  )
  handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options, cancelFuture);

  @override
  void close({bool force = false}) {}
}

int _adapterSeq = 0;

DioHttpClient _clientWithAdapter(_StubAdapter adapter) {
  final client = DioHttpClient(
    dioConfig: DioHttpConfig(baseUrl: 'https://test-${++_adapterSeq}.invalid'),
  );
  client.dio.httpClientAdapter = adapter;
  return client;
}

Options _testOptions({required bool refresh}) => CacheOptions(
  store: MemCacheStore(),
  policy: refresh ? CachePolicy.refresh : CachePolicy.request,
).toOptions();

ResponseBody _htmlBody(
  String html,
  int statusCode, {
  Map<String, List<String>>? headers,
}) => ResponseBody.fromBytes(
  utf8.encode(html),
  statusCode,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['text/html; charset=utf-8'],
    ...?headers,
  },
);

void main() {
  group('buildGalleryStatsUrl', () {
    test('builds canonical e-hentai stats URL for valid gid and hex token', () {
      expect(
        buildGalleryStatsUrl(' 3104821 ', ' 9a4f2c1b8e '),
        'https://e-hentai.org/stats.php?gid=3104821&t=9a4f2c1b8e',
      );
      expect(
        buildGalleryStatsUrl('42', 'ABCDEF0123'),
        'https://e-hentai.org/stats.php?gid=42&t=ABCDEF0123',
      );
    });

    test('rejects invalid or unsafe gid and token values', () {
      expect(buildGalleryStatsUrl('', '9a4f2c1b8e'), isEmpty);
      expect(buildGalleryStatsUrl('3104821', ''), isEmpty);
      expect(buildGalleryStatsUrl('abc123', '9a4f2c1b8e'), isEmpty);
      expect(buildGalleryStatsUrl('3104821', 'zzzzzzzzzz'), isEmpty);
      expect(buildGalleryStatsUrl('3104821&foo=1', '9a4f2c1b8e'), isEmpty);
      expect(buildGalleryStatsUrl('../123', '9a4f2c1b8e'), isEmpty);
    });
  });

  group('parseCompactStatNumber', () {
    test(
      'parses plain integers, commas, K/M/B suffixes, placeholders, and guards infinity overflow',
      () {
        expect(parseCompactStatNumber('5731'), 5731);
        expect(parseCompactStatNumber('5,731'), 5731);
        expect(parseCompactStatNumber('570K'), 570000);
        expect(parseCompactStatNumber('12.5k'), 12500);
        expect(parseCompactStatNumber('16.2M'), 16200000);
        expect(parseCompactStatNumber('1.1B'), 1100000000);
        expect(parseCompactStatNumber('-'), 0);
        expect(parseCompactStatNumber('—'), 0);
        expect(parseCompactStatNumber(''), 0);
        expect(parseCompactStatNumber('N/A'), 0);
        // Huge number overflowing double to Infinity after B scaling must return 0.
        expect(parseCompactStatNumber('${'9' * 305}B'), 0);
        expect(parseCompactStatNumber('9' * 400), 0);
      },
    );
  });

  group('parseGalleryStats', () {
    test('parses total visits, rankings, and trimmed daily/monthly/yearly series', () {
      const html = '''
<!DOCTYPE html>
<html>
<head><title>Gallery Stats - E-Hentai.org</title></head>
<body>
  <div class="stuffbox">
    <p>Total Visits: <strong>128,450</strong></p>
    <table>
      <tbody>
        <tr><th colspan="5">Ranking &amp; Score</th></tr>
        <tr><td>All-Time</td><td>Ranking:</td><td></td><td>#42</td><td>3,250</td></tr>
        <tr><td colspan="5"></td></tr>
        <tr><td>Past Year</td><td>Ranking:</td><td></td><td>#128</td><td>1,420</td></tr>
        <tr><td colspan="5"></td></tr>
        <tr><td>Past Month</td><td>Ranking:</td><td></td><td>#19</td><td>980</td></tr>
        <tr><td colspan="5"></td></tr>
        <tr><td>Yesterday</td><td>Ranking:</td><td></td><td>Unranked</td><td>-</td></tr>
      </tbody>
    </table>
  </div>
  <div id="graphs">
    <div>
      <p>Daily Statistics</p>
      <table>
        <tbody>
          <tr><td class="stdk">1st</td><td class="stdk">2nd</td><td class="stdk">3rd</td></tr>
          <tr><td class="stdv">-</td><td class="stdv">420</td><td class="stdv">1.2K</td></tr>
          <tr><td class="stdv">0</td><td class="stdv">3.5K</td><td class="stdv">12K</td></tr>
        </tbody>
      </table>
    </div>
    <div>
      <p>Monthly Statistics</p>
      <table>
        <tbody>
          <tr><td class="stdk">January</td><td class="stdk">February</td><td class="stdk">March</td></tr>
          <tr><td class="stdv">0</td><td class="stdv">12.4K</td><td class="stdv">28K</td></tr>
          <tr><td class="stdv">0</td><td class="stdv">140K</td><td class="stdv">310K</td></tr>
        </tbody>
      </table>
    </div>
    <div>
      <p>Yearly Statistics</p>
      <table>
        <tbody>
          <tr><td class="stdk">2024</td><td class="stdk">2025</td><td class="stdk">2026</td></tr>
          <tr><td class="stdv">-</td><td class="stdv">80K</td><td class="stdv">48.4K</td></tr>
          <tr><td class="stdv">-</td><td class="stdv">1.2M</td><td class="stdv">650K</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</body>
</html>
''';

      final stats = parseGalleryStats(html);
      expect(stats.totalVisits, 128450);
      expect(stats.hasAnyRanking, isTrue);
      expect(stats.allTimeRanking, 42);
      expect(stats.allTimeScore, 3250);
      expect(stats.yearRanking, 128);
      expect(stats.yearScore, 1420);
      expect(stats.monthRanking, 19);
      expect(stats.monthScore, 980);
      expect(stats.dayRanking, isNull);
      expect(stats.dayScore, isNull);

      expect(stats.dailyStats.map((e) => e.period), <String>['2nd', '3rd']);
      expect(stats.dailyStats[0].visits, 420);
      expect(stats.dailyStats[0].hits, 3500);
      expect(stats.dailyStats[1].visits, 1200);
      expect(stats.dailyStats[1].hits, 12000);

      expect(
        stats.monthlyStats.map((e) => e.period),
        <String>['February', 'March'],
      );
      expect(stats.monthlyStats[0].visits, 12400);
      expect(stats.monthlyStats[1].hits, 310000);

      expect(stats.yearlyStats.map((e) => e.period), <String>['2025', '2026']);
      expect(stats.yearlyStats[0].hits, 1200000);
      expect(stats.defaultGranularity, GalleryStatsGranularity.monthly);
    });

    test('parses unranked gallery without ranking table', () {
      const html = '''
<div class="stuffbox">
  <p>Total Visits: <strong>312</strong></p>
</div>
<div id="graphs">
  <div>
    <p>Daily Statistics</p>
    <table><tbody>
      <tr><td class="stdk">14th</td></tr>
      <tr><td class="stdv">312</td></tr>
      <tr><td class="stdv">4.2K</td></tr>
    </tbody></table>
  </div>
</div>
''';
      final stats = parseGalleryStats(html);
      expect(stats.totalVisits, 312);
      expect(stats.hasAnyRanking, isFalse);
      expect(stats.isEmpty, isFalse);
      expect(stats.dailyStats, hasLength(1));
      expect(stats.monthlyStats, isEmpty);
      expect(stats.defaultGranularity, GalleryStatsGranularity.daily);
    });

    test('does not leak monthly-only chart or ranking into other periods via positional fallback', () {
      const html = '''
<div class="stuffbox">
  <p>Total Visits: <strong>900</strong></p>
  <table><tbody>
    <tr><td>Ranking</td><td></td><td></td><td></td><td>Score</td></tr>
    <tr><td>Past Month</td><td></td><td></td><td>#13</td><td>520</td></tr>
  </tbody></table>
</div>
<div id="graphs">
  <div>
    <p>Monthly Statistics</p>
    <table><tbody>
      <tr><td class="stdk">March</td></tr>
      <tr><td class="stdv">900</td></tr>
      <tr><td class="stdv">7.5K</td></tr>
    </tbody></table>
  </div>
</div>
''';
      final stats = parseGalleryStats(html);
      expect(stats.totalVisits, 900);
      expect(stats.monthRanking, 13);
      expect(stats.monthScore, 520);
      expect(stats.allTimeRanking, isNull);
      expect(stats.yearRanking, isNull);
      expect(stats.dayRanking, isNull);
      expect(stats.monthlyStats, hasLength(1));
      expect(stats.monthlyStats.first.period, 'March');
      expect(stats.dailyStats, isEmpty);
      expect(stats.yearlyStats, isEmpty);
    });

    test('distinguishes explicit zero Total Visits from missing Total Visits and ignores unrelated bold numbers', () {
      const explicitZeroHtml = '''
<div class="stuffbox">
  <p>Total Visits: <strong>0</strong></p>
</div>
''';
      final zeroStats = parseGalleryStats(explicitZeroHtml);
      expect(zeroStats.totalVisits, 0);
      expect(zeroStats.hasTotalVisits, isTrue);
      expect(zeroStats.isEmpty, isFalse);

      const missingTotalHtml = '''
<div id="graphs">
  <div>
    <p>Monthly Statistics</p>
    <table><tbody>
      <tr><td class="stdk">May</td></tr>
      <tr><td class="stdv">45</td></tr>
      <tr><td class="stdv">300</td></tr>
    </tbody></table>
  </div>
</div>
''';
      final missingTotalStats = parseGalleryStats(missingTotalHtml);
      expect(missingTotalStats.totalVisits, isNull);
      expect(missingTotalStats.hasTotalVisits, isFalse);
      expect(missingTotalStats.isEmpty, isFalse);
      expect(missingTotalStats.monthlyStats, hasLength(1));

      const errorBoxHtml = '''
<div class="stuffbox">
  <p><strong>404</strong> Not found</p>
</div>
''';
      expect(
        () => parseGalleryStats(errorBoxHtml),
        throwsA(
          isA<GalleryStatsException>().having(
            (e) => e.kind,
            'kind',
            GalleryStatsErrorKind.unavailable,
          ),
        ),
      );
    });

    test('throws loginRequired when E-Hentai returns login page', () {
      const loginHtml = '''
<html>
<head><title>E-Hentai.org Login</title></head>
<body>
  <p>This page requires you to log on.</p>
  <form name="ipb_login_form" method="post"></form>
</body>
</html>
''';
      expect(
        () => parseGalleryStats(loginHtml),
        throwsA(
          isA<GalleryStatsException>().having(
            (e) => e.kind,
            'kind',
            GalleryStatsErrorKind.loginRequired,
          ),
        ),
      );
    });

    test('throws unavailable for empty or non-stats HTML', () {
      expect(
        () => parseGalleryStats('   '),
        throwsA(
          isA<GalleryStatsException>().having(
            (e) => e.kind,
            'kind',
            GalleryStatsErrorKind.unavailable,
          ),
        ),
      );
      expect(
        () => parseGalleryStats('<html><body>Gallery not found</body></html>'),
        throwsA(
          isA<GalleryStatsException>().having(
            (e) => e.kind,
            'kind',
            GalleryStatsErrorKind.unavailable,
          ),
        ),
      );
    });
  });

  group('getGalleryStats request handling', () {
    late Directory tempDir;

    setUpAll(() {
      tempDir = Directory.systemTemp.createTempSync('gallery_stats_test_');
      Global.tempPath = tempDir.path;
    });

    tearDownAll(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    setUp(() {
      Get.testMode = true;
      Get.put<LocaleService>(LocaleService());
      Get.put<EhSettingService>(_FakeSettings());
    });

    tearDown(Get.reset);

    test('requests e-hentai.org/stats.php with gid, t, and refresh cache policy', () async {
      RequestOptions? captured;
      final client = _clientWithAdapter(
        _StubAdapter((options, _) async {
          captured = options;
          return _htmlBody(
            '<div class="stuffbox"><p>Total Visits: <strong>777</strong></p></div>',
            200,
          );
        }),
      );

      final stats = await getGalleryStats(
        gid: '3104821',
        token: '9a4f2c1b8e',
        refresh: true,
        httpClient: client,
        optionsBuilder: _testOptions,
      );

      expect(stats.totalVisits, 777);
      expect(captured, isNotNull);
      expect(captured!.uri.host, 'e-hentai.org');
      expect(captured!.uri.path, '/stats.php');
      expect(captured!.uri.queryParameters['gid'], '3104821');
      expect(captured!.uri.queryParameters['t'], '9a4f2c1b8e');
      expect(
        CacheOptions.fromExtra(captured!)?.policy,
        CachePolicy.refresh,
      );
    });

    test('classifies 403 Cloudflare challenge as retryable network error rather than unavailable', () async {
      final client = _clientWithAdapter(
        _StubAdapter((options, _) async {
          return _htmlBody(
            '<html><head><title>Just a moment...</title></head>'
            '<body>Checking if the site connection is secure (cf-chl-widget)</body></html>',
            403,
            headers: const <String, List<String>>{
              'cf-mitigated': <String>['challenge'],
            },
          );
        }),
      );

      await expectLater(
        getGalleryStats(
          gid: '3104821',
          token: '9a4f2c1b8e',
          httpClient: client,
          optionsBuilder: _testOptions,
        ),
        throwsA(
          isA<GalleryStatsException>().having(
            (e) => e.kind,
            'kind',
            GalleryStatsErrorKind.network,
          ),
        ),
      );
    });

    test('maps HTTP 401 and 403 login HTML to loginRequired, 404 to unavailable, and 500 to network', () async {
      final client401 = _clientWithAdapter(
        _StubAdapter((_, _) async => _htmlBody('Unauthorized', 401)),
      );
      await expectLater(
        getGalleryStats(
          gid: '3104821',
          token: '9a4f2c1b8e',
          httpClient: client401,
          optionsBuilder: _testOptions,
        ),
        throwsA(
          isA<GalleryStatsException>().having(
            (e) => e.kind,
            'kind',
            GalleryStatsErrorKind.loginRequired,
          ),
        ),
      );

      final client403Login = _clientWithAdapter(
        _StubAdapter(
          (_, _) async => _htmlBody(
            '<html><title>E-Hentai.org Login</title>'
            '<body>This page requires you to log on.</body></html>',
            403,
          ),
        ),
      );
      await expectLater(
        getGalleryStats(
          gid: '3104821',
          token: '9a4f2c1b8e',
          httpClient: client403Login,
          optionsBuilder: _testOptions,
        ),
        throwsA(
          isA<GalleryStatsException>().having(
            (e) => e.kind,
            'kind',
            GalleryStatsErrorKind.loginRequired,
          ),
        ),
      );

      final client404 = _clientWithAdapter(
        _StubAdapter(
          (_, _) async => _htmlBody(
            '<div class="stuffbox"><p>Total Visits: <strong>404</strong></p></div>',
            404,
          ),
        ),
      );
      await expectLater(
        getGalleryStats(
          gid: '3104821',
          token: '9a4f2c1b8e',
          httpClient: client404,
          optionsBuilder: _testOptions,
        ),
        throwsA(
          isA<GalleryStatsException>().having(
            (e) => e.kind,
            'kind',
            GalleryStatsErrorKind.unavailable,
          ),
        ),
      );

      final client403NonLogin = _clientWithAdapter(
        _StubAdapter(
          (_, _) async => _htmlBody(
            '<div class="stuffbox"><p>Total Visits: <strong>403</strong></p></div>',
            403,
          ),
        ),
      );
      await expectLater(
        getGalleryStats(
          gid: '3104821',
          token: '9a4f2c1b8e',
          httpClient: client403NonLogin,
          optionsBuilder: _testOptions,
        ),
        throwsA(
          isA<GalleryStatsException>().having(
            (e) => e.kind,
            'kind',
            GalleryStatsErrorKind.unavailable,
          ),
        ),
      );

      final client500 = _clientWithAdapter(
        _StubAdapter((_, _) async => _htmlBody('Server error', 500)),
      );
      await expectLater(
        getGalleryStats(
          gid: '3104821',
          token: '9a4f2c1b8e',
          httpClient: client500,
          optionsBuilder: _testOptions,
        ),
        throwsA(
          isA<GalleryStatsException>().having(
            (e) => e.kind,
            'kind',
            GalleryStatsErrorKind.network,
          ),
        ),
      );
    });

    test('propagates CancelException when request is cancelled in-flight', () async {
      final token = CancelToken();
      final started = Completer<void>();
      final neverResponds = Completer<ResponseBody>();
      final client = _clientWithAdapter(
        _StubAdapter((_, cancelFuture) {
          if (!started.isCompleted) {
            started.complete();
          }
          cancelFuture?.then((_) {
            if (!neverResponds.isCompleted) {
              neverResponds.completeError(
                DioException.requestCancelled(
                  requestOptions: RequestOptions(path: '/stats.php'),
                  reason: 'in-flight cancel',
                ),
              );
            }
          });
          return neverResponds.future;
        }),
      );

      final future = getGalleryStats(
        gid: '3104821',
        token: '9a4f2c1b8e',
        cancelToken: token,
        httpClient: client,
        optionsBuilder: _testOptions,
      );
      await started.future;
      token.cancel('user collapsed stats mid-flight');

      await expectLater(future, throwsA(isA<CancelException>()));
    });
  });

  group('GalleryStats derived metrics', () {
    const sample = GalleryStats(totalVisits: 10000);

    test('favoriteRate handles valid, zero, clamped, and invalid inputs', () {
      expect(sample.favoriteRate(420), closeTo(0.042, 1e-9));
      expect(sample.favoriteRate(0), 0.0);
      expect(sample.favoriteRate(15000), 1.0);
      expect(sample.favoriteRate(null), isNull);
      expect(const GalleryStats(totalVisits: 0).favoriteRate(50), isNull);
    });

    test('averageDailyVisits computes UTC daily rate and ignores <24h galleries', () {
      final now = DateTime.utc(2026, 11, 25, 12, 0);
      expect(
        sample.averageDailyVisits('2026-11-15 12:00', nowUtc: now),
        closeTo(1000.0, 1e-6),
      );
      expect(
        sample.averageDailyVisits('2026-11-25 00:00', nowUtc: now),
        isNull,
      );
      expect(
        sample.averageDailyVisits('not-a-date', nowUtc: now),
        isNull,
      );
    });
  });
}
