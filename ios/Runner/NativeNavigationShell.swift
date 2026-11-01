import Flutter
import UIKit

/// Builds containment before the window appears, including on the legacy path.
@objc(ErosSceneRootController)
final class ErosSceneRootController: UIViewController {
    private(set) var flutterViewController: FlutterViewController?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        flutterViewController?.supportedInterfaceOrientations ?? .allButUpsideDown
    }

    override var shouldAutorotate: Bool {
        flutterViewController?.shouldAutorotate ?? true
    }

    override var childForStatusBarStyle: UIViewController? { children.first }
    override var childForStatusBarHidden: UIViewController? { children.first }
    override var childForHomeIndicatorAutoHidden: UIViewController? { children.first }
    override var childForScreenEdgesDeferringSystemGestures: UIViewController? { children.first }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let flutter = storyboard?.instantiateViewController(
            withIdentifier: "ErosFlutterContent"
        ) as? FlutterViewController else {
            preconditionFailure("Main.storyboard must contain ErosFlutterContent")
        }
        flutterViewController = flutter
        let content: UIViewController
        if #available(iOS 27.1, *) {
            content = ErosNativeNavigationShell(flutterViewController: flutter)
        } else {
            content = flutter
        }
        addChild(content)
        content.view.frame = view.bounds
        content.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(content.view)
        content.didMove(toParent: self)
    }
}

@objc(ErosFlutterViewController)
final class ErosFlutterViewController: FlutterViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ErosAdaptiveEnvironmentPlugin.geometryDidChange()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        ErosAdaptiveEnvironmentPlugin.geometryDidChange()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        ErosAdaptiveEnvironmentPlugin.geometryDidChange()
    }

    // The vertical bar only re-shows a hidden status bar when the window's
    // root is asked to refresh, not this nested content controller.
    override func setNeedsStatusBarAppearanceUpdate() {
        super.setNeedsStatusBarAppearanceUpdate()
        guard let root = view.window?.rootViewController, root !== self else {
            return
        }
        root.setNeedsStatusBarAppearanceUpdate()
        if #available(iOS 27.1, *) {
            root.setNeedsUpdateOfVerticalBarConfiguration()
        }
    }
}

