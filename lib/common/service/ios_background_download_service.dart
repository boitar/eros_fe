import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:eros_fe/generated/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundDownloadTaskItem {
  const BackgroundDownloadTaskItem({
    required this.gid,
    required this.title,
    required this.fileCount,
    required this.completedCount,
  });

  final int gid;
  final String title;
  final int fileCount;
  final int completedCount;
}

enum BackgroundSessionEndReason {
  completed,
  userPaused,
  userRemoved,
  failed,
  disabled,
}

enum IosBackgroundDownloadMode {
  idle,
  continuedProcessing,
  silentAudio,
  gracePeriod;

  static IosBackgroundDownloadMode fromWire(String? value) {
    switch (value) {
      case 'continued_processing':
        return IosBackgroundDownloadMode.continuedProcessing;
      case 'silent_audio':
        return IosBackgroundDownloadMode.silentAudio;
      case 'grace_period':
        return IosBackgroundDownloadMode.gracePeriod;
      default:
        return IosBackgroundDownloadMode.idle;
    }
  }
}

class IosBackgroundDownloadStatus {
  const IosBackgroundDownloadStatus({
    this.isLiveContainer = false,
    this.supportsContinuedProcessing = false,
    this.activeMode = IosBackgroundDownloadMode.idle,
    this.isSessionActive = false,
    this.notificationAuthorized,
  });

  factory IosBackgroundDownloadStatus.fromMap(Map<Object?, Object?> map) {
    return IosBackgroundDownloadStatus(
      isLiveContainer: map['isLiveContainer'] as bool? ?? false,
      supportsContinuedProcessing:
          map['supportsContinuedProcessing'] as bool? ?? false,
      activeMode: IosBackgroundDownloadMode.fromWire(
        map['activeMode'] as String?,
      ),
      isSessionActive: map['isSessionActive'] as bool? ?? false,
      notificationAuthorized: map['notificationAuthorized'] as bool?,
    );
  }

  final bool isLiveContainer;
  final bool supportsContinuedProcessing;
  final IosBackgroundDownloadMode activeMode;
  final bool isSessionActive;
  final bool? notificationAuthorized;
}

class BackgroundDownloadProgressSnapshot {
  const BackgroundDownloadProgressSnapshot({
    required this.activeGalleryCount,
    required this.completedPages,
    required this.totalPages,
    required this.completedUnits,
    required this.totalUnits,
    required this.title,
    required this.subtitle,
  });

  final int activeGalleryCount;
  final int completedPages;
  final int totalPages;
  final int completedUnits;
  final int totalUnits;
  final String title;
  final String subtitle;
}

class BackgroundDownloadStrings {
  const BackgroundDownloadStrings({
    required this.downloadingGalleries,
    required this.progressPages,
    required this.completedTitle,
    required this.completedSingleBody,
    required this.completedMultiBody,
  });

  final String Function(int count) downloadingGalleries;
  final String Function(int completed, int total) progressPages;
  final String completedTitle;
  final String Function(String title) completedSingleBody;
  final String Function(int count) completedMultiBody;

  static BackgroundDownloadStrings resolve() {
    try {
      final l10n = L10n.current;
      return BackgroundDownloadStrings(
        downloadingGalleries: l10n.ios_bg_download_multi_title,
        progressPages: l10n.ios_bg_download_progress_pages,
        completedTitle: l10n.ios_bg_download_complete_title,
        completedSingleBody: l10n.ios_bg_download_complete_single,
        completedMultiBody: l10n.ios_bg_download_complete_multi,
      );
    } on Object {
      return BackgroundDownloadStrings(
        downloadingGalleries: (count) => 'Downloading $count galleries',
        progressPages: (completed, total) => '$completed/$total pages',
        completedTitle: 'Download complete',
        completedSingleBody: (title) => '$title finished downloading',
        completedMultiBody: (count) => '$count galleries finished downloading',
      );
    }
  }
}

abstract class IosBackgroundDownloadBridge {
  Future<IosBackgroundDownloadStatus> getStatus();

