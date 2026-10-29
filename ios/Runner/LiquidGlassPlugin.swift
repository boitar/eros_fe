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
