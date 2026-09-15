import UIKit
import Flutter
import flutter_downloader

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        GeneratedPluginRegistrant.register(with: self)
        if let shareRegistrar = registrar(forPlugin: "ErosSharePlugin") {
            ErosSharePlugin.register(with: shareRegistrar)
        }
        FlutterDownloaderPlugin.setPluginRegistrantCallback(registerPlugins)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    @objc func step(displaylink: CADisplayLink) {
        // Will be called once a frame has been built while matching desired frame rate
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        print("applicationDidEnterBackground")
        addBlurEffect()
    }

//    override func applicationWillResignActive(_ application: UIApplication) {
//        print("applicationWillResignActive")
//        addBlurEffect()
//    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        print("applicationDidBecomeActive")
        SecurityBlurEffect.removeBlurEffect()
    }
    
    override func applicationWillEnterForeground(_ application: UIApplication) {
        print("applicationWillEnterForeground")
        SecurityBlurEffect.removeBlurEffect()
    }

    func addBlurEffect() {
        let BLURRED_IN_RECENT_TASK = "flutter.blurredInRecentTasks"

        let isBlurredInRecentTasks = UserDefaults.standard.bool(forKey: BLURRED_IN_RECENT_TASK)

        print("isBlurredInRecentTasks :", isBlurredInRecentTasks)
        if isBlurredInRecentTasks {
            SecurityBlurEffect.addBlurEffect()
        }
    }
}

private func registerPlugins(registry: FlutterPluginRegistry) {
    if (!registry.hasPlugin("FlutterDownloaderPlugin")) {
        FlutterDownloaderPlugin.register(with: registry.registrar(forPlugin: "FlutterDownloaderPlugin")!)
    }
}

private final class ErosShareResult {
    private let callback: FlutterResult
    private var finished = false

    init(_ callback: @escaping FlutterResult) {
        self.callback = callback
    }

    func finish(_ value: Any?) {
        guard !finished else { return }
        finished = true
        callback(value)
    }
}

private final class ErosShareItem: NSObject, UIActivityItemSource {
    private let item: Any
    private let subject: String?

