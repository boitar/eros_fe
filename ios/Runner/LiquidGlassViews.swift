import UIKit
import Flutter
import CoreText

final class LiquidGlassPopupViewFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "eros/liquid-glass-popup"
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
                arguments args: Any?) -> FlutterPlatformView {
        LiquidGlassPopupPlatformView(frame: frame, id: viewId,
                                    configuration: args as? [String: Any] ?? [:],
                                    messenger: messenger)
    }
}

/// Labels and controls belong to the effect's contentView, not Flutter siblings
/// behind the platform view. Flutter continues to own the route and callbacks.
private final class LiquidGlassPopupPlatformView: NSObject, FlutterPlatformView {
    private let root: UIView
    private let channel: FlutterMethodChannel
    private var configuration: [String: Any]
    private var observer: NSObjectProtocol?

    init(frame: CGRect, id: Int64, configuration: [String: Any],
         messenger: FlutterBinaryMessenger) {
        root = UIView(frame: frame)
        channel = FlutterMethodChannel(name: "eros/liquid-glass-popup/\(id)",
                                       binaryMessenger: messenger)
        self.configuration = configuration
        super.init()
        rebuild()
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(nil); return }
            if call.method == "update", let values = call.arguments as? [String: Any] {
                self.configuration = values
                self.rebuild()
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        observer = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.rebuild() }
    }

    deinit {
        channel.setMethodCallHandler(nil)
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func view() -> UIView { root }

    private func surface() -> UIVisualEffectView {
        let effect: UIVisualEffect?
        if UIAccessibility.isReduceTransparencyEnabled {
            effect = nil
        } else if #available(iOS 26.0, *),
                  configuration["followSystemTransparency"] as? Bool ?? true {
            effect = UIGlassEffect(style: .regular)
        } else {
            effect = UIBlurEffect(style: .systemThickMaterial)
        }
        let view = UIVisualEffectView(effect: effect)
        view.backgroundColor = effect == nil ? .secondarySystemBackground : .clear
        view.layer.cornerRadius = 28
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    private func number(_ key: String, fallback: CGFloat) -> CGFloat {
        (configuration[key] as? NSNumber).map { CGFloat(truncating: $0) } ?? fallback
    }

    private func color(_ argb: NSNumber) -> UIColor {
        let value = argb.uint32Value
        return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255,
                       alpha: CGFloat((value >> 24) & 255) / 255)
    }

    private func label(_ text: String, size: CGFloat, title: Bool) -> UILabel {
        let sheet = configuration["sheet"] as? Bool == true
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = sheet || !title ? .natural : .center
        label.font = .systemFont(ofSize: size,
                                weight: title ? (sheet ? .medium : .semibold) : .regular)
        label.textColor = sheet ? UIColor.secondaryLabel.withAlphaComponent(0.9) : .label
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = label.textAlignment
        paragraph.minimumLineHeight = size * (title && !sheet ? 1.3 : 1.35)
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: label.font as Any, .paragraphStyle: paragraph, .kern: 0
        ])
        label.accessibilityTraits = title && !sheet ? .header : .staticText
        return label
    }

    private func button(_ values: [String: Any], index: Int, cancel: Bool = false) -> UIButton {
        let sheet = configuration["sheet"] as? Bool == true && !cancel
        let symbol = sheet ? values["symbol"] as? String : nil
        let button = UIButton(type: .system)
        var style = UIButton.Configuration.plain()
        style.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20,
                                                      bottom: 14, trailing: symbol == nil ? 20 : 56)
        let font = UIFont.systemFont(ofSize: number("actionSize", fallback: 17),
                                     weight: cancel || values["primary"] as? Bool == true ? .semibold : .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = sheet ? .natural : .center
        paragraph.minimumLineHeight = font.pointSize * 1.3
        style.attributedTitle = AttributedString(values["label"] as? String ?? "",
                                                attributes: AttributeContainer([
                                                    .font: font, .paragraphStyle: paragraph, .kern: 0
                                                ]))
        style.titleAlignment = sheet ? .leading : .center
        style.titleLineBreakMode = .byWordWrapping
        let tint = (configuration["tint"] as? NSNumber).map(color) ?? .systemBlue
        let destructive = values["destructive"] as? Bool == true
        style.baseForegroundColor = destructive ? .systemRed : (sheet ? .label : tint)
        if let argb = values["color"] as? NSNumber {
            style.baseForegroundColor = color(argb)
        }
        button.configuration = style
        button.contentHorizontalAlignment = sheet ? .leading : .center
        button.titleLabel?.numberOfLines = 0
        button.isEnabled = values["enabled"] as? Bool ?? true
        if let symbol, let image = UIImage(systemName: symbol) {
            let icon = UIImageView(image: image)
            icon.tintColor = destructive ? .systemRed : .secondaryLabel
            icon.isAccessibilityElement = false
            icon.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(icon)
            NSLayoutConstraint.activate([
                icon.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -20),
                icon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 20),
                icon.heightAnchor.constraint(equalToConstant: 20)
            ])
            icon.contentMode = .scaleAspectFit
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        button.addAction(UIAction { [weak self] _ in
            self?.channel.invokeMethod("action", arguments: index)
        }, for: .touchUpInside)
        return button
    }

    private func rebuild() {
        root.subviews.forEach { $0.removeFromSuperview() }
        root.overrideUserInterfaceStyle = configuration["dark"] as? Bool == true ? .dark : .light
        root.semanticContentAttribute = configuration["rtl"] as? Bool == true
            ? .forceRightToLeft : .forceLeftToRight
        let outer = UIStackView()
        outer.axis = .vertical
        outer.spacing = 8
        outer.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: root.topAnchor),
            outer.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            outer.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: root.trailingAnchor)
        ])
        let main = surface()
        outer.addArrangedSubview(main)
        let scroll = UIScrollView()
        scroll.hideEdgeEffects()
        scroll.alwaysBounceVertical = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        main.contentView.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: main.contentView.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: main.contentView.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: main.contentView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: main.contentView.trailingAnchor)
        ])
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        let title = configuration["title"] as? String ?? ""
        let message = configuration["message"] as? String ?? ""
        let sheet = configuration["sheet"] as? Bool == true
        if !title.isEmpty || !message.isEmpty {
            let header = UIStackView()
            header.axis = .vertical
            header.spacing = 8
            header.isLayoutMarginsRelativeArrangement = true
            header.directionalLayoutMargins = NSDirectionalEdgeInsets(top: sheet ? 16 : 22,
                                                                      leading: sheet ? 20 : 22,
                                                                      bottom: sheet ? 16 : 22,
                                                                      trailing: sheet ? 20 : 22)
            if !title.isEmpty {
                header.addArrangedSubview(label(title, size: number("titleSize", fallback: sheet ? 15 : 19), title: true))
            }
            if !message.isEmpty {
                header.addArrangedSubview(label(message, size: number("messageSize", fallback: sheet ? 13 : 15), title: false))
            }
            stack.addArrangedSubview(header)
        }
        let actions = configuration["actions"] as? [[String: Any]] ?? []
        let hasCancel = configuration["hasCancel"] as? Bool == true
        for (index, action) in actions.enumerated() {
            if hasCancel && index == actions.count - 1 {
                let cancel = surface()
                let control = button(action, index: index, cancel: true)
                control.translatesAutoresizingMaskIntoConstraints = false
                cancel.contentView.addSubview(control)
                NSLayoutConstraint.activate([
                    control.topAnchor.constraint(equalTo: cancel.contentView.topAnchor),
                    control.bottomAnchor.constraint(equalTo: cancel.contentView.bottomAnchor),
                    control.leadingAnchor.constraint(equalTo: cancel.contentView.leadingAnchor),
                    control.trailingAnchor.constraint(equalTo: cancel.contentView.trailingAnchor)
                ])
                cancel.setContentCompressionResistancePriority(.required, for: .vertical)
                outer.addArrangedSubview(cancel)
                continue
            }
            if !stack.arrangedSubviews.isEmpty {
                let separator = UIView()
                separator.backgroundColor = .separator
                separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                stack.addArrangedSubview(separator)
            }
            stack.addArrangedSubview(button(action, index: index))
        }
    }
}

