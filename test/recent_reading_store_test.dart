import 'package:eros_fe/common/controller/recent_reading_store.dart';
import 'package:flutter_test/flutter_test.dart';

RecentReadingEntry _entry(String id, int time, {String? gid, int index = 0}) =>
    RecentReadingEntry(
      id: id,
      gid: gid ?? id,
      time: time,
      index: index,
      title: 'Work $id',
    );

void main() {
  test(
    'records first page, de-duplicates, sorts and keeps five entries',
    () async {
      final writes = <String>[];
      final store = RecentReadingStore(
        write: (value) async => writes.add(value),
      );

      for (var i = 0; i < 6; i++) {
        final id = 'gid:$i';
        expect(
          store.record(
            store.ticket(id),
            _entry(id, i + 1, index: i == 0 ? 0 : i),
          ),
          isTrue,
        );
      }
      await store.pendingWrites;

      expect(store.recent, hasLength(5));
      expect(store.recent.map((entry) => entry.id), [
        'gid:5',
        'gid:4',
        'gid:3',
        'gid:2',
        'gid:1',
      ]);
      expect(store.recent.every((entry) => entry.index >= 0), isTrue);
      expect(writes, isNotEmpty);

      expect(
        store.record(store.ticket('gid:1'), _entry('gid:1', 20, index: 8)),
        isTrue,
      );
      expect(store.recent.first.id, 'gid:1');
      expect(store.recent.first.index, 8);
    },
  );

  test('clear invalidates a pending presentation event', () async {
    final store = RecentReadingStore();
    final ticket = store.ticket('gid:late');
    await store.clear();

    expect(store.record(ticket, _entry('gid:late', 1, index: 0)), isFalse);
    expect(store.recent, isEmpty);
  });

  test('remove invalidates a pending event for the removed gallery', () async {
    final store = RecentReadingStore();
    final ticket = store.ticket('gid:removed');
    expect(
      store.record(ticket, _entry('gid:removed', 1, gid: 'removed')),
      isTrue,
    );
    await store.remove('removed');

    expect(store.recent, isEmpty);
    expect(
      store.record(ticket, _entry('gid:removed', 2, gid: 'removed', index: 1)),
      isFalse,
    );
  });

  test(
    'persisted entries reload without importing unrelated progress',
    () async {
      String? persisted;
      final first = RecentReadingStore(
        write: (value) async => persisted = value,
      );
      expect(
        first.record(
          first.ticket('download:/book'),
          _entry('download:/book', 4),
        ),
        isTrue,
      );
      await first.pendingWrites;

      final restored = RecentReadingStore(read: () => persisted);
      restored.load();
      expect(restored.recent.single.id, 'download:/book');
      expect(restored.recent.single.index, 0);
    },
  );
}