  Future<bool> requestNotificationPermission();

  Future<IosBackgroundDownloadStatus?> startSession({
    required String title,
    required String subtitle,
    required int completedUnits,
    required int totalUnits,
    required bool allowSilentAudioKeepAlive,
    required bool requestNotificationPermission,
    required bool userInitiated,
  });

  Future<void> updateProgress({
    required String title,
    required String subtitle,
    required int completedUnits,
    required int totalUnits,
  });

  Future<void> finishSession({
    required bool success,
    String? notifyTitle,
    String? notifyBody,
    bool onlyNotifyInBackground = true,
  });

  Future<void> acknowledgeExpiration({int? sessionToken});

  Stream<Map<Object?, Object?>> get events;
}

class MethodChannelIosBackgroundDownloadBridge
    implements IosBackgroundDownloadBridge {
  MethodChannelIosBackgroundDownloadBridge();

  static const MethodChannel _methodChannel =
      MethodChannel('eros/background-download');
  static const EventChannel _eventChannel =
      EventChannel('eros/background-download/events');

  @override
  Future<IosBackgroundDownloadStatus> getStatus() async {
    try {
      final raw =
          await _methodChannel.invokeMapMethod<Object?, Object?>('getStatus');
      if (raw == null) {
        return const IosBackgroundDownloadStatus();
      }
      return IosBackgroundDownloadStatus.fromMap(raw);
    } on MissingPluginException {
      return const IosBackgroundDownloadStatus();
    } on PlatformException catch (e) {
      debugPrint('iOS background download getStatus failed: $e');
      return const IosBackgroundDownloadStatus();
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      final granted = await _methodChannel
          .invokeMethod<bool>('requestNotificationPermission');
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('iOS notification permission request failed: $e');
      return false;
    }
  }

  @override
  Future<IosBackgroundDownloadStatus?> startSession({
    required String title,
    required String subtitle,
    required int completedUnits,
    required int totalUnits,
    required bool allowSilentAudioKeepAlive,
    required bool requestNotificationPermission,
    required bool userInitiated,
  }) async {
    try {
      final raw = await _methodChannel.invokeMapMethod<Object?, Object?>(
        'startSession',
        <String, Object?>{
          'title': title,
          'subtitle': subtitle,
          'completedUnits': completedUnits,
          'totalUnits': totalUnits,
          'allowSilentAudioKeepAlive': allowSilentAudioKeepAlive,
          'requestNotificationPermission': requestNotificationPermission,
          'userInitiated': userInitiated,
        },
      );
      if (raw == null) {
        return null;
      }
      return IosBackgroundDownloadStatus.fromMap(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('iOS background download startSession failed: $e');
      return null;
    }
  }

  @override
  Future<void> updateProgress({
    required String title,
    required String subtitle,
    required int completedUnits,
    required int totalUnits,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'updateProgress',
        <String, Object?>{
          'title': title,
          'subtitle': subtitle,
          'completedUnits': completedUnits,
          'totalUnits': totalUnits,
        },
      );
    } on MissingPluginException {
      // Non-iOS or test environment.
    } on PlatformException catch (e) {
      debugPrint('iOS background download updateProgress failed: $e');
    }
  }

  @override
  Future<void> finishSession({
    required bool success,
    String? notifyTitle,
    String? notifyBody,
    bool onlyNotifyInBackground = true,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'finishSession',
        <String, Object?>{
          'success': success,
          'notifyTitle': notifyTitle,
          'notifyBody': notifyBody,
          'onlyNotifyInBackground': onlyNotifyInBackground,
        },
      );
    } on MissingPluginException {
      // Non-iOS or test environment.
    } on PlatformException catch (e) {
      debugPrint('iOS background download finishSession failed: $e');
    }
  }

  @override
  Future<void> acknowledgeExpiration({int? sessionToken}) async {
    try {
      await _methodChannel.invokeMethod<void>(
        'acknowledgeExpiration',
        sessionToken == null ? null : <String, Object?>{'sessionToken': sessionToken},
      );
    } on MissingPluginException {
      // Non-iOS or test environment.
    } on PlatformException catch (e) {
      debugPrint('iOS background download acknowledgeExpiration failed: $e');
    }
  }

  @override
  Stream<Map<Object?, Object?>> get events => _eventChannel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .cast<Map<Object?, Object?>>();
}

