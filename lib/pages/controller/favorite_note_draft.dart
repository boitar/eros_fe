/// One dialog's note draft. Late reads never replace user edits or a new dialog.
class FavoriteNoteDraft {
  String text = '';
  bool edited = false;
  bool active = true;
  bool _failed = false;
  Future<void>? _loading;

  void edit(String value) {
    edited = true;
    text = value;
  }

  void load(Future<String?> Function() read, void Function(String) apply) {
    _loading = () async {
      try {
        final note = await read() ?? '';
        if (!edited) {
          text = note;
          if (active) apply(note);
        }
      } catch (_) {
        _failed = true;
      }
    }();
  }

  Future<String> forSave() async {
    if (edited) return text;
    await _loading;
    if (_failed) throw StateError('原收藏备注未能读取，未提交更改，请重试');
    return text;
  }
}
