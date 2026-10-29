import UIKit
import Flutter

final class ErosLiquidGlassPlugin {
    private static var accessibilityPlugins: [ErosAccessibilitySettingsPlugin] = []
    static func register(with registrar: FlutterPluginRegistrar) {
        registrar.register(LiquidGlassViewFactory(), withId: LiquidGlassViewFactory.viewType)
        // Native tab selection owns its touch sequence. Flutter's default
        // asynchronous gesture blocking can leave UIKit's continuous
        // selection recognizer in a stale state after a tap or reselection.
        // Hit testing still blocks this view when a Flutter route covers it.
        registrar.register(
            LiquidGlassTabBarViewFactory(messenger: registrar.messenger()),
            withId: LiquidGlassTabBarViewFactory.viewType,
            gestureRecognizersBlockingPolicy:
                FlutterPlatformViewGestureRecognizersBlockingPolicyDoNotBlockGesture
        )
        registrar.register(LiquidGlassCategoryViewFactory(messenger: registrar.messenger()), withId: LiquidGlassCategoryViewFactory.viewType)
        registrar.register(LiquidGlassPopupViewFactory(messenger: registrar.messenger()), withId: LiquidGlassPopupViewFactory.viewType)
        accessibilityPlugins.append(ErosAccessibilitySettingsPlugin(messenger: registrar.messenger()))
    }
}

final class ErosAccessibilitySettingsPlugin: NSObject, FlutterStreamHandler {
    private static let channelName = "eros/accessibility-settings"
    private let channel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private var observer: NSObjectProtocol?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterEventChannel(
            name: Self.channelName,
            binaryMessenger: messenger
        )
        super.init()
        channel.setStreamHandler(self)
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        stopObserving()
        eventSink = events
        observer = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.eventSink?(UIAccessibility.isReduceTransparencyEnabled)
        }
        events(UIAccessibility.isReduceTransparencyEnabled)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopObserving()
        return nil
    }

    private func stopObserving() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        eventSink = nil
    }

    deinit {
        stopObserving()
        channel.setStreamHandler(nil)
    }
}

final class ErosAppearancePlugin: NSObject, FlutterPlugin {
    private static let channelName = "eros/appearance"
    private static var currentStyle: UIUserInterfaceStyle = .unspecified

    /// The app palette's page colour. UIKit shows it behind Flutter during
    /// transitions and overscroll, so it must match the Flutter canvas.
    private(set) static var canvasColor: UIColor = .systemBackground
    static let canvasDidChange = Notification.Name("ErosAppearanceCanvasDidChange")

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(ErosAppearancePlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "setPalette" {
            setPalette(call.arguments, result: result)
            return
        }
        guard call.method == "setStyle" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard let value = call.arguments as? String,
              let style = Self.style(from: value) else {
            result(FlutterError(
                code: "invalid_style",
                message: "Expected light, dark, or system",
                details: nil
            ))
            return
        }

        Self.currentStyle = style
        DispatchQueue.main.async {
            Self.applyCurrentStyle()
        }
        result(nil)
    }

    private func setPalette(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let values = arguments as? [String: Any],
              let light = Self.color(values["canvas"]),
              let dark = Self.color(values["canvasDark"]) else {
            result(FlutterError(
                code: "invalid_palette",
                message: "Expected ARGB canvas and canvasDark",
                details: nil
            ))
            return
        }
        let lightContrast = Self.color(values["canvasHighContrast"]) ?? light
        let darkContrast = Self.color(values["canvasDarkHighContrast"]) ?? dark
        let canvas = UIColor { traits in
            let high = traits.accessibilityContrast == .high
            if traits.userInterfaceStyle == .dark {
                return high ? darkContrast : dark
            }
            return high ? lightContrast : light
        }
        DispatchQueue.main.async {
            Self.canvasColor = canvas
            Self.applyCurrentStyle()
            NotificationCenter.default.post(name: Self.canvasDidChange, object: nil)
        }
        result(nil)
    }