typedef BackgroundExpirationCallback = Future<void> Function(String reason);

enum _SessionLifecycleState { idle, starting, active }

class IosBackgroundDownloadService {
  IosBackgroundDownloadService({
    IosBackgroundDownloadBridge? bridge,
    bool? isSupportedPlatform,
    this.throttleInterval = const Duration(milliseconds: 600),
    this.startRetryCooldown = const Duration(seconds: 2),
    DateTime Function()? clock,
    BackgroundDownloadStrings Function()? stringsResolver,
  })  : _bridge = bridge ?? MethodChannelIosBackgroundDownloadBridge(),
        isSupportedPlatform = isSupportedPlatform ?? Platform.isIOS,
        _clock = clock ?? DateTime.now,
        _stringsResolver = stringsResolver ?? BackgroundDownloadStrings.resolve;

  static const int _unitsPerPage = 100;
  static const int _maxInFlightBonusPerPage = 90;
  static const int _bytesPerUnitStep = 64 * 1024;
  static const int _maxTitleLength = 42;
  static const int _maxStartRetries = 3;

  final IosBackgroundDownloadBridge _bridge;
  final bool isSupportedPlatform;
  final Duration throttleInterval;
  final Duration startRetryCooldown;
  final DateTime Function() _clock;
  final BackgroundDownloadStrings Function() _stringsResolver;

  StreamSubscription<Map<Object?, Object?>>? _eventSubscription;
  BackgroundExpirationCallback? _onExpired;
  void Function(IosBackgroundDownloadStatus status)? _onStatusChanged;

  IosBackgroundDownloadStatus _status = const IosBackgroundDownloadStatus();
  IosBackgroundDownloadStatus get status => _status;

  _SessionLifecycleState _sessionState = _SessionLifecycleState.idle;
  bool get isSessionActive => _sessionState == _SessionLifecycleState.active;

  int _sessionEpoch = 0;
  int _expirationEpoch = 0;
  int _consecutiveStartFailures = 0;
  DateTime? _lastStartFailureAt;

  DateTime? _lastProgressSentAt;
  int _lastSentCompletedPages = -1;
  int _lastSentActiveCount = -1;
  int _lastSentTotalUnits = -1;
  int _lastSentCompletedUnits = -1;
  String _lastSentTitle = '';
  String _lastSentSubtitle = '';

  final Set<int> _sessionTrackedGids = <int>{};
  final Map<int, String> _completedTitlesInSession = <int, String>{};
  final Map<int, int> _completedPagesInSession = <int, int>{};

  Future<void> _syncChain = Future<void>.value();

  void attach({
    required BackgroundExpirationCallback onExpired,
    void Function(IosBackgroundDownloadStatus status)? onStatusChanged,
  }) {
    _onExpired = onExpired;
    _onStatusChanged = onStatusChanged;
    if (!isSupportedPlatform || _eventSubscription != null) {
      return;
    }
    _eventSubscription = _bridge.events.listen(
      _handleNativeEvent,
      onError: (Object error) {
        debugPrint('iOS background download event stream error: $error');
      },
    );
  }

  Future<IosBackgroundDownloadStatus> refreshStatus() async {
    if (!isSupportedPlatform) {
      return _status;
    }
    _status = await _bridge.getStatus();
    _onStatusChanged?.call(_status);
    return _status;
  }

  Future<bool> requestNotificationPermission() async {
    if (!isSupportedPlatform) {
      return false;
    }
    final granted = await _bridge.requestNotificationPermission();
    await refreshStatus();
    return granted;
  }

