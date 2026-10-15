import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_fe/common/parser/user_profile_parser.dart';
import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/network/request.dart';
import 'package:eros_fe/pages/setting/webview/cf_verify_in.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/avatar_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'profile URLs preserve empty values and resolve relative/protocol-relative images',
      () {
    String profile(String src) =>
        '<div id="profilename">Neutral</div><div></div><div><img src="$src"></div>';
    expect(parseUserProfile(profile('')).avatarUrl, '');
    expect(parseUserProfile(profile('//images.example.test/a.png')).avatarUrl,
        'https://images.example.test/a.png');
    expect(parseUserProfile(profile('uploads/a.png')).avatarUrl,
        'https://forums.e-hentai.org/uploads/a.png');
    expect(parseUserProfile(profile('javascript:bad')).avatarUrl, '');
  });
  test('upload parser rejects empty, unknown, login and explicit errors', () {
    for (final html in [
      '',
      '<html>Welcome</html>',
      '<a href="?auth_key=0123456789abcdef0123456789abcdef">unknown</a>',
      '<input type="password">',
      '<div class="errorwrap">Too big</div>'
    ]) {
      expect(parseAvatarUpdateResult(html).success, false, reason: html);
    }
    expect(parseAvatarUpdateResult(avatarFormHtml).success, true);
    expect(parseAvatarUpdateResult('<p>Avatar has been updated</p>').success,
        true);
    expect(parseAvatarUpdateResult('<p>Just a moment...</p>').cfBlocked, true);
    expect(
        CfVerifyWebView.isForumUri(Uri.parse('https://forums.e-hentai.org/')),
        true);
    for (final url in [
      'https://e-hentai.org.example.test/',
      'https://forums.e-hentai.org.evil/',
      'http://forums.e-hentai.org/'
    ]) {
      expect(CfVerifyWebView.isForumUri(Uri.parse(url)), false);
    }
  });
  for (final outcome in [
    'ok',
    'empty',
    'error',
    'challenge',
    'account-change'
  ]) {
    test('real local HTTP multipart/auth response: $outcome', () async {
      HttpOverrides.global = null;
      final dir = await Directory.systemTemp.createTemp('avatar-request-test-');
      final file =
          await File('${dir.path}/misnamed.jpg').writeAsBytes(neutralAvatarPng);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var gets = 0;
      var posts = 0;
      var currentAccount = true;
      String? body;
      String? authKey;
      String? referer;
      server.listen((request) async {
        request.response.headers.contentType = ContentType.html;
        if (request.method == 'GET') {
          gets++;
          request.response.write(avatarFormHtml);
          if (outcome == 'account-change') {
            currentAccount = false;
          }
        } else {
          posts++;
          authKey = request.uri.queryParameters['auth_key'];
          referer = request.headers.value('referer');
          body = latin1.decode(await request
              .fold<List<int>>([], (buffer, data) => buffer..addAll(data)));
          if (outcome == 'ok') {
            request.response.write(avatarFormHtml);
          }
          if (outcome == 'error') {
            request.response
                .write('<div class="errorwrap">Avatar too large</div>');
          }
          if (outcome == 'challenge') {
            request.response.statusCode = 403;
            request.response
                .write('<title>Just a moment</title>challenge-platform');
          }
        }
        await request.response.close();
      });
      final dio = Dio()
        ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
          options.baseUrl = 'http://127.0.0.1:${server.port}';
          options.path = '/index.php';
          handler.next(options);
        }));
      try {
        final result =
            uploadAvatarToForum(file.path, client: dio, checkAccount: () {
          if (!currentAccount) {
            throw StateError('account changed');
          }
        });
        if (outcome == 'ok') {
          expect(await result, true);
        } else if (outcome == 'challenge') {
          await expectLater(
              result,
              throwsA(isA<EhError>()
                  .having((e) => e.type, 'type', EhErrorType.cfBlocked)));
        } else {
          await expectLater(result, throwsA(anything));
        }
        expect(gets, 1);
        expect(posts, outcome == 'account-change' ? 0 : 1);
        if (posts == 1) {
          expect(authKey, '0123456789abcdef0123456789abcdef');
          expect(referer, contains('CODE=24'));
          expect(body, contains('name="upload_avatar"; filename="avatar.png"'));
          expect(body?.toLowerCase(), contains('content-type: image/png'));
          expect(body, contains('name="CODE"'));
          expect(body, contains('25'));
        }
      } finally {
        dio.close(force: true);
        await server.close(force: true);
        await dir.delete(recursive: true);
      }
    });
  }
  test('HTTP 403 challenge on auth form reaches the verification path',
      () async {
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = 403;
      request.response.write('cf_chl_opt');
      await request.response.close();
    });
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        options.baseUrl = 'http://127.0.0.1:${server.port}';
        options.path = '/';
        handler.next(options);
      }));
    try {
      await expectLater(
          getAvatarAuthKey(client: dio),
          throwsA(isA<EhError>()
              .having((e) => e.type, 'type', EhErrorType.cfBlocked)));
    } finally {
      dio.close(force: true);
      await server.close(force: true);
    }
  });
}
