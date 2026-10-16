import 'dart:convert';
import 'package:eros_fe/extension.dart';
import 'package:eros_fe/models/eh_config.dart';
import 'package:eros_fe/utils/liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  final legacy = <String, dynamic>{
    'favoritesOrder': '',
    'listMode': '',
    'catFilter': 0,
    'maxHistory': 100,
    'viewModel': '',
  };
  test('missing, null, and unknown layouts restore two-row default', () {
    for (final value in [null, 'futureLayout', '']) {
      final config =
          EhConfig.fromJson({...legacy, 'liquidGlassTopBarLayout': value});
      expect(LiquidGlassTopBarLayout.parse(config.liquidGlassTopBarLayout),
          LiquidGlassTopBarLayout.twoRow);
    }
    expect(
        LiquidGlassTopBarLayout.parse(
            EhConfig.fromJson(legacy).liquidGlassTopBarLayout),
        LiquidGlassTopBarLayout.twoRow);
  });
  test('layout participates in export/import, clone, copy, equality and hash',
      () {
    final base = EhConfig.fromJson(legacy);
    for (final layout in LiquidGlassTopBarLayout.values) {
      final config = base.copyWith(liquidGlassTopBarLayout: layout.name.oN);
      final restored = EhConfig.fromJson(
          jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>);
      expect(restored, config);
      expect(restored.hashCode, config.hashCode);
      expect(config.clone(), config);
      expect(LiquidGlassTopBarLayout.parse(restored.liquidGlassTopBarLayout),
          layout);
      expect(config == base, isFalse);
    }
  });
}
