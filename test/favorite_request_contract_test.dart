import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:eros_fe/common/controller/favorite_state_store.dart';
import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/models/user.dart';
import 'package:eros_fe/network/api.dart';
import 'package:eros_fe/network/app_dio/pdio.dart';
import 'package:eros_fe/network/favorite_mutation.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/network/text_form.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

class _Settings extends GetxService implements EhSettingService {
  @override
  RxBool isSiteEx = false.obs;
  @override
  bool get nativeHttpClientAdapter => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected setting: ${invocation.memberName}');
}

class _User extends GetxController implements UserController {
  @override
  Rx<User> user = const User().obs;

  @override
  bool get isLogin =>
      (user.value.memberId?.isNotEmpty ?? false) &&
      (user.value.passHash?.isNotEmpty ?? false);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected user access: ${invocation.memberName}');
}

class _Server implements HttpClientAdapter {
  String category = '';
  String note = '';
  int postStatus = 200;
  bool unknownDetail = false;
  bool staleNote = false;
  bool timeoutAfterSave = false;
  bool switchAccountOnRead = false;
  String? postBody;
  String? postLocation;
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  String _escape(String value) => const HtmlEscape().convert(value);
  String get popup => '''
<div id="galpop">${List.generate(10, (i) => '''
<div><div><input name="favcat" value="$i" ${i == 0 ? 'checked' : ''}></div>
<div>icon</div><div>Folder $i</div></div>''').join()}
<textarea>${_escape(staleNote ? 'stale' : note)}</textarea></div>''';

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final bytes = <int>[];
    if (requestStream != null) {
      await requestStream.forEach(bytes.addAll);
    }
    final body = utf8.decode(bytes);
    bodies.add(body);
    final headers = <String, List<String>>{
      Headers.contentTypeHeader: ['text/html; charset=utf-8'],
    };
    if (options.method == 'POST') {
      if (postLocation != null) {
        headers['location'] = [postLocation!];
      }
      if (options.uri.path == '/mytags') {
        return ResponseBody.fromString('', 302, headers: headers);
      }
      if (options.uri.path != '/gallerypopups.php') {
        return ResponseBody.fromString('Synthetic refusal', 403,
            headers: headers);
      }
      if (postStatus == 200 && postBody == null) {
        final fields = Uri.splitQueryString(body);
        category = fields['favcat'] == 'favdel' ? '' : fields['favcat']!;
        note = fields['favnote']!;
        if (timeoutAfterSave) {
          throw DioException(
              requestOptions: options, type: DioExceptionType.receiveTimeout);
        }
      }
      return ResponseBody.fromString(
          postBody ?? '<script>window.close()</script>', postStatus,
          headers: headers);
    }
    if (switchAccountOnRead) {
      favoriteStates.setAccount('different-account');
    }
    if (options.uri.path == '/gallerypopups.php') {
      return ResponseBody.fromString(popup, 200, headers: headers);
    }
    final html = unknownDetail
        ? '<p>Unknown response</p>'
        : category.isEmpty
            ? '<div id="fav"></div><a id="favoritelink">Add to Favorites</a>'
            : '<div id="fav"><div style="background-position:0px -'
                '${2 + int.parse(category) * 19}px"></div></div>'
                '<a id="favoritelink">Folder $category</a>';
    return ResponseBody.fromString(html, 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Server server;
  late _Settings settings;
  final originalConfig = globalDioConfig;
  setUp(() {
    Get.testMode = true;
    settings = Get.put<EhSettingService>(_Settings()) as _Settings;
    Get.put<UserController>(_User()
      ..user(const User(memberId: '9000999', passHash: 'synthetic-only')));
    favoriteStates.setAccount('9000999');
    ApiCacheSetup.initialize();
    globalDioConfig = const DioHttpConfig(
        baseUrl: 'https://e-hentai.org',
        proxy: 'DIRECT',
        domainFronting: false);
    server = _Server();
    final dio = DioHttpClient(dioConfig: globalDioConfig).dio;
    dio.interceptors.clear();
    dio.httpClientAdapter = server;
  });
  tearDown(() {
    globalDioConfig = originalConfig;
    Get.reset();
  });

  test('logged-out favorite is rejected before any network request', () async {
    Get.find<UserController>().user(const User());
    await expectLater(
        galleryAddFavorite('42', 'synthetic-token', favcat: '0'),
        throwsA(isA<FavoriteMutationException>().having((e) => e.failure,
            'failure', FavoriteMutationFailure.authentication)));
    expect(server.requests, isEmpty);
  });

  for (final ex in [false, true]) {
    for (final category in ['0', '7', '9']) {
      test('real request chain confirms $category on ${ex ? "EX" : "EH"}',
          () async {
        settings.isSiteEx.value = ex;
        const note = ' leading &+=\n备注 trailing ';
        await galleryAddFavorite('42', 'synthetic-token',
            favcat: category, favnote: note);
        expect(favoriteStates['42']?.category, category);
        expect(favoriteStates['42']?.title, 'Folder $category');
        expect(server.requests.first.uri.host,
            ex ? 'exhentai.org' : 'e-hentai.org');
        expect(server.requests.first.contentType,
            Headers.formUrlEncodedContentType);
        expect(Uri.splitQueryString(server.bodies.first), {
          'favcat': category,
          'favnote': note,
          'apply': 'Add to Favorites',
          'update': '1',
        });
        expect(server.requests.where((r) => r.method == 'POST'), hasLength(1));
        expect(server.requests.where((r) => r.method == 'GET'), hasLength(2));
      });
    }
  }

  test('removal is confirmed from detail without reading default popup',
      () async {
    server.category = '7';
    favoriteStates.commit('42', '7', 'Folder 7');
    await galleryAddFavorite('42', 'synthetic-token');
    expect(favoriteStates['42']?.category, '');
    expect(server.requests, hasLength(2));
    expect(Uri.splitQueryString(server.bodies.first)['apply'], 'Apply Changes');
  });

  test('403 is retained and never promoted by the default zero popup',
      () async {
    server.postStatus = 403;
    favoriteStates.commit('42', '', '');
    await expectLater(
        galleryAddFavorite('42', 'synthetic-token', favcat: '0'),
        throwsA(isA<FavoriteMutationException>()
            .having((error) => error.statusCode, 'status', 403)));
    expect(server.requests, hasLength(1));
    expect(favoriteStates['42']?.category, '');
    expect(favoriteStates.isBusy('42'), isFalse);
  });

  test('timeout after save is read back without a second POST', () async {
    server.timeoutAfterSave = true;
    await galleryAddFavorite('42', 'synthetic-token', favcat: '7');
    expect(favoriteStates['42']?.category, '7');
    expect(server.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  for (final response in ['login', 'challenge', 'unknown', 'stale-note']) {
    test('$response never updates a confirmed state', () async {
      favoriteStates.commit('42', '9', 'Original');
      if (response == 'login') {
        server.postStatus = 302;
        server.postLocation =
            'https://forums.e-hentai.org/remoteapi.php?private';
      } else if (response == 'challenge') {
        server.postBody = '<title>Just a moment</title><div id="cf-chl-test">';
      } else if (response == 'unknown') {
        server.unknownDetail = true;
      } else {
        server.staleNote = true;
      }
      await expectLater(
          galleryAddFavorite('42', 'synthetic-token',
              favcat: '7', favnote: 'New note'),
          throwsA(isA<FavoriteMutationException>()));
      expect(favoriteStates['42']?.category, '9');
      expect(server.requests.where((r) => r.method == 'POST'), hasLength(1));
    });
  }

  test('late response after account switch never commits into the new account',
      () async {
    server.switchAccountOnRead = true;
    await expectLater(
        galleryAddFavorite('42', 'synthetic-token', favcat: '7'),
        throwsA(isA<FavoriteMutationException>().having((e) => e.failure,
            'failure', FavoriteMutationFailure.accountChanged)));
    expect(favoriteStates['42'], isNull);
    expect(favoriteStates.isBusy('42'), isFalse);
  });

  test('verified sibling endpoints use text forms and retain failure contracts',
      () async {
    expect(
        await postArchiverLocalDownload('https://e-hentai.org/archiver.php',
            dltype: 'res', dlcheck: 'Download Resample Archive'),
        '');
    expect(
        await postArchiverRemoteDownload(
            'https://e-hentai.org/archiver.php', '1280'),
        '');
    expect(
        await actionMytags(dataMap: {
          'tagset_action': 'rename',
          'tagset_name': 'Tag &+= 备注',
        }),
        isTrue);
    expect(
        await postEhProfile(paramMap: {
          'profile_set': '1',
          'name': 'Name &+= 备注',
        }),
        isNull);
    await expectLater(
        postComment(
            gid: '42',
            token: 'synthetic-token',
            comment: 'Comment &+= 备注',
            isEdit: true,
            commentId: '123'),
        throwsA(isA<HttpException>()));
    for (final request in server.requests) {
      expect(request.contentType, Headers.formUrlEncodedContentType);
    }
    final fields = server.bodies.map(Uri.splitQueryString).toList();
    expect(fields[0]['dltype'], 'res');
    expect(fields[1]['hathdl_xres'], '1280');
    expect(fields[2]['tagset_name'], 'Tag &+= 备注');
    expect(fields[3]['name'], 'Name &+= 备注');
    expect(fields[4]['edit_comment'], '123');
  });

  test('form options do not mutate the supplied redirect/cache settings', () {
    final base = Options(followRedirects: false, extra: {'cache': 'kept'});
    final result = textFormOptions(base);
    expect(result.contentType, Headers.formUrlEncodedContentType);
    expect(result.followRedirects, isFalse);
    expect(result.extra, {'cache': 'kept'});
    expect(base.contentType, isNull);
  });
}

// Avoid the production persistent cache and user filesystem in these tests.
class ApiCacheSetup {
  static void initialize() {
    Api.cacheOption = CacheOptions(store: MemCacheStore());
  }
}
