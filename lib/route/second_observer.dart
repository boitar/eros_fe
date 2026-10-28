import 'package:eros_fe/common/service/layout_service.dart';

import 'eh_observer.dart';

class SecondNavigatorObserver extends EhNavigatorObserver {
  factory SecondNavigatorObserver() =>
      SecondNavigatorObserver.forId(detailNavigatorId ?? 2);

  factory SecondNavigatorObserver.forId(int id) =>
      _instances.putIfAbsent(id, SecondNavigatorObserver._);

  SecondNavigatorObserver._();
  static final Map<int, SecondNavigatorObserver> _instances = {};
}