    init(item: Any, subject: String?) {
        self.item = item
        self.subject = subject
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any {
        item
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        item
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        subject ?? ""
    }
}

private final class ErosSharePlugin: NSObject, FlutterPlugin {
    private static let channelName = "cn.honjow.eros/share"
    private static let maxPresentationAttempts = 30

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(ErosSharePlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "share" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "invalid_arguments",
                message: "Share arguments are missing",
                details: nil
            ))
            return
        }

        let completion = ErosShareResult(result)
        DispatchQueue.main.async { [weak self] in
            self?.presentShare(
                arguments: arguments,
                completion: completion,
                attempt: 0
            )
        }
    }

    private func presentShare(
        arguments: [String: Any],
        completion: ErosShareResult,
        attempt: Int
    ) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let presenter = activePresenter(), canPresent(presenter) else {
            guard attempt < Self.maxPresentationAttempts else {
                completion.finish(FlutterError(
                    code: "no_presenter",
                    message: "No active view controller is available for sharing",
                    details: nil
                ))
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.presentShare(
                    arguments: arguments,
                    completion: completion,
                    attempt: attempt + 1
                )
            }
            return
        }

        guard let items = makeItems(from: arguments) else {
            completion.finish(FlutterError(
                code: "invalid_content",
                message: "No valid share content was provided",
                details: nil
            ))
            return
        }

        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes(
            from: arguments["excludedCupertinoActivities"] as? [String]
        )

        if let popover = controller.popoverPresentationController {
            // Flutter reports the anchor in window coordinates. Use the
            // containing window as the popover source so the coordinate space
            // remains correct even when the presenter is a nested controller.
            guard let presenterView = presenter.view else {
                completion.finish(FlutterError(
                    code: "no_presenter",
                    message: "The active presenter has no view",
                    details: nil
                ))
                return
            }
            let sourceView = presenterView.window ?? presenterView
            popover.sourceView = sourceView
            popover.sourceRect = normalizedOrigin(
                from: origin(from: arguments),
                in: sourceView.bounds
            )
        }

        controller.completionWithItemsHandler = {
            activityType,
            completed,
            _,
            error in
            if let error {
                completion.finish(FlutterError(
                    code: "share_failed",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else if completed {
                completion.finish(activityType?.rawValue ?? "completed")
            } else {
                completion.finish("")
            }
        }

        presenter.present(controller, animated: true)
    }

    private func makeItems(from arguments: [String: Any]) -> [Any]? {
        let text = arguments["text"] as? String
        let uri = arguments["uri"] as? String
        let paths = arguments["paths"] as? [String]
        let subject = (arguments["title"] as? String)
            ?? (arguments["subject"] as? String)

        if let uri {
            guard let url = URL(string: uri), !uri.isEmpty else {
                return nil
            }
            return [ErosShareItem(item: url, subject: subject)]
        }

        var items = [Any]()
        if let paths, !paths.isEmpty {
            for path in paths where !path.isEmpty {
                items.append(ErosShareItem(
                    item: URL(fileURLWithPath: path),
                    subject: subject
                ))
            }
            if let text, !text.isEmpty {
                items.append(ErosShareItem(item: text, subject: subject))
            }
        } else if let text, !text.isEmpty {
            items.append(ErosShareItem(item: text, subject: subject))
        }

        return items.isEmpty ? nil : items
    }

    private func activePresenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let orderedScenes = scenes.sorted { lhs, rhs in
            activationPriority(lhs.activationState) >
                activationPriority(rhs.activationState)
        }

        for scene in orderedScenes {
            guard scene.activationState == .foregroundActive ||
                scene.activationState == .foregroundInactive else {
                continue
            }
            let windows = scene.windows
                .filter {
                    !$0.isHidden &&
                        $0.alpha > 0 &&
                        $0.rootViewController != nil &&
                        !$0.bounds.isEmpty
                }
                .sorted { lhs, rhs in
                    if lhs.isKeyWindow != rhs.isKeyWindow {
                        return lhs.isKeyWindow
                    }
                    return lhs.windowLevel.rawValue > rhs.windowLevel.rawValue
                }

            if let window = windows.first,
               let root = window.rootViewController {
                return topViewController(from: root)
            }
        }
        return nil
    }

    private func activationPriority(
        _ state: UIScene.ActivationState
    ) -> Int {
        switch state {
        case .foregroundActive: return 3
        case .foregroundInactive: return 2
        case .background: return 1
        case .unattached: return 0
        @unknown default: return 0
        }
    }

    private func topViewController(
        from controller: UIViewController
    ) -> UIViewController {
        if let presented = controller.presentedViewController,
           !presented.isBeingDismissed {
            return topViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        if let split = controller as? UISplitViewController,
           let last = split.viewControllers.last {
            return topViewController(from: last)
        }
        return controller
    }

    private func canPresent(_ controller: UIViewController) -> Bool {
        guard controller.viewIfLoaded?.window != nil,
              !controller.isBeingDismissed,
              !controller.isBeingPresented,
              controller.presentedViewController == nil,
              controller.transitionCoordinator == nil else {
            return false
        }
        return true
    }

    private func origin(from arguments: [String: Any]) -> CGRect? {
        guard let x = cgFloat(arguments["originX"]),
              let y = cgFloat(arguments["originY"]),
              let width = cgFloat(arguments["originWidth"]),
              let height = cgFloat(arguments["originHeight"]) else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func cgFloat(_ value: Any?) -> CGFloat? {
        if let number = value as? NSNumber {
            return CGFloat(truncating: number)
        }
        if let value = value as? Double {
            return CGFloat(value)
        }
        if let value = value as? Int {
            return CGFloat(value)
        }
        return nil
    }

    private func normalizedOrigin(from origin: CGRect?, in bounds: CGRect) -> CGRect {
        let fallback = CGRect(
            x: max(bounds.midX - 0.5, 0),
            y: max(bounds.midY - 0.5, 0),
            width: 1,
            height: 1
        )
        guard let origin,
              !origin.isEmpty,
              origin.minX.isFinite,
              origin.minY.isFinite,
              origin.maxX.isFinite,
              origin.maxY.isFinite else {
            return fallback
        }
        let intersection = origin.intersection(bounds)
        return intersection.isNull || intersection.isEmpty
            ? fallback
            : intersection
    }

    private func excludedActivityTypes(
        from values: [String]?
    ) -> [UIActivity.ActivityType]? {
        guard let values else { return nil }
        var mapping: [String: UIActivity.ActivityType] = [
            "postToFacebook": .postToFacebook,
            "postToTwitter": .postToTwitter,
            "postToWeibo": .postToWeibo,
            "message": .message,
            "mail": .mail,
            "print": .print,
            "copyToPasteboard": .copyToPasteboard,
            "assignToContact": .assignToContact,
            "saveToCameraRoll": .saveToCameraRoll,
            "addToReadingList": .addToReadingList,
            "postToFlickr": .postToFlickr,
            "postToVimeo": .postToVimeo,
            "postToTencentWeibo": .postToTencentWeibo,
            "airDrop": .airDrop,
            "openInIBooks": .openInIBooks,
            "markupAsPDF": .markupAsPDF,
        ]
        if #available(iOS 15.4, *) {
            mapping["sharePlay"] = .sharePlay
        }
        if #available(iOS 16.0, *) {
            mapping["collaborationInviteWithLink"] =
                .collaborationInviteWithLink
            mapping["collaborationCopyLink"] = .collaborationCopyLink
        }
        if #available(iOS 16.4, *) {
            mapping["addToHomeScreen"] = .addToHomeScreen
        }
        return values.compactMap { mapping[$0] }
    }
}
