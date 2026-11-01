import 'dart:io';

import 'package:eros_fe/common/parser/user_profile_parser.dart';
import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/network/app_dio/exception.dart' as app;
import 'package:eros_fe/utils/cf_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const challenge =
      '<!DOCTYPE html><html lang="en-US"><head><title>Just a moment...</title>'
      '<script src="/cdn-cgi/challenge-platform/h/b/orchestrate"></script>';

  test('a Cloudflare 403 never dumps its HTML into the error text', () {
    final error =
        app.BadRequestException(message: '403 Error', code: 403, data: challenge);
    expect(isCloudflareChallenge(error.data as String), true);
    expect(error.toString(), isNot(contains('<!DOCTYPE')));
    expect(error.toString(), contains('<${challenge.length} chars>'));
  });

  test('short plain error bodies are kept', () {
    final error =
        app.BadRequestException(message: '400', code: 400, data: 'bad gid');
    expect(error.toString(), contains('_data: bad gid'));
  });

  test('only cfBlocked EhErrors count as Cloudflare blocks', () {
    expect(isCfBlockedError(EhError(type: EhErrorType.cfBlocked)), true);
    expect(isCfBlockedError(EhError()), false);
    expect(isCfBlockedError(app.BadRequestException(data: challenge)), false);
    expect(isCfBlockedError(null), false);
  });

  test('verification exposes cookie values and requires cf_clearance', () {
    final verification = CfVerification(
        [Cookie('cf_clearance', 'token'), Cookie('cf_duid', 'duid')], 'UA');
    expect(verification.isComplete, true);
    expect(verification.value('cf_duid'), 'duid');
    expect(verification.value('missing'), isNull);
    expect(
        CfVerification([Cookie('cf_clearance', '')], null).isComplete, false);
  });
}
