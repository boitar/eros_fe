import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../route/eh_observer.dart';

typedef NativeNavigationTabHandler = Future<void> Function(String route);
typedef NativeNavigationBackHandler = Future<void> Function();
typedef NativeNavigationActionHandler = Future<void> Function(String action);

class NativeNavigationState {
  const NativeNavigationState({
    required this.tabId,
    required this.selectedTabId,
    required this.title,
    this.tabs = const <NativeNavigationTab>[],
    this.canGoBack = false,
    this.actions = const <NativeNavigationAction>[],
    this.toolbarActions = const <NativeNavigationAction>[],
    this.visible = true,
    this.navigationBarVisible = false,
    this.titleVisible = true,
    this.titleMonospacedDigits = false,
    this.barStyle = NativeBarStyle.system,
    this.animateBars = false,
    this.ownBar = false,
    this.backTitle = 'Back',
  });

  NativeNavigationState.withChrome(
    NativePageChrome? chrome, {
    required this.tabId,
    required this.selectedTabId,
    required String fallbackTitle,
    this.tabs = const <NativeNavigationTab>[],
    this.canGoBack = false,
    this.visible = true,
    this.backTitle = 'Back',
  })  : title = chrome?.title ?? fallbackTitle,
        actions = chrome?.actions ?? const <NativeNavigationAction>[],
        toolbarActions =
            chrome?.toolbarActions ?? const <NativeNavigationAction>[],
        navigationBarVisible = chrome?.navigationBarVisible ?? false,
        titleVisible = chrome?.titleVisible ?? true,
        titleMonospacedDigits = chrome?.titleMonospacedDigits ?? false,
        barStyle = chrome?.barStyle ?? NativeBarStyle.system,
        animateBars = chrome?.animateBars ?? false,
        ownBar = chrome?.ownBar ?? false;

  final String tabId;
  final String selectedTabId;
  final String title;
  final List<NativeNavigationTab> tabs;
  final bool canGoBack;
  final List<NativeNavigationAction> actions;

  /// Items of the bottom toolbar, shown together with the navigation bar.
  final List<NativeNavigationAction> toolbarActions;
  final bool visible;
  final bool navigationBarVisible;
  final bool titleVisible;
  final bool titleMonospacedDigits;
  final NativeBarStyle barStyle;
  final bool animateBars;

  /// The page draws its own bar; see [NativePageChrome.ownBar].
  final bool ownBar;
  final String backTitle;

  /// Finds an enabled action by id among bar items, toolbar items and menus.
  NativeNavigationAction? actionWithId(String id) =>
      NativeNavigationAction._find(<NativeNavigationAction>[
        ...actions,
        ...toolbarActions,
      ], id);

  Map<String, Object> toMap() => <String, Object>{
        'tabId': tabId,
        'selectedTabId': selectedTabId,
        'title': title,
        'tabs': tabs.map((tab) => tab.toMap()).toList(),
        'canGoBack': canGoBack,
        'actions': actions.map((action) => action.toMap()).toList(),
        'toolbarActions':
            toolbarActions.map((action) => action.toMap()).toList(),
        'visible': visible,
        'navigationBarVisible': navigationBarVisible,
        'titleVisible': titleVisible,
        'titleMonospacedDigits': titleMonospacedDigits,
        'barStyle': barStyle.name,
        'animateBars': animateBars,
        'ownBar': ownBar,
        'backTitle': backTitle,
      };
}

/// Appearance of the native bars; dark keeps media pages dark without
/// changing the brightness Flutter sees.
enum NativeBarStyle { system, dark }

/// How long an item survives when the bar runs out of room.
enum NativeBarItemPriority { standard, high, low }

class NativeNavigationTab {
  const NativeNavigationTab({
    required this.id,
    required this.title,
    this.symbol,
  });

  final String id;
  final String title;
  final String? symbol;

  Map<String, Object> toMap() => <String, Object>{
        'id': id,
        'title': title,
        'symbol': symbol ?? '',
      };
}

class NativeNavigationAction {
  const NativeNavigationAction({
    required this.id,
    required this.title,
    this.symbol,
    this.enabled = true,
    this.onPressed,
    this.children = const <NativeNavigationAction>[],
    this.inline = false,
    this.checked,
    this.selected = false,
    this.primaryWithMenu = false,
    this.prominent = false,
    this.priority = NativeBarItemPriority.standard,
    this.group = '',
  });

  final String id;
  final String title;
  final String? symbol;
  final bool enabled;
  final FutureOr<void> Function()? onPressed;

  /// Non-empty turns the item into a menu, or a section inside a menu.
  final List<NativeNavigationAction> children;

  /// Shows [children] as a titled section of the enclosing menu.
  final bool inline;

