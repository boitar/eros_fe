import 'package:eros_fe/component/exception/error.dart';
import 'package:eros_fe/utils/cf_verification.dart';

/// An explicit completed verification permits exactly one retry.
Future<bool> uploadAvatarWithVerification({
  required Future<void> Function() upload,
  required Future<CfVerification?> Function() verify,
  required Future<void> Function(CfVerification) synchronize,
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
