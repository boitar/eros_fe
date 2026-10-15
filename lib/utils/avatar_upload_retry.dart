import 'dart:io';

import 'package:eros_fe/component/exception/error.dart';

class AvatarVerification {
  const AvatarVerification(this.cookies, this.userAgent);

  final List<Cookie> cookies;
  final String? userAgent;

  bool get isComplete => cookies.any(
      (cookie) => cookie.name == 'cf_clearance' && cookie.value.isNotEmpty);
}

/// An explicit completed verification permits exactly one retry.
Future<bool> uploadAvatarWithVerification({
  required Future<void> Function() upload,
  required Future<AvatarVerification?> Function() verify,
  required Future<void> Function(AvatarVerification) synchronize,
  required void Function() checkAccount,
}) async {
  checkAccount();
  try {
    await upload();
    checkAccount();
    return true;
  } on EhError catch (error) {
    if (error.type != EhErrorType.cfBlocked) {
      rethrow;
    }
  }
  checkAccount();
  final verification = await verify();
  checkAccount();
  if (verification == null || !verification.isComplete) {
    return false;
  }
  await synchronize(verification);
  checkAccount();
  await upload();
  checkAccount();
  return true;
}
