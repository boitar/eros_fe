import 'dart:async';
import 'dart:convert';

import 'package:eros_fe/store/hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Local UI state, independent of navigation, synchronized profiles and mobile
/// layout preferences. Stable identifiers survive language and tab changes.
class DesktopUiPreferences extends ChangeNotifier {
  DesktopUiPreferences({this.read, this.write});
  static final instance = DesktopUiPreferences();
  static const storageKey = 'desktop_browse_ui_v1';
  final String? Function()? read;
  final Future<void> Function(String)? write;
  bool _loaded = false;
  bool sidebarVisible = true;
  final Set<String> collapsed = {};
  double? splitRatio;
  double? legacyProportion;
  Future<void> _pending = Future.value();

  void load() {
    if (_loaded) return;
    if (read == null && !Hive.isBoxOpen(configBox)) return;
    _loaded = true;
    try {
      final value = read != null ? read!() : Hive.box<String>(configBox).get(storageKey);
      final data = jsonDecode(value ?? '{}');
      if (data is Map) {
        sidebarVisible = data['sidebarVisible'] != false;
        final sections = data['collapsed'];
        if (sections is List) collapsed.addAll(sections.whereType<String>());
        final ratio = data['splitRatio'];
        if (ratio is num && ratio.isFinite && ratio > 0 && ratio < 1) {
          splitRatio = ratio.toDouble();
        }
      }
      if (value == null && Hive.isBoxOpen(configBox)) {
        final layout = jsonDecode(
          Hive.box<String>(configBox).get(layoutConfigKey) ?? '{}',
        );
        final old = layout is Map ? layout['sideProportion'] : null;
        if (old is num && old.isFinite && old >= 0 && old <= 1) {
          legacyProportion = old.toDouble();
        }
      }
    } on Object {
      // A damaged UI preference never prevents opening the library.
    }
  }

  bool isExpanded(String section) => !collapsed.contains(section);

  void toggleSection(String section) {
    if (!collapsed.remove(section)) collapsed.add(section);
    _save();
  }

  void showSidebar(bool visible) {
    if (sidebarVisible == visible) return;
    sidebarVisible = visible;
    _save();
  }

  void setSplitRatio(double? ratio) {
    splitRatio = ratio;
    // Reset means the new default, not a re-import of the old mobile ratio.
    legacyProportion = null;
    _save();
  }

  void _save() {
    notifyListeners();
    final value = jsonEncode({
      'sidebarVisible': sidebarVisible,
      'collapsed': collapsed.toList(),
      'splitRatio': splitRatio,
    });
    _pending = _pending
        .then((_) async {
          if (write != null) {
            await write!(value);
          } else if (Hive.isBoxOpen(configBox)) {
            await Hive.box<String>(configBox).put(storageKey, value);
          }
        })
        .catchError((Object error) {
          debugPrint('Unable to save desktop UI preferences: $error');
        });
    unawaited(_pending);
  }

  @visibleForTesting
  Future<void> get pendingWrites => _pending;
}
