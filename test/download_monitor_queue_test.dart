import 'dart:async';

import 'package:eros_fe/common/controller/download/download_monitor.dart';
import 'package:eros_fe/common/controller/download/download_task_manager.dart'
    as download_tasks;
import 'package:eros_fe/common/controller/download/gallery_slot_manager.dart';
import 'package:eros_fe/common/controller/download_state.dart';
import 'package:eros_fe/component/quene_task/quene_task.dart';
import 'package:eros_fe/store/db/entity/gallery_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clearing one gallery monitor removes all of its progress state', () {
    final state = DownloadState();
    final monitor = DownloadMonitor(state);
    state.downloadCounts
      ..['12_1'] = 100
      ..['12_2'] = 200
      ..['13_1'] = 300;
    state.lastCounts[12] = [0, 300];
    state.lastCounts[13] = [0, 300];
    state.downloadSpeeds[12] = '100B/s';
    state.noSpeed[12] = 2;
    state.chkTimers[12] = Timer(const Duration(hours: 1), () {});

    monitor.cancelDownloadStateChkTimer(gid: 12);

    expect(state.downloadCounts.keys, contains('13_1'));
    expect(state.downloadCounts.keys, isNot(contains('12_1')));
    expect(state.downloadCounts.keys, isNot(contains('12_2')));
    expect(state.lastCounts, isNot(contains(12)));
    expect(state.downloadSpeeds, isNot(contains(12)));
    expect(state.noSpeed, isNot(contains(12)));
  });

  test('a new download attempt starts speed history at zero', () {
    final state = DownloadState();
    final monitor = DownloadMonitor(state);
    state.downloadCounts['12_1'] = 2048;
    monitor.updateDownloadSpeed(12);

    monitor.cancelDownloadStateChkTimer(gid: 12);
    state.downloadCounts['12_1'] = 64;
    monitor.updateDownloadSpeed(12);

    expect(state.lastCounts[12], [0, 64]);
    expect(state.downloadSpeeds[12], '32.00 B');
  });

  test(
      'queue awaits async work, continues after an error, and skips cancelled work',
      () async {
    final queue = QueueTask();
    final events = <String>[];
    final secondDone = Completer<void>();
    final cancelledToken = TaskCancelToken()..cancel();

    queue.add(({name}) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      events.add('first-done');
      throw StateError('expected test error');
    });
    queue.add(({name}) {
      events.add('second-done');
      secondDone.complete();
    });
    queue.add(({name}) {
      events.add('cancelled-ran');
    }, taskCancelToken: cancelledToken);

    await secondDone.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(events, ['first-done', 'second-done']);
  });

  test('pausing a waiting gallery removes it before the next slot is opened',
      () async {
    final started = <int>[];
    final slotManager = GallerySlotManager(
      maxConcurrentGalleries: 1,
      onStartGallery: (task) => started.add(task.gid),
      onUpdateStatus: (gid, status) async => null,
    );

    GalleryTask task(int gid) => GalleryTask(
          gid: gid,
          token: 'token-$gid',
          title: 'task-$gid',
          dirPath: '/tmp/task-$gid',
          fileCount: 1,
          status: download_tasks.TaskStatus.enqueued.value,
        );

    slotManager.addGalleryTask(task(1));
    slotManager.addGalleryTask(task(2));

    expect(slotManager.isGalleryActive(1), isTrue);
    expect(slotManager.isGalleryWaiting(2), isTrue);

    await slotManager.onGalleryStatusChanged(
      2,
      download_tasks.TaskStatus.paused,
    );
    expect(slotManager.isGalleryWaiting(2), isFalse);

    await slotManager.onGalleryStatusChanged(
      1,
      download_tasks.TaskStatus.failed,
    );

    expect(started, [1]);
    expect(slotManager.isGalleryActive(2), isFalse);
  });
}