final class LiquidGlassViewFactory: NSObject,
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
    private var appearanceObserver: NSObjectProtocol?
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
        let usesSystemLiquidGlass: Bool
        if #available(iOS 26.0, *), followSystemLiquidGlassAppearance {
            usesSystemLiquidGlass = true
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
            usesSystemLiquidGlass = false
            // The opt-out path is deliberately not Liquid Glass. Keep the
            // accessibility setting honored when using the legacy fallback.
            effectView = UIVisualEffectView(effect: nil)
            effectView.backgroundColor = .secondarySystemBackground
        } else {
            usesSystemLiquidGlass = false
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
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak effectView] _ in
            guard !usesSystemLiquidGlass else { return }
            effectView?.effect = UIAccessibility.isReduceTransparencyEnabled
                ? nil
                : UIBlurEffect(style: .systemMaterial)
            effectView?.backgroundColor = UIAccessibility.isReduceTransparencyEnabled
                ? .secondarySystemBackground
                : .clear
        }
        super.init()
    }

    deinit {
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
        }
    }

    func view() -> UIView {
        platformView
    }
}

final class LiquidGlassTabBarViewFactory: NSObject,
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
        SystemLiquidGlassTabBarPlatformView(
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
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
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

/// Keep the material, selection lens and labels in one native platform view.
/// Separate effect views retain the inner lens rather than merging it into
/// the encompassing shell as overlapping members of a glass container would.
final class LiquidGlassCategoryViewFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "eros/liquid-glass-categories"
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
                arguments args: Any?) -> FlutterPlatformView {
        LiquidGlassCategoryPlatformView(frame: frame, viewId: viewId,
                                       arguments: args, messenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

private final class ErosCategoryButton: UIButton {
    override func contentRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: 10, dy: 0)
    }
}

