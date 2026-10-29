import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';

final ehTextTheme = const CupertinoTextThemeData().copyWith(
  // textStyle: const CupertinoTextThemeData().textStyle.copyWith(
  //       // fontFamily: EHConst.fontFamily,
  //       fontFamilyFallback: EHConst.fontFamilyFallback,
  //     ),
  textStyle: const CupertinoTextThemeData().textStyle.useSystemChineseFont(),
);

enum ThemesModeEnum {
  system,
  lightMode,
  darkMode,
}

class CustomTheme {
  late CupertinoThemeData themeData;
}

// ignore: avoid_classes_with_only_static_members
class ThemeColors {
  static const CupertinoDynamicColor commitBackground =
      CupertinoDynamicColor.withBrightness(
    debugLabel: 'commitBackground',
    color: Color.fromARGB(255, 242, 242, 247),
    darkColor: Color.fromARGB(255, 30, 30, 30),
  );

  // Gray
  static const CupertinoDynamicColor commitBackgroundGray =
      CupertinoDynamicColor.withBrightness(
    debugLabel: 'commitBackground',
    color: Color.fromARGB(255, 242, 242, 247),
    darkColor: Color.fromARGB(255, 40, 40, 40),
  );

  static const CupertinoDynamicColor pressedBackground =
      CupertinoDynamicColor.withBrightness(
    debugLabel: 'pressedBackground',
    color: Color.fromARGB(255, 209, 209, 214),
    darkColor: Color.fromARGB(255, 50, 50, 50),
  );

  static const CupertinoDynamicColor commitText =
      CupertinoDynamicColor.withBrightness(
    debugLabel: 'commitText',
    color: CupertinoColors.label,
    darkColor: CupertinoColors.systemGrey4,
  );

