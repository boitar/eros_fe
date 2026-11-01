import UIKit
import Flutter

/// Optional geometry bridge for the Duo-ready Flutter layout.
///
/// The geometry bridge keeps the iOS 27.1 APIs behind availability checks so
/// the same binary still runs on the project's 15.6 deployment target.
final class ErosAdaptiveEnvironmentPlugin: NSObject, FlutterPlugin,
    FlutterStreamHandler {
    private static let methodChannelName = "eros/adaptive-environment"
    private static let eventChannelName = "eros/adaptive-environment/events"
    private static let navigationChannelName = "eros/native-navigation"

    private static weak var shared: ErosAdaptiveEnvironmentPlugin?
    private var eventSink: FlutterEventSink?
    private var observers: [NSObjectProtocol] = []
    private var navigationState: [String: Any] = [:]
    private weak var observedView: UIView?
    private var hingeInteraction: UIInteraction?
    private var geometryUpdateScheduled = false
    private var layoutVersion = 0
    private var lastSnapshotSignature: String?
    private var hingeState: [String: Any]?
    private var divisionRegionsSuppressed = false

    static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = ErosAdaptiveEnvironmentPlugin()
        shared = plugin
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(plugin, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(plugin)

        let navigationChannel = FlutterMethodChannel(
            name: navigationChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(plugin, channel: navigationChannel)

    }

    static func geometryDidChange() {
        guard let plugin = shared, plugin.eventSink != nil,
              !plugin.geometryUpdateScheduled else { return }
        plugin.geometryUpdateScheduled = true
        DispatchQueue.main.async { [weak plugin] in
            guard let plugin else { return }
            plugin.geometryUpdateScheduled = false
            plugin.installHingeInteractionIfAvailable()
            plugin.publishSnapshot()
        }
    }

    func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "getSnapshot":
            result(snapshot())
        case "getShellState":
            if #available(iOS 27.1, *) {
                result(ErosNativeNavigationShell.isInstalled())
            } else {
                result(false)
            }
        case "publishState":
            guard let state = call.arguments as? [String: Any] else {
                result(FlutterError(
                    code: "invalid_navigation_state",
                    message: "Navigation state must be a map",
                    details: nil
                ))
                return
            }
            navigationState = state
            if #available(iOS 27.1, *) {
                ErosNativeNavigationShell.shared?.applyNavigationState(state)
            }
            result(nil)
        case "setEnabled":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        stopObserving()
        eventSink = events
        let names: [Notification.Name] = [
            UIApplication.didBecomeActiveNotification,
            UIApplication.didChangeStatusBarFrameNotification,
            UIWindow.didBecomeKeyNotification,
            UIWindow.didBecomeVisibleNotification,
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.publishSnapshot()
            }
        }
        installHingeInteractionIfAvailable()
        publishSnapshot()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopObserving()
        return nil
    }

    private func stopObserving() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        geometryUpdateScheduled = false
        lastSnapshotSignature = nil
        if let hingeInteraction, let observedView {
            observedView.removeInteraction(hingeInteraction)
        }
        hingeInteraction = nil
        hingeState = nil
        divisionRegionsSuppressed = false
        observedView = nil
        eventSink = nil
    }

    private func publishSnapshot() {
        var value = snapshot()
        let signature = snapshotSignature(value)
        guard signature != lastSnapshotSignature else {
            return
        }
        lastSnapshotSignature = signature
        layoutVersion += 1
        value["layoutVersion"] = layoutVersion
        #if EROS_SIMULATOR_UI_TEST
        if ProcessInfo.processInfo.arguments.contains("--eros-test-semantics"),
           let data = try? JSONSerialization.data(
               withJSONObject: value, options: [.sortedKeys]
           ), let json = String(data: data, encoding: .utf8) {
            NSLog("EROS_ADAPTIVE_GEOMETRY %@", json)
        }
        #endif
        eventSink?(value)
    }

    private func snapshotSignature(_ value: [String: Any]) -> String {
        var geometry = value
        geometry.removeValue(forKey: "layoutVersion")
        // The reader follows regions, not angle estimates. An unchanged
        // geometry must not rebuild every Flutter page for a hinge sample.
        geometry.removeValue(forKey: "hinge")
        if let data = try? JSONSerialization.data(
            withJSONObject: geometry,
            options: [.sortedKeys]
        ), let string = String(data: data, encoding: .utf8) {
            return string
        }
        return [
            value["width"] as? Double ?? 0,
            value["height"] as? Double ?? 0,
            value["safeLeft"] as? Double ?? 0,
            value["safeTop"] as? Double ?? 0,
            value["safeRight"] as? Double ?? 0,
            value["safeBottom"] as? Double ?? 0,
        ].map { String($0) }.joined(separator: ":")
    }

    private func snapshot() -> [String: Any] {
        guard let view = activeFlutterViewController()?.view else {
            return [
                "width": 0.0,
                "height": 0.0,
                "safeLeft": 0.0,
                "safeTop": 0.0,
                "safeRight": 0.0,
                "safeBottom": 0.0,
                "horizontalSizeClass": 0,
                "verticalSizeClass": 0,
                "reservedRegions": [],
                "reservedRegionsSupported": false,
                "hingeSupported": false,
                "systemBarEdge": "",
                "layoutVersion": 0,
                "nativeSupported": true,
            ]
        }

        let bounds = view.bounds
        let safe = view.safeAreaInsets
        // The window's insets exclude navigation, tool and tab bars, so
        // content laid out against them stays put while those bars toggle.
        var windowSafe = safe
        if let window = view.window {
            let rect = view.convert(
                window.bounds.inset(by: window.safeAreaInsets),
                from: window
            )
            windowSafe = UIEdgeInsets(
                top: max(0, rect.minY - bounds.minY),
                left: max(0, rect.minX - bounds.minX),
                bottom: max(0, bounds.maxY - rect.maxY),
                right: max(0, bounds.maxX - rect.maxX)
            )
        }
        let traits = view.traitCollection
        let edge: String
        if #available(iOS 27.1, *) {
            // Insets alone can't tell the vertical bar from a notch.
            let rtl = traits.layoutDirection == .rightToLeft
            switch traits.verticalBarEdge {
            case .leading:
                edge = rtl ? "right" : "left"
            case .trailing:
                edge = rtl ? "left" : "right"
            default:
                edge = safe.top > safe.bottom ? "top"
                    : safe.bottom > safe.top ? "bottom" : ""
            }
        } else if safe.right > safe.left {
            edge = "right"
        } else if safe.left > safe.right {
            edge = "left"
        } else if safe.top > safe.bottom {
            edge = "top"
        } else if safe.bottom > safe.top {
            edge = "bottom"
        } else {
            edge = ""
        }

        var reservedRegions: [[String: Any]] = []
        var reservedRegionsSupported = false
        if #available(iOS 27.1, *) {
            reservedRegions = reservedRegionMaps(for: view)
            reservedRegionsSupported = true
        }

        let result: [String: Any] = [
            "width": Double(bounds.width),
            "height": Double(bounds.height),
            "safeLeft": Double(safe.left),
            "safeTop": Double(safe.top),
            "safeRight": Double(safe.right),
            "safeBottom": Double(safe.bottom),
            "windowSafeLeft": Double(windowSafe.left),
            "windowSafeTop": Double(windowSafe.top),
            "windowSafeRight": Double(windowSafe.right),
            "windowSafeBottom": Double(windowSafe.bottom),
            "horizontalSizeClass": sizeClassValue(traits.horizontalSizeClass),
            "verticalSizeClass": sizeClassValue(traits.verticalSizeClass),
            "reservedRegions": reservedRegions,
            "reservedRegionsSupported": reservedRegionsSupported,
            "hingeSupported": hingeInteraction != nil,
            "systemBarEdge": edge,
            "layoutVersion": layoutVersion,
            "nativeSupported": true,
            "hinge": hingeState as Any? ?? NSNull(),
        ]
        return result
    }

    @available(iOS 27.1, *)
    private func reservedRegionMaps(for view: UIView) -> [[String: Any]] {
        let regions = view.reservedRegions(kind: .division) +
            view.reservedRegions(kind: .occlusion)
        return regions.compactMap { region -> [String: Any]? in
            // A fully open/closed system hinge cannot have an active fold.
            // UIKit may retain the last division until its next layout pass.
            if region.kind == .division && divisionRegionsSuppressed {
                return nil
            }
            let kind = region.kind == .occlusion ? "occlusion" : "division"
            return [
                "x": Double(region.frame.origin.x),
                "y": Double(region.frame.origin.y),
                "width": Double(region.frame.size.width),
                "height": Double(region.frame.size.height),
                "kind": kind,
                "active": region.isActive,
                "marginLeft": Double(region.margins.left),
                "marginTop": Double(region.margins.top),
                "marginRight": Double(region.margins.right),
                "marginBottom": Double(region.margins.bottom),
            ]
        }
    }

    private func installHingeInteractionIfAvailable() {
        guard #available(iOS 27.1, *) else {
            return
        }
        guard let view = activeFlutterViewController()?.view else {
            return
        }
        if observedView === view, hingeInteraction != nil {
            return
        }
        if let hingeInteraction, let observedView {
            observedView.removeInteraction(hingeInteraction)
        }
        let interaction = UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            if let hinge = update.hinge {
                self.divisionRegionsSuppressed =
                    hinge.status == .fullyOpen || hinge.status == .closed
                self.hingeState = [
                    "angle": Double(hinge.angle),
                    "status": String(describing: hinge.status),
                ]
            } else {
                self.hingeState = nil
                self.divisionRegionsSuppressed = false
            }
            #if EROS_SIMULATOR_UI_TEST
            if ProcessInfo.processInfo.arguments.contains("--eros-test-semantics") {
                NSLog("EROS_ADAPTIVE_HINGE %@", String(describing: self.hingeState))
            }
            #endif
            self.observedView?.setNeedsLayout()
            // UIKit can finish updating reserved regions after the hinge
            // callback. Read them on the coalesced layout turn, not from the
            // callback's previous geometry (especially when unfolding).
            Self.geometryDidChange()
        }
        view.addInteraction(interaction)
        observedView = view
        hingeInteraction = interaction
    }

    private func sizeClassValue(_ value: UIUserInterfaceSizeClass) -> Int {
        switch value {
        case .compact:
            return 1
        case .regular:
            return 2
        case .unspecified:
            return 0
        @unknown default:
            return 0
        }
    }

    private func activeFlutterViewController() -> FlutterViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter {
                $0.activationState == .foregroundActive ||
                    $0.activationState == .foregroundInactive
            }
            .sorted {
                activationPriority($0.activationState) >
                    activationPriority($1.activationState)
            }

        for scene in scenes {
            let windows = scene.windows
                .filter {
                    !$0.isHidden &&
                        $0.alpha > 0 &&
                        !$0.bounds.isEmpty &&
                        $0.rootViewController != nil
                }
                .sorted {
                    if $0.isKeyWindow != $1.isKeyWindow {
                        return $0.isKeyWindow
                    }
                    return $0.windowLevel.rawValue > $1.windowLevel.rawValue
                }
            for window in windows {
                if let flutter = findFlutterViewController(
                    from: window.rootViewController
                ) {
                    return flutter
                }
            }
        }
        return nil
    }

    private func findFlutterViewController(
        from controller: UIViewController?
    ) -> FlutterViewController? {
        guard let controller else { return nil }
        if let flutter = controller as? FlutterViewController {
            return flutter
        }
        if let presented = controller.presentedViewController,
           !presented.isBeingDismissed,
           let flutter = findFlutterViewController(from: presented) {
            return flutter
        }
        if let navigation = controller as? UINavigationController,
           let visible = findFlutterViewController(
               from: navigation.visibleViewController
           ) {
            return visible
        }
        if let tab = controller as? UITabBarController,
           let selected = findFlutterViewController(
               from: tab.selectedViewController
           ) {
            return selected
        }
        if let split = controller as? UISplitViewController {
            for child in split.viewControllers.reversed() {
                if let flutter = findFlutterViewController(from: child) {
                    return flutter
                }
            }
        }
        for child in controller.children.reversed() {
            if let flutter = findFlutterViewController(from: child) {
                return flutter
            }
        }
        return nil
    }

    private func activationPriority(_ state: UIScene.ActivationState) -> Int {
        switch state {
        case .foregroundActive: return 3
        case .foregroundInactive: return 2
        case .background: return 1
        case .unattached: return 0
        @unknown default: return 0
        }
    }

    deinit {
        stopObserving()
    }
}
