import 'dart:async';

import 'package:eros_fe/common/controller/download/download_monitor.dart';
import 'package:eros_fe/common/controller/download_state.dart';
import 'package:eros_fe/component/quene_task/quene_task.dart';
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
}
