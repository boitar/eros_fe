import 'package:eros_fe/common/service/layout_service.dart';

import 'eh_observer.dart';

class FirstNavigatorObserver extends EhNavigatorObserver {
  factory FirstNavigatorObserver() =>
      FirstNavigatorObserver.forId(primaryNavigatorId ?? 1);

  factory FirstNavigatorObserver.forId(int id) =>
      _instances.putIfAbsent(id, FirstNavigatorObserver._);

  FirstNavigatorObserver._();
  static final Map<int, FirstNavigatorObserver> _instances = {};
}
