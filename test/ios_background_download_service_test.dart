import 'dart:async';

import 'package:eros_fe/common/service/ios_background_download_service.dart';
import 'package:eros_fe/models/download_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiver/core.dart';

class _FakeBridge implements IosBackgroundDownloadBridge {
  final StreamController<Map<Object?, Object?>> eventController =
      StreamController<Map<Object?, Object?>>.broadcast();

  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];
  IosBackgroundDownloadStatus? nextStatus = const IosBackgroundDownloadStatus(
    isLiveContainer: false,
    supportsContinuedProcessing: true,
    activeMode: IosBackgroundDownloadMode.continuedProcessing,
    isSessionActive: true,
  );
  Completer<IosBackgroundDownloadStatus?>? startSessionGate;
  bool notificationPermissionGranted = true;
  final List<int?> acknowledgedTokens = <int?>[];

  @override
  Stream<Map<Object?, Object?>> get events => eventController.stream;

  @override
  Future<IosBackgroundDownloadStatus> getStatus() async =>
      nextStatus ?? const IosBackgroundDownloadStatus();

  @override
  Future<bool> requestNotificationPermission() async {
    calls.add({'method': 'requestNotificationPermission'});
    return notificationPermissionGranted;
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
    calls.add({
      'method': 'startSession',
      'title': title,
      'subtitle': subtitle,
      'completedUnits': completedUnits,
      'totalUnits': totalUnits,
      'allowSilentAudioKeepAlive': allowSilentAudioKeepAlive,
      'requestNotificationPermission': requestNotificationPermission,
      'userInitiated': userInitiated,
    });
    if (startSessionGate != null) {
      return startSessionGate!.future;
    }
    return nextStatus;
  }

  @override
  Future<void> updateProgress({
    required String title,
    required String subtitle,
    required int completedUnits,
    required int totalUnits,
  }) async {
    calls.add({
      'method': 'updateProgress',
      'title': title,
      'subtitle': subtitle,
      'completedUnits': completedUnits,
      'totalUnits': totalUnits,
    });
  }

  @override
  Future<void> finishSession({
    required bool success,
    String? notifyTitle,
    String? notifyBody,
    bool onlyNotifyInBackground = true,
  }) async {
    calls.add({
      'method': 'finishSession',
      'success': success,
      'notifyTitle': notifyTitle,
      'notifyBody': notifyBody,
      'onlyNotifyInBackground': onlyNotifyInBackground,
    });
  }

  @override
  Future<void> acknowledgeExpiration({int? sessionToken}) async {
    acknowledgedTokens.add(sessionToken);
    calls.add({
      'method': 'acknowledgeExpiration',
      'sessionToken': sessionToken,
    });
  }

  Future<void> close() => eventController.close();
}

BackgroundDownloadTaskItem _task({
  required int gid,
  required String title,
  required int fileCount,
  int completCount = 0,
}) {
  return BackgroundDownloadTaskItem(
    gid: gid,
    title: title,
    fileCount: fileCount,
    completedCount: completCount,
  );
}

