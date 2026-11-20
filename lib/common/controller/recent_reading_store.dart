import 'dart:async';
import 'dart:convert';

import 'package:eros_fe/store/hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// A local projection of successful reader presentations. Browsing metadata,
/// progress-cache timestamps and remote progress never create entries here.
@immutable
class RecentReadingEntry {
  const RecentReadingEntry({
    required this.id,
    required this.time,
    required this.index,
    this.gid,
    this.source = 'gallery',
    this.sourcePath,
    this.url,
    this.token,
    this.title,
    this.cover,
    this.total,
  });
  final String id, source;
  final String? gid, sourcePath, url, token, title, cover;
  final int time, index;
  final int? total;

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'index': index,
    'gid': gid,
    'source': source,
    'sourcePath': sourcePath,
    'url': url,
    'token': token,
    'title': title,
    'cover': cover,
    'total': total,
  };
  static RecentReadingEntry? parse(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        value['id'] == '' ||
        value['time'] is! int ||
        value['index'] is! int ||
        value['index'] < 0)
      return null;
    return RecentReadingEntry(
      id: value['id'],
      time: value['time'],
      index: value['index'],
      gid: value['gid'] is String ? value['gid'] : null,
      source: value['source'] is String ? value['source'] : 'gallery',
      sourcePath: value['sourcePath'] is String ? value['sourcePath'] : null,
      url: value['url'] is String ? value['url'] : null,
      token: value['token'] is String ? value['token'] : null,
      title: value['title'] is String ? value['title'] : null,
      cover: value['cover'] is String ? value['cover'] : null,
      total: value['total'] is int && value['total'] > 0
          ? value['total']
          : null,
    );
  }
}

class ReadingEventTicket {
  const ReadingEventTicket(this.id, this.epoch, this.revision);
  final String id;
  final int epoch, revision;
}

class RecentReadingStore extends ChangeNotifier {
  RecentReadingStore({this.read, this.write});
  static final instance = RecentReadingStore();
  static const storageKey = 'recent_reading_v1';
  final String? Function()? read;
  final Future<void> Function(String)? write;
  final Map<String, RecentReadingEntry> _entries = {};
  final Map<String, int> _removed = {};
  List<RecentReadingEntry> _recent = const [];
  int _epoch = 0;
  bool _loaded = false;
  Future<void> _pending = Future.value();
  List<RecentReadingEntry> get recent => _recent;

  void load() {
    if (_loaded || (read == null && !Hive.isBoxOpen(configBox))) return;
    _loaded = true;
    try {
      final raw = read != null
          ? read!()
          : Hive.box<String>(configBox).get(storageKey);
      final data = jsonDecode(raw ?? '{}');
      if (data is! Map) return;
      if (data['epoch'] is int) _epoch = data['epoch'];
      if (data['removed'] is Map) {
        for (final entry in (data['removed'] as Map).entries) {
          if (entry.key is String && entry.value is int)
            _removed[entry.key] = entry.value;
        }
      }
      if (data['entries'] is List) {
        for (final value in data['entries']) {
          final entry = RecentReadingEntry.parse(value);
          if (entry != null) _entries[entry.id] = entry;
        }
      }
      _sort();
    } on Object {
      // Old progress is deliberately not imported: a cache timestamp doesn't
      // prove a decoded page was ever visible. Corrupt rows fail individually.
    }
  }

  ReadingEventTicket ticket(String id) {
    load();
    return ReadingEventTicket(id, _epoch, _removed[id] ?? 0);
  }

  bool record(ReadingEventTicket ticket, RecentReadingEntry entry) {
    if (ticket.id != entry.id ||
        ticket.epoch != _epoch ||
        ticket.revision != (_removed[entry.id] ?? 0) ||
        entry.index < 0)
      return false;
    _entries[entry.id] = entry;
    _sort();
    _save();
    return true;
  }

  Future<void> remove(String gid) {
    load();
    final ids =
        _entries.values
            .where((e) => e.gid == gid || e.id == gid)
            .map((e) => e.id)
            .toSet()
          ..add('gid:$gid');
    for (final id in ids) {
      _entries.remove(id);
      _removed[id] = (_removed[id] ?? 0) + 1;
    }
    _sort();
    return _save();
  }

  Future<void> clear() {
    load();
    _epoch++;
    _entries.clear();
    _removed.clear();
    _sort();
    return _save();
  }

  void _sort() {
    final sorted = _entries.values.toList()
      ..sort((a, b) {
        final time = b.time.compareTo(a.time);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });
    _recent = List.unmodifiable(sorted.take(5));
  }

  Future<void> _save() {
    notifyListeners();
    final value = jsonEncode({
      'epoch': _epoch,
      'removed': _removed,
      'entries': _entries.values.map((e) => e.toJson()).toList(),
    });
    final operation = _pending.then((_) async {
      if (write != null) {
        await write!(value);
      } else if (Hive.isBoxOpen(configBox)) {
        await Hive.box<String>(configBox).put(storageKey, value);
      }
    });
    _pending = operation.catchError((Object error) {
      debugPrint('Unable to save recently read works: $error');
    });
    return _pending;
  }

  @visibleForTesting
  Future<void> get pendingWrites => _pending;
}
