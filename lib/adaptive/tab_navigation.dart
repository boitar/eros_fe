import 'package:eros_fe/route/first_observer.dart';
import 'package:eros_fe/route/second_observer.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A destination owns both Dart stacks, regardless of its current tab position.
class TabNavigationStack {
  TabNavigationStack(this.id, this.primaryId, this.detailId)
      : primaryObserver = FirstNavigatorObserver.forId(primaryId),
        detailObserver = SecondNavigatorObserver.forId(detailId);

  final String id;
  final int primaryId;
  final int detailId;
  final FirstNavigatorObserver primaryObserver;
  final SecondNavigatorObserver detailObserver;

  bool get detailOnTop =>
      detailObserver.history.length > 1 &&
      (primaryObserver.history.length <= 1 ||
          detailObserver.activeRouteVersion >
              primaryObserver.activeRouteVersion);

  int get topNavigatorId => detailOnTop ? detailId : primaryId;

  void reset() {
    primaryObserver.resetHistory();
    detailObserver.resetHistory();
  }
}

class TabNavigationRegistry extends ChangeNotifier {
  TabNavigationRegistry({int Function()? allocateNavigatorId})
      : _allocateNavigatorId = allocateNavigatorId;

  final int Function()? _allocateNavigatorId;
  final Map<String, TabNavigationStack> _stacks = {};
  int _nextId = 1;
  String? _selected;
  bool _notificationScheduled = false;
  bool _disposed = false;

  String? get selectedId => _selected;
  TabNavigationStack? get selected => _stacks[_selected];

  TabNavigationStack stackFor(String id) => _stacks.putIfAbsent(id, () {
        final stack = TabNavigationStack(
            id,
            _allocateNavigatorId?.call() ?? _nextId++,
            _allocateNavigatorId?.call() ?? _nextId++);
        stack.primaryObserver.revision.addListener(_changed);
        stack.detailObserver.revision.addListener(_changed);
        return stack;
      });

  TabNavigationStack select(String id) {
    final stack = stackFor(id);
    if (_selected != id) {
      _selected = id;
      _changed();
    }
    return stack;
  }

  void _changed() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  void reset() {
    for (final stack in _stacks.values) {
      stack.primaryObserver.revision.removeListener(_changed);
      stack.detailObserver.revision.removeListener(_changed);
      stack.reset();
    }
    _stacks.clear();
    _selected = null;
    // GetX retains nested keys; never reuse one while an old tree unmounts.
  }

  @override
  void dispose() {
    _disposed = true;
    reset();
    super.dispose();
  }
}

class TabNavigationScope extends InheritedWidget {
  const TabNavigationScope({
    super.key,
    required this.stack,
    required super.child,
  });

  final TabNavigationStack stack;

  static TabNavigationStack? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabNavigationScope>()?.stack;

  @override
  bool updateShouldNotify(TabNavigationScope oldWidget) =>
      stack != oldWidget.stack;
}

/// Keep editable drafts while still removing an inactive tab from keyboard and
/// accessibility focus. EditableText normally clears composing on focus loss.
class RetainedTab extends StatefulWidget {
  const RetainedTab({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<RetainedTab> createState() => _RetainedTabState();
}

class _RetainedTabState extends State<RetainedTab> {
  final _RetainedDraftRegistry _registry = _RetainedDraftRegistry();
  final Map<TextEditingController, TextEditingValue> _drafts = {};
  int _generation = 0;

  @override
  void didUpdateWidget(RetainedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (!widget.active) {
      _drafts
        ..clear()
        ..addAll(_registry.values);
    }
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      final current = _registry.values;
      for (final entry in _drafts.entries) {
        if (current[entry.key]?.text == entry.value.text) {
          entry.key.value = entry.value;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => Offstage(
        offstage: !widget.active,
        child: TickerMode(
          enabled: widget.active,
          child: FocusScope(
            canRequestFocus: widget.active,
            skipTraversal: !widget.active,
            child:
                _RetainedDraftScope(registry: _registry, child: widget.child),
          ),
        ),
      );
}

class _RetainedDraftRegistry {
  final Map<Object, TextEditingController> _controllers = {};
  Map<TextEditingController, TextEditingValue> get values => {
        for (final controller in _controllers.values)
          controller: controller.value,
      };
}

class _RetainedDraftScope extends InheritedWidget {
  const _RetainedDraftScope({required this.registry, required super.child});
  final _RetainedDraftRegistry registry;

  @override
  bool updateShouldNotify(_RetainedDraftScope oldWidget) =>
      registry != oldWidget.registry;
}

/// Editors explicitly register their owned controller; no element-tree scans or
/// global controller searches are needed during a tab transition.
class RetainedDraft extends StatefulWidget {
  const RetainedDraft({
    super.key,
    required this.controller,
    required this.child,
  });
  final TextEditingController controller;
  final Widget child;

  @override
  State<RetainedDraft> createState() => _RetainedDraftState();
}

class _RetainedDraftState extends State<RetainedDraft> {
  _RetainedDraftRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(RetainedDraft oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  void _register() {
    _registry?._controllers.remove(this);
    _registry = context
        .dependOnInheritedWidgetOfExactType<_RetainedDraftScope>()
        ?.registry;
    _registry?._controllers[this] = widget.controller;
  }

  @override
  void dispose() {
    _registry?._controllers.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
