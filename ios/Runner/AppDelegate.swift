import UIKit
import Flutter
import flutter_downloader
import CoreText

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FlutterDownloaderPlugin.setPluginRegistrantCallback(registerPlugins)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(
        _ engineBridge: FlutterImplicitEngineBridge
    ) {
        let registry = engineBridge.pluginRegistry
        GeneratedPluginRegistrant.register(with: registry)
        if let shareRegistrar = registry.registrar(forPlugin: "ErosSharePlugin") {
            ErosSharePlugin.register(with: shareRegistrar)
        }
        if let appearanceRegistrar = registry.registrar(forPlugin: "ErosAppearance") {
            ErosAppearancePlugin.register(with: appearanceRegistrar)
        }
        if let glassRegistrar = registry.registrar(forPlugin: "ErosLiquidGlass") {
            glassRegistrar.register(
                LiquidGlassViewFactory(),
                withId: LiquidGlassViewFactory.viewType
            )
            glassRegistrar.register(
                LiquidGlassTabBarViewFactory(messenger: glassRegistrar.messenger()),
                withId: LiquidGlassTabBarViewFactory.viewType
            )
        }
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
        ErosAppearancePlugin.applyCurrentStyle()
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

final class SceneDelegate: FlutterSceneDelegate {
    override func sceneDidEnterBackground(_ scene: UIScene) {
        let blurredInRecentTasksKey = "flutter.blurredInRecentTasks"
        if UserDefaults.standard.bool(forKey: blurredInRecentTasksKey) {
            SecurityBlurEffect.addBlurEffect()
        }
    }

    override func sceneWillEnterForeground(_ scene: UIScene) {
        SecurityBlurEffect.removeBlurEffect()
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        SecurityBlurEffect.removeBlurEffect()
        ErosAppearancePlugin.applyCurrentStyle()
    }
}

private func registerPlugins(registry: FlutterPluginRegistry) {
    if (!registry.hasPlugin("FlutterDownloaderPlugin")) {
        FlutterDownloaderPlugin.register(with: registry.registrar(forPlugin: "FlutterDownloaderPlugin")!)
    }
}

private final class ErosAppearancePlugin: NSObject, FlutterPlugin {
    private static let channelName = "eros/appearance"
    private static var currentStyle: UIUserInterfaceStyle = .unspecified

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(ErosAppearancePlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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

private final class LiquidGlassViewFactory: NSObject,
    FlutterPlatformViewFactory {
    static let viewType = "eros/liquid-glass"

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        LiquidGlassPlatformView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

private final class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
    private let platformView: UIView

    init(frame: CGRect, viewIdentifier: Int64, arguments: Any?) {
        let arguments = arguments as? [String: Any]
        let cornerRadius = (arguments?["cornerRadius"] as? NSNumber)
            .map { CGFloat(truncating: $0) } ?? 0
        let isInteractive = (arguments?["interactive"] as? NSNumber)?.boolValue ?? true
        let followSystemLiquidGlassAppearance =
            (arguments?["followSystemTransparency"] as? NSNumber)?.boolValue ?? true
        let styleName = arguments?["style"] as? String ?? "regular"
        let containerSpacing = (arguments?["containerSpacing"] as? NSNumber)
            .map { CGFloat(truncating: $0) } ?? 0

        let container = UIView(frame: frame)
        container.backgroundColor = .clear

        let effectView: UIVisualEffectView
        if #available(iOS 26.0, *), followSystemLiquidGlassAppearance {
            // UIKit owns the system Liquid Glass appearance, including the
            // iOS 27 Settings > Appearance > Liquid Glass preference. There
            // is no public API for reading that slider, so do not inspect
            // private defaults or try to reproduce the system value here.
            // Reduce Transparency and the other accessibility adjustments are
            // also applied by the system Liquid Glass implementation.
            let effect = UIGlassEffect(
                style: styleName == "clear" ? .clear : .regular
            )
            // Let UIKit supply the native pressed/hover highlight while
            // Flutter owns the tab drag and selection transition above it.
            effect.isInteractive = isInteractive
            if containerSpacing > 0 {
                let containerEffect = UIGlassContainerEffect()
                containerEffect.spacing = containerSpacing
                let containerView = UIVisualEffectView(effect: containerEffect)
                let elementView = UIVisualEffectView(effect: effect)
                elementView.frame = containerView.bounds
                elementView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                containerView.contentView.addSubview(elementView)
                effectView = containerView
            } else {
                effectView = UIVisualEffectView(effect: effect)
            }
        } else if UIAccessibility.isReduceTransparencyEnabled {
            // The opt-out path is deliberately not Liquid Glass. Keep the
            // accessibility setting honored when using the legacy fallback.
            effectView = UIVisualEffectView(effect: nil)
            effectView.backgroundColor = .secondarySystemBackground
        } else {
            // The app-level switch is off: use the pre-Liquid-Glass blur and
            // keep the setting independent from the system Liquid Glass
            // appearance slider.
            effectView = UIVisualEffectView(
                effect: UIBlurEffect(style: .systemMaterial)
            )
        }

        effectView.frame = container.bounds
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        effectView.layer.cornerRadius = cornerRadius
        effectView.layer.masksToBounds = cornerRadius > 0
        effectView.isUserInteractionEnabled = false
        container.addSubview(effectView)

        platformView = container
        super.init()
    }

    func view() -> UIView {
        platformView
    }
}

private final class LiquidGlassTabBarViewFactory: NSObject,
    FlutterPlatformViewFactory {
    static let viewType = "eros/liquid-glass-tab-bar"

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        LiquidGlassTabBarPlatformView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            messenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

private struct ErosNativeTabItem {
    let label: String
    let codePoint: Int
    let fontFamily: String?
    let fallbackSymbol: String

    init?(dictionary: [String: Any]) {
        guard let label = dictionary["label"] as? String,
              let codePoint = (dictionary["codePoint"] as? NSNumber)?.intValue else {
            return nil
        }
        self.label = label
        self.codePoint = codePoint
        self.fontFamily = dictionary["fontFamily"] as? String
        self.fallbackSymbol = dictionary["fallbackSymbol"] as? String ?? "circle.fill"
    }
}

private final class ErosLiquidGlassRootView: UIView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

/// A visual Liquid Glass layer must never win hit testing over the controls
/// that are composited above it. `isUserInteractionEnabled = false` is the
/// normal UIKit contract, but a platform-view accessibility snapshot can
/// still consider a visual-effect descendant while resolving `isHittable`.
/// Returning nil makes the visual-only role explicit for both UIKit and
/// XCTest, while leaving the sibling controls as the only event targets.
private final class ErosPassthroughGlassView: UIVisualEffectView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

private final class ErosTabButton: UIButton {
    private let contentStack = UIStackView()
    private let iconContainer = UIView()
    private let iconLabel = UILabel()
    private let fallbackImageView = UIImageView()
    private let textLabel = UILabel()
    var isCompact = false

    override var isSelected: Bool {
        didSet {
            updateColors()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        // These views only compose the button's visual content. If a generic
        // UIView remains interactive, UIKit's hit test stops at that child
        // instead of reaching UIButton and touchUpInside never fires.
        contentStack.isUserInteractionEnabled = false
        iconContainer.isUserInteractionEnabled = false
        iconLabel.isUserInteractionEnabled = false
        fallbackImageView.isUserInteractionEnabled = false
        textLabel.isUserInteractionEnabled = false
        iconLabel.textAlignment = .center
        iconLabel.adjustsFontSizeToFitWidth = true
        iconLabel.minimumScaleFactor = 0.8
        iconLabel.numberOfLines = 1
        iconLabel.baselineAdjustment = .alignCenters
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        fallbackImageView.contentMode = .scaleAspectFit
        fallbackImageView.translatesAutoresizingMaskIntoConstraints = false
        textLabel.textAlignment = .center
        textLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        textLabel.adjustsFontSizeToFitWidth = true
        textLabel.minimumScaleFactor = 0.75
        textLabel.numberOfLines = 1
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.baselineAdjustment = .alignCenters

        iconContainer.addSubview(iconLabel)
        iconContainer.addSubview(fallbackImageView)
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        contentStack.spacing = 2
        contentStack.addArrangedSubview(iconContainer)
        contentStack.addArrangedSubview(textLabel)
        iconContainer.heightAnchor.constraint(equalToConstant: 28).isActive = true
        textLabel.heightAnchor.constraint(equalToConstant: 16).isActive = true
        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            iconLabel.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor),
            iconLabel.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            iconLabel.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
            fallbackImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            fallbackImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            fallbackImageView.widthAnchor.constraint(equalToConstant: 24),
            fallbackImageView.heightAnchor.constraint(equalToConstant: 24),
        ])
        addSubview(contentStack)
        updateColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: ErosNativeTabItem, compact: Bool, font: UIFont?) {
        isCompact = compact
        accessibilityLabel = item.label
        accessibilityHint = compact ? "点击展开底栏" : nil
        iconLabel.font = font ?? UIFont.systemFont(ofSize: 22, weight: .semibold)
        if font != nil {
            iconLabel.text = String(UnicodeScalar(item.codePoint)!)
            iconLabel.isHidden = false
            fallbackImageView.isHidden = true
        } else {
            iconLabel.text = nil
            iconLabel.isHidden = true
            fallbackImageView.image = UIImage(systemName: item.fallbackSymbol)
            fallbackImageView.isHidden = false
        }
        textLabel.text = compact ? nil : item.label
        textLabel.isHidden = compact
        setNeedsLayout()
        updateColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let stackHeight: CGFloat = isCompact ? 28 : 46
        contentStack.frame = CGRect(
            x: 4,
            y: max(0, (bounds.height - stackHeight) / 2),
            width: max(0, bounds.width - 8),
            height: stackHeight
        )
    }

    private func updateColors() {
        let color: UIColor = isSelected ? .label : .secondaryLabel
        iconLabel.textColor = color
        fallbackImageView.tintColor = color
        textLabel.textColor = color
        alpha = isHighlighted ? 0.65 : 1.0
    }
}

private final class LiquidGlassTabBarPlatformView: NSObject, FlutterPlatformView,
    UIGestureRecognizerDelegate {
    private let platformView: ErosLiquidGlassRootView
    private let channel: FlutterMethodChannel
    private let glassContainerView = ErosPassthroughGlassView(effect: nil)
    private let shellGlassView = ErosPassthroughGlassView(effect: nil)
    private let selectionGlassView = ErosPassthroughGlassView(effect: nil)
    private let searchGlassView = ErosPassthroughGlassView(effect: nil)
    private let controlsView = UIView()
    private let expandedViewportView = UIView()
    private let expandedStack = UIStackView()
    private let compactButton = ErosTabButton()
    private let searchButton = UIButton(type: .system)
    private var tabButtons: [ErosTabButton] = []
    private var items: [ErosNativeTabItem] = []
    private var selectedIndex = 0
    private var collapseProgress: CGFloat = 0
    private var hideSearchOnScroll = false
    private var followSystemAppearance = true
    private var bottomInset: CGFloat = 0
    private var configuredHeight: CGFloat = 68
    private var hasSearch = false
    private var searchMaterialHidden = false
    private var effectsConfigured = false
    private var panGesture: UIPanGestureRecognizer?
    private var compactTapSuppressed = false
    private var panIsActive = false
    private var panDidMove = false
    private var dragStartIndex = 0
    private var previewIndex = 0

    // Keep the visual handoff continuous. The expanded stack starts fading
    // before the compact button appears, while interaction changes hands only
    // after the two visual states overlap. This prevents the compact icon from
    // popping in at the same instant that the expanded controls lose input.
    private let compactVisualStart: CGFloat = 0.52
    private let compactVisualEnd: CGFloat = 0.84
    private let interactionHandoff: CGFloat = 0.72

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        let root = ErosLiquidGlassRootView(frame: frame)
        platformView = root
        channel = FlutterMethodChannel(
            name: "eros/liquid-glass-tab-bar/\(viewId)",
            binaryMessenger: messenger
        )
        super.init()

        root.backgroundColor = .clear
        root.isAccessibilityElement = false
        root.onLayout = { [weak self] in
            self?.applyLayout()
        }
        configureHierarchy()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        panGesture = pan
        root.addGestureRecognizer(pan)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        apply(arguments: args as? [String: Any] ?? [:])
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func view() -> UIView {
        platformView
    }

    private func configureHierarchy() {
        [glassContainerView, shellGlassView, selectionGlassView, searchGlassView]
            .forEach {
                $0.isUserInteractionEnabled = false
                $0.isAccessibilityElement = false
                $0.accessibilityElementsHidden = true
            }
        controlsView.backgroundColor = .clear
        controlsView.isUserInteractionEnabled = true
        controlsView.isAccessibilityElement = false
        controlsView.accessibilityElementsHidden = false
        expandedViewportView.backgroundColor = .clear
        expandedViewportView.clipsToBounds = true
        expandedViewportView.isAccessibilityElement = false
        expandedViewportView.accessibilityElementsHidden = false
        // Keep the visual stack physically behind the hit-test stack as well
        // as marking it non-interactive. This avoids UIKit/XCTest treating a
        // UIGlassEffect descendant as an occluding sibling during AX queries.
        glassContainerView.layer.zPosition = -1
        controlsView.layer.zPosition = 1

        platformView.addSubview(glassContainerView)
        glassContainerView.contentView.addSubview(shellGlassView)
        glassContainerView.contentView.addSubview(selectionGlassView)
        glassContainerView.contentView.addSubview(searchGlassView)
        platformView.addSubview(controlsView)
        controlsView.addSubview(expandedViewportView)
        expandedViewportView.addSubview(expandedStack)
        controlsView.addSubview(compactButton)
        controlsView.addSubview(searchButton)

        compactButton.accessibilityIdentifier = "liquid-glass-compact-tab"
        compactButton.isHidden = true

        expandedStack.axis = .horizontal
        expandedStack.alignment = .fill
        expandedStack.distribution = .fillEqually
        expandedStack.spacing = 0

        compactButton.addTarget(self, action: #selector(didPressCompact), for: .touchDown)
        compactButton.addTarget(self, action: #selector(didTapCompact), for: .touchUpInside)
        let compactLongPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(ignoreCompactLongPress(_:))
        )
        compactLongPress.minimumPressDuration = 0.35
        compactLongPress.cancelsTouchesInView = true
        compactButton.addGestureRecognizer(compactLongPress)
        searchButton.addTarget(self, action: #selector(didTapSearch), for: .touchUpInside)
        searchButton.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        searchButton.accessibilityLabel = "搜索"
        searchButton.accessibilityIdentifier = "liquid-glass-search"
        searchButton.accessibilityTraits = .button
        searchButton.tintColor = .label
        searchButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    private func apply(arguments: [String: Any]) {
        let oldFollowSystemAppearance = followSystemAppearance
        var controlsNeedRebuild = false
        if let rawItems = arguments["items"] as? [[String: Any]] {
            let nextItems = rawItems.compactMap(ErosNativeTabItem.init(dictionary:))
            controlsNeedRebuild = items.count != nextItems.count || zip(items, nextItems).contains {
                $0.label != $1.label ||
                    $0.codePoint != $1.codePoint ||
                    $0.fontFamily != $1.fontFamily ||
                    $0.fallbackSymbol != $1.fallbackSymbol
            }
            items = nextItems
        }
        selectedIndex = clamp(
            (arguments["selectedIndex"] as? NSNumber)?.intValue ?? selectedIndex,
            count: items.count
        )
        // Flutter can rebuild while UIKit is previewing a drag. Do not let an
        // update carrying the old committed index snap the glass back under
        // the finger; the drag commits once, on release.
        if !panIsActive {
            previewIndex = selectedIndex
        }
        collapseProgress = clampProgress(arguments["collapseProgress"])
        hideSearchOnScroll = (arguments["hideSearchOnScroll"] as? NSNumber)?.boolValue ?? hideSearchOnScroll
        followSystemAppearance = (arguments["followSystemTransparency"] as? NSNumber)?.boolValue ?? followSystemAppearance
        bottomInset = max(0, number(arguments["bottomInset"], defaultValue: bottomInset))
        configuredHeight = max(0, number(arguments["height"], defaultValue: configuredHeight))
        hasSearch = (arguments["hasSearch"] as? NSNumber)?.boolValue ?? hasSearch

        if oldFollowSystemAppearance != followSystemAppearance || !effectsConfigured {
            updateVisualEffects()
        }
        if controlsNeedRebuild {
            rebuildControls()
        }
        updateSelectionState()
        applyLayout()
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "update":
            if let arguments = call.arguments as? [String: Any] {
                apply(arguments: arguments)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func rebuildControls() {
        tabButtons.forEach { button in
            expandedStack.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        tabButtons.removeAll(keepingCapacity: true)

        for (index, item) in items.enumerated() {
            let button = ErosTabButton()
            button.tag = index
            button.accessibilityIdentifier = "liquid-glass-tab-\(index)"
            button.addTarget(self, action: #selector(didTapTab(_:)), for: .touchUpInside)
            button.configure(item: item, compact: false, font: iconFont(for: item))
            expandedStack.addArrangedSubview(button)
            tabButtons.append(button)
        }

        if items.isEmpty {
            compactButton.isHidden = true
            return
        }
        compactButton.isHidden = false
        compactButton.configure(
            item: items[clamp(selectedIndex, count: items.count)],
            compact: true,
            font: iconFont(for: items[clamp(selectedIndex, count: items.count)])
        )
        updateSelectionState()
    }

    private func updateVisualEffects() {
        glassContainerView.effect = makeContainerEffect()
        shellGlassView.effect = makeElementEffect(style: .regular, interactive: false)
        selectionGlassView.effect = makeElementEffect(style: .clear, interactive: false)
        searchGlassView.effect = makeElementEffect(style: .clear, interactive: false)
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled && !followSystemAppearance
        let fallbackColor: UIColor = reduceTransparency ? .secondarySystemBackground : .clear
        [glassContainerView, shellGlassView, selectionGlassView, searchGlassView].forEach {
            $0.backgroundColor = fallbackColor
        }
        effectsConfigured = true
        applyCornerConfiguration(to: shellGlassView)
        applyCornerConfiguration(to: selectionGlassView)
        applyCornerConfiguration(to: searchGlassView)
    }

    private func makeContainerEffect() -> UIVisualEffect? {
        guard followSystemAppearance else { return nil }
        if #available(iOS 26.0, *) {
            let effect = UIGlassContainerEffect()
            effect.spacing = 12
            return effect
        }
        return nil
    }

    private enum ElementStyle {
        case regular
        case clear
    }

    private func makeElementEffect(style: ElementStyle, interactive: Bool) -> UIVisualEffect? {
        if #available(iOS 26.0, *), followSystemAppearance {
            let effect = UIGlassEffect(style: style == .clear ? .clear : .regular)
            effect.isInteractive = interactive
            return effect
        }
        if UIAccessibility.isReduceTransparencyEnabled {
            return nil
        }
        return UIBlurEffect(style: .systemMaterial)
    }

    private func applyLayout() {
        let bounds = platformView.bounds
        glassContainerView.frame = bounds
        controlsView.frame = bounds

        let progress = clampProgress(collapseProgress)
        let eased = easeInOutCubic(progress)
        let baseHeight = max(0, bounds.height - bottomInset)
        let expandedHeight = max(0, baseHeight - 12)
        let glassHeight = lerp(expandedHeight, min(expandedHeight, 48), progress)
        let searchInset: CGFloat = hasSearch ? 76 : 12
        let expandedWidth = max(0, bounds.width - 12 - searchInset)
        let compactWidth = min(48, expandedWidth)
        let shellWidth = lerp(expandedWidth, compactWidth, eased)
        let shellTop = lerp(6, 10, progress)
        let shellRadius = lerp(30, 24, progress)

        shellGlassView.frame = CGRect(
            x: 12,
            y: shellTop,
            width: shellWidth,
            height: glassHeight
        )
        applyCornerConfiguration(to: shellGlassView, radius: shellRadius)

        let shellFrame = shellGlassView.frame
        // The viewport follows the shell and clips the transition. The stack
        // itself keeps the full expanded geometry, so its arranged buttons do
        // not get narrower on every scroll tick. This is the key difference
        // between moving the expanded rail and squeezing its icons.
        let expandedShellFrame = CGRect(
            x: 12,
            y: 6,
            width: expandedWidth,
            height: expandedHeight
        )
        let expandedContentFrame = expandedShellFrame.insetBy(dx: 8, dy: 4)
        expandedViewportView.frame = shellFrame.insetBy(dx: 8, dy: 4)
        expandedStack.transform = .identity
        expandedStack.frame = CGRect(
            origin: .zero,
            size: expandedContentFrame.size
        )
        expandedStack.layoutIfNeeded()

        // Move the selected item toward the compact button's center while the
        // viewport narrows. The stack has no scale transform, so glyphs keep
        // their designed size; non-selected items leave through the clipped
        // edges instead of being compressed into the selected item.
        if !items.isEmpty,
           tabButtons.indices.contains(clamp(previewIndex, count: items.count)) {
            let selectedButton = tabButtons[clamp(previewIndex, count: items.count)]
            let selectedCenter = selectedButton.convert(
                CGPoint(x: selectedButton.bounds.midX, y: selectedButton.bounds.midY),
                to: controlsView
            )
            let compactCenter = CGPoint(
                x: shellFrame.midX,
                y: shellFrame.midY
            )
            let anchorProgress = easeInOut(
                normalizedProgress(
                    progress,
                    start: 0.20,
                    end: compactVisualEnd
                )
            )
            expandedStack.transform = CGAffineTransform(
                translationX: (compactCenter.x - selectedCenter.x) * anchorProgress,
                y: (compactCenter.y - selectedCenter.y) * anchorProgress
            )
        }

        let compactBlend = easeInOut(
            normalizedProgress(
                progress,
                start: compactVisualStart,
                end: compactVisualEnd
            )
        )
        let expandedBlend = 1.0 - easeInOut(
            normalizedProgress(
                progress,
                start: 0.28,
                end: compactVisualEnd
            )
        )
        let compactVisible = compactBlend > 0.001 && !items.isEmpty
        compactButton.frame = shellFrame
        compactButton.isCompact = true
        selectionGlassView.frame = selectionFrame()
        applyCornerConfiguration(to: selectionGlassView, radius: max(0, min(24, glassHeight / 2 - 2)))

        let expandedVisible = expandedBlend > 0.01
        expandedStack.alpha = expandedBlend
        expandedStack.isUserInteractionEnabled = progress < interactionHandoff
        expandedStack.isAccessibilityElement = false
        expandedStack.accessibilityElementsHidden = !expandedVisible || progress >= interactionHandoff
        tabButtons.forEach {
            $0.isAccessibilityElement = expandedVisible && progress < interactionHandoff
            $0.accessibilityElementsHidden = !expandedVisible || progress >= interactionHandoff
        }
        selectionGlassView.alpha = expandedBlend
        selectionGlassView.isHidden = expandedBlend <= 0.001 || items.isEmpty

        compactButton.alpha = compactBlend
        compactButton.isUserInteractionEnabled = compactVisible && progress >= interactionHandoff
        compactButton.isHidden = !compactVisible
        compactButton.isAccessibilityElement = compactVisible && progress >= interactionHandoff
        compactButton.accessibilityElementsHidden = !compactVisible || progress < interactionHandoff
        compactButton.accessibilityTraits = [.button, .selected]
        panGesture?.isEnabled = progress < interactionHandoff

        searchGlassView.isHidden = !hasSearch
        searchGlassView.frame = CGRect(
            x: max(0, bounds.width - 68),
            y: shellTop,
            width: 56,
            height: glassHeight
        )
        applyCornerConfiguration(to: searchGlassView, radius: min(28, glassHeight / 2))
        searchButton.frame = searchGlassView.frame
        let shouldHideSearch = hideSearchOnScroll && progress >= 0.84
        if shouldHideSearch != searchMaterialHidden {
            searchMaterialHidden = shouldHideSearch
            searchGlassView.effect = shouldHideSearch
                ? nil
                : makeElementEffect(style: .clear, interactive: false)
        }
        searchButton.alpha = shouldHideSearch
            ? 0
            : (hideSearchOnScroll ? 1 - easeInOut(progress) : 1)
        searchButton.isHidden = !hasSearch || shouldHideSearch
        searchButton.isUserInteractionEnabled = hasSearch && !shouldHideSearch
        searchButton.isAccessibilityElement = hasSearch && !shouldHideSearch
        searchButton.accessibilityElementsHidden = !hasSearch || shouldHideSearch

    }

    private func selectionFrame() -> CGRect {
        guard !items.isEmpty,
              tabButtons.indices.contains(clamp(previewIndex, count: items.count))
        else {
            return .zero
        }

        // The buttons live in the inset expanded stack, while the old
        // implementation calculated the capsule from the full shell width.
        // Converting the actual button frame keeps the icon, label, and clear
        // glass lens on the same rectangle at every index and during a drag.
        let button = tabButtons[clamp(previewIndex, count: items.count)]
        return button
            .convert(button.bounds, to: glassContainerView.contentView)
            .insetBy(dx: 1, dy: 1)
    }

    private func updateSelectionState() {
        selectedIndex = clamp(selectedIndex, count: items.count)
        previewIndex = clamp(previewIndex, count: items.count)
        for (index, button) in tabButtons.enumerated() {
            button.isSelected = index == previewIndex
            button.accessibilityTraits = index == previewIndex
                ? [.button, .selected]
                : [.button]
        }
        guard !items.isEmpty else { return }
        let item = items[previewIndex]
        compactButton.configure(item: item, compact: true, font: iconFont(for: item))
        compactButton.isSelected = true
        compactButton.accessibilityTraits = [.button, .selected]
    }

    private func updatePreview(index: Int) {
        previewIndex = clamp(index, count: items.count)
        updateSelectionState()
        applyLayout()
    }

    private func commitSelection(index: Int, notify: Bool) {
        selectedIndex = clamp(index, count: items.count)
        previewIndex = selectedIndex
        updateSelectionState()
        applyLayout()
        if notify {
            channel.invokeMethod("select", arguments: selectedIndex)
        }
    }

    @objc private func didTapTab(_ sender: ErosTabButton) {
        // A horizontal pan and UIButton's touch-up can both finish for the
        // same pointer. The pan owns a drag commit; suppress the trailing
        // button tap so the selection cannot visibly jump back.
        if panIsActive || panDidMove {
            panDidMove = false
            return
        }
        commitSelection(index: sender.tag, notify: true)
    }

    @objc private func didTapCompact() {
        guard !compactTapSuppressed else {
            compactTapSuppressed = false
            return
        }
        guard collapseProgress >= interactionHandoff else { return }
        channel.invokeMethod("expand", arguments: nil)
    }

    @objc private func didPressCompact() {
        compactTapSuppressed = false
    }

    @objc private func ignoreCompactLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            compactTapSuppressed = true
        }
        // The recognizer intentionally consumes the current UIButton tap.
        // A compact bar is an expand affordance, never a tab-switch gesture.
    }

    @objc private func didTapSearch() {
        channel.invokeMethod("search", arguments: nil)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !items.isEmpty, collapseProgress < interactionHandoff else { return }
        let location = gesture.location(in: platformView)
        let shellFrame = shellGlassView.frame
        switch gesture.state {
        case .began:
            guard shellFrame.contains(location) else { return }
            panIsActive = true
            panDidMove = false
            dragStartIndex = selectedIndex
            updatePreview(index: indexForPanLocation(location))
        case .changed:
            guard panIsActive else { return }
            if abs(gesture.translation(in: platformView).x) > 4 {
                panDidMove = true
            }
            if shellFrame.contains(location) {
                updatePreview(index: indexForPanLocation(location))
            }
        case .ended:
            guard panIsActive else { return }
            panIsActive = false
            commitSelection(index: previewIndex, notify: previewIndex != dragStartIndex)
        case .cancelled, .failed:
            panIsActive = false
            panDidMove = false
        default:
            break
        }
    }

    private func indexForPanLocation(_ location: CGPoint) -> Int {
        guard !items.isEmpty else { return 0 }
        let contentFrame = expandedStack.convert(expandedStack.bounds, to: platformView)
        let itemWidth = max(1, expandedStack.bounds.width / CGFloat(items.count))
        let localX = min(
            max(0, location.x - contentFrame.minX),
            max(0, expandedStack.bounds.width - 0.001)
        )
        return clamp(Int(localX / itemWidth), count: items.count)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard collapseProgress < interactionHandoff else { return false }
        guard let view = touch.view else { return true }
        if view == searchButton || view.isDescendant(of: searchButton) {
            return false
        }
        if view == compactButton || view.isDescendant(of: compactButton) {
            return false
        }
        return true
    }

    @objc private func accessibilitySettingsChanged() {
        updateVisualEffects()
        applyLayout()
    }

    private func iconFont(for item: ErosNativeTabItem) -> UIFont? {
        Self.registerFontIfNeeded()
        let names = [
            item.fontFamily,
            "FontAwesome7Free-Solid",
            "Font Awesome 7 Free Solid",
            "Font Awesome 7 Free"
        ].compactMap { $0 }
        for name in names {
            if let font = UIFont(name: name, size: 22) {
                return font
            }
        }
        return nil
    }

    private static var fontRegistered = false

    private static func registerFontIfNeeded() {
        guard !fontRegistered else { return }
        fontRegistered = true
        let relativePath = "flutter_assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf"
        var candidates: [URL] = []
        if let privateFrameworks = Bundle.main.privateFrameworksURL {
            candidates.append(privateFrameworks.appendingPathComponent("App.framework").appendingPathComponent(relativePath))
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Frameworks/App.framework").appendingPathComponent(relativePath))
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("App.framework").appendingPathComponent(relativePath))
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            break
        }
    }

    private func applyCornerConfiguration(to view: UIView, radius: CGFloat = 0) {
        if #available(iOS 26.0, *) {
            view.cornerConfiguration = .capsule()
            view.layer.masksToBounds = true
        } else {
            view.layer.cornerRadius = radius
            view.layer.masksToBounds = radius > 0
        }
    }

    private func number(_ value: Any?, defaultValue: CGFloat) -> CGFloat {
        (value as? NSNumber).map { CGFloat(truncating: $0) } ?? defaultValue
    }

    private func clampProgress(_ value: Any?) -> CGFloat {
        clamp(number(value, defaultValue: 0), min: 0, max: 1)
    }

    private func clamp(_ value: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(0, value), count - 1)
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(min, value), max)
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    private func easeInOut(_ progress: CGFloat) -> CGFloat {
        progress * progress * (3 - 2 * progress)
    }

    private func normalizedProgress(
        _ progress: CGFloat,
        start: CGFloat,
        end: CGFloat
    ) -> CGFloat {
        guard end > start else { return progress >= end ? 1 : 0 }
        return clamp((progress - start) / (end - start), min: 0, max: 1)
    }

    private func easeInOutCubic(_ progress: CGFloat) -> CGFloat {
        progress < 0.5
            ? 4 * progress * progress * progress
            : 1 - pow(-2 * progress + 2, 3) / 2
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
