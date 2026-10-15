import 'dart:async';
import 'dart:io';

import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/utils/avatar_upload_retry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final proof = AvatarVerification(
      [Cookie('cf_clearance', 'offline-only')], 'offline-UA');
  for (final canceled in [true, false]) {
    test('canceled or incomplete verification never retries: $canceled',
        () async {
      var uploads = 0;
      var syncs = 0;
      final result = await uploadAvatarWithVerification(
        upload: () async {
          uploads++;
          throw EhError(type: EhErrorType.cfBlocked);
        },
        verify: () async =>
            canceled ? null : const AvatarVerification([], null),
        synchronize: (_) async {
          syncs++;
        },
        checkAccount: () {},
      );
      expect(result, false);
      expect(uploads, 1);
      expect(syncs, 0);
    });
  }
  test(
      'completed verification waits for cookie synchronization before exactly one retry',
      () async {
    final saved = Completer<void>();
    var uploads = 0;
    var syncing = false;
    final result = uploadAvatarWithVerification(
      upload: () async {
        uploads++;
        if (uploads == 1) {
          throw EhError(type: EhErrorType.cfBlocked);
        }
        expect(saved.isCompleted, true);
      },
      verify: () async => proof,
      synchronize: (_) {
        syncing = true;
        return saved.future;
      },
      checkAccount: () {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(syncing, true);
    expect(uploads, 1);
    saved.complete();
    expect(await result, true);
    expect(uploads, 2);
  });
  test('a second challenge escapes without opening verification again',
      () async {
    var uploads = 0;
    var verifications = 0;
    await expectLater(
        uploadAvatarWithVerification(
          upload: () async {
            uploads++;
            throw EhError(type: EhErrorType.cfBlocked);
          },
          verify: () async {
            verifications++;
            return proof;
          },
          synchronize: (_) async {},
          checkAccount: () {},
        ),
        throwsA(anything));
    expect(uploads, 2);
    expect(verifications, 1);
  });
  test('account change while verification is open blocks cookie sync and retry',
      () async {
    var accountValid = true;
    var syncs = 0;
    var uploads = 0;
    await expectLater(
        uploadAvatarWithVerification(
          upload: () async {
            uploads++;
            throw EhError(type: EhErrorType.cfBlocked);
          },
          verify: () async {
            accountValid = false;
            return proof;
          },
          synchronize: (_) async {
            syncs++;
          },
          checkAccount: () {
            if (!accountValid) {
              throw StateError('account changed');
            }
          },
        ),
        throwsStateError);
    expect(uploads, 1);
    expect(syncs, 0);
  });
  test('ordinary upload errors and cookie failures do not retry', () async {
    var verifications = 0;
    await expectLater(
        uploadAvatarWithVerification(
          upload: () async => throw EhError(error: 'invalid image'),
          verify: () async {
            verifications++;
            return proof;
          },
          synchronize: (_) async {},
          checkAccount: () {},
        ),
        throwsA(anything));
    expect(verifications, 0);
    var uploads = 0;
    await expectLater(
        uploadAvatarWithVerification(
          upload: () async {
            uploads++;
            throw EhError(type: EhErrorType.cfBlocked);
          },
          verify: () async => proof,
          synchronize: (_) async => throw StateError('cookie write failed'),
          checkAccount: () {},
        ),
        throwsStateError);
    expect(uploads, 1);
  });
}