  static const CupertinoDynamicColor tagText =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'tagText',
    color: Color(0xFF5E636B),
    darkColor: Color(0xFFA3A7AF),
    highContrastColor: Color(0xFF454A52),
    darkHighContrastColor: Color(0xFFC4C7CE),
  );

  static const CupertinoDynamicColor tagBackground =
      CupertinoDynamicColor.withBrightnessAndContrast(
    debugLabel: 'tagBackground',
    color: Color(0x0F14161C),
    darkColor: Color(0x14FFFFFF),
    highContrastColor: Color(0x1F14161C),
    darkHighContrastColor: Color(0x24FFFFFF),
  );

  static const CupertinoDynamicColor line =
      CupertinoDynamicColor.withBrightness(
    debugLabel: 'line',
    color: Color(0xffeeeeee),
    darkColor: CupertinoColors.secondaryLabel,
  );

  static const Color dialogColor = CupertinoDynamicColor.withBrightness(
    color: Color(0xCCF2F2F2),
    darkColor: Color(0xBF1E1E1E),
  );

  static List<Color> get tagColorList => tagColorTagType.values.toList();

  /// 标签总分类颜色
  static const Map<String, Color> tagColorTagType = <String, Color>{
    'artist': CupertinoDynamicColor.withBrightness(
      color: Color(0xffE6D6D0),
      darkColor: Color.fromARGB(255, 94, 84, 78),
    ),
    'female': CupertinoDynamicColor.withBrightness(
      color: Color(0xffFAE0D4),
      darkColor: Color.fromARGB(255, 144, 111, 68),
    ),
    'male': CupertinoDynamicColor.withBrightness(
      color: Color(0xfff9eed8),
      darkColor: Color.fromARGB(255, 150, 138, 74),
    ),
    'parody': CupertinoDynamicColor.withBrightness(
      color: Color(0xffd8e6e2),
      darkColor: Color.fromARGB(255, 72, 112, 104),
    ),
    'character': CupertinoDynamicColor.withBrightness(
      color: Color(0xffd5e4f7),
      darkColor: Color.fromARGB(255, 73, 103, 127),
    ),
    'group': CupertinoDynamicColor.withBrightness(
      color: Color(0xffdfd6f7),
      darkColor: Color.fromARGB(255, 97, 82, 132),
    ),
    'language': CupertinoDynamicColor.withBrightness(
      color: Color(0xfff5d5e5),
      darkColor: Color.fromARGB(255, 127, 74, 107),
    ),
    'reclass': CupertinoDynamicColor.withBrightness(
      color: Color(0xfffbd6d5),
      darkColor: Color.fromARGB(255, 146, 85, 84),
    ),
    'misc': CupertinoDynamicColor.withBrightness(
      color: Color(0xffd7d7d6),
      darkColor: Color.fromARGB(255, 99, 102, 106),
    ),
    'temp': CupertinoDynamicColor.withBrightness(
      color: Color(0xffd7d7d6),
      darkColor: Color.fromARGB(255, 99, 102, 106),
    ),
    'other': CupertinoDynamicColor.withBrightness(
      color: Color(0xfffbd6d5),
      darkColor: Color.fromARGB(255, 146, 85, 84),
    ),
    'cosplayer': CupertinoDynamicColor.withBrightness(
      color: Color(0xfff5d5e5),
      darkColor: Color.fromARGB(255, 127, 74, 107),
    ),
  };

  static List<Color> get catColorList => catColor.entries
      .where((e) => e.key != 'default')
      .map((e) => e.value)
      .toList();

  static BoringAvatarPalette boringAvatarPalette = BoringAvatarPalette(
    richAvatarColorList,
  );

  static List<Color> avatarColorFromCatList = catColor.entries
      .where((e) => e.key != 'default')
      .map((e) => e.value)
      .toList()
    ..shuffle();

  static List<Color> avatarColorList = <Color>[
    CupertinoColors.systemRed,
    CupertinoColors.systemOrange,
    CupertinoColors.systemYellow,
    CupertinoColors.systemGreen,
    CupertinoColors.systemTeal,
    CupertinoColors.systemBlue,
    CupertinoColors.systemIndigo,
    CupertinoColors.systemPurple,
    CupertinoColors.systemPink,
  ]..shuffle();

  static List<Color> richAvatarColorList = <Color>[
    Color(0xFFFF5252), // Red
    Color(0xFFFF4081), // Pink
    Color(0xFFE040FB), // Purple
    Color(0xFF7C4DFF), // Deep Purple
    Color(0xFF536DFE), // Indigo
    Color(0xFF448AFF), // Blue
    Color(0xFF40C4FF), // Light Blue
    Color(0xFF18FFFF), // Cyan
    Color(0xFF64FFDA), // Teal
    Color(0xFF69F0AE), // Green
    Color(0xFFB2FF59), // Light Green
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFFC107), // Amber
    Color(0xFFFF9800), // Orange
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF000000), // Black
    Color(0xFFFFFFFF), // White
    Color(0xFF9E9E9E), // Gray
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFD32F2F), // Dark Red
    Color(0xFFC2185B), // Dark Pink
    Color(0xFF7B1FA2), // Dark Purple
    Color(0xFF512DA8), // Dark Deep Purple
    Color(0xFF303F9F), // Dark Indigo
    Color(0xFF1976D2), // Dark Blue
    Color(0xFF0288D1), // Dark Light Blue
    Color(0xFF0097A7), // Dark Cyan
    Color(0xFF00796B), // Dark Teal
    Color(0xFF388E3C), // Dark Green
    Color(0xFF689F38), // Dark Light Green
    Color(0xFFFBC02D), // Dark Yellow
    Color(0xFFFFA000), // Dark Amber
    Color(0xFFF57C00), // Dark Orange
    Color(0xFFE64A19), // Dark Deep Orange
  ]..shuffle();

  // 画廊类型主题色
  static const Map<String, Color> catColor = <String, Color>{
    'Doujinshi': CupertinoDynamicColor.withBrightness(
      color: Color(0xfff44336),
      darkColor: Color.fromARGB(255, 145, 49, 39),
    ),
    'Manga': CupertinoDynamicColor.withBrightness(
      color: Color(0xffff9800),
      darkColor: Color.fromARGB(255, 206, 113, 56),
    ),
    'Artist CG': CupertinoDynamicColor.withBrightness(
      color: Color(0xfffbc02d),
      darkColor: Color.fromARGB(255, 202, 145, 58),
    ),
    'Game CG': CupertinoDynamicColor.withBrightness(
      color: Color(0xff4caf50),
      darkColor: Color.fromARGB(255, 115, 145, 112),
    ),
    'Western': CupertinoDynamicColor.withBrightness(
      color: Color(0xff8bc34a),
      darkColor: Color.fromARGB(255, 169, 158, 104),
    ),
    'Non-H': CupertinoDynamicColor.withBrightness(
      color: Color(0xff2196f3),
      darkColor: Color.fromARGB(255, 112, 168, 203),
    ),
    'Image Set': CupertinoDynamicColor.withBrightness(
      color: Color(0xff3f51b5),
      darkColor: Color.fromARGB(255, 59, 93, 157),
    ),
    'Cosplay': CupertinoDynamicColor.withBrightness(
      color: Color(0xff9c27b0),
      darkColor: Color.fromARGB(255, 98, 57, 156),
    ),
    'Asian Porn': CupertinoDynamicColor.withBrightness(
      color: Color(0xff9575cd),
      darkColor: Color.fromARGB(255, 150, 60, 127),
    ),
    'Misc': CupertinoDynamicColor.withBrightness(
      color: Color(0xfff06292),
      darkColor: Color.fromARGB(255, 188, 91, 123),
    ),
    'Private': CupertinoDynamicColor.withBrightness(
      color: Color.fromARGB(255, 90, 90, 93),
      darkColor: Color.fromARGB(255, 70, 70, 73),
    ),
    'default': CupertinoColors.systemBackground
  };

  /// fav 颜色
  static const Map<String, Color> favColor = <String, Color>{
    '0': Color(0xff5F5F5F),
    '1': Color(0xffDE1C31),
    '2': Color(0xffF97D1C),
    '3': Color(0xffF8B500),
    '4': Color(0xff2BAE85),
    '5': Color(0xff5BAE23),
    '6': Color(0xff22A2C3),
    '7': Color(0xff1661AB),
    '8': Color(0xff9F3EF9),
    '9': Color(0xffEC2D7A),
    'a': Color(0xffB5A4A4),
    'l': Color.fromARGB(255, 169, 158, 104),
  };

  /// 收藏颜色解析失败时仍显示收藏状态。
  static Color favColorFor(String? favcat) =>
      favColor[favcat] ?? CupertinoColors.systemGrey;

  static const Map<String, Color> colorRatingMap = <String, Color>{
    'ir': Color.fromARGB(255, 255, 150, 46),
    'ir irr': Color.fromARGB(255, 255, 100, 120),
    'ir irg': Color.fromARGB(255, 50, 200, 50),
    'ir irb': Color.fromARGB(255, 126, 120, 255),
  };

  // tup
  static const CupertinoDynamicColor tagUpColor =
      CupertinoDynamicColor.withBrightness(
    debugLabel: 'tagUpColor',
    color: Color.fromARGB(255, 32, 186, 64),
    darkColor: Color.fromARGB(255, 110, 210, 110),
  );

  static const CupertinoDynamicColor tagDownColor =
      CupertinoDynamicColor.withBrightness(
    debugLabel: 'tagDownColor',
    color: Color.fromARGB(255, 250, 70, 70),
    darkColor: Color.fromARGB(255, 250, 107, 125),
  );
}