    private static func color(_ value: Any?) -> UIColor? {
        guard let number = value as? NSNumber else { return nil }
        let argb = UInt32(truncatingIfNeeded: number.int64Value)
        return UIColor(
            red: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255
        )
    }

    static func applyCurrentStyle() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                Self.applyCurrentStyle()
            }
            return
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = currentStyle
                window.backgroundColor = canvasColor
            }
        }
    }

    private static func style(from value: String) -> UIUserInterfaceStyle? {
        switch value {
        case "light":
            return .light
        case "dark":
            return .dark
        case "system":
            return .unspecified
        default:
            return nil
        }
    }
}

/// Pull-down menus for Flutter setting rows. A transparent button placed over
/// the row's value presents a real UIMenu, so the material, haptics and morph
/// all come from UIKit. Requires `performPrimaryAction` (iOS 17.4); Flutter
/// draws its own menu when this reports `false`.
final class ErosMenuPlugin: NSObject, FlutterPlugin {
    private static let channelName = "eros/menu"
    private let channel: FlutterMethodChannel
    private weak var registrar: FlutterPluginRegistrar?
    private var anchor: ErosMenuAnchor?

    private init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
        self.channel = channel
        self.registrar = registrar
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(
            ErosMenuPlugin(channel: channel, registrar: registrar),
            channel: channel
        )
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "show" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard #available(iOS 17.4, *),
              let values = call.arguments as? [String: Any],
              let token = values["token"] as? Int,
              let frame = Self.rect(values["rect"]),
              let items = values["items"] as? [[String: Any]],
              !items.isEmpty,
              let host = registrar?.viewController?.view,
              host.window != nil else {
            result(false)
            return
        }
        anchor?.cancel()

        let actions = items.enumerated().map { index, item -> UIAction in
            let symbol = item["symbol"] as? String
            let action = UIAction(
                title: item["title"] as? String ?? "",
                image: symbol.flatMap { UIImage(systemName: $0) }
            ) { [weak self] _ in
                self?.channel.invokeMethod(
                    "selected",
                    arguments: ["token": token, "index": index]
                )
            }
            action.subtitle = item["subtitle"] as? String
            action.state = item["checked"] as? Bool == true ? .on : .off
            return action
        }
        let button = ErosMenuAnchor(frame: frame)
        button.menu = UIMenu(options: .singleSelection, children: actions)
        button.showsMenuAsPrimaryAction = true
        button.isAccessibilityElement = false
        button.onEnd = { [weak self, weak button] in
            self?.channel.invokeMethod("dismissed", arguments: ["token": token])
            if let button, self?.anchor === button {
                self?.anchor = nil
            }
            button?.removeFromSuperview()
        }
        host.addSubview(button)
        anchor = button
        button.performPrimaryAction()
        result(true)
    }

    private static func rect(_ value: Any?) -> CGRect? {
        guard let values = value as? [String: Any],
              let x = values["x"] as? NSNumber,
              let y = values["y"] as? NSNumber,
              let width = values["width"] as? NSNumber,
              let height = values["height"] as? NSNumber,
              width.doubleValue > 0,
              height.doubleValue > 0 else {
            return nil
        }
        return CGRect(
            x: x.doubleValue,
            y: y.doubleValue,
            width: width.doubleValue,
            height: height.doubleValue
        )
    }
}

/// Invisible source of a settings menu; removes itself once the menu closes.
private final class ErosMenuAnchor: UIButton {
    var onEnd: (() -> Void)?

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(
            interaction,
            willEndFor: configuration,
            animator: animator
        )
        guard let animator else {
            finish()
            return
        }
        animator.addCompletion { [weak self] in self?.finish() }
    }

    /// A newer menu replaces this one before it opened or while it closes.
    func cancel() {
        contextMenuInteraction?.dismissMenu()
        finish()
    }

    private func finish() {
        let end = onEnd
        onEnd = nil
        end?()
    }
}
