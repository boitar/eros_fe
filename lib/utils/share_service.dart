import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'logger.dart';
import 'toast.dart';

/// The single entry point for native share sheets.
///
/// Keeping the presentation details here is important on iOS: the share
/// sheet needs a live presenter and iPad needs a non-empty anchor rect. It
/// also prevents two taps from presenting two native controllers at once.
class ShareService {
  ShareService._();

  static const MethodChannel _iosShareChannel =
      MethodChannel('cn.honjow.eros/share');

  static bool _isSharing = false;

  static bool get isSharing => _isSharing;

  /// Returns a global, non-empty rect suitable for share_plus.
  ///
  /// The first context is normally the pressed button. The app and overlay
  /// contexts are fallbacks for controller-driven actions. A final 1x1 rect
  /// keeps the iPad popover contract valid when an action has no widget
  /// context left (for example, after a modal route was dismissed).
  static Rect positionOrigin(BuildContext? context) {
    for (final candidate in <BuildContext?>[
      context,
      Get.context,
      Get.overlayContext,
    ]) {
      final rect = _originFromContext(candidate);
      if (rect != null) {
        return rect;
      }
    }

    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  static Future<ShareResult?> shareText(
    String text, {
    BuildContext? context,
    String? subject,
    String? title,
    Rect? sharePositionOrigin,
  }) {
    return share(
      ShareParams(
        text: text,
        subject: subject,
        title: title,
        sharePositionOrigin: sharePositionOrigin,
      ),
      context: context,
      fallbackText: text,
    );
  }

  static Future<ShareResult?> shareFiles(
    List<XFile> files, {
    BuildContext? context,
    String? subject,
    String? title,
    Rect? sharePositionOrigin,
  }) {
    return share(
      ShareParams(
        files: files,
        subject: subject,
        title: title,
        sharePositionOrigin: sharePositionOrigin,
      ),
      context: context,
    );
  }

  static Future<ShareResult?> share(
    ShareParams params, {
    BuildContext? context,
    String? fallbackText,
  }) async {
    if (_isSharing) {
      logger.d('share ignored: another share request is active');
      _notify('Share already in progress');
      return null;
    }

    _isSharing = true;
    try {
      final Rect origin;
      if (_usableRect(params.sharePositionOrigin)) {
        origin = params.sharePositionOrigin!;
      } else {
        origin = positionOrigin(context);
      }
      final request = _withPositionOrigin(params, origin);
      final result = defaultTargetPlatform == TargetPlatform.iOS &&
              _canUseIosBridge(request)
          ? await _shareOnIos(request)
          : await SharePlus.instance.share(request);

      if (result.status == ShareResultStatus.unavailable) {
        await _reportFailure(
          message: 'Sharing is unavailable',
          fallbackText: fallbackText,
        );
      }
      return result;
    } on PlatformException catch (error, stackTrace) {
      logger.e(
        'share failed: ${error.code}',
        error: error,
        stackTrace: stackTrace,
      );
      await _reportFailure(
        message: 'Share failed',
        fallbackText: fallbackText,
      );
      return null;
    } catch (error, stackTrace) {
      logger.e('share failed: ${error.runtimeType}',
          error: error, stackTrace: stackTrace);
      await _reportFailure(
        message: 'Share failed',
        fallbackText: fallbackText,
      );
      return null;
    } finally {
      _isSharing = false;
    }
  }

  /// Waits until a Flutter modal route has had time to leave the hierarchy.
  /// UIKit cannot present a share controller while the previous route is
  /// still being dismissed.
  static Future<void> waitForModalDismissal() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  static Rect? _originFromContext(BuildContext? context) {
    if (context == null || !context.mounted) {
      return null;
    }

    try {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.attached &&
          renderObject.hasSize &&
          renderObject.size.width > 0 &&
          renderObject.size.height > 0) {
        final offset = renderObject.localToGlobal(Offset.zero);
        final rect = offset & renderObject.size;
        if (_usableRect(rect)) {
          return rect;
        }
      }
    } catch (_) {
      // A context can be detached between a tap and this lookup.
    }

    try {
      final size = MediaQuery.of(context).size;
      if (size.width > 0 && size.height > 0) {
        return Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 1,
          height: 1,
        );
      }
    } catch (_) {
      // The fallback contexts may not be below a MediaQuery.
    }

    return null;
  }

  static bool _usableRect(Rect? rect) {
    return rect != null &&
        rect.width > 0 &&
        rect.height > 0 &&
        rect.left.isFinite &&
        rect.top.isFinite &&
        rect.right.isFinite &&
        rect.bottom.isFinite;
  }

  static ShareParams _withPositionOrigin(ShareParams params, Rect origin) {
    return ShareParams(
      text: params.text,
      title: params.title,
      subject: params.subject,
      previewThumbnail: params.previewThumbnail,
      sharePositionOrigin: origin,
      uri: params.uri,
      files: params.files,
      fileNameOverrides: params.fileNameOverrides,
      downloadFallbackEnabled: params.downloadFallbackEnabled,
      mailToFallbackEnabled: params.mailToFallbackEnabled,
      excludedCupertinoActivities: params.excludedCupertinoActivities,
    );
  }

  static bool _canUseIosBridge(ShareParams params) {
    // The bridge passes file paths to UIKit. Data-only XFiles still need the
    // share_plus platform implementation to materialize a temporary file.
    if (params.files?.any((file) => file.path.isEmpty) ?? false) {
      return false;
    }
    if (params.previewThumbnail?.path.isEmpty ?? false) {
      return false;
    }
    return params.fileNameOverrides == null;
  }

  static Future<ShareResult> _shareOnIos(ShareParams params) async {
    final files = params.files;
    final arguments = <String, dynamic>{
      if (params.text != null) 'text': params.text,
      if (params.title != null) 'title': params.title,
      if (params.subject != null) 'subject': params.subject,
      if (params.uri != null) 'uri': params.uri.toString(),
      if (files != null) 'paths': files.map((file) => file.path).toList(),
      if (files != null)
        'mimeTypes': files.map((file) => file.mimeType ?? '').toList(),
      if (params.sharePositionOrigin != null) ...{
        'originX': params.sharePositionOrigin!.left,
        'originY': params.sharePositionOrigin!.top,
        'originWidth': params.sharePositionOrigin!.width,
        'originHeight': params.sharePositionOrigin!.height,
      },
      if (params.excludedCupertinoActivities != null)
        'excludedCupertinoActivities': params.excludedCupertinoActivities!
            .map((activity) => activity.value)
            .toList(),
    };
    final raw = await _iosShareChannel.invokeMethod<String>('share', arguments);
    return _resultFromRaw(raw);
  }

  static ShareResult _resultFromRaw(String? raw) {
    if (raw == null) {
      return ShareResult.unavailable;
    }
    if (raw.isEmpty) {
      return const ShareResult('', ShareResultStatus.dismissed);
    }
    return ShareResult(raw, ShareResultStatus.success);
  }

  static Future<void> _reportFailure({
    required String message,
    String? fallbackText,
  }) async {
    if (fallbackText != null && fallbackText.isNotEmpty) {
      try {
        await Clipboard.setData(ClipboardData(text: fallbackText));
        _notify('$message; link copied to clipboard');
        return;
      } catch (error, stackTrace) {
        logger.e('share fallback copy failed',
            error: error, stackTrace: stackTrace);
      }
    }
    _notify(message);
  }

  static void _notify(String message) {
    try {
      showToast(message);
    } catch (error) {
      logger.d('share notification unavailable: ${error.runtimeType}');
    }
  }
}
