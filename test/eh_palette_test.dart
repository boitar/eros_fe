import 'dart:math' as math;

import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

typedef _Pick = Color Function(CupertinoDynamicColor);

const Map<String, _Pick> _variants = <String, _Pick>{
  'light': _light,
  'dark': _dark,
  'light high contrast': _lightHigh,
  'dark high contrast': _darkHigh,
};

Color _light(CupertinoDynamicColor c) => c.color;
Color _dark(CupertinoDynamicColor c) => c.darkColor;
Color _lightHigh(CupertinoDynamicColor c) => c.highContrastColor;
Color _darkHigh(CupertinoDynamicColor c) => c.darkHighContrastColor;

void main() {
  const palettes = <String, EhPalette>{
    'graphite': EhPalette.graphite,
    'oled': EhPalette.oled,
  };

  group('EhPalette contrast', () {
    for (final palette in palettes.entries) {
      for (final variant in _variants.entries) {
        final p = palette.value;
        final pick = variant.value;
        final label = '${palette.key} · ${variant.key}';
        final grounds = <String, Color>{
          'canvas': pick(p.canvas),
          'surface': pick(p.surface),
          'raised': pick(p.raised),
        };

        test('$label: body text reaches 4.5:1 on every ground', () {
          for (final ground in grounds.entries) {
            expect(_contrast(pick(p.text1), ground.value),
                greaterThanOrEqualTo(7.0),
                reason: 'text1 on ${ground.key}');
            expect(_contrast(pick(p.text2), ground.value),
                greaterThanOrEqualTo(4.5),
                reason: 'text2 on ${ground.key}');
          }
        });

        test('$label: accent and text3 stay legible on surface', () {
          final surface = grounds['surface']!;
          expect(_contrast(pick(EhPalette.accent), surface),
              greaterThanOrEqualTo(4.5));
          expect(_contrast(pick(p.text3), surface), greaterThanOrEqualTo(3.0));
        });
      }

      test('${palette.key}: increased contrast pushes text2 past 7:1', () {
        final p = palette.value;
        expect(_contrast(p.text2.highContrastColor, p.surface.highContrastColor),
            greaterThanOrEqualTo(7.0));
        expect(
            _contrast(
                p.text2.darkHighContrastColor, p.surface.darkHighContrastColor),
            greaterThanOrEqualTo(7.0));
      });
    }

    test('text on the accent fill reaches 4.5:1', () {
      expect(_contrast(EhPalette.onAccent.color, EhPalette.accent.color),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(EhPalette.onAccent.darkColor, EhPalette.accent.darkColor),
          greaterThanOrEqualTo(4.5));
    });

    test('tag chips keep 4.5:1 text on cards', () {
      for (final p in palettes.values) {
        final lightChip = Color.alphaBlend(
            ThemeColors.tagBackground.color, p.surface.color);
        final darkChip = Color.alphaBlend(
            ThemeColors.tagBackground.darkColor, p.surface.darkColor);
        expect(_contrast(ThemeColors.tagText.color, lightChip),
            greaterThanOrEqualTo(4.5));
        expect(_contrast(ThemeColors.tagText.darkColor, darkChip),
            greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('EhPalette structure', () {
    test('both dark styles share the light palette', () {
      List<Color> lights(EhPalette p) => <Color>[
            p.canvas.color,
            p.surface.color,
            p.raised.color,
            p.field.color,
            p.fill.color,
            p.hairline.color,
            p.text1.color,
            p.text2.color,
            p.text3.color,
          ];
      expect(lights(EhPalette.oled), lights(EhPalette.graphite));
    });

    test('dark backgrounds step up from canvas to raised', () {
      for (final p in palettes.values) {
        final steps = <Color>[
          p.canvas.darkColor,
          p.surface.darkColor,
          p.raised.darkColor,
        ].map(_luminance).toList();
        expect(steps[0], lessThan(steps[1]));
        expect(steps[1], lessThan(steps[2]));
      }
      expect(EhPalette.oled.canvas.darkColor, const Color(0xFF000000));
    });

    test('elevated dark canvas is brighter than the base canvas', () {
      for (final p in palettes.values) {
        expect(_luminance(p.canvas.darkElevatedColor),
            greaterThan(_luminance(p.canvas.darkColor)));
      }
    });

    test('theme data takes canvas, bar and accent from the palette', () {
      final data = EhPalette.graphite
          .themeData(Brightness.dark, const CupertinoTextThemeData());
      expect(data.brightness, Brightness.dark);
      expect(data.scaffoldBackgroundColor, EhPalette.graphite.canvas);
      expect(data.barBackgroundColor, EhPalette.graphite.bar);
      expect(data.primaryColor, EhPalette.accent);
      expect(data.primaryContrastingColor, EhPalette.onAccent);
    });

    test('nav actions follow the accent, not the text theme default blue', () {
      final data = EhPalette.graphite
          .themeData(Brightness.dark, const CupertinoTextThemeData());
      expect(data.textTheme.navActionTextStyle.color, EhPalette.accent);
      expect(data.textTheme.actionTextStyle.color, EhPalette.accent);
    });

    test('pick follows the requested brightness', () {
      expect(EhPalette.pick(EhPalette.oled.surface, dark: true),
          const Color(0xFF101114));
      expect(EhPalette.pick(EhPalette.oled.surface, dark: false),
          const Color(0xFFFFFFFF));
    });
  });

  testWidgets('tokens resolve increased contrast and elevation in context',
      (tester) async {
    late Color canvas;
    late Color elevated;
    late Color text2;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          platformBrightness: Brightness.dark,
          highContrast: true,
        ),
        child: CupertinoTheme(
          data: const CupertinoThemeData(brightness: Brightness.dark),
          child: Builder(builder: (context) {
            canvas = EhPalette.graphite.canvas.resolveFrom(context);
            text2 = EhPalette.graphite.text2.resolveFrom(context);
            return CupertinoUserInterfaceLevel(
              data: CupertinoUserInterfaceLevelData.elevated,
              child: Builder(builder: (context) {
                elevated = EhPalette.graphite.canvas.resolveFrom(context);
                return const SizedBox();
              }),
            );
          }),
        ),
      ),
    );
    expect(canvas.toARGB32(), 0xFF0A0B0D);
    expect(text2.toARGB32(), 0xFFC4C7CE);
    expect(elevated.toARGB32(), 0xFF121316);
  });
}