/// UIKit owns only chrome. Dart remains the single owner of logical routes.
@available(iOS 27.1, *)
final class ErosNativeNavigationShell: UITabBarController,
    UITabBarControllerDelegate {
    static weak var shared: ErosNativeNavigationShell?

    // Keep one controller/engine alive even while its view moves between hosts.
    let flutterViewController: FlutterViewController
    private let navigationChannel: FlutterMethodChannel
    private var hosts: [String: NativeTabHostController] = [:]
    private var navigationControllers: [String: UINavigationController] = [:]
    private var routes = ["__pending__"]
    private weak var flutterHost: NativeTabHostController?
    private var lastState: [String: Any] = [:]
    private var applyingState = false
    private var lastBarCollapsed = false

    init(flutterViewController: FlutterViewController) {
        self.flutterViewController = flutterViewController
        navigationChannel = FlutterMethodChannel(
            name: "eros/native-navigation",
            binaryMessenger: flutterViewController.binaryMessenger
        )
        super.init(nibName: nil, bundle: nil)
        Self.shared = self
        delegate = self
        let host = NativeTabHostController()
        let navigation = UINavigationController(rootViewController: host)
        navigation.setNavigationBarHidden(true, animated: false)
        hosts["__pending__"] = host
        navigationControllers["__pending__"] = navigation
        setViewControllers([navigation], animated: false)
        moveFlutter(to: host)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func isInstalled() -> Bool { shared != nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Bars float over colourful covers: keep their symbols and the
        // selected tab monochrome and let the glass lens mark selection.
        view.tintColor = .label
        // The bar items move into the vertical bar, but a title keeps a
        // horizontal band that pushes the panes down; refresh on axis changes.
        registerForTraitChanges(
            UITraitCollection.systemTraitsAffectingVerticalBarEdge
        ) { (self: Self, _: UITraitCollection) in
            guard !self.lastState.isEmpty else { return }
            self.updateNavigationChrome(self.lastState)
        }
    }

    func applyNavigationState(_ state: [String: Any]) {
        dispatchPrecondition(condition: .onQueue(.main))
        let descriptors = (state["tabs"] as? [[String: Any]] ?? [])
            .compactMap(NativeTabDescriptor.init)
        // Ignore partial/early publications instead of destroying live tabs.
        guard !descriptors.isEmpty,
              Set(descriptors.map(\.id)).count == descriptors.count else {
            return
        }
        lastState = state
        applyingState = true
        defer { applyingState = false }
        let newRoutes = descriptors.map(\.id)
        let selectedRoute = state["selectedTabId"] as? String ?? newRoutes[0]
        let index = newRoutes.firstIndex(of: selectedRoute) ?? 0

        if routes == ["__pending__"] {
            let firstRoute = newRoutes[index]
            hosts[firstRoute] = hosts.removeValue(forKey: "__pending__")
            navigationControllers[firstRoute] =
                navigationControllers.removeValue(forKey: "__pending__")
        }
        for descriptor in descriptors {
            if hosts[descriptor.id] == nil {
                let host = NativeTabHostController()
                let navigation = UINavigationController(rootViewController: host)
                navigation.setNavigationBarHidden(true, animated: false)
                hosts[descriptor.id] = host
                navigationControllers[descriptor.id] = navigation
            }
            let item = navigationControllers[descriptor.id]!.tabBarItem!
            item.title = descriptor.title
            item.image = UIImage(systemName: descriptor.symbol)
            item.accessibilityIdentifier = "native-tab-\(descriptor.id)"
        }
        moveFlutter(to: hosts[newRoutes[index]]!)
        if routes != newRoutes {
            setViewControllers(
                newRoutes.compactMap { navigationControllers[$0] },
                animated: false
            )
        }
        routes = newRoutes
        selectedIndex = index
        hosts = hosts.filter { newRoutes.contains($0.key) }
        navigationControllers = navigationControllers.filter {
            newRoutes.contains($0.key)
        }
        updateNavigationChrome(state)
    }

    private func moveFlutter(to host: NativeTabHostController) {
        guard flutterHost !== host else { return }
        flutterHost?.detach(flutterViewController)
        host.attach(flutterViewController)
        flutterHost = host
        ErosAdaptiveEnvironmentPlugin.geometryDidChange()
    }

    private func updateNavigationChrome(_ state: [String: Any]) {
        guard selectedIndex < routes.count,
              let host = hosts[routes[selectedIndex]],
              let navigation = navigationControllers[routes[selectedIndex]] else {
            return
        }
        let canGoBack = state["canGoBack"] as? Bool ?? false
        let title = state["title"] as? String ?? ""
        let titleVisible = state["titleVisible"] as? Bool ?? true
        // A page with its own Flutter bar takes nothing from this one.
        let ownBar = state["ownBar"] as? Bool ?? false
        let showsBack = canGoBack && !ownBar
        let bar = navigation.navigationBar
        let barWasHidden = navigation.isNavigationBarHidden
        let hadBack = host.navigationItem.leftBarButtonItem != nil
        let previousTitle = host.navigationItem.title
        let usesVerticalBar = traitCollection.verticalBarEdge != .unspecified
        // Collapsing the vertical bar would reflow the panes sideways, so only
        // the horizontal bar follows the list's scroll direction.
        let collapsed = (state["barCollapsed"] as? Bool ?? false) && !usesVerticalBar
        // Beside the vertical bar an empty bar still keeps its band at the
        // top, so a page with its own bar starts where its neighbours do and
        // nothing moves while one slides over the other.
        let hidden = ownBar
            ? !usesVerticalBar
            : !(state["navigationBarVisible"] as? Bool ?? false) || collapsed
        // Items moving in and out of the vertical bar fade like the system's;
        // the horizontal bar fades as a whole below.
        let fadesItems = usesVerticalBar && !barWasHidden && !hidden
            && !UIAccessibility.isReduceMotionEnabled
        // Root lists already name themselves with the tab and group rail; a
        // title there only splits the top chrome into two separate rows.
        // Pages whose header shows the full title keep only their actions.
        host.setBarTitle(
            usesVerticalBar || !showsBack || !titleVisible ? nil : title,
            monospacedDigits: state["titleMonospacedDigits"] as? Bool ?? false
        )
        let backTitle = state["backTitle"] as? String ?? "Back"
        if !showsBack {
            host.navigationItem.setLeftBarButton(nil, animated: fadesItems)
        } else if let back = host.navigationItem.leftBarButtonItem {
            back.title = backTitle
        } else {
            let back = UIBarButtonItem(
                title: backTitle,
                image: UIImage(systemName: "chevron.backward"),
                target: self,
                action: #selector(handleBack)
            )
            back.accessibilityIdentifier = "native-back"
            host.navigationItem.setLeftBarButton(back, animated: fadesItems)
        }
        let send: (String) -> Void = { [weak self] id in
            self?.navigationChannel.invokeMethod("action", arguments: id)
        }
        let actions = ownBar ? [] : NativeBarAction.list(state["actions"]).map {
            host.barItem(for: $0, send: send)
        }
        let currentActions = host.navigationItem.rightBarButtonItems ?? []
        if !currentActions.elementsEqual(actions, by: ===) {
            host.navigationItem.setRightBarButtonItems(
                actions.isEmpty ? nil : actions,
                animated: fadesItems
            )
        }
        // Toolbar groups are separated by flexible space; the system spaces
        // items inside a group and moves them into the vertical bar.
        var toolbarItems: [UIBarButtonItem] = []
        var lastGroup: String?
        for action in ownBar ? [] : NativeBarAction.list(state["toolbarActions"]) {
            if let lastGroup, lastGroup != action.group {
                toolbarItems.append(.flexibleSpace())
            }
            toolbarItems.append(host.barItem(for: action, send: send))
            lastGroup = action.group
        }
        host.toolbarItems = toolbarItems
        let dark = state["barStyle"] as? String == "dark"
        // Only the bars change style; the Flutter controller keeps reporting
        // the app's own brightness.
        navigation.navigationBar.overrideUserInterfaceStyle = dark ? .dark : .unspecified
        navigation.toolbar.overrideUserInterfaceStyle = dark ? .dark : .unspecified
        let animateBars = (state["animateBars"] as? Bool ?? false)
            && !UIAccessibility.isReduceMotionEnabled
        let slidesBar = collapsed != lastBarCollapsed
            || (animateBars && hidden != navigation.isNavigationBarHidden)
        // A pushed page's bar fades in with the slide instead of popping in
        // ahead of it. Leaving stays immediate: the bar must go before the
        // page below lays out, and glass doesn't survive a snapshot to fade.
        let fadesBar = !slidesBar && !usesVerticalBar
            && !UIAccessibility.isReduceMotionEnabled
        navigation.setNavigationBarHidden(hidden, animated: slidesBar)
        if fadesBar, barWasHidden, !hidden {
            bar.alpha = 0
            UIView.animate(withDuration: 0.25) { bar.alpha = 1 }
        } else if fadesBar, !barWasHidden, !hidden,
                  hadBack != showsBack || previousTitle != host.navigationItem.title {
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.2
            bar.layer.add(fade, forKey: "eros.chrome")
        }
        navigation.setToolbarHidden(
            hidden || toolbarItems.isEmpty,
            animated: animateBars
        )
        lastBarCollapsed = collapsed
        let visible = state["visible"] as? Bool ?? true
        setTabBarHidden(!visible, animated: false)
        ErosAdaptiveEnvironmentPlugin.geometryDidChange()
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        guard !applyingState,
              let index = viewControllers?.firstIndex(of: viewController),
              index < routes.count,
              let host = hosts[routes[index]] else { return false }
        // Detach before UIKit starts forwarding the tab's disappearance.
        moveFlutter(to: host)
        return true
    }

    func tabBarController(
        _ tabBarController: UITabBarController,
        didSelect viewController: UIViewController
    ) {
        guard !applyingState,
              let index = viewControllers?.firstIndex(of: viewController),
              index < routes.count else { return }
        navigationChannel.invokeMethod("selectTab", arguments: routes[index])
    }

    @objc private func handleBack() {
        navigationChannel.invokeMethod("goBack", arguments: nil)
    }
}

/// A bar item or menu entry published by Dart. Menus nest; inline children
/// render as a titled section of the enclosing menu.
private struct NativeBarAction {
    let id: String
    let title: String
    let symbol: String
    let enabled: Bool
    let checked: Bool?
    let selected: Bool
    let inline: Bool
    let primaryWithMenu: Bool
    let prominent: Bool
    let priority: String
    let group: String
    let children: [NativeBarAction]
    /// Stable description of everything that affects the built item.
    let signature: String

    init?(_ value: [String: Any]) {
        guard let id = value["id"] as? String, !id.isEmpty else { return nil }
        self.id = id
        title = value["title"] as? String ?? id
        symbol = value["symbol"] as? String ?? ""
        enabled = value["enabled"] as? Bool ?? true
        checked = value["checked"] as? Bool
        selected = value["selected"] as? Bool ?? false
        inline = value["inline"] as? Bool ?? false
        primaryWithMenu = value["primaryWithMenu"] as? Bool ?? false
        prominent = value["prominent"] as? Bool ?? false
        priority = value["priority"] as? String ?? ""
        group = value["group"] as? String ?? ""
        children = Self.list(value["children"])
        let data = try? JSONSerialization.data(
            withJSONObject: value,
            options: [.sortedKeys]
        )
        signature = data.flatMap { String(data: $0, encoding: .utf8) } ?? id
    }

    static func list(_ value: Any?) -> [NativeBarAction] {
        (value as? [[String: Any]] ?? []).compactMap(NativeBarAction.init)
    }

    var image: UIImage? { symbol.isEmpty ? nil : UIImage(systemName: symbol) }

    func menuElement(send: @escaping (String) -> Void) -> UIMenuElement {
        if !children.isEmpty {
            return UIMenu(
                title: title,
                image: inline ? nil : image,
                options: inline ? [.displayInline] : [],
                children: children.map { $0.menuElement(send: send) }
            )
        }
        let id = id
        let action = UIAction(
            title: title,
            image: image,
            identifier: UIAction.Identifier(id)
        ) { _ in send(id) }
        action.attributes = enabled ? [] : [.disabled]
        if let checked { action.state = checked ? .on : .off }
        return action
    }
}

private extension NativeTabHostController {
    func setBarTitle(_ title: String?, monospacedDigits: Bool) {
        navigationItem.title = title
        guard monospacedDigits, let title else {
            navigationItem.titleView = nil
            return
        }
        // Counters keep their width while the digits change.
        let label = navigationItem.titleView as? UILabel ?? UILabel()
        label.font = .monospacedDigitSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .headline).pointSize,
            weight: .semibold
        )
        label.adjustsFontForContentSizeCategory = true
        label.text = title
        label.accessibilityTraits = .header
        label.sizeToFit()
        navigationItem.titleView = label
    }

    /// Reuses the item while its content is unchanged, so republishing a
    /// page counter neither flickers the bar nor closes an open menu.
    func barItem(
        for action: NativeBarAction,
        send: @escaping (String) -> Void
    ) -> UIBarButtonItem {
        if let cached = barItemCache[action.id], cached.signature == action.signature {
            return cached.item
        }
        let id = action.id
        let item: UIBarButtonItem
        if action.children.isEmpty {
            item = UIBarButtonItem(
                title: action.title,
                image: action.image,
                primaryAction: UIAction(title: action.title, image: action.image) { _ in
                    send(id)
                },
                menu: nil
            )
        } else {
            let menu = UIMenu(children: action.children.map { $0.menuElement(send: send) })
            item = UIBarButtonItem(
                title: action.title,
                image: action.image,
                primaryAction: action.primaryWithMenu
                    ? UIAction(title: action.title, image: action.image) { _ in send(id) }
                    : nil,
                menu: menu
            )
        }
        item.isEnabled = action.enabled
        item.isSelected = action.selected
        if action.prominent, #available(iOS 26.0, *) {
            item.style = .prominent
        }
        item.accessibilityIdentifier = id
        item.accessibilityLabel = action.title
        if #available(iOS 27.0, *) {
            switch action.priority {
            case "high": item.visibilityPriority = .high
            case "low": item.visibilityPriority = .low
            default: break
            }
        }
        barItemCache[id] = (action.signature, item)
        return item
    }
}