  /// Atomically records a completed gallery for the active session so concurrent
  /// completions are never lost or leaked into a later session.
  void recordGalleryCompleted({
    required int gid,
    required String title,
    required int fileCount,
  }) {
    if (!isSupportedPlatform || _sessionState == _SessionLifecycleState.idle) {
      return;
    }
    if (!_sessionTrackedGids.contains(gid)) {
      return;
    }
    final normalized = title.trim();
    if (normalized.isNotEmpty) {
      _completedTitlesInSession[gid] = normalized;
    }
    _completedPagesInSession[gid] = math.max(fileCount, 0);
  }

  Future<void> syncDownloadState({
    required List<BackgroundDownloadTaskItem> activeTasks,
    required Map<String, int> downloadCounts,
    required Map<int, String> downloadSpeeds,
    required bool backgroundDownloadEnabled,
    required bool completionNotifyEnabled,
    bool userInitiated = false,
    BackgroundSessionEndReason endReason = BackgroundSessionEndReason.completed,
    int? justCompletedGid,
    String? justCompletedTitle,
    int? justCompletedFileCount,
  }) {
    if (!isSupportedPlatform) {
      return Future<void>.value();
    }
    final queuedExpirationEpoch = _expirationEpoch;
    // Serialize calls so concurrent completion callbacks cannot race and leave
    // stale completion entries for the next session.
    _syncChain = _syncChain.then((_) {
      if (queuedExpirationEpoch != _expirationEpoch) {
        return Future<void>.value();
      }
      return _syncDownloadStateSerialized(
        activeTasks: activeTasks,
        downloadCounts: downloadCounts,
        downloadSpeeds: downloadSpeeds,
        backgroundDownloadEnabled: backgroundDownloadEnabled,
        completionNotifyEnabled: completionNotifyEnabled,
        userInitiated: userInitiated,
        endReason: endReason,
        justCompletedGid: justCompletedGid,
        justCompletedTitle: justCompletedTitle,
        justCompletedFileCount: justCompletedFileCount,
      );
    });
    return _syncChain;
  }

  Future<void> _syncDownloadStateSerialized({
    required List<BackgroundDownloadTaskItem> activeTasks,
    required Map<String, int> downloadCounts,
    required Map<int, String> downloadSpeeds,
    required bool backgroundDownloadEnabled,
    required bool completionNotifyEnabled,
    required bool userInitiated,
    required BackgroundSessionEndReason endReason,
    int? justCompletedGid,
    String? justCompletedTitle,
    int? justCompletedFileCount,
  }) async {
    if (justCompletedGid != null &&
        justCompletedTitle != null &&
        _sessionState != _SessionLifecycleState.idle) {
      recordGalleryCompleted(
        gid: justCompletedGid,
        title: justCompletedTitle,
        fileCount: justCompletedFileCount ?? 0,
      );
    }

    if (!backgroundDownloadEnabled) {
      if (_sessionState != _SessionLifecycleState.idle) {
        await _endSession(
          success: false,
          completionNotifyEnabled: false,
          endReason: BackgroundSessionEndReason.disabled,
        );
      }
      return;
    }

    if (activeTasks.isEmpty) {
      if (_sessionState != _SessionLifecycleState.idle) {
        await _endSession(
          success: endReason == BackgroundSessionEndReason.completed &&
              _completedTitlesInSession.isNotEmpty,
          completionNotifyEnabled: completionNotifyEnabled,
          endReason: endReason,
        );
      }
      return;
    }

    for (final task in activeTasks) {
      _sessionTrackedGids.add(task.gid);
    }

    final completedSessionPages = _completedPagesInSession.values
        .fold<int>(0, (sum, count) => sum + count);

    final snapshot = buildSnapshot(
      activeTasks: activeTasks,
      downloadCounts: downloadCounts,
      downloadSpeeds: downloadSpeeds,
      strings: _stringsResolver(),
      priorCompletedPages: completedSessionPages,
    );

    if (_sessionState == _SessionLifecycleState.idle) {
      final now = _clock();
      if (_consecutiveStartFailures >= _maxStartRetries &&
          _lastStartFailureAt != null &&
          now.difference(_lastStartFailureAt!) < startRetryCooldown) {
        return;
      }

      _sessionState = _SessionLifecycleState.starting;
      final epoch = ++_sessionEpoch;
      final updatedStatus = await _bridge.startSession(
        title: snapshot.title,
        subtitle: snapshot.subtitle,
        completedUnits: snapshot.completedUnits,
        totalUnits: snapshot.totalUnits,
        allowSilentAudioKeepAlive: true,
        requestNotificationPermission: completionNotifyEnabled,
        userInitiated: userInitiated,
      );

      // Ignore stale result if the session ended/expired while starting.
      if (epoch != _sessionEpoch ||
          _sessionState != _SessionLifecycleState.starting) {
        return;
      }

      if (updatedStatus == null) {
        _sessionState = _SessionLifecycleState.idle;
        _consecutiveStartFailures++;
        _lastStartFailureAt = _clock();
        return;
      }

      _consecutiveStartFailures = 0;
      _lastStartFailureAt = null;
      _sessionState = _SessionLifecycleState.active;
      _status = updatedStatus;
      _recordSentSnapshot(snapshot);
      _onStatusChanged?.call(_status);
      return;
    }

    if (_sessionState != _SessionLifecycleState.active) {
      return;
    }

    final now = _clock();
    final majorChange = snapshot.completedPages != _lastSentCompletedPages ||
        snapshot.activeGalleryCount != _lastSentActiveCount ||
        snapshot.totalUnits != _lastSentTotalUnits;
    final textOrProgressChanged = snapshot.completedUnits != _lastSentCompletedUnits ||
        snapshot.title != _lastSentTitle ||
        snapshot.subtitle != _lastSentSubtitle;
    final throttleElapsed = _lastProgressSentAt == null ||
        now.difference(_lastProgressSentAt!) >= throttleInterval;

    if (!majorChange && (!throttleElapsed || !textOrProgressChanged)) {
      return;
    }

    _recordSentSnapshot(snapshot);
    await _bridge.updateProgress(
      title: snapshot.title,
      subtitle: snapshot.subtitle,
      completedUnits: snapshot.completedUnits,
      totalUnits: snapshot.totalUnits,
    );
  }

