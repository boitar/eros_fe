import 'dart:async';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:eros_fe/common/colors.dart';
import 'package:eros_fe/common/global.dart';
import 'package:eros_fe/common/service/base_service.dart';
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

  /// Keeps native UIKit's trait collection aligned with the app-level theme.
  ///
  /// Flutter's CupertinoThemeData does not change UIWindow's
  /// userInterfaceStyle. Native Liquid Glass therefore needs this explicit
  /// public-API bridge when the user selects Light or Dark instead of System.
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
  }

  CupertinoThemeData get _getDarkTheme => _ehSettingService.isPureDarkTheme
      ? ThemeColors.darkPureTheme
      : ThemeColors.darkGrayTheme;

  CupertinoThemeData? get themeData {
    switch (themeModel) {
      case ThemesModeEnum.system:
        return platformBrightness.value == Brightness.dark
            ? _getDarkTheme
            : ThemeColors.lightTheme;
      case ThemesModeEnum.lightMode:
        return ThemeColors.lightTheme;
      case ThemesModeEnum.darkMode:
        return _getDarkTheme;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _themeModel.value =
        EnumToString.fromString(ThemesModeEnum.values, Global.profile.theme) ??
            ThemesModeEnum.system;
    syncNativeAppearance();
    everFromEnum(_themeModel, (String value) {
      Global.profile = Global.profile.copyWith(theme: value);
    });
  }
}

final EHTheme ehTheme = EHTheme();

class EHTheme {
  ThemeService get _themeService => Get.find();
  EhSettingService get _ehSettingService => Get.find();

  Color? _getColorWithTheme(EhDynamicColor ehcolor) {
    final Color effDarkColor = _ehSettingService.isPureDarkTheme
        ? ehcolor.darkColor
        : ehcolor.darkGrayColor;

    switch (_themeService.themeModel) {
      case ThemesModeEnum.system:
        return _themeService.platformBrightness.value == Brightness.dark
            ? effDarkColor
            : ehcolor.color;
      case ThemesModeEnum.lightMode:
        return ehcolor.color;
      case ThemesModeEnum.darkMode:
        return effDarkColor;
      default:
        return null;
    }
  }

  CupertinoThemeData? get themeData => _themeService.themeData;

  /// 文本输入框的背景色
  Color? get textFieldBackgroundColor =>
      _getColorWithTheme(EhDynamicColors.textFieldBackground);

  /// 评论输入框颜色
  Color? get commentTextFieldBackgroundColor =>
      _getColorWithTheme(EhDynamicColors.commentTextFieldBackground);

  /// 评论回复框颜色
  Color? get commentReplyBackgroundColor =>
      _getColorWithTheme(EhDynamicColors.commentReplyBackground);

  /// 评论背景颜色
  Color? get commentBackgroundColor =>
      _getColorWithTheme(EhDynamicColors.commentBackground);

  // 收藏备注输入框颜色
  Color? get favnoteTextFieldBackgroundColor =>
      _getColorWithTheme(EhDynamicColors.favnoteTextFieldBackground);

  /// item 背景色
  Color? get itemBackgroundColor =>
      _getColorWithTheme(EhDynamicColors.itemBackground);

  Color? get commitIconColor => _getColorWithTheme(EhDynamicColors.commitIcon);

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
