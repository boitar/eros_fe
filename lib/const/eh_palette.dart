import 'package:flutter/cupertino.dart';

/// Semantic colour tokens shared by every surface.
///
/// Each token is a [CupertinoDynamicColor] carrying light, dark, increased
/// contrast and elevated variants, so `CupertinoDynamicColor.resolve` picks
/// the right value for Dark Mode, Increase Contrast, and sheets/popovers.
/// Light values are identical in both palettes; the two dark styles only
/// differ in how far the background steps go down.
///
/// Liquid Glass takes its colour from the content underneath, so [canvas]
/// is also what the native bars and the soft scroll edge sample at rest.
@immutable
class EhPalette {
  const EhPalette._({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.field,
    required this.fill,
    required this.fillPressed,
    required this.hairline,
    required this.edgeLight,
    required this.bar,
    required this.text1,
    required this.text2,
    required this.text3,
  });

  /// Page background and the end colour of every scroll edge fade.
  final CupertinoDynamicColor canvas;

  /// Gallery cards, grouped setting rows, comment cards.
  final CupertinoDynamicColor surface;

  /// Popovers, menus and anything above [surface].
  final CupertinoDynamicColor raised;

  /// Opaque text field background.
  final CupertinoDynamicColor field;

  /// Translucent fill for chips, tags and placeholders.
  final CupertinoDynamicColor fill;
  final CupertinoDynamicColor fillPressed;

  /// 0.5pt borders and separators.
  final CupertinoDynamicColor hairline;

  /// Top highlight on dark cards; transparent in light mode.
  final CupertinoDynamicColor edgeLight;

  /// Flutter-drawn bar background used when native glass is off.
  final CupertinoDynamicColor bar;

  final CupertinoDynamicColor text1;
  final CupertinoDynamicColor text2;

  /// Chevrons and placeholders only; never the sole carrier of information.
  final CupertinoDynamicColor text3;

