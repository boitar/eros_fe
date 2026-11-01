import 'dart:io' as io;

import 'package:eros_fe/common/controller/user_controller.dart';
import 'package:eros_fe/index.dart';
import 'package:eros_fe/pages/setting/webview/cf_verify_in.dart';
import 'package:eros_fe/utils/avatar_store.dart';
import 'package:eros_fe/utils/avatar_upload_retry.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// 头像图片来源
enum AvatarSource { album, file, url }

/// 头像用途
enum AvatarTarget { forum, local }

/// 「上传头像」流程：
/// 选择来源（相册/文件/URL）→ 选择用途（上传论坛/仅本地）→ 执行
Future<void> showAvatarManageFlow(BuildContext context) async {
  final UserController controller = Get.find();
  try {
    final account = controller.captureAvatarAccount();
    await _manageAvatar(context, controller, account);
  } catch (error) {
    showToast('$error');
  }
}

Future<void> _manageAvatar(BuildContext context, UserController userController,
    AvatarAccountToken account) async {
  final L10n l10n = L10n.of(context);

  // 1. 选择来源
  final AvatarSource? source = await showCupertinoModalPopup<AvatarSource>(
    context: context,
    builder: (_) => EhActionSheet(
      title: Text(l10n.avatar_source),
      actions: <CupertinoActionSheetAction>[
        CupertinoActionSheetAction(
          child: Text(l10n.avatar_from_album),
          onPressed: () => Get.back(result: AvatarSource.album),
        ),
        CupertinoActionSheetAction(
          child: Text(l10n.avatar_from_file),
          onPressed: () => Get.back(result: AvatarSource.file),
        ),
        CupertinoActionSheetAction(
          child: Text(l10n.avatar_from_url),
          onPressed: () => Get.back(result: AvatarSource.url),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text(l10n.cancel),
        onPressed: () => Get.back(),
      ),
    ),
  );
  if (source == null || !context.mounted) {
    return;
  }

  userController.checkAvatarAccount(account);

  // 2. 获取图片来源
  String? filePath;
  String? urlText;
  switch (source) {
    case AvatarSource.album:
      final XFile? picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      filePath = picked?.path;
    case AvatarSource.file:
      try {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        );
        filePath = result?.files.single.path;
      } on Exception catch (e) {
        logger.e('Pick file failed', error: e);
        rethrow;
      }
    case AvatarSource.url:
      if (!context.mounted) {
        return;
      }
      urlText = await _inputAvatarUrl(context);
  }
  if (source == AvatarSource.url && (urlText == null || urlText.isEmpty)) {
    return;
  }
  if (filePath == null && urlText == null) {
    return;
  }

  if (!context.mounted) {
    return;
  }
  userController.checkAvatarAccount(account);
  if (urlText != null) {
    AvatarStore.imageUri(urlText);
  }

  // 3. 选择用途
  final AvatarTarget? target = await showCupertinoModalPopup<AvatarTarget>(
    context: context,
    builder: (_) => EhActionSheet(
      title: Text(l10n.avatar_target),
      actions: <CupertinoActionSheetAction>[
        CupertinoActionSheetAction(
          child: Text(l10n.avatar_use_forum),
          onPressed: () => Get.back(result: AvatarTarget.forum),
        ),
        CupertinoActionSheetAction(
          child: Text(l10n.avatar_use_local),
          onPressed: () => Get.back(result: AvatarTarget.local),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text(l10n.cancel),
        onPressed: () => Get.back(),
      ),
    ),
  );
  if (target == null || !context.mounted) {
    return;
  }

  // 4. 执行
  userController.checkAvatarAccount(account);
  switch (target) {
    case AvatarTarget.forum:
      String localFile = filePath ?? '';
      if (localFile.isEmpty) {
        // URL 来源：先落地为临时文件再上传
        _showLoading();
        try {
          localFile = await AvatarStore.downloadToTemp(urlText!,
              memberId: account.memberId);
        } finally {
          _hideLoading();
        }
      }
      try {
        if (!context.mounted) {
          return;
        }
        userController.checkAvatarAccount(account);
        await _uploadForumWithCfFallback(
            context, localFile, userController, account);
      } finally {
        if (filePath == null && localFile.isNotEmpty) {
          await io.File(localFile).parent.delete(recursive: true);
        }
      }
    case AvatarTarget.local:
      _showLoading();
      String savedPath;
      try {
        savedPath = filePath != null
            ? await AvatarStore.saveFromFile(filePath,
                memberId: account.memberId)
            : await AvatarStore.saveFromUrl(urlText!,
                memberId: account.memberId);
      } finally {
        _hideLoading();
      }
      userController.setLocalAvatarPath(savedPath, account: account);
      showToast(l10n.avatar_local_success);
  }
}

/// 上传头像到论坛；被 Cloudflare 拦截时引导用户在应用内 WebView 完成验证后重试一次
Future<void> _uploadForumWithCfFallback(
  BuildContext context,
  String filePath,
  UserController controller,
  AvatarAccountToken account,
) async {
  final l10n = L10n.of(context);
  final confirmed = await uploadAvatarWithVerification(
    checkAccount: () => controller.checkAvatarAccount(account),
    upload: () async {
      _showLoading();
      try {
        await controller.uploadForumAvatar(filePath, account: account);
      } finally {
        _hideLoading();
      }
    },
    verify: () async {
      if (!context.mounted) {
        return null;
      }
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => EhAlertDialog(
          title: Text(l10n.avatar_cf_verify_title),
          content: Text(l10n.avatar_cf_verify_message),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: Text(l10n.cancel),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text(l10n.ok),
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        return null;
      }
      controller.checkAvatarAccount(account);
      return openCfVerification();
    },
    synchronize: (verification) => applyCfVerification(
      verification,
      checkAccount: () => controller.checkAvatarAccount(account),
    ),
  );
  if (confirmed) {
    showToast(l10n.avatar_upload_success);
  }
}

/// URL 输入弹窗
Future<String?> _inputAvatarUrl(BuildContext context) {
  return showCupertinoDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _AvatarUrlDialog(),
  );
}

class _AvatarUrlDialog extends StatefulWidget {
  const _AvatarUrlDialog();
  @override
  State<_AvatarUrlDialog> createState() => _AvatarUrlDialogState();
}

class _AvatarUrlDialogState extends State<_AvatarUrlDialog> {
  final _textController = TextEditingController();
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return EhAlertDialog(
      title: Text(l10n.avatar_from_url),
      content: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: CupertinoTextField(
          controller: _textController,
          autofocus: true,
          placeholder: 'https://',
          minLines: 1,
          maxLines: 3,
        ),
      ),
      actions: [
        CupertinoDialogAction(
            child: Text(l10n.cancel), onPressed: () => Navigator.pop(context)),
        CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(l10n.ok),
            onPressed: () =>
                Navigator.pop(context, _textController.text.trim())),
      ],
    );
  }
}

void _showLoading() {
  SmartDialog.showLoading(
    builder: (_) => Center(
      child: CupertinoPopupSurface(
        child: Container(
          height: 80,
          width: 80,
          alignment: Alignment.center,
          child: const CupertinoActivityIndicator(radius: 20),
        ),
      ),
    ),
    backType: SmartBackType.block,
  );
}

void _hideLoading() {
  SmartDialog.dismiss(status: SmartStatus.loading);
}