void main() {
  late _FakeBridge bridge;
  late DateTime now;
  late IosBackgroundDownloadService service;

  final strings = BackgroundDownloadStrings(
    downloadingGalleries: (count) => 'Downloading $count galleries',
    progressPages: (completed, total) => '$completed/$total pages',
    completedTitle: 'Download complete',
    completedSingleBody: (title) => '$title finished downloading',
    completedMultiBody: (count) => '$count galleries finished downloading',
  );

  setUp(() {
    bridge = _FakeBridge();
    now = DateTime(2026, 11, 25, 1, 0, 0);
    service = IosBackgroundDownloadService(
      bridge: bridge,
      isSupportedPlatform: true,
      throttleInterval: const Duration(milliseconds: 600),
      startRetryCooldown: const Duration(seconds: 2),
      clock: () => now,
      stringsResolver: () => strings,
    );
  });

  tearDown(() async {
    await service.dispose();
    await bridge.close();
  });

  test('starts session on first active task and finishes with single completion notification', () async {
    await service.syncDownloadState(
      activeTasks: [_task(gid: 101, title: 'Sample Gallery', fileCount: 10, completCount: 2)],
      downloadCounts: {'101_3': 256 * 1024},
      downloadSpeeds: {101: '1.2 MB'},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      userInitiated: true,
    );

    expect(service.isSessionActive, isTrue);
    expect(bridge.calls.length, 1);
    expect(bridge.calls.first['method'], 'startSession');
    expect(bridge.calls.first['title'], 'Sample Gallery');
    expect(bridge.calls.first['subtitle'], '2/10 pages · 1.2 MB/s');
    expect(bridge.calls.first['totalUnits'], 1000);
    expect(bridge.calls.first['completedUnits'], 204);
    expect(bridge.calls.first['allowSilentAudioKeepAlive'], isTrue);
    expect(bridge.calls.first['requestNotificationPermission'], isTrue);
    expect(bridge.calls.first['userInitiated'], isTrue);

    await service.syncDownloadState(
      activeTasks: const [],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      endReason: BackgroundSessionEndReason.completed,
      justCompletedGid: 101,
      justCompletedTitle: 'Sample Gallery',
      justCompletedFileCount: 10,
    );

    expect(service.isSessionActive, isFalse);
    expect(bridge.calls.length, 2);
    expect(bridge.calls.last['method'], 'finishSession');
    expect(bridge.calls.last['success'], isTrue);
    expect(bridge.calls.last['notifyTitle'], 'Download complete');
    expect(bridge.calls.last['notifyBody'], 'Sample Gallery finished downloading');
    expect(bridge.calls.last['onlyNotifyInBackground'], isTrue);
  });

  test('keeps monotonic progress across gallery completions and aggregates multi-gallery notifications', () async {
    await service.syncDownloadState(
      activeTasks: [
        _task(gid: 1, title: 'Gallery A', fileCount: 10, completCount: 9),
        _task(gid: 2, title: 'Gallery B', fileCount: 10, completCount: 0),
      ],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      userInitiated: true,
    );

    expect(bridge.calls.first['title'], 'Downloading 2 galleries');
    expect(bridge.calls.first['completedUnits'], 900);
    expect(bridge.calls.first['totalUnits'], 2000);

    // Gallery A finishes (10/10), Gallery B still at 0/10 -> progress must advance to 10/20 (50%), NOT drop to 0/10.
    await service.syncDownloadState(
      activeTasks: [_task(gid: 2, title: 'Gallery B', fileCount: 10, completCount: 0)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      justCompletedGid: 1,
      justCompletedTitle: 'Gallery A',
      justCompletedFileCount: 10,
    );

    final midUpdate = bridge.calls.last;
    expect(midUpdate['method'], 'updateProgress');
    expect(midUpdate['title'], 'Gallery B');
    expect(midUpdate['completedUnits'], 1000);
    expect(midUpdate['totalUnits'], 2000);
    expect(midUpdate['subtitle'], '10/20 pages');

    // Duplicate completion report for gid 1 is deduplicated.
    await service.syncDownloadState(
      activeTasks: [_task(gid: 2, title: 'Gallery B', fileCount: 10, completCount: 2)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      justCompletedGid: 1,
      justCompletedTitle: 'Gallery A',
      justCompletedFileCount: 10,
    );

    // Gallery B finishes -> session completes with count 2.
    await service.syncDownloadState(
      activeTasks: const [],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      endReason: BackgroundSessionEndReason.completed,
      justCompletedGid: 2,
      justCompletedTitle: 'Gallery B',
      justCompletedFileCount: 10,
    );

    final finish = bridge.calls.last;
    expect(finish['method'], 'finishSession');
    expect(finish['success'], isTrue);
    expect(finish['notifyBody'], '2 galleries finished downloading');
  });

  test('suppresses completion notification when remaining task is manually paused or removed after an earlier completion', () async {
    await service.syncDownloadState(
      activeTasks: [
        _task(gid: 1, title: 'Gallery A', fileCount: 5, completCount: 4),
        _task(gid: 2, title: 'Gallery B', fileCount: 5, completCount: 1),
      ],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      userInitiated: true,
    );

    // Gallery A finishes while B is still active.
    await service.syncDownloadState(
      activeTasks: [_task(gid: 2, title: 'Gallery B', fileCount: 5, completCount: 1)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      justCompletedGid: 1,
      justCompletedTitle: 'Gallery A',
      justCompletedFileCount: 5,
    );

    // User manually pauses Gallery B -> session ends due to userPaused -> NO completion notification.
    await service.syncDownloadState(
      activeTasks: const [],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      endReason: BackgroundSessionEndReason.userPaused,
    );

    final finish = bridge.calls.last;
    expect(finish['method'], 'finishSession');
    expect(finish['success'], isFalse);
    expect(finish['notifyTitle'], isNull);
    expect(finish['notifyBody'], isNull);
  });

  test('concurrent dual completions are accounted in one session and do not leak into next session', () async {
    await service.syncDownloadState(
      activeTasks: [
        _task(gid: 11, title: 'First', fileCount: 3, completCount: 2),
        _task(gid: 12, title: 'Second', fileCount: 3, completCount: 2),
      ],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      userInitiated: true,
    );

    // Atomically record both completions when status transitions to complete.
    service.recordGalleryCompleted(gid: 11, title: 'First', fileCount: 3);
    service.recordGalleryCompleted(gid: 12, title: 'Second', fileCount: 3);

    // Two concurrent sync calls arrive seeing empty activeTasks.
    await Future.wait([
      service.syncDownloadState(
        activeTasks: const [],
        downloadCounts: const {},
        downloadSpeeds: const {},
        backgroundDownloadEnabled: true,
        completionNotifyEnabled: true,
        endReason: BackgroundSessionEndReason.completed,
        justCompletedGid: 11,
        justCompletedTitle: 'First',
        justCompletedFileCount: 3,
      ),
      service.syncDownloadState(
        activeTasks: const [],
        downloadCounts: const {},
        downloadSpeeds: const {},
        backgroundDownloadEnabled: true,
        completionNotifyEnabled: true,
        endReason: BackgroundSessionEndReason.completed,
        justCompletedGid: 12,
        justCompletedTitle: 'Second',
        justCompletedFileCount: 3,
      ),
    ]);

    final finishCalls = bridge.calls.where((c) => c['method'] == 'finishSession').toList();
    expect(finishCalls.length, 1);
    expect(finishCalls.first['notifyBody'], '2 galleries finished downloading');

    // Starting a new session later and pausing it must NOT inherit stale completions.
    await service.syncDownloadState(
      activeTasks: [_task(gid: 13, title: 'Third', fileCount: 4, completCount: 0)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      userInitiated: true,
    );
    await service.syncDownloadState(
      activeTasks: const [],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      endReason: BackgroundSessionEndReason.userRemoved,
    );
    expect(bridge.calls.last['notifyTitle'], isNull);
  });

  test('throttles byte/speed updates and refreshes when speed text changes after interval', () async {
    await service.syncDownloadState(
      activeTasks: [_task(gid: 5, title: 'Large Ori', fileCount: 4, completCount: 1)],
      downloadCounts: {'5_2': 64 * 1024},
      downloadSpeeds: {5: '2.0 MB'},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: false,
      userInitiated: true,
    );
    expect(bridge.calls.length, 1);

    // 200ms later: throttled.
    now = now.add(const Duration(milliseconds: 200));
    await service.syncDownloadState(
      activeTasks: [_task(gid: 5, title: 'Large Ori', fileCount: 4, completCount: 1)],
      downloadCounts: {'5_2': 64 * 1024},
      downloadSpeeds: {5: '3.5 MB'},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: false,
    );
    expect(bridge.calls.length, 1);

    // 500ms more (700ms total): speed subtitle changed -> updates even with same completedUnits.
    now = now.add(const Duration(milliseconds: 500));
    await service.syncDownloadState(
      activeTasks: [_task(gid: 5, title: 'Large Ori', fileCount: 4, completCount: 1)],
      downloadCounts: {'5_2': 64 * 1024},
      downloadSpeeds: {5: '3.5 MB'},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: false,
    );
    expect(bridge.calls.length, 2);
    expect(bridge.calls.last['subtitle'], '1/4 pages · 3.5 MB/s');

    // 100ms later: page completed -> bypasses throttle immediately.
    now = now.add(const Duration(milliseconds: 100));
    await service.syncDownloadState(
      activeTasks: [_task(gid: 5, title: 'Large Ori', fileCount: 4, completCount: 2)],
      downloadCounts: const {},
      downloadSpeeds: {5: '3.5 MB'},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: false,
    );
    expect(bridge.calls.length, 3);
    expect(bridge.calls.last['completedUnits'], 200);
  });

  test('stays idle when startSession fails and retries cleanly when bridge recovers', () async {
    bridge.nextStatus = null;

    await service.syncDownloadState(
      activeTasks: [_task(gid: 20, title: 'Retry Me', fileCount: 6, completCount: 0)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      userInitiated: false,
    );

    expect(service.isSessionActive, isFalse);
    expect(bridge.calls.length, 1);
    expect(bridge.calls.first['method'], 'startSession');
    expect(bridge.calls.first['userInitiated'], isFalse);

    // Bridge recovers -> next sync retries startSession instead of sending updateProgress.
    bridge.nextStatus = const IosBackgroundDownloadStatus(
      activeMode: IosBackgroundDownloadMode.silentAudio,
      isSessionActive: true,
    );
    await service.syncDownloadState(
      activeTasks: [_task(gid: 20, title: 'Retry Me', fileCount: 6, completCount: 1)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      userInitiated: true,
    );

    expect(service.isSessionActive, isTrue);
    expect(bridge.calls.length, 2);
    expect(bridge.calls.last['method'], 'startSession');
    expect(bridge.calls.last['userInitiated'], isTrue);
  });

  test('disabling background download stops active session immediately without notifying', () async {
    await service.syncDownloadState(
      activeTasks: [_task(gid: 7, title: 'Active', fileCount: 8, completCount: 2)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      userInitiated: true,
    );
    expect(service.isSessionActive, isTrue);

    await service.syncDownloadState(
      activeTasks: [_task(gid: 7, title: 'Active', fileCount: 8, completCount: 2)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: false,
      completionNotifyEnabled: true,
    );

    expect(service.isSessionActive, isFalse);
    expect(bridge.calls.last['method'], 'finishSession');
    expect(bridge.calls.last['notifyTitle'], isNull);
  });

  test('native expired event passes sessionToken to acknowledgeExpiration and handles in-flight pause', () async {
    final pauseGate = Completer<void>();
    final reasons = <String>[];
    service.attach(
      onExpired: (reason) async {
        reasons.add(reason);
        await pauseGate.future;
      },
    );

    await service.syncDownloadState(
      activeTasks: [_task(gid: 9, title: 'Test', fileCount: 10, completCount: 1)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      userInitiated: true,
    );

    bridge.eventController.add({
      'type': 'expired',
      'reason': 'grace_expired',
      'sessionToken': 42,
    });
    await Future<void>.delayed(Duration.zero);

    expect(reasons, ['grace_expired']);
    expect(service.isSessionActive, isFalse);
    // Must not acknowledge before the pause callback finishes.
    expect(bridge.acknowledgedTokens, isEmpty);

    pauseGate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(bridge.acknowledgedTokens, [42]);
  });

  test('stale queued sync snapshots from before expiration cannot reopen session', () async {
    final startGate = Completer<IosBackgroundDownloadStatus?>();
    bridge.startSessionGate = startGate;

    // 1. Kick off session start (in-flight) and queue a follow-up sync snapshot.
    final firstSync = service.syncDownloadState(
      activeTasks: [_task(gid: 30, title: 'InFlight', fileCount: 10, completCount: 1)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
      userInitiated: true,
    );
    final staleQueuedSync = service.syncDownloadState(
      activeTasks: [_task(gid: 30, title: 'InFlight', fileCount: 10, completCount: 2)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
    );

    // 2. Native expiration fires while startSession is still pending.
    service.attach(onExpired: (_) async {});
    bridge.eventController.add({
      'type': 'expired',
      'reason': 'grace_expired',
      'sessionToken': 7,
    });
    await Future<void>.delayed(Duration.zero);

    // 3. Complete the old startSession call -> stale queued sync MUST be dropped, NOT reopen a session.
    startGate.complete(const IosBackgroundDownloadStatus(
      activeMode: IosBackgroundDownloadMode.gracePeriod,
      isSessionActive: true,
    ));
    await Future.wait([firstSync, staleQueuedSync]);

    expect(service.isSessionActive, isFalse);
    expect(
      bridge.calls.where((c) => c['method'] == 'startSession').length,
      1,
    );
    expect(
      bridge.calls.where((c) => c['method'] == 'updateProgress'),
      isEmpty,
    );
    expect(bridge.acknowledgedTokens, [7]);
  });

  test('native status event updates live container and active mode status', () async {
    IosBackgroundDownloadStatus? observed;
    service.attach(
      onExpired: (_) async {},
      onStatusChanged: (status) => observed = status,
    );

    bridge.eventController.add({
      'type': 'status',
      'isLiveContainer': true,
      'supportsContinuedProcessing': true,
      'activeMode': 'silent_audio',
      'isSessionActive': true,
    });
    await Future<void>.delayed(Duration.zero);

    expect(observed?.isLiveContainer, isTrue);
    expect(observed?.supportsContinuedProcessing, isTrue);
    expect(observed?.activeMode, IosBackgroundDownloadMode.silentAudio);
    expect(service.status.activeMode, IosBackgroundDownloadMode.silentAudio);
  });

  test('non-iOS platform stays completely no-op', () async {
    final nonIos = IosBackgroundDownloadService(
      bridge: bridge,
      isSupportedPlatform: false,
      stringsResolver: () => strings,
    );

    await nonIos.syncDownloadState(
      activeTasks: [_task(gid: 1, title: 'Desktop', fileCount: 5, completCount: 1)],
      downloadCounts: const {},
      downloadSpeeds: const {},
      backgroundDownloadEnabled: true,
      completionNotifyEnabled: true,
    );

    expect(nonIos.isSessionActive, isFalse);
    expect(bridge.calls, isEmpty);
    await nonIos.dispose();
  });

  test('DownloadConfig persists iOS background download settings cleanly', () {
    const config = DownloadConfig(
      iosBackgroundDownload: true,
      iosBackgroundDownloadNotify: false,
    );

    final decoded = DownloadConfig.fromJson(config.toJson());
    expect(decoded.iosBackgroundDownload, isTrue);
    expect(decoded.iosBackgroundDownloadNotify, isFalse);
    expect(decoded, config);

    final updated = decoded.copyWith(
      // ignore: deprecated_member_use
      iosBackgroundDownload: Optional.of(false),
      // ignore: deprecated_member_use
      iosBackgroundDownloadNotify: Optional.of(true),
    );
    expect(updated.iosBackgroundDownload, isFalse);
    expect(updated.iosBackgroundDownloadNotify, isTrue);
    expect(updated.clone(), updated);
  });
}