  /// Content-layer accent (Ink indigo). Glass bars stay monochrome.
  static const CupertinoDynamicColor accent =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'ehAccent',
    color: Color(0xFF4A5BD8),
    darkColor: Color(0xFF8C9AFF),
    highContrastColor: Color(0xFF3243C2),
    darkHighContrastColor: Color(0xFFA8B2FF),
  );

  /// Text and glyphs placed on [accent].
  static const CupertinoDynamicColor onAccent =
      CupertinoDynamicColor.withBrightness(
    debugLabel: 'ehOnAccent',
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF0E0F12),
  );

  static const CupertinoDynamicColor accentSoft =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'ehAccentSoft',
    color: Color(0x1A4A5BD8),
    darkColor: Color(0x298C9AFF),
    highContrastColor: Color(0x294A5BD8),
    darkHighContrastColor: Color(0x3D8C9AFF),
  );

  /// 1px list separators: a touch stronger than [hairline], which is 0.5pt.
  static const CupertinoDynamicColor separator =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'ehSeparator',
    color: Color(0x2414161C),
    darkColor: Color(0x1FFFFFFF),
    highContrastColor: Color(0x4D14161C),
    darkHighContrastColor: Color(0x4DFFFFFF),
  );

  /// Behind text and chips laid over cover art.
  static const Color scrim = Color(0x750C0C10);

  static const CupertinoDynamicColor star = CupertinoDynamicColor.withBrightness(
    debugLabel: 'ehStar',
    color: Color(0xFFF0A030),
    darkColor: Color(0xFFE8A54A),
  );

  static const EhPalette graphite = EhPalette._(
    canvas: CupertinoDynamicColor(
      debugLabel: 'ehCanvas',
      color: Color(0xFFF2F3F6),
      darkColor: Color(0xFF0E0F12),
      highContrastColor: Color(0xFFECEEF2),
      darkHighContrastColor: Color(0xFF0A0B0D),
      elevatedColor: Color(0xFFF2F3F6),
      darkElevatedColor: Color(0xFF17181C),
      highContrastElevatedColor: Color(0xFFECEEF2),
      darkHighContrastElevatedColor: Color(0xFF121316),
    ),
    surface: CupertinoDynamicColor(
      debugLabel: 'ehSurface',
      color: Color(0xFFFFFFFF),
      darkColor: Color(0xFF17181C),
      highContrastColor: Color(0xFFFFFFFF),
      darkHighContrastColor: Color(0xFF1E1F24),
      elevatedColor: Color(0xFFFFFFFF),
      darkElevatedColor: Color(0xFF202126),
      highContrastElevatedColor: Color(0xFFFFFFFF),
      darkHighContrastElevatedColor: Color(0xFF26272D),
    ),
    raised: CupertinoDynamicColor(
      debugLabel: 'ehRaised',
      color: Color(0xFFFFFFFF),
      darkColor: Color(0xFF202126),
      highContrastColor: Color(0xFFFFFFFF),
      darkHighContrastColor: Color(0xFF26272D),
      elevatedColor: Color(0xFFFFFFFF),
      darkElevatedColor: Color(0xFF27292F),
      highContrastElevatedColor: Color(0xFFFFFFFF),
      darkHighContrastElevatedColor: Color(0xFF2E3036),
    ),
    field: CupertinoDynamicColor.withBrightnessAndContrast(
      debugLabel: 'ehField',
      color: Color(0xFFE8E9ED),
      darkColor: Color(0xFF1F2025),
      highContrastColor: Color(0xFFDFE1E6),
      darkHighContrastColor: Color(0xFF2A2B31),
    ),
    fill: _fill,
    fillPressed: _fillPressed,
    hairline: CupertinoDynamicColor.withBrightnessAndContrast(
      debugLabel: 'ehHairline',
      color: Color(0x1414161C),
      darkColor: Color(0x14FFFFFF),
      highContrastColor: Color(0x3814161C),
      darkHighContrastColor: Color(0x38FFFFFF),
    ),
    edgeLight: CupertinoDynamicColor.withBrightness(
      debugLabel: 'ehEdgeLight',
      color: Color(0x00FFFFFF),
      darkColor: Color(0x17FFFFFF),
    ),
    bar: CupertinoDynamicColor.withBrightness(
      debugLabel: 'ehBar',
      color: Color(0xC7F2F3F6),
      darkColor: Color(0xC70E0F12),
    ),
    text1: _text1,
    text2: _text2,
    text3: _text3,
  );

  /// OLED: the same light values, with the dark steps anchored on #000.
  static const EhPalette oled = EhPalette._(
    canvas: CupertinoDynamicColor(
      debugLabel: 'ehCanvasOled',
      color: Color(0xFFF2F3F6),
      darkColor: Color(0xFF000000),
      highContrastColor: Color(0xFFECEEF2),
      darkHighContrastColor: Color(0xFF000000),
      elevatedColor: Color(0xFFF2F3F6),
      darkElevatedColor: Color(0xFF101114),
      highContrastElevatedColor: Color(0xFFECEEF2),
      darkHighContrastElevatedColor: Color(0xFF16171A),
    ),
    surface: CupertinoDynamicColor(
      debugLabel: 'ehSurfaceOled',
      color: Color(0xFFFFFFFF),
      darkColor: Color(0xFF101114),
      highContrastColor: Color(0xFFFFFFFF),
      darkHighContrastColor: Color(0xFF18191D),
      elevatedColor: Color(0xFFFFFFFF),
      darkElevatedColor: Color(0xFF18191D),
      highContrastElevatedColor: Color(0xFFFFFFFF),
      darkHighContrastElevatedColor: Color(0xFF1F2024),
    ),
    raised: CupertinoDynamicColor(
      debugLabel: 'ehRaisedOled',
      color: Color(0xFFFFFFFF),
      darkColor: Color(0xFF18191D),
      highContrastColor: Color(0xFFFFFFFF),
      darkHighContrastColor: Color(0xFF1F2024),
      elevatedColor: Color(0xFFFFFFFF),
      darkElevatedColor: Color(0xFF1F2024),
      highContrastElevatedColor: Color(0xFFFFFFFF),
      darkHighContrastElevatedColor: Color(0xFF26272C),
    ),
    field: CupertinoDynamicColor.withBrightnessAndContrast(
      debugLabel: 'ehFieldOled',
      color: Color(0xFFE8E9ED),
      darkColor: Color(0xFF16171A),
      highContrastColor: Color(0xFFDFE1E6),
      darkHighContrastColor: Color(0xFF222328),
    ),
    fill: _fill,
    fillPressed: _fillPressed,
    hairline: CupertinoDynamicColor.withBrightnessAndContrast(
      debugLabel: 'ehHairlineOled',
      color: Color(0x1414161C),
      darkColor: Color(0x17FFFFFF),
      highContrastColor: Color(0x3814161C),
      darkHighContrastColor: Color(0x3DFFFFFF),
    ),
    edgeLight: CupertinoDynamicColor.withBrightness(
      debugLabel: 'ehEdgeLightOled',
      color: Color(0x00FFFFFF),
      darkColor: Color(0x1AFFFFFF),
    ),
    bar: CupertinoDynamicColor.withBrightness(
      debugLabel: 'ehBarOled',
      color: Color(0xC7F2F3F6),
      darkColor: Color(0xC7000000),
    ),
    text1: _text1,
    text2: _text2,
    text3: _text3,
  );

  static const CupertinoDynamicColor _fill =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'ehFill',
    color: Color(0x0D14161C),
    darkColor: Color(0x11FFFFFF),
    highContrastColor: Color(0x1F14161C),
    darkHighContrastColor: Color(0x24FFFFFF),
  );

  static const CupertinoDynamicColor _fillPressed =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'ehFillPressed',
    color: Color(0x1714161C),
    darkColor: Color(0x1AFFFFFF),
    highContrastColor: Color(0x2914161C),
    darkHighContrastColor: Color(0x2EFFFFFF),
  );

  static const CupertinoDynamicColor _text1 =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'ehText1',
    color: Color(0xFF14161A),
    darkColor: Color(0xFFECEDF0),
    highContrastColor: Color(0xFF000000),
    darkHighContrastColor: Color(0xFFFFFFFF),
  );

  static const CupertinoDynamicColor _text2 =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'ehText2',
    color: Color(0xFF5E636B),
    darkColor: Color(0xFFA3A7AF),
    highContrastColor: Color(0xFF454A52),
    darkHighContrastColor: Color(0xFFC4C7CE),
  );

  static const CupertinoDynamicColor _text3 =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'ehText3',
    color: Color(0xFF8A9099),
    darkColor: Color(0xFF6C7079),
    highContrastColor: Color(0xFF6A707A),
    darkHighContrastColor: Color(0xFF8E929B),
  );

  /// Graphite is the default dark style; pure black suits OLED screens.
  static EhPalette forDarkStyle({required bool pureBlack}) =>
      pureBlack ? oled : graphite;

  /// Two-layer soft shadow for light cards; dark cards use [edgeLight].
  static const List<BoxShadow> lightCardShadows = <BoxShadow>[
    BoxShadow(color: Color(0x0D101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x12101828), blurRadius: 14, offset: Offset(0, 4)),
  ];

  CupertinoThemeData themeData(
    Brightness brightness,
    CupertinoTextThemeData textTheme,
  ) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: accent,
      primaryContrastingColor: onAccent,
      barBackgroundColor: bar,
      scaffoldBackgroundColor: canvas,
      // A text theme built with the default constructor carries its own
      // systemBlue; action and nav-action styles must follow the accent.
      textTheme: textTheme.copyWith(primaryColor: accent),
      // Switches tint with the accent instead of the system green.
      applyThemeToAll: true,
    );
  }

  /// Resolves [color] without a [BuildContext], for callers that only know
  /// whether the app is dark. Increased contrast and elevation need a context.
  static Color pick(CupertinoDynamicColor color, {required bool dark}) =>
      dark ? color.darkColor : color.color;
}
