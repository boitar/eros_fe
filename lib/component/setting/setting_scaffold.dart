import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:flutter/cupertino.dart';

/// A settings page. With the native shell its title and buttons go to the
/// Liquid Glass bar; otherwise a Flutter navigation bar shows them.
class SettingScaffold extends StatelessWidget {
  const SettingScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const <NativeNavigationAction>[],
    this.trailing,
  });

  final String title;

  /// Usually a [CustomScrollView] whose slivers sit in a [SliverSafeArea].
  final Widget child;

  /// Bar buttons for the native shell.
  final List<NativeNavigationAction> actions;

  /// The same buttons for the Flutter bar.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool nativeBar = NativeNavigationScope.isEnabled(context);
    return NativeNavigationPage(
      chrome: NativePageChrome(title: title, actions: actions),
      child: CupertinoPageScaffold(
        navigationBar: nativeBar
            ? null
            : CupertinoNavigationBar(
                padding: trailing == null
                    ? null
                    : const EdgeInsetsDirectional.only(end: 8),
                middle: Text(title),
                trailing: trailing,
              ),
        child: child,
      ),
    );
  }
}