private struct NativeTabDescriptor {
    let id: String
    let title: String
    let symbol: String

    init?(_ value: [String: Any]) {
        guard let id = value["id"] as? String, !id.isEmpty else { return nil }
        self.id = id
        title = value["title"] as? String ?? id
        symbol = value["symbol"] as? String ?? "circle"
    }
}

private final class NativeTabHostController: UIViewController {
    private weak var flutter: FlutterViewController?
    private var constraints: [NSLayoutConstraint] = []
    fileprivate var barItemCache: [String: (signature: String, item: UIBarButtonItem)] = [:]
    private var visible = false
    private var appearing: Bool?
    private var canvasObserver: NSObjectProtocol?

    deinit {
        if let canvasObserver {
            NotificationCenter.default.removeObserver(canvasObserver)
        }
    }

    override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        flutter?.supportedInterfaceOrientations ?? .allButUpsideDown
    }
    override var shouldAutorotate: Bool { flutter?.shouldAutorotate ?? true }
    override var childForStatusBarStyle: UIViewController? { flutter }
    override var childForStatusBarHidden: UIViewController? { flutter }
    override var childForHomeIndicatorAutoHidden: UIViewController? { flutter }
    override var childForScreenEdgesDeferringSystemGestures: UIViewController? { flutter }

    // UIKit otherwise picks whichever platform-view scroll view it finds
    // first, so the top bar mask comes and goes with those views.
    private let edgeAnchorScrollView = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Seen behind Flutter while a tab or route transitions.
        view.backgroundColor = ErosAppearancePlugin.canvasColor
        canvasObserver = NotificationCenter.default.addObserver(
            forName: ErosAppearancePlugin.canvasDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.view.backgroundColor = ErosAppearancePlugin.canvasColor
        }
        edgeAnchorScrollView.isHidden = true
        edgeAnchorScrollView.isUserInteractionEnabled = false
        edgeAnchorScrollView.scrollsToTop = false
        edgeAnchorScrollView.frame = .zero
        view.addSubview(edgeAnchorScrollView)
        edgeAnchorScrollView.hideEdgeEffects()
        setContentScrollView(edgeAnchorScrollView, for: .top)
        setContentScrollView(edgeAnchorScrollView, for: .bottom)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appearing = true
        flutter?.beginAppearanceTransition(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        visible = true
        if appearing != nil { flutter?.endAppearanceTransition() }
        appearing = nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        appearing = false
        flutter?.beginAppearanceTransition(false, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        visible = false
        if appearing != nil { flutter?.endAppearanceTransition() }
        appearing = nil
    }

    func attach(_ controller: FlutterViewController) {
        precondition(controller.parent == nil)
        flutter = controller
        addChild(controller)
        if let appearing {
            controller.beginAppearanceTransition(appearing, animated: false)
        } else if visible {
            controller.beginAppearanceTransition(true, animated: false)
        }
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        constraints = [
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        controller.didMove(toParent: self)
        controller.view.subviews
            .compactMap { $0 as? UIScrollView }
            .forEach { $0.hideEdgeEffects() }
        if appearing == nil && visible { controller.endAppearanceTransition() }
    }

    func detach(_ controller: FlutterViewController) {
        guard flutter === controller else { return }
        if appearing != nil { controller.endAppearanceTransition() }
        if visible || appearing == true {
            controller.beginAppearanceTransition(false, animated: false)
        }
        controller.willMove(toParent: nil)
        NSLayoutConstraint.deactivate(constraints)
        constraints.removeAll()
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        if visible || appearing == true { controller.endAppearanceTransition() }
        flutter = nil
    }
}

extension UIScrollView {
    /// Flutter draws its own bars; a system edge mask only covers content.
    func hideEdgeEffects() {
        guard #available(iOS 26.0, *) else { return }
        topEdgeEffect.isHidden = true
        leftEdgeEffect.isHidden = true
        bottomEdgeEffect.isHidden = true
        rightEdgeEffect.isHidden = true
    }
}