  /// Checkmark state inside a menu; null shows no state.
  final bool? checked;

  /// Toggle look for bar items that switch something on.
  final bool selected;

  /// Tapping runs [onPressed]; a long press opens [children].
  final bool primaryWithMenu;

  /// The tinted look of a confirming action such as Done.
  final bool prominent;
  final NativeBarItemPriority priority;

  /// Toolbar items with different groups are separated by flexible space.
  final String group;

  static NativeNavigationAction? _find(
      List<NativeNavigationAction> actions, String id) {
    for (final action in actions) {
      if (action.id == id) return action.enabled ? action : null;
      final child = _find(action.children, id);
      if (child != null) return child;
    }
    return null;
  }

  Map<String, Object> toMap() => <String, Object>{
        'id': id,
        'title': title,
        'symbol': symbol ?? '',
        'enabled': enabled,
        if (children.isNotEmpty)
          'children': children.map((child) => child.toMap()).toList(),
        if (inline) 'inline': true,
        if (checked != null) 'checked': checked!,
        if (selected) 'selected': true,
        if (primaryWithMenu) 'primaryWithMenu': true,
        if (prominent) 'prominent': true,
        if (priority != NativeBarItemPriority.standard)
          'priority': priority.name,
        if (group.isNotEmpty) 'group': group,
      };
}

/// Dart owns the logical navigation stack. The optional native shell only
/// mirrors this state and sends user actions back through the same channel.
class NativeNavigationBridge {
  NativeNavigationBridge._();

  static const MethodChannel _channel = MethodChannel('eros/native-navigation');
  static final ValueNotifier<bool> enabled = ValueNotifier(false);
  static final ValueNotifier<int> chromeRevision = ValueNotifier(0);
  static final ValueNotifier<int> sourceRevision = ValueNotifier(0);

  /// A root list asked to tuck its navigation bar away while scrolling.
  static final ValueNotifier<bool> rootBarCollapsed = ValueNotifier(false);
  static final Map<Object, (Object, NativePageChrome)> _chrome = {};
  static final Map<Route<dynamic>, NativeNavigationSource> _sources = {};
  static NativeNavigationConnection? _connection;

  static NativePageChrome? chromeFor(Object? key) => _chrome[key]?.$2;

  static void registerChrome(
      Object key, Object owner, NativePageChrome chrome) {
    final previous = _chrome[key]?.$2;
    _chrome[key] = (owner, chrome);
    if (previous?.signature != chrome.signature) chromeRevision.value++;
  }

  static void unregisterChrome(Object key, Object owner) {
    if (identical(_chrome[key]?.$1, owner)) {
      _chrome.remove(key);
      chromeRevision.value++;
    }
  }

  static NativeNavigationConnection initialize({
    NativeNavigationTabHandler? onSelectTab,
    NativeNavigationBackHandler? onBack,
    NativeNavigationActionHandler? onAction,
  }) {
    final connection = NativeNavigationConnection._();
    _connection = connection;
    _channel.setMethodCallHandler((call) async {
      if (!connection.isCurrent) return;
      switch (call.method) {
        case 'selectTab':
          final route = call.arguments?.toString();
          if (route != null && onSelectTab != null) {
            await onSelectTab(route);
          }
          return;
        case 'goBack':
          await onBack?.call();
          return;
        case 'action':
          final action = call.arguments?.toString();
          if (action != null && onAction != null) {
            await onAction(action);
          }
          return;
        default:
          return;
      }
    });
    return connection;
  }

  static NativeNavigationSource attachSource({
    required Route<dynamic> route,
    required NativeNavigationState Function() state,
    required NativeNavigationTabHandler onSelectTab,
    required NativeNavigationBackHandler onBack,
  }) {
    final source = NativeNavigationSource._(route, state, onSelectTab, onBack);
    _sources[route] = source;
    source.invalidate();
    return source;
  }

  static Future<bool> isNativeShellAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('getShellState') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> publish(
    NativeNavigationState state, {
    bool barCollapsed = false,
  }) async {
    try {
      await _channel.invokeMethod<void>('publishState', {
        ...state.toMap(),
        'barCollapsed': barCollapsed,
      });
    } on MissingPluginException {
      // The legacy Flutter shell remains the fallback on older systems.
    } catch (_) {
      // Navigation state is advisory; never block Dart navigation on UIKit.
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      // Optional native shell.
    } catch (_) {
      // Keep the Flutter path working.
    }
  }
}

/// A late dispose must not remove a newer host's channel handlers.
class NativeNavigationConnection {
  NativeNavigationConnection._();
  bool get isCurrent => identical(NativeNavigationBridge._connection, this);

