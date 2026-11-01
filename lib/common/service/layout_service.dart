import 'package:eros_fe/adaptive/tab_navigation.dart';
import 'package:eros_fe/models/base/eh_models.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:get/get.dart';

import '../global.dart';

enum LayoutMode {
  small,
  large,
}

LayoutMode get layoutMode => Get.find<LayoutServices>().layoutMode;
bool get isLayoutLarge => Get.find<LayoutServices>().isLayoutLarge;
bool get usesAdaptiveNavigation {
  if (!Get.isRegistered<LayoutServices>() ||
      !Get.find<LayoutServices>().adaptiveNavigationMounted) return false;
  final history = MainNavigatorObserver().history;
  if (history.isEmpty) return true;
  final route = history.last.settings.name;
  return route == EHRoutes.home || route == EHRoutes.root;
}

int? get primaryNavigatorId => usesAdaptiveNavigation
    ? Get.find<LayoutServices>().tabNavigation.selected?.primaryId ?? 1
    : null;
int? get detailNavigatorId => usesAdaptiveNavigation
    ? Get.find<LayoutServices>().tabNavigation.selected?.detailId ?? 2
    : null;

/// Where a list page such as search opens. A split keeps it in the list
/// column; a single column shows only the stack on top, so a list page
/// opened from a detail page goes over that page rather than under it.
int? get listNavigatorId {
  if (!usesAdaptiveNavigation) return null;
  final layout = Get.find<LayoutServices>();
  final stack = layout.tabNavigation.selected;
  if (!layout.isLayoutLarge && stack != null && stack.detailOnTop) {
    return stack.detailId;
  }
  return primaryNavigatorId;
}

EhLayoutHelper ehLayoutHelper = EhLayoutHelper();

class EhLayoutHelper {
  LayoutServices layoutServices = Get.find();

  bool get isLayoutLarge => layoutServices.isLayoutLarge;
}

class LayoutServices extends GetxService {
  LayoutMode layoutMode = LayoutMode.small;
  Object? _adaptiveOwner;
  int _nextNavigatorId = 1;
  late TabNavigationRegistry _tabNavigation = _createNavigation();
  TabNavigationRegistry get tabNavigation => _tabNavigation;
  bool get adaptiveNavigationMounted => _adaptiveOwner != null;

  TabNavigationRegistry _createNavigation() =>
      TabNavigationRegistry(allocateNavigatorId: () => _nextNavigatorId++);

  TabNavigationRegistry mountNavigation(Object owner) {
    if (_adaptiveOwner != null) _tabNavigation = _createNavigation();
    _adaptiveOwner = owner;
    return _tabNavigation;
  }

  void unmountNavigation(Object owner, TabNavigationRegistry navigation) {
    if (identical(_adaptiveOwner, owner)) {
      _adaptiveOwner = null;
      _tabNavigation = _createNavigation();
    }
    navigation.dispose();
  }

  int get activePaneNavigatorId => tabNavigation.selected?.topNavigatorId ?? 1;
  bool get isLayoutLarge => layoutMode == LayoutMode.large;

  late EhLayout _ehLayout;

  final _half = false.obs;
  bool get half => _half.value;
  set half(bool val) => _half.value = val;

  final _sideProportion = 0.0.obs;
  double get sideProportion => _sideProportion.value;
  set sideProportion(double val) => _sideProportion.value = val;

  @override
  void onInit() {
    super.onInit();

    _ehLayout = hiveHelper.getEhLayout();
    sideProportion = _ehLayout.sideProportion ?? 0.0;

    debounce<double>(
      _sideProportion,
      (double val) {
        _ehLayout = _ehLayout.copyWith(sideProportion: val.oN);
        hiveHelper.setEhLayout(_ehLayout);
      },
      time: const Duration(milliseconds: 3000),
    );
  }

  @override
  void onClose() {
    tabNavigation.dispose();
    super.onClose();
  }
}