private final class ErosCategoryScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool { true }
}

private final class LiquidGlassCategoryPlatformView: NSObject,
    FlutterPlatformView, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    private let root: ErosLiquidGlassRootView
    private let shell = ErosPassthroughGlassView()
    private let lens = ErosPassthroughGlassView()
    private let controls = ErosCategoryScrollView()
    private var ids: [String] = []
    private var layoutName = ""
    private var needsReveal = true
    private var restoredOffset = false
    private var initialOffset: CGFloat = 0
    private var pageProgress: CGFloat?
    private let channel: FlutterMethodChannel
    private var buttons: [UIButton] = []
    private var titles: [String] = []
    private var longPressEnabled: [Bool] = []
    private var selectedIndex = -1
    private var previewIndex = -1
    private var followSystem = true
    private var effectsConfigured = false
    private var fontSize: CGFloat = 15
    private var opacity: CGFloat = 1
    /// Segment widths laid out by Dart, which owns the shared rail geometry.
    private var segmentWidths: [CGFloat] = []
    private let lensInset: CGFloat = 3

    init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
        root = ErosLiquidGlassRootView(frame: frame)
        channel = FlutterMethodChannel(name: "eros/liquid-glass-categories/\(viewId)",
                                       binaryMessenger: messenger)
        super.init()
        root.backgroundColor = .clear
        root.isAccessibilityElement = false
        for effect in [shell, lens] {
            effect.isUserInteractionEnabled = false
            effect.accessibilityElementsHidden = true
            effect.layer.masksToBounds = true
            root.addSubview(effect)
        }
        controls.accessibilityIdentifier = "liquid-glass-category-scroll"
        controls.hideEdgeEffects()
        controls.showsHorizontalScrollIndicator = false
        controls.alwaysBounceHorizontal = false
        controls.delaysContentTouches = true
        controls.canCancelContentTouches = true
        controls.delegate = self
        root.addSubview(controls)
        lens.removeFromSuperview()
        controls.addSubview(lens)
        root.onLayout = { [weak self] in self?.layout() }
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(nil); return }
            if call.method == "update", let arguments = call.arguments as? [String: Any] {
                self.apply(arguments)
                result(nil)
            } else if call.method == "progress", let progress = call.arguments as? NSNumber {
                self.pageProgress = CGFloat(progress.doubleValue)
                self.updateProgress()
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(updateEffects),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        apply(arguments as? [String: Any] ?? [:])
    }

    deinit {
        channel.setMethodCallHandler(nil)
        NotificationCenter.default.removeObserver(self)
    }

    func view() -> UIView { root }

    private func apply(_ arguments: [String: Any]) {
        let nextTitles = arguments["titles"] as? [String] ?? titles
        let nextIds = arguments["ids"] as? [String] ?? ids
        let rebuild = nextTitles != titles || nextIds != ids
        ids = nextIds
        let nextLayout = arguments["layout"] as? String ?? layoutName
        if nextLayout != layoutName {
            controls.setContentOffset(controls.contentOffset, animated: false)
            pageProgress = nil
            needsReveal = true
        }
        layoutName = nextLayout
        initialOffset = CGFloat((arguments["offset"] as? NSNumber)?.doubleValue ?? 0)
        titles = nextTitles
        longPressEnabled = arguments["longPressEnabled"] as? [Bool] ?? longPressEnabled
        fontSize = CGFloat((arguments["fontSize"] as? NSNumber)?.doubleValue ?? 15)
        if let widths = arguments["segmentWidths"] as? [NSNumber] {
            segmentWidths = widths.map { CGFloat($0.doubleValue) }
        }
        opacity = min(1, max(0, CGFloat((arguments["opacity"] as? NSNumber)?.doubleValue ?? 1)))
        root.alpha = opacity
        let interactive = arguments["interactive"] as? Bool ?? true
        controls.isUserInteractionEnabled = interactive
        controls.accessibilityElementsHidden = !interactive || opacity <= 0
        root.overrideUserInterfaceStyle = (arguments["dark"] as? Bool ?? false) ? .dark : .light
        let nextFollow = arguments["followSystemTransparency"] as? Bool ?? followSystem
        if nextFollow != followSystem || !effectsConfigured {
            followSystem = nextFollow
            updateEffects()
        }
        let nextIndex = ids.firstIndex(of: arguments["selectedId"] as? String ?? "") ?? -1
        let selectionChanged = nextIndex != selectedIndex
        if selectionChanged || rebuild { needsReveal = true }
        selectedIndex = nextIndex
        if rebuild {
            buttons.forEach { $0.removeFromSuperview() }
            buttons = titles.enumerated().map { index, title in
                let button = ErosCategoryButton(type: .custom)
                button.tag = index
                button.setTitle(title, for: .normal)
                button.titleLabel?.numberOfLines = 1
                button.titleLabel?.lineBreakMode = .byClipping
                button.accessibilityLabel = title
                button.accessibilityIdentifier = "liquid-glass-category-\(index)"
                button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
                longPress.delegate = self
                button.addGestureRecognizer(longPress)
                controls.addSubview(button)
                return button
            }
            previewIndex = selectedIndex
            layout()
        }
        updateLabels()
        layout()
        if selectionChanged { showSelection(selectedIndex, animated: true) }
    }

    @objc private func updateEffects() {
        if #available(iOS 26.0, *), followSystem {
            shell.effect = UIGlassEffect(style: .regular)
            lens.effect = UIGlassEffect(style: .clear)
            shell.backgroundColor = .clear
            lens.backgroundColor = .clear
        } else if UIAccessibility.isReduceTransparencyEnabled {
            shell.effect = nil
            lens.effect = nil
            shell.backgroundColor = .secondarySystemBackground
            lens.backgroundColor = .tertiarySystemBackground
        } else {
            shell.effect = UIBlurEffect(style: .systemMaterial)
            lens.effect = UIBlurEffect(style: .systemThinMaterial)
            shell.backgroundColor = .clear
            lens.backgroundColor = .clear
        }
        effectsConfigured = true
    }

    private func layout() {
        shell.frame = root.bounds
        shell.layer.cornerRadius = root.bounds.height / 2
        root.layer.cornerRadius = root.bounds.height / 2
        root.clipsToBounds = true
        let sizeChanged = restoredOffset && controls.bounds.size != root.bounds.size
        controls.frame = root.bounds
        let provided = segmentWidths.count == buttons.count && !buttons.isEmpty
        let widths = provided ? segmentWidths : buttons.enumerated().map { index, _ -> CGFloat in
            let regular = (titles[index] as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: fontSize)]).width
            let bold = (titles[index] as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: fontSize, weight: .semibold)]).width
            return max(44, max(regular, bold) + 28)
        }
        let naturalWidth = widths.reduce(0, +)
        // Dart-provided widths already fill the track; never add gaps to them.
        let fits = naturalWidth <= root.bounds.width + 0.5
        let gap = !provided && fits && buttons.count > 1
            ? (root.bounds.width - naturalWidth) / CGFloat(buttons.count - 1)
            : 0
        var x = !provided && fits && buttons.count == 1
            ? (root.bounds.width - naturalWidth) / 2
            : 0
        for (index, button) in buttons.enumerated() {
            let width = widths[index]
            button.frame = CGRect(x: x, y: 0, width: width, height: root.bounds.height)
            x += width + (index < buttons.count - 1 ? gap : 0)
        }
        controls.contentSize = CGSize(
            width: fits ? max(root.bounds.width, naturalWidth) : naturalWidth,
            height: root.bounds.height
        )
        if !restoredOffset && root.bounds.width > 0 {
            controls.contentOffset.x = min(max(0, initialOffset), max(0, x - root.bounds.width))
            restoredOffset = true
            // A remount after collapse preserves deliberate browsing away from selection.
            if initialOffset > 0 { needsReveal = false }
        }
        lens.frame = selectionFrame(previewIndex)
        lens.layer.cornerRadius = max(0, root.bounds.height / 2 - lensInset)
        lens.isHidden = !titles.indices.contains(previewIndex)
        if let _ = pageProgress { updateProgress() }
        if (needsReveal || sizeChanged), buttons.indices.contains(selectedIndex), root.bounds.width > 0 {
            controls.scrollRectToVisible(buttons[selectedIndex].frame, animated: false)
            needsReveal = false
        }
    }

    private func updateProgress() {
        guard let progress = pageProgress, !buttons.isEmpty else { return }
        let page = min(CGFloat(buttons.count - 1), max(0, progress))
        let lower = Int(floor(page)), upper = Int(ceil(page))
        let t = page - CGFloat(lower)
        let a = selectionFrame(lower), b = selectionFrame(upper)
        lens.layer.removeAllAnimations()
        lens.isHidden = false
        lens.frame = CGRect(x: a.minX + (b.minX - a.minX) * t, y: a.minY,
                            width: a.width + (b.width - a.width) * t, height: a.height)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        channel.invokeMethod("offset", arguments: Double(scrollView.contentOffset.x))
    }

    private func selectionFrame(_ index: Int) -> CGRect {
        guard buttons.indices.contains(index) else { return .zero }
        return buttons[index].frame.insetBy(dx: lensInset, dy: lensInset)
    }

    private func updateLabels() {
        for (index, button) in buttons.enumerated() {
            let selected = index == previewIndex
            button.isSelected = selected
            button.setTitleColor(selected ? .systemBlue : .label, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: fontSize,
                                                  weight: selected ? .semibold : .regular)
            button.accessibilityTraits = selected ? [.button, .selected] : [.button]
        }
    }

    private func showSelection(_ index: Int, animated: Bool) {
        let wasHidden = lens.isHidden
        previewIndex = index
        updateLabels()
        lens.isHidden = !titles.indices.contains(index)
        let target = selectionFrame(index)
        guard animated, !wasHidden, !lens.isHidden,
              !UIAccessibility.isReduceMotionEnabled else {
            lens.layer.removeAllAnimations()
            lens.frame = target
            return
        }
        UIView.animate(withDuration: 0.30, delay: 0,
                       usingSpringWithDamping: 0.86, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.lens.frame = target
        }
    }

    @objc private func tapped(_ button: UIButton) {
        guard !controls.isDragging && !controls.isDecelerating else { return }
        commit(button.tag)
    }

    private func commit(_ index: Int) {
        guard titles.indices.contains(index) else { return }
        selectedIndex = index
        showSelection(index, animated: true)
        channel.invokeMethod("select", arguments: ids[index])
    }

    @objc private func held(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let button = gesture.view as? UIButton,
              longPressEnabled.indices.contains(button.tag), longPressEnabled[button.tag] else { return }
        channel.invokeMethod("longPress", arguments: ids[button.tag])
    }

    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        if let pan = gesture as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: root)
            return titles.count > 1 && abs(velocity.x) > abs(velocity.y)
        }
        if let button = gesture.view as? UIButton {
            return longPressEnabled.indices.contains(button.tag) && longPressEnabled[button.tag]
        }
        return true
    }

}