  Future<void> _endSession({
    required bool success,
    required bool completionNotifyEnabled,
    required BackgroundSessionEndReason endReason,
  }) async {
    _sessionEpoch++;
    _sessionState = _SessionLifecycleState.idle;
    _consecutiveStartFailures = 0;
    _lastStartFailureAt = null;
    _resetSentSnapshot();

    final completedTitles = _completedTitlesInSession.values.toList();
    _completedTitlesInSession.clear();
    _completedPagesInSession.clear();
    _sessionTrackedGids.clear();

    String? notifyTitle;
    String? notifyBody;
    final allowNotify = completionNotifyEnabled &&
        endReason == BackgroundSessionEndReason.completed &&
        completedTitles.isNotEmpty;
    if (allowNotify) {
      final strings = _stringsResolver();
      notifyTitle = strings.completedTitle;
      notifyBody = completedTitles.length == 1
          ? strings.completedSingleBody(_truncate(completedTitles.first))
          : strings.completedMultiBody(completedTitles.length);
    }

    await _bridge.finishSession(
      success: success,
      notifyTitle: notifyTitle,
      notifyBody: notifyBody,
      onlyNotifyInBackground: true,
    );
  }

  void _recordSentSnapshot(BackgroundDownloadProgressSnapshot snapshot) {
    _lastProgressSentAt = _clock();
    _lastSentCompletedPages = snapshot.completedPages;
    _lastSentActiveCount = snapshot.activeGalleryCount;
    _lastSentTotalUnits = snapshot.totalUnits;
    _lastSentCompletedUnits = snapshot.completedUnits;
    _lastSentTitle = snapshot.title;
    _lastSentSubtitle = snapshot.subtitle;
  }

  void _resetSentSnapshot() {
    _lastProgressSentAt = null;
    _lastSentCompletedPages = -1;
    _lastSentActiveCount = -1;
    _lastSentTotalUnits = -1;
    _lastSentCompletedUnits = -1;
    _lastSentTitle = '';
    _lastSentSubtitle = '';
  }

