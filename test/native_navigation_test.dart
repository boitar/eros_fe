import 'package:eros_fe/adaptive/native_navigation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('page chrome changes without introducing a second route stack',
      (tester) async {
    NativeNavigationBridge.enabled.value = true;
    addTearDown(() => NativeNavigationBridge.enabled.value = false);
    final title = ValueNotifier('Gallery');
    addTearDown(title.dispose);
    await tester.pumpWidget(CupertinoApp(
      home: NativeNavigationScope(
        child: ValueListenableBuilder(
          valueListenable: title,
          builder: (_, value, __) => NativeNavigationPage(
            tabId: '/test-gallery',
            chrome: NativePageChrome(
              title: value,
              actions: const [
                NativeNavigationAction(
                    id: 'search', title: 'Search', symbol: 'magnifyingglass'),
              ],
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ));
    await tester.pump();
    final route =
        ModalRoute.of(tester.element(find.byType(NativeNavigationPage)))!;
    expect(NativeNavigationBridge.chromeFor(route)!.title, 'Gallery');
    expect(NativeNavigationBridge.chromeFor('/test-gallery'), isNull);
    title.value = 'Favorites';
    await tester.pump();
    await tester.pump();
    expect(
        NativeNavigationBridge.chromeFor(route)!.title, 'Favorites');
    NativeNavigationBridge.enabled.value = false;
    await tester.pump();
    await tester.pump();
    expect(NativeNavigationBridge.chromeFor(route), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('native shell availability and reader visibility are advisory',
      (tester) async {
    const channel = MethodChannel('eros/native-navigation');
    final publications = <Map<Object?, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'getShellState') return true;
        if (call.method == 'publishState') {
          publications.add(Map<Object?, Object?>.from(call.arguments as Map));
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    expect(await NativeNavigationBridge.isNativeShellAvailable(), isTrue);
    await NativeNavigationBridge.publish(const NativeNavigationState(
      tabId: '/gallery',
      selectedTabId: '/gallery',
      title: 'Reader',
      visible: false,
      canGoBack: true,
    ));
    expect(publications.single['visible'], isFalse);
    expect(publications.single['navigationBarVisible'], isFalse);
    expect(publications.single['canGoBack'], isTrue);
    expect(publications.single.keys, isNot(contains('routes')));
  });

  testWidgets('disposing an old channel lease cannot remove a newer handler',
      (tester) async {
    var oldCalls = 0;
    var newCalls = 0;
    final old =
        NativeNavigationBridge.initialize(onAction: (_) async => oldCalls++);
    final current =
        NativeNavigationBridge.initialize(onAction: (_) async => newCalls++);
    old.dispose();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'eros/native-navigation',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('action', 'test')),
        (_) {});
    await tester.pump();
    expect(oldCalls, 0);
    expect(newCalls, 1);
    expect(current.isCurrent, isTrue);
    current.dispose();
    expect(current.isCurrent, isFalse);
  });

  test('menus, toolbar items and title options serialize for UIKit', () {
    const state = NativeNavigationState(
      tabId: '/gallery',
      selectedTabId: '/gallery',
      title: '7 / 43',
      titleMonospacedDigits: true,
      barStyle: NativeBarStyle.dark,
      animateBars: true,
      actions: [
        NativeNavigationAction(
          id: 'more',
          title: 'More',
          symbol: 'ellipsis.circle',
          children: [
            NativeNavigationAction(
              id: 'direction',
              title: 'Reading Direction',
              inline: true,
              children: [
                NativeNavigationAction(id: 'ltr', title: 'LTR', checked: true),
                NativeNavigationAction(
                    id: 'rtl', title: 'RTL', checked: false),
              ],
            ),
          ],
        ),
      ],
      toolbarActions: [
        NativeNavigationAction(
          id: 'thumbs',
          title: 'Thumbnails',
          selected: true,
          priority: NativeBarItemPriority.high,
          group: 'view',
        ),
      ],
    );
    final map = state.toMap();
    expect(map['titleMonospacedDigits'], isTrue);
    expect(map['barStyle'], 'dark');
    expect(map['animateBars'], isTrue);
    final more = (map['actions']! as List).single as Map<String, Object>;
    final section = (more['children']! as List).single as Map<String, Object>;
    expect(section['inline'], isTrue);
    final ltr = (section['children']! as List).first as Map<String, Object>;
    expect(ltr['checked'], isTrue);
    final thumbs =
        (map['toolbarActions']! as List).single as Map<String, Object>;
    expect(thumbs['selected'], isTrue);
    expect(thumbs['priority'], 'high');
    expect(thumbs['group'], 'view');
    expect(thumbs.containsKey('checked'), isFalse);
  });

  test('a checkmark change alone republishes chrome', () {
    NativePageChrome chrome(bool checked) => NativePageChrome(
          title: 'Reader',
          toolbarActions: [
            NativeNavigationAction(
              id: 'layout',
              title: 'Layout',
              children: [
                NativeNavigationAction(
                    id: 'single', title: 'Single', checked: checked),
              ],
            ),
          ],
        );
    expect(chrome(true).signature, isNot(chrome(false).signature));
    expect(chrome(true).signature, chrome(true).signature);
  });

  test('actions are found inside menus and the toolbar', () {
    var pressed = '';
    final state = NativeNavigationState(
      tabId: '/',
      selectedTabId: '/',
      title: '',
      actions: [
        NativeNavigationAction(
          id: 'more',
          title: 'More',
          children: [
            NativeNavigationAction(
                id: 'settings',
                title: 'Settings',
                onPressed: () => pressed = 'settings'),
            NativeNavigationAction(
                id: 'disabled',
                title: 'Disabled',
                enabled: false,
                onPressed: () => pressed = 'disabled'),
          ],
        ),
      ],
      toolbarActions: [
        NativeNavigationAction(
            id: 'save', title: 'Save', onPressed: () => pressed = 'save'),
      ],
    );
    state.actionWithId('settings')!.onPressed!();
    expect(pressed, 'settings');
    state.actionWithId('save')!.onPressed!();
    expect(pressed, 'save');
    expect(state.actionWithId('disabled'), isNull);
    expect(state.actionWithId('missing'), isNull);
  });

  test('page chrome flows into the published state', () {
    const chrome = NativePageChrome(
      title: 'Gallery title',
      titleVisible: false,
      toolbarActions: [NativeNavigationAction(id: 'save', title: 'Save')],
    );
    final state = NativeNavigationState.withChrome(
      chrome,
      tabId: '/gallery',
      selectedTabId: '/gallery',
      fallbackTitle: 'Gallery',
      canGoBack: true,
    );
    expect(state.title, 'Gallery title');
    expect(state.titleVisible, isFalse);
    expect(state.navigationBarVisible, isTrue);
    expect(state.toolbarActions.single.id, 'save');
    final fallback = NativeNavigationState.withChrome(null,
        tabId: '/gallery', selectedTabId: '/gallery', fallbackTitle: 'Tab');
    expect(fallback.title, 'Tab');
    expect(fallback.navigationBarVisible, isFalse);
  });
}