/// Observes touch lifetime only; never recognizes, delays, or prevents a
/// system tab gesture. UIKit remains the sole owner of preview and selection.
private final class ErosTouchLifetime: UIGestureRecognizer {
    var changed: ((Bool) -> Void)?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { changed?(true) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { changed?(false); state = .failed }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { changed?(false); state = .failed }
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

/// Tracks finger movement across a control to drive scrub haptics while the
/// system keeps owning the gesture itself: this recognizer never leaves the
/// observing state before failing, never delays or cancels touches, and
/// cannot prevent (or be prevented by) any other recognizer. The system
/// iOS 26 tab-bar drag keeps selecting on lift; this observer only reports
/// locations so each crossed item can tick.
private final class ErosScrubObserver: UIGestureRecognizer {
    var onBegin: ((CGPoint) -> Void)?
    var onMove: ((CGPoint) -> Void)?
    var onEnd: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { return }
        onBegin?(touch.location(in: view))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { return }
        onMove?(touch.location(in: view))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        onEnd?()
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        onEnd?()
        state = .failed
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

private final class SystemLiquidGlassTabBarPlatformView: NSObject, FlutterPlatformView, UITabBarDelegate {
    private let root: ErosLiquidGlassRootView
    private let bar = UITabBar()
    private let searchGlass = ErosPassthroughGlassView()
    private let search = UIButton(type: .system)
    private let channel: FlutterMethodChannel
    private var items: [ErosNativeTabItem] = []
    private var selectedIndex = 0
    private var hasSearch = false
    private var height: CGFloat = 68
    private var bottomInset: CGFloat = 0
    private var followsSystem: Bool?
    private var transparencyObserver: NSObjectProtocol?
    private var scrubDownLocation: CGPoint?
    private var scrubDragging = false
    private var scrubHoverIndex = -1

    private var systemOwnsGlassAppearance: Bool {
        if #available(iOS 26.0, *) {
            return followsSystem ?? true
        }
        return false
    }

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
        root = ErosLiquidGlassRootView(frame: frame)
        channel = FlutterMethodChannel(name: "eros/liquid-glass-tab-bar/\(viewId)", binaryMessenger: messenger)
        super.init()
        root.backgroundColor = .clear
        bar.delegate = self
        // This bar lives in a Flutter pane, which can be only 320pt wide
        // while the iPad window still has regular-width traits. Keep UIKit's
        // compact item layout and distribute it across the actual bar width.
        bar.itemPositioning = .fill
        if #available(iOS 17.0, *) {
            bar.traitOverrides.horizontalSizeClass = .compact
        }
        root.addSubview(bar)
        let scrubObserver = ErosScrubObserver()
        scrubObserver.delaysTouchesBegan = false
        scrubObserver.delaysTouchesEnded = false
        scrubObserver.cancelsTouchesInView = false
        scrubObserver.onBegin = { [weak self] point in self?.scrubBegan(at: point) }
        scrubObserver.onMove = { [weak self] point in self?.scrubMoved(to: point) }
        scrubObserver.onEnd = { [weak self] in self?.scrubEnded() }
        bar.addGestureRecognizer(scrubObserver)
        searchGlass.isUserInteractionEnabled = false
        searchGlass.accessibilityElementsHidden = true
        searchGlass.layer.cornerRadius = 24
        searchGlass.clipsToBounds = true
        root.addSubview(searchGlass)
        root.addSubview(search)
        search.addTarget(self, action: #selector(openSearch), for: .touchUpInside)
        search.setImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        search.accessibilityLabel = "Search"
        search.accessibilityIdentifier = "liquid-glass-search"
        search.isAccessibilityElement = true
        root.onLayout = { [weak self] in self?.layout() }
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "update", let values = call.arguments as? [String: Any] {
                self?.apply(values)
                result(nil)
            } else { result(FlutterMethodNotImplemented) }
        }
        transparencyObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, !self.systemOwnsGlassAppearance else { return }
            self.updateEffects()
        }
        apply(arguments as? [String: Any] ?? [:])
    }
    deinit {
        channel.setMethodCallHandler(nil)
        if let transparencyObserver {
            NotificationCenter.default.removeObserver(transparencyObserver)
        }
    }
    func view() -> UIView { root }

    private func apply(_ values: [String: Any]) {
        let next = (values["items"] as? [[String: Any]] ?? []).compactMap(ErosNativeTabItem.init)
        if next.map({ "\($0.label):\($0.codePoint):\($0.fontFamily ?? "")" }) != items.map({ "\($0.label):\($0.codePoint):\($0.fontFamily ?? "")" }) {
            items = next
            bar.items = items.enumerated().map { index, item in
                let tab = UITabBarItem(title: item.label, image: icon(item), tag: index)
                tab.accessibilityIdentifier = "liquid-glass-tab-\(index)"
                return tab
            }
        }
        selectedIndex = min(max(0, (values["selectedIndex"] as? NSNumber)?.intValue ?? 0), max(0, items.count - 1))
        if let tabs = bar.items, tabs.indices.contains(selectedIndex) {
            if bar.selectedItem !== tabs[selectedIndex] { bar.selectedItem = tabs[selectedIndex] }
        }
        if let searchLabel = values["searchLabel"] as? String {
            search.accessibilityLabel = searchLabel
        }
        hasSearch = values["hasSearch"] as? Bool ?? false
        height = CGFloat((values["height"] as? NSNumber)?.doubleValue ?? 68)
        bottomInset = max(0, CGFloat((values["bottomInset"] as? NSNumber)?.doubleValue ?? 0))
        root.overrideUserInterfaceStyle = (values["dark"] as? Bool ?? false) ? .dark : .light
        // Leave the system appearance untouched by default. The existing
        // material preference can explicitly request the traditional fallback.
        let nextFollow = values["followSystemTransparency"] as? Bool ?? true
        if followsSystem != nextFollow {
            followsSystem = nextFollow
            updateEffects()
        }
        layout()
    }

    private func updateEffects() {
        if #available(iOS 26.0, *), followsSystem ?? true {
            searchGlass.effect = UIGlassEffect(style: .regular)
            searchGlass.backgroundColor = .clear
            bar.standardAppearance = UITabBarAppearance()
            bar.scrollEdgeAppearance = nil
            return
        }

        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        searchGlass.effect = reduceTransparency
            ? nil
            : UIBlurEffect(style: .systemMaterial)
        searchGlass.backgroundColor = reduceTransparency
            ? .secondarySystemBackground
            : .clear

        let appearance = UITabBarAppearance()
        if reduceTransparency {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .secondarySystemBackground
        } else {
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        }
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
    }

    private func layout() {
        let width = max(0, root.bounds.width - (hasSearch ? 70 : 16))
        // The platform view includes the bottom safe-area height. Keep the
        // controls above the home indicator, but consume part of that blank
        // area so the glass does not float too far above it.
        let availableBottomSpace = max(0, root.bounds.height - height)
        let verticalOffset = min(bottomInset * 0.38, min(16, availableBottomSpace))
        let containerCenterY = verticalOffset + height / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bar.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        bar.center = CGPoint(x: 8 + width / 2, y: containerCenterY)
        bar.layoutIfNeeded()

        // Align the search control to UITabBar's actual safe-area center.
        let tabContentCenterY =
            bar.frame.minY + bar.safeAreaLayoutGuide.layoutFrame.midY -
                min(4, bottomInset * 0.12)
        // UITabBar's visible glass capsule is inset within the bar view's
        // bounds. Match search to that painted edge, not the wider view frame.
        let visibleRailLeadingInset = bar.frame.minX + 21
        search.frame = CGRect(
            x: root.bounds.width - visibleRailLeadingInset - 48,
            y: tabContentCenterY - 24,
            width: 48,
            height: 48
        )
        search.alpha = hasSearch ? 1 : 0
        searchGlass.frame = search.frame
        searchGlass.alpha = search.alpha
        search.isUserInteractionEnabled = hasSearch
        search.accessibilityElementsHidden = !search.isUserInteractionEnabled
        CATransaction.commit()
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        selectedIndex = item.tag
        channel.invokeMethod("select", arguments: item.tag)
    }

    @objc private func openSearch() {
        channel.invokeMethod("search", arguments: nil)
    }

    // MARK: - Drag-scrub haptics

    private func scrubBegan(at point: CGPoint) {
        scrubDownLocation = point
        scrubDragging = false
        scrubHoverIndex = -1
    }

    /// Ticks once per crossed tab while the finger actually drags. A plain
    /// tap stays silent here so the commit light impact in didSelect is the
    /// only haptic for it.
    private func scrubMoved(to point: CGPoint) {
        guard let start = scrubDownLocation else { return }
        if !scrubDragging {
            let dx = point.x - start.x
            let dy = point.y - start.y
            guard dx * dx + dy * dy > 36 else { return }
            scrubDragging = true
        }
        let index = scrubIndex(at: point)
        if index != scrubHoverIndex {
            scrubHoverIndex = index
            if index >= 0 {
                channel.invokeMethod("hover", arguments: index)
            }
        }
    }

    private func scrubEnded() {
        scrubDownLocation = nil
        scrubDragging = false
        scrubHoverIndex = -1
    }

    /// Maps a touch position to a tab index. The glass capsule is inset
    /// inside the bar bounds (search alignment uses the same 21pt inset), so
    /// the inset span is what the item count divides. -1 means outside it.
    private func scrubIndex(at point: CGPoint) -> Int {
        guard !items.isEmpty else { return -1 }
        let capsuleInset: CGFloat = 21
        let span = bar.bounds.width - capsuleInset * 2
        guard span > 0 else { return -1 }
        let fraction = (point.x - capsuleInset) / span
        guard fraction >= 0, fraction <= 1 else { return -1 }
        return min(items.count - 1, Int(fraction * CGFloat(items.count)))
    }

    private func icon(_ item: ErosNativeTabItem) -> UIImage? {
        let relativePath = "flutter_assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf"
        let url = Bundle.main.bundleURL.appendingPathComponent("Frameworks/App.framework").appendingPathComponent(relativePath)
        if !Self.registered {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            Self.registered = true
        }
        guard item.codePoint > 0, let scalar = UnicodeScalar(item.codePoint),
              let font = [item.fontFamily, "FontAwesome7Free-Solid", "Font Awesome 7 Free Solid", "Font Awesome 7 Free"].compactMap({ $0 }).compactMap({ UIFont(name: $0, size: 23) }).first else {
            return UIImage(systemName: item.fallbackSymbol)
        }
        return UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28)).image { _ in
            let text = String(scalar) as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]
            let size = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: (28 - size.width) / 2, y: (28 - size.height) / 2), withAttributes: attrs)
        }.withRenderingMode(.alwaysTemplate)
    }
    private static var registered = false
}
