import 'package:collection/collection.dart';
import 'package:eros_fe/common/service/layout_service.dart';
import 'package:eros_fe/route/main_observer.dart';
import 'package:eros_fe/route/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

String get searchPageCtrlTag =>
    Get.find<ControllerTagService>().snapshot.searchTag;
String get pageCtrlTag => Get.find<ControllerTagService>().snapshot.galleryTag;

String pageCtrlTagOf(BuildContext context) =>
    ControllerTagScope.read(context)?.galleryTag ?? pageCtrlTag;
String searchPageCtrlTagOf(BuildContext context) =>
    ControllerTagScope.read(context)?.searchTag ?? searchPageCtrlTag;

class ControllerTagSnapshot {
  const ControllerTagSnapshot({this.galleryTag = '', this.searchTag = '0'});
  final String galleryTag;
  final String searchTag;
}

/// Route-local ownership also applies when an inactive tab rebuilds on resize.
class ControllerTagScope extends InheritedWidget {
  const ControllerTagScope({
    super.key,
    required this.snapshot,
    required super.child,
  });
  final ControllerTagSnapshot snapshot;

  static ControllerTagSnapshot? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ControllerTagScope>()?.snapshot;

  @override
  bool updateShouldNotify(ControllerTagScope oldWidget) =>
      snapshot != oldWidget.snapshot;
}

/// Root routes can outlive Home and its selected tab. Capture their immutable
/// ownership before descendants build or the outgoing tab registry is reset.
class ControllerTagRoute extends StatefulWidget {
  const ControllerTagRoute({super.key, required this.child});
  final Widget child;

  @override
  State<ControllerTagRoute> createState() => _ControllerTagRouteState();
}

class _ControllerTagRouteState extends State<ControllerTagRoute> {
  ControllerTagSnapshot? _snapshot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments = ModalRoute.of(context)?.settings.arguments;
    _snapshot ??= ControllerTagScope.read(context) ??
        (arguments is ControllerTagSnapshot ? arguments : null) ??
        Get.find<ControllerTagService>().snapshot;
  }

  @override
  Widget build(BuildContext context) =>
      ControllerTagScope(snapshot: _snapshot!, child: widget.child);
}

class _ControllerEntry {
  const _ControllerEntry(this.owner, this.tag, this.value);
  final String? owner;
  final String tag;
  final String value;
}

class ControllerTagService extends GetxService {
  final List<_ControllerEntry> _galleries = [];
  final List<_ControllerEntry> _searches = [];
  int _nextGallery = 0;
  int _nextSearch = 0;

  String? get _owner => Get.isRegistered<LayoutServices>()
      ? Get.find<LayoutServices>().tabNavigation.selectedId
      : null;
  String? get currentOwner => _owner;

  ControllerTagSnapshot get snapshot {
    for (final route in MainNavigatorObserver().history.reversed) {
      final arguments = route.settings.arguments;
      if (arguments is ControllerTagSnapshot) return arguments;
      if (route.settings.name == EHRoutes.home ||
          route.settings.name == EHRoutes.root) break;
    }
    return snapshotFor(_owner);
  }

  ControllerTagSnapshot snapshotFor(String? owner) => ControllerTagSnapshot(
        galleryTag:
            _galleries.lastWhereOrNull((e) => e.owner == owner)?.tag ?? '',
        searchTag:
            _searches.lastWhereOrNull((e) => e.owner == owner)?.tag ?? '0',
      );

  List<String> get pageGids =>
      _galleries.where((e) => e.owner == _owner).map((e) => e.value).toList();
  String get currGid =>
      _galleries.lastWhereOrNull((e) => e.owner == _owner)?.value ?? '';
  int get pageCtrlDepth => _galleries.where((e) => e.owner == _owner).length;
  List<String> get searchTextList =>
      _searches.where((e) => e.owner == _owner).map((e) => e.value).toList();
  String get currSearchText =>
      _searches.lastWhereOrNull((e) => e.owner == _owner)?.value ?? '';
  int get searchPageCtrlDepth =>
      _searches.where((e) => e.owner == _owner).length;

  /// Every live gallery tag for [gid], across tabs, oldest first.
  Iterable<String> galleryTagsFor(String gid) =>
      _galleries.where((e) => e.value == gid).map((e) => e.tag);

  String pushPageCtrl({String? gid, String? owner, bool unique = false}) {
    final destination = owner ?? _owner;
    final tag = destination == null && !unique
        ? gid ?? ''
        : '${gid ?? ''}@${++_nextGallery}';
    _galleries.add(_ControllerEntry(destination, tag, gid ?? ''));
    return tag;
  }

  void popPageCtrl({String? tag}) {
    final target = tag ?? snapshot.galleryTag;
    _galleries.removeWhere((e) => e.tag == target);
  }

  String pushSearchPageCtrl({String? searchText}) {
    final tag = '${++_nextSearch}';
    _searches.add(_ControllerEntry(_owner, tag, searchText ?? tag));
    return tag;
  }

  void popSearchPageCtrl({String? tag}) {
    final target = tag ?? snapshot.searchTag;
    _searches.removeWhere((e) => e.tag == target);
  }
}