  void dispose() {
    if (!isCurrent) return;
    NativeNavigationBridge._connection = null;
    NativeNavigationBridge._channel.setMethodCallHandler(null);
  }
}

/// Home contributes its tab state; the application host owns root navigation.
class NativeNavigationSource {
  NativeNavigationSource._(
      this.route, this.state, this.onSelectTab, this.onBack);
  final Route<dynamic> route;
  final NativeNavigationState Function() state;
  final NativeNavigationTabHandler onSelectTab;
  final NativeNavigationBackHandler onBack;

  void invalidate() => NativeNavigationBridge.sourceRevision.value++;

  void dispose() {
    if (!identical(NativeNavigationBridge._sources[route], this)) return;
    NativeNavigationBridge._sources.remove(route);
    invalidate();
  }
}

/// Lives above the root Navigator, including splash, reader and forced replaces.
class NativeNavigationHost extends StatefulWidget {
  const NativeNavigationHost({
    super.key,
    required this.observer,
    required this.navigatorKey,
    required this.child,
    this.backTitle = 'Back',
  });

  final EhNavigatorObserver observer;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final String backTitle;

  @override
  State<NativeNavigationHost> createState() => _NativeNavigationHostState();
}

class _NativeNavigationHostState extends State<NativeNavigationHost> {
  late final NativeNavigationConnection _connection;
  bool _scheduled = false;
  bool _available = false;
  List<NativeNavigationTab> _tabs = const [
    NativeNavigationTab(id: '__content__', title: 'Eros', symbol: 'book'),
  ];
  String _selected = '__content__';
  Route<dynamic>? _publishedRoute;
  NativeNavigationSource? _publishedSource;
  String? _publishedTab;

