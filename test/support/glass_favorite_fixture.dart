import 'package:eros_fe/common/service/ehsetting_service.dart';
import 'package:eros_fe/common/service/theme_service.dart';
import 'package:eros_fe/const/theme_colors.dart';
import 'package:get/get.dart';

class PickerSettings extends GetxService implements EhSettingService {
  @override
  RxBool isFavPicker = true.obs;
  @override
  bool get isPureDarkTheme => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PickerTheme extends GetxService implements ThemeService {
  @override
  ThemesModeEnum get themeModel => ThemesModeEnum.lightMode;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
