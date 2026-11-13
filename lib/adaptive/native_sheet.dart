import 'dart:async';

import 'package:eros_fe/adaptive/platform_capabilities.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/widget/liquid_glass_popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef NativeSheetEventHandler = void Function(
    NativeSheetSession session, String name, Object? value);

/// UIKit sheets for the secondary pages (rate, jump, seek, archiver).
///
/// Used on iOS when the glass effect resolves to the native renderer; every
/// other path draws the same layout with `showEhSheet`.
abstract final class NativeSheet {
  static const MethodChannel _channel = MethodChannel('eros/native-sheet');
  static final Map<int, NativeSheetSession> _sessions =
      <int, NativeSheetSession>{};
  static int _nextId = 0;
  static bool _unavailable = false;
  static bool _handlerInstalled = false;

  @visibleForTesting
  static bool? debugAvailable;

  static bool get available {
    if (kDebugMode && debugAvailable != null) {
      return debugAvailable!;
    }
    return !_unavailable &&
        !kIsWeb &&
        PlatformCapabilities.uiKitGlass &&
        liquidGlassPopupsEnabled &&
        GlassMode.resolve(enabled: true).forComponent() == GlassMode.native;
  }

  /// Colours shared by every native sheet, resolved for [context].
  static Map<String, Object> style(BuildContext context) => <String, Object>{
        'tint': EhPalette.accent.resolveFrom(context).toARGB32(),
        'onTint': EhPalette.onAccent.resolveFrom(context).toARGB32(),
        'star': EhPalette.star.resolveFrom(context).toARGB32(),
        'dark': CupertinoTheme.brightnessOf(context) == Brightness.dark,
        'textScale': MediaQuery.textScalerOf(context).scale(17) / 17,
        'closeLabel':
            CupertinoLocalizations.of(context).modalBarrierDismissLabel,
      };

  /// Presents [kind] with [config]. Returns null when UIKit cannot show it,
  /// so the caller falls back to the Flutter sheet.
  static Future<NativeSheetSession?> present({
    required String kind,
    required Map<String, Object?> config,
    required NativeSheetEventHandler onEvent,
  }) async {
    if (!available) {
      return null;
    }
    if (!_handlerInstalled) {
      _channel.setMethodCallHandler(_handle);
      _handlerInstalled = true;
    }
    final session = NativeSheetSession._(++_nextId, onEvent);
    _sessions[session.id] = session;
    try {
      final shown = await _channel.invokeMethod<bool>('present', {
        'id': session.id,
        'kind': kind,
        'config': config,
      });
      if (shown ?? false) {
        return session;
      }
    } on MissingPluginException {
      _unavailable = true;
    } on PlatformException catch (error) {
      debugPrint('native sheet $kind failed: $error');
    }
    _sessions.remove(session.id);
    return null;
  }

  static Future<void> _handle(MethodCall call) async {
    final arguments = call.arguments;
    if (arguments is! Map) {
      return;
    }
    final session = _sessions[arguments['id']];
    if (session == null) {
      return;
    }
    switch (call.method) {
      case 'event':
        final name = arguments['name'];
        if (name is String) {
          session._onEvent(session, name, arguments['value']);
        }
      case 'dismissed':
        _sessions.remove(session.id);
        session._finish();
    }
  }
}

/// One presented native sheet.
class NativeSheetSession {
  NativeSheetSession._(this.id, this._onEvent);

  final int id;
  final NativeSheetEventHandler _onEvent;
  final Completer<void> _closed = Completer<void>();

  bool get isClosed => _closed.isCompleted;

  /// Completes once UIKit has dismissed the sheet, however it was closed.
  Future<void> get closed => _closed.future;

  Future<void> update(Map<String, Object?> config) async {
    if (isClosed) {
      return;
    }
    try {
      await NativeSheet._channel
          .invokeMethod<void>('update', {'id': id, 'config': config});
    } on PlatformException {
      // The sheet is already gone.
    }
  }

  /// Dismisses the sheet; [closed] completes when the animation ends.
  Future<void> dismiss() async {
    if (isClosed) {
      return;
    }
    try {
      await NativeSheet._channel.invokeMethod<void>('dismiss', {'id': id});
    } on PlatformException {
      _finish();
    }
    return closed;
  }

  void _finish() {
    if (!_closed.isCompleted) {
      _closed.complete();
    }
  }
}
