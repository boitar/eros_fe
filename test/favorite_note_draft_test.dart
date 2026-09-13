import 'dart:async';
import 'package:eros_fe/pages/controller/favorite_note_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new favorite needs no note request', () async {
    expect(await FavoriteNoteDraft().forSave(), '');
  });
  test('untouched note waits at save and preserves the original', () async {
    final read = Completer<String?>();
    final draft = FavoriteNoteDraft();
    draft.load(() => read.future, (_) {});
    var finished = false;
    final save = draft.forSave().then((value) {
      finished = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(finished, false);
    draft.active = false;
    read.complete('original note');
    expect(await save, 'original note');
  });
  test('typing or explicitly clearing the note wins over late data', () async {
    for (final edit in ['my note', '']) {
      final read = Completer<String?>();
      final draft = FavoriteNoteDraft();
      var applied = false;
      draft.load(() => read.future, (_) {
        applied = true;
      });
      draft.edit(edit);
      expect(await draft.forSave(), edit);
      read.complete('old note');
      await Future<void>.delayed(Duration.zero);
      expect(applied, false);
      expect(await draft.forSave(), edit);
    }
  });
  test('closed dialog never receives a late note', () async {
    final read = Completer<String?>();
    final draft = FavoriteNoteDraft();
    var applied = false;
    draft.load(() => read.future, (_) {
      applied = true;
    });
    draft.active = false;
    read.complete('old');
    expect(await draft.forSave(), 'old');
    expect(applied, false);
  });
  test('failed read cannot silently erase an untouched original note',
      () async {
    final draft = FavoriteNoteDraft();
    draft.load(() async => throw StateError('offline'), (_) {});
    await expectLater(draft.forSave(), throwsStateError);
    draft.edit('replacement');
    expect(await draft.forSave(), 'replacement');
  });
}