  Future<void> _handleNativeEvent(Map<Object?, Object?> event) async {
    final type = event['type'] as String?;
    if (type == 'status') {
      _status = IosBackgroundDownloadStatus.fromMap(event);
      _onStatusChanged?.call(_status);
      return;
    }
    if (type == 'expired') {
      final reason = event['reason'] as String? ?? 'continued_task_expired';
      final sessionToken = (event['sessionToken'] as num?)?.toInt();
      _expirationEpoch++;
      _sessionEpoch++;
      _sessionState = _SessionLifecycleState.idle;
      _resetSentSnapshot();
      _completedTitlesInSession.clear();
      _completedPagesInSession.clear();
      _sessionTrackedGids.clear();
      try {
        await _onExpired?.call(reason);
      } finally {
        await _bridge.acknowledgeExpiration(sessionToken: sessionToken);
      }
    }
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _onExpired = null;
    _onStatusChanged = null;
  }

  static BackgroundDownloadProgressSnapshot buildSnapshot({
    required List<BackgroundDownloadTaskItem> activeTasks,
    required Map<String, int> downloadCounts,
    required Map<int, String> downloadSpeeds,
    required BackgroundDownloadStrings strings,
    int priorCompletedPages = 0,
  }) {
    var totalPages = math.max(priorCompletedPages, 0);
    var completedPages = math.max(priorCompletedPages, 0);
    var inFlightBonus = 0;
    final activeGids = <int>{};

    for (final task in activeTasks) {
      activeGids.add(task.gid);
      final fileCount = math.max(task.fileCount, 0);
      final done = math.min(math.max(task.completedCount, 0), fileCount);
      totalPages += fileCount;
      completedPages += done;
    }

    final remainingPages = math.max(totalPages - completedPages, 0);
    if (remainingPages > 0) {
      var activeInFlightBytes = 0;
      for (final entry in downloadCounts.entries) {
        final sep = entry.key.indexOf('_');
        if (sep <= 0) {
          continue;
        }
        final gid = int.tryParse(entry.key.substring(0, sep));
        if (gid != null && activeGids.contains(gid) && entry.value > 0) {
          activeInFlightBytes += entry.value;
        }
      }
      if (activeInFlightBytes > 0) {
        final maxBonus = remainingPages * _maxInFlightBonusPerPage;
        final computedBonus = math.max(1, activeInFlightBytes ~/ _bytesPerUnitStep);
        inFlightBonus = math.min(computedBonus, maxBonus);
      }
    }

    final totalUnits = math.max(totalPages * _unitsPerPage, 1);
    final completedUnits = math.min(
      completedPages * _unitsPerPage + inFlightBonus,
      totalPages > 0 && completedPages < totalPages
          ? totalUnits - 1
          : totalUnits,
    );

    final String title;
    if (activeTasks.length == 1) {
      title = _truncate(activeTasks.first.title);
    } else {
      title = strings.downloadingGalleries(activeTasks.length);
    }

    final speedParts = <String>[];
    for (final task in activeTasks) {
      final speed = downloadSpeeds[task.gid]?.trim();
      if (speed != null && speed.isNotEmpty && speed != '0B' && speed != '0 B') {
        speedParts.add('$speed/s');
      }
    }

    final progressText = strings.progressPages(completedPages, totalPages);
    final subtitle = speedParts.isNotEmpty
        ? '$progressText · ${speedParts.first}'
        : progressText;

    return BackgroundDownloadProgressSnapshot(
      activeGalleryCount: activeTasks.length,
      completedPages: completedPages,
      totalPages: totalPages,
      completedUnits: completedUnits,
      totalUnits: totalUnits,
      title: title,
      subtitle: subtitle,
    );
  }

  static String _truncate(String input) {
    final normalized = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= _maxTitleLength) {
      return normalized;
    }
    return '${normalized.substring(0, _maxTitleLength - 1)}…';
  }
}
