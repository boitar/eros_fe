import 'package:eros_fe/debug/offline_acceptance.dart';
import 'package:eros_fe/index.dart';

const offlineAccessibilityAcceptanceEnabled = offlineAcceptanceEnabled &&
    bool.fromEnvironment('EROS_ACCESSIBILITY_ACCEPTANCE');

void initializeOfflineAccessibility() {
  if (!offlineAccessibilityAcceptanceEnabled) {
    return;
  }
  if (Global.profile.user.memberId?.isNotEmpty ?? false) {
    throw StateError(
        'Accessibility acceptance requires an empty isolated account');
  }
  Global.profile = Global.profile.copyWith(
      locale: 'zh_CN',
      ehConfig: Global.profile.ehConfig.copyWith(listMode: 'list'),
      customTabConfig: const CustomTabConfig(lastIndex: 0, profiles: [
        CustomProfile(
            uuid: 'offline-accessibility',
            name: 'Offline',
            searchText: ['neutral'])
      ]).oN,
      tabConfig: TabConfig(
          tabItemList: List<TabItem>.of(const [
        TabItem(name: EHRoutes.gallery, enable: true),
        TabItem(name: EHRoutes.favorite, enable: false),
        TabItem(name: EHRoutes.toplist, enable: false),
        TabItem(name: EHRoutes.download, enable: false),
        TabItem(name: EHRoutes.history, enable: false),
      ])).oN);
}
