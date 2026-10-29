import 'dart:async';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/base_service.dart';
import 'package:eros_fe/const/eh_palette.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'ehsetting_service.dart';

class ThemeService extends ProfileService {
  static const MethodChannel _appearanceChannel =
      MethodChannel('eros/appearance');

  final EhSettingService _ehSettingService = Get.find();
  final Rx<ThemesModeEnum> _themeModel = ThemesModeEnum.system.obs;
  Rx<Brightness?> platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness.obs;

  set themeModel(ThemesModeEnum value) {
    _themeModel.value = value;
    syncNativeAppearance();
  }

  ThemesModeEnum get themeModel {
    return _themeModel.value;
  }

  /// The active dark style decides how deep the dark background steps go.
  EhPalette get palette =>
      EhPalette.forDarkStyle(pureBlack: _ehSettingService.isPureDarkTheme);

  /// Keeps native UIKit's trait collection aligned with the app-level theme.
  ///
  /// Flutter's CupertinoThemeData does not change UIWindow's
  /// userInterfaceStyle. Native Liquid Glass therefore needs this explicit
  /// public-API bridge when the user selects Light or Dark instead of System.
  /// The canvas colour goes along so UIKit hosts behind Flutter never flash
  /// a system white or black during transitions and overscroll.
  void syncNativeAppearance() {
    final String style;
    switch (themeModel) {
      case ThemesModeEnum.system:
        style = 'system';
      case ThemesModeEnum.lightMode:
        style = 'light';
      case ThemesModeEnum.darkMode:
        style = 'dark';
    }

    unawaited(
      _appearanceChannel.invokeMethod<void>('setStyle', style).catchError(
            (_) {},
          ),
    );

    final canvas = palette.canvas;
    unawaited(
      _appearanceChannel.invokeMethod<void>('setPalette', <String, int>{
        'canvas': canvas.color.toARGB32(),
        'canvasDark': canvas.darkColor.toARGB32(),
        'canvasHighContrast': canvas.highContrastColor.toARGB32(),
        'canvasDarkHighContrast': canvas.darkHighContrastColor.toARGB32(),
      }).catchError((_) {}),
    );
  }

  CupertinoThemeData get _lightTheme =>
      palette.themeData(Brightness.light, ehTextTheme);

  CupertinoThemeData get _darkTheme =>
      palette.themeData(Brightness.dark, ehTextTheme);

  CupertinoThemeData? get themeData {
    switch (themeModel) {
      case ThemesModeEnum.system:
        return platformBrightness.value == Brightness.dark
            ? _darkTheme
            : _lightTheme;
      case ThemesModeEnum.lightMode:
        return _lightTheme;
      case ThemesModeEnum.darkMode:
        return _darkTheme;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _themeModel.value =
        EnumToString.fromString(ThemesModeEnum.values, Global.profile.theme) ??
            ThemesModeEnum.system;
    syncNativeAppearance();
    ever<bool>(
      _ehSettingService.pureDarkThemeObs,
      (_) => syncNativeAppearance(),
    );
    everFromEnum(_themeModel, (String value) {
      Global.profile = Global.profile.copyWith(theme: value);
    });
  }
}

final EHTheme ehTheme = EHTheme();

class EHTheme {
  ThemeService get _themeService => Get.find();
  EhSettingService get _ehSettingService => Get.find();

  EhPalette get palette =>
      EhPalette.forDarkStyle(pureBlack: _ehSettingService.isPureDarkTheme);

  Color _pick(CupertinoDynamicColor color) =>
      EhPalette.pick(color, dark: isDarkMode);

  CupertinoThemeData? get themeData => _themeService.themeData;

  /// 文本输入框的背景色
  Color? get textFieldBackgroundColor => _pick(palette.field);

  /// 评论输入框颜色
  Color? get commentTextFieldBackgroundColor => _pick(palette.field);

  /// 评论回复框颜色：嵌在评论卡片里，退回页面底色
  Color? get commentReplyBackgroundColor => _pick(palette.canvas);

  /// 评论背景颜色
  Color? get commentBackgroundColor => _pick(palette.surface);

  // 收藏备注输入框颜色
  Color? get favnoteTextFieldBackgroundColor => _pick(palette.field);

  /// item 背景色
  Color? get itemBackgroundColor => _pick(palette.surface);

  Color? get commitIconColor => _pick(palette.text3);

  bool get _isSeldark => _themeService.themeModel == ThemesModeEnum.darkMode;
  bool get _isSelLigth => _themeService.themeModel == ThemesModeEnum.lightMode;

  bool get isDarkMode {
    if (_isSelLigth) {
      return false;
    } else {
      return _isSeldark ||
          _themeService.platformBrightness.value == Brightness.dark;
    }
  }
}