  /// The page whose bar the shell shows. A dialog or sheet floats over that
  /// page without a bar of its own; taking it for the top page would hide
  /// the bar and, with it, shift every page by the bar's band and back.
  Route<dynamic>? get _route {
    final history = widget.observer.history;
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i] is! PopupRoute) return history[i];
    }
    return null;
  }

  /// A dialog or sheet is up; the bar stays but its buttons wait for it.
  bool get _overlaid => widget.observer.history.lastOrNull is PopupRoute;

  NativeNavigationSource? get _source =>
      NativeNavigationBridge._sources[_route];
  bool get _hasPublishedContext =>
      identical(_route, _publishedRoute) &&
      identical(_source, _publishedSource) &&
      (_source == null || _source!.state().selectedTabId == _publishedTab);

  @override
  void initState() {
    super.initState();
    widget.observer.revision.addListener(_schedule);
    NativeNavigationBridge.chromeRevision.addListener(_schedule);
    NativeNavigationBridge.sourceRevision.addListener(_schedule);
    NativeNavigationBridge.rootBarCollapsed.addListener(_schedule);
    _connection = NativeNavigationBridge.initialize(
      onSelectTab: (id) async {
        if (!_hasPublishedContext || _overlaid) return;
        final source = _source;
        if (source != null && source.state().tabs.any((tab) => tab.id == id)) {
          await source.onSelectTab(id);
        }
      },
      onBack: () async {
        if (!_hasPublishedContext) return;
        final navigator = widget.navigatorKey.currentState;
        if (navigator?.canPop() ?? false) {
          await navigator!.maybePop();
        } else {
          await _source?.onBack();
        }
      },
      onAction: (id) async {
        if (!_hasPublishedContext || _overlaid) return;
        final state = _resolve();
        if (!state.navigationBarVisible) return;
        await state.actionWithId(id)?.onPressed?.call();
      },
    );
    _refreshAvailability();
  }

  Future<void> _refreshAvailability([int attempt = 0]) async {
    final available = await NativeNavigationBridge.isNativeShellAvailable();
    if (!mounted || !_connection.isCurrent) return;
    if (available) {
      _available = true;
      NativeNavigationBridge.enabled.value = true;
      await NativeNavigationBridge.setEnabled(true);
      _schedule();
    } else if (attempt < 10) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (mounted) await _refreshAvailability(attempt + 1);
    }
  }

  NativeNavigationState _resolve() {
    final source = _source;
    if (source != null) {
      final state = source.state();
      if (state.tabs.isNotEmpty) {
        _tabs = state.tabs;
        _selected = state.selectedTabId;
      }
      return state;
    }
    final chrome = NativeNavigationBridge.chromeFor(_route);
    // Keep a host for the single Flutter controller even without a Home route.
    // Its cached tab descriptors are hidden and have no remaining callbacks.
    return NativeNavigationState.withChrome(
      chrome,
      tabId: _selected,
      selectedTabId: _selected,
      tabs: _tabs,
      fallbackTitle: '',
      canGoBack: widget.navigatorKey.currentState?.canPop() ?? false,
      visible: false,
      backTitle: widget.backTitle,
    );
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && _available && _connection.isCurrent) {
        final state = _resolve();
        _publishedRoute = _route;
        _publishedSource = _source;
        _publishedTab = state.selectedTabId;
        NativeNavigationBridge.publish(
          state,
          barCollapsed:
              NativeNavigationBridge.rootBarCollapsed.value && !state.canGoBack,
        );
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(NativeNavigationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.observer != widget.observer) {
      oldWidget.observer.revision.removeListener(_schedule);
      widget.observer.revision.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void dispose() {
    widget.observer.revision.removeListener(_schedule);
    NativeNavigationBridge.chromeRevision.removeListener(_schedule);
    NativeNavigationBridge.sourceRevision.removeListener(_schedule);
    NativeNavigationBridge.rootBarCollapsed.removeListener(_schedule);
    if (_connection.isCurrent) {
      NativeNavigationBridge.enabled.value = false;
      NativeNavigationBridge.setEnabled(false);
    }
    _connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NativeNavigationScope(child: widget.child);
}

class NativePageChrome {
  const NativePageChrome({
    required this.title,
    this.actions = const [],
    this.toolbarActions = const [],
    this.navigationBarVisible = true,
    this.titleVisible = true,
    this.titleMonospacedDigits = false,
    this.barStyle = NativeBarStyle.system,
    this.animateBars = false,
    this.ownBar = false,
  });

  final String title;
  final List<NativeNavigationAction> actions;
  final List<NativeNavigationAction> toolbarActions;
  final bool navigationBarVisible;

  /// Pages whose content already names them keep only their actions in the
  /// bar; the title still labels the page for VoiceOver and the back menu.
  final bool titleVisible;
  final bool titleMonospacedDigits;
  final NativeBarStyle barStyle;
  final bool animateBars;

  /// The page draws its own Flutter bar, so the native one shows no title,
  /// back button or items for it. Beside the vertical bar it keeps its empty
  /// band, so the page starts where its neighbours do.
  final bool ownBar;

  String get signature => jsonEncode(<String, Object>{
        'title': title,
        'navigationBarVisible': navigationBarVisible,
        'titleVisible': titleVisible,
        'titleMonospacedDigits': titleMonospacedDigits,
        'barStyle': barStyle.name,
        'animateBars': animateBars,
        'ownBar': ownBar,
        'actions': actions.map((e) => e.toMap()).toList(),
        'toolbarActions': toolbarActions.map((e) => e.toMap()).toList(),
      });
}

/// What the bar shows for a page pushed over a tab's root. A page that
/// publishes nothing, such as one still on its first frame, is taken to draw
/// its own bar: beside the vertical bar the native band then stays, so the
/// page doesn't move by the band's height when the bar would otherwise hide.
NativePageChrome pushedPageChrome(Route<dynamic> route) =>
    NativeNavigationBridge.chromeFor(route) ?? _withoutChrome;

const NativePageChrome _withoutChrome = NativePageChrome(
  title: '',
  navigationBarVisible: false,
  ownBar: true,
);

class NativeNavigationScope extends InheritedNotifier<ValueNotifier<bool>> {
  NativeNavigationScope({super.key, required super.child})
      : super(notifier: NativeNavigationBridge.enabled);

  static bool isEnabled(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NativeNavigationScope>()
          ?.notifier
          ?.value ??
      false;
}

/// A page opts into managed native chrome without handing its route to UIKit.
/// Complex pages can keep their Flutter bar until they supply equivalent items.
class NativeNavigationPage extends StatefulWidget {
  const NativeNavigationPage({
    super.key,
    required this.chrome,
    required this.child,
    this.tabId,
  });

  final NativePageChrome chrome;
  final String? tabId;
  final Widget child;

  @override
  State<NativeNavigationPage> createState() => _NativeNavigationPageState();
}

class _NativeNavigationPageState extends State<NativeNavigationPage> {
  Object? _key;
  int _publication = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateChrome();
  }

  @override
  void didUpdateWidget(NativeNavigationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateChrome();
  }

  void _updateChrome() {
    final enabled = NativeNavigationScope.isEnabled(context);
    final key = enabled ? ModalRoute.of(context) ?? widget.tabId : null;
    final publication = ++_publication;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || publication != _publication) return;
      if (_key != null && _key != key) {
        NativeNavigationBridge.unregisterChrome(_key!, this);
      }
      _key = key;
      if (key != null) {
        NativeNavigationBridge.registerChrome(key, this, widget.chrome);
      }
    });
  }

  @override
  void dispose() {
    if (_key != null) NativeNavigationBridge.unregisterChrome(_key!, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
