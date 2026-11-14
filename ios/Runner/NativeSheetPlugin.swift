import Flutter
import UIKit

/// UIKit sheets for the secondary pages: rate, page jump, date/GID seek,
/// archiver, torrent and favorite order. Dart owns the data and the actions;
/// UIKit owns presentation, input and validation, and reports `event` /
/// `dismissed` back.
final class ErosNativeSheetPlugin: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    private var sheets: [Int: AnyObject] = [:]

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "eros/native-sheet",
                                           binaryMessenger: registrar.messenger())
        let instance = ErosNativeSheetPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(false)
            return
        }
        let arguments = call.arguments as? [String: Any] ?? [:]
        guard let id = (arguments["id"] as? NSNumber)?.intValue else {
            result(FlutterError(code: "args", message: "missing id", details: nil))
            return
        }
        switch call.method {
        case "present":
            let kind = arguments["kind"] as? String ?? ""
            let config = arguments["config"] as? [String: Any] ?? [:]
            result(present(id: id, kind: kind, config: config))
        case "update":
            if let sheet = sheets[id] as? ErosSheetController {
                sheet.update(arguments["config"] as? [String: Any] ?? [:])
            }
            result(nil)
        case "dismiss":
            if let sheet = sheets[id] as? ErosSheetController {
                sheet.close()
            } else {
                channel.invokeMethod("dismissed", arguments: ["id": id])
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 26.0, *)
    private func present(id: Int, kind: String, config: [String: Any]) -> Bool {
        guard let presenter = Self.topPresenter() else {
            return false
        }
        let emit: (String, Any?) -> Void = { [weak self] name, value in
            self?.channel.invokeMethod("event", arguments: [
                "id": id, "name": name, "value": value ?? NSNull()
            ])
        }
        let dismissed: () -> Void = { [weak self] in
            guard let self, self.sheets.removeValue(forKey: id) != nil else { return }
            self.channel.invokeMethod("dismissed", arguments: ["id": id])
        }
        let sheet: ErosSheetController
        switch kind {
        case "rate":
            sheet = ErosRateSheet(config: config, emit: emit, dismissed: dismissed)
        case "pageJump":
            sheet = ErosPageJumpSheet(config: config, emit: emit, dismissed: dismissed)
        case "seek":
            sheet = ErosSeekSheet(config: config, emit: emit, dismissed: dismissed)
        case "archiver":
            sheet = ErosArchiverSheet(config: config, emit: emit, dismissed: dismissed)
        case "torrent":
            sheet = ErosTorrentSheet(config: config, emit: emit, dismissed: dismissed)
        case "favoriteOrder", "actionList":
            sheet = ErosActionListSheet(config: config, emit: emit, dismissed: dismissed)
        default:
            return false
        }
        sheets[id] = sheet
        presenter.present(sheet, animated: true)
        return true
    }

    static func topPresenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        let window = windows.first { $0.isKeyWindow } ?? windows.first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController,
              !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}

// MARK: - Shared sheet chrome

@available(iOS 26.0, *)
class ErosSheetController: UIViewController, UISheetPresentationControllerDelegate {
    private(set) var config: [String: Any]
    let emit: (String, Any?) -> Void
    private let onDismissed: () -> Void
    private var finished = false

    let header = UIView()
    let closeButton = UIButton(type: .system)
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    var trailingButton: UIButton?
    let scrollView = UIScrollView()
    let content = UIStackView()
    private var lastFittingHeight: CGFloat = 0

    /// Whether the sheet may also be dragged to full height.
    var allowsLarge: Bool { false }

    init(config: [String: Any], emit: @escaping (String, Any?) -> Void,
         dismissed: @escaping () -> Void) {
        self.config = config
        self.emit = emit
        self.onDismissed = dismissed
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        overrideUserInterfaceStyle = bool("dark") ? .dark : .light
        if let sheet = sheetPresentationController {
            sheet.delegate = self
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
            sheet.detents = detents()
        }
        preferredContentSize = CGSize(width: 440, height: 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Config helpers

    func string(_ key: String, _ fallback: String = "") -> String {
        config[key] as? String ?? fallback
    }

    func bool(_ key: String) -> Bool { config[key] as? Bool == true }

    func number(_ key: String) -> Double? { (config[key] as? NSNumber)?.doubleValue }

    func color(_ key: String, _ fallback: UIColor) -> UIColor {
        guard let value = config[key] as? NSNumber else { return fallback }
        let argb = value.uint32Value
        return UIColor(red: CGFloat((argb >> 16) & 0xff) / 255,
                       green: CGFloat((argb >> 8) & 0xff) / 255,
                       blue: CGFloat(argb & 0xff) / 255,
                       alpha: CGFloat((argb >> 24) & 0xff) / 255)
    }

    var tint: UIColor { color("tint", .systemIndigo) }
    var onTint: UIColor { color("onTint", .white) }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // The system glass stays visible at the rim; content sits on a
        // legibility backing so text holds up over busy covers.
        view.backgroundColor = Self.backingColor()
        view.tintColor = tint
        buildHeader()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 0
        content.translatesAutoresizingMaskIntoConstraints = false
        content.isLayoutMarginsRelativeArrangement = true
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 16,
                                                                   bottom: 20, trailing: 16)
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            // Duo's outer display reserves a side region for the status bar.
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
        buildContent()
        apply()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let height = fittingHeight()
        if abs(height - lastFittingHeight) > 0.5 {
            lastFittingHeight = height
            relayoutSheet(animated: lastFittingHeight > 0 && view.window != nil)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil {
            finish()
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onDismissed()
    }

    func update(_ values: [String: Any]) {
        config = values
        overrideUserInterfaceStyle = bool("dark") ? .dark : .light
        view.tintColor = tint
        titleLabel.text = string("title")
        subtitleLabel.text = string("subtitle")
        subtitleLabel.isHidden = subtitleLabel.text?.isEmpty ?? true
        apply()
        view.setNeedsLayout()
    }

    /// Emits the final action, then closes; Dart runs it once closed.
    func finishWith(_ name: String, _ value: Any?) {
        view.endEditing(true)
        emit(name, value)
        close()
    }

    func close() {
        view.endEditing(true)
        guard presentingViewController != nil else {
            finish()
            return
        }
        dismiss(animated: true) { [weak self] in self?.finish() }
    }

    // MARK: Subclass hooks

    func buildContent() {}
    func apply() {}

    // MARK: Sizing

    private func detents() -> [UISheetPresentationController.Detent] {
        let fit = UISheetPresentationController.Detent.custom(identifier: .init("eros.fit")) {
            [weak self] context in
            guard let self else { return context.maximumDetentValue * 0.5 }
            return min(self.fittingHeight(), context.maximumDetentValue)
        }
        return allowsLarge ? [fit, .large()] : [fit]
    }

    func fittingHeight() -> CGFloat {
        guard isViewLoaded else { return 320 }
        let width = view.bounds.width > 0 ? view.bounds.width : 390
        let size = content.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel)
        return ceil(headerHeight + size.height)
    }

    private let headerHeight: CGFloat = 66

    func relayoutSheet(animated: Bool = true) {
        guard let sheet = sheetPresentationController else { return }
        if animated {
            sheet.animateChanges { sheet.invalidateDetents() }
        } else {
            sheet.invalidateDetents()
        }
    }

    // MARK: Header

    private func buildHeader() {
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        var close = UIButton.Configuration.glass()
        close.image = UIImage(systemName: "xmark",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        close.baseForegroundColor = .label
        closeButton.configuration = close
        closeButton.accessibilityLabel = string("closeLabel", "Close")
        closeButton.addAction(UIAction { [weak self] _ in self?.close() }, for: .primaryActionTriggered)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(closeButton)

        titleLabel.text = string("title")
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.accessibilityTraits = .header
        subtitleLabel.text = string("subtitle")
        subtitleLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 12, weight: .medium))
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.isHidden = subtitleLabel.text?.isEmpty ?? true
        let titles = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titles.axis = .vertical
        titles.alignment = .center
        titles.spacing = 1
        titles.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titles)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: headerHeight),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: 4),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            titles.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titles.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titles.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
        ])
    }

    func setTrailing(symbol: String, label: String, action: @escaping () -> Void) {
        let button = UIButton(type: .system)
        var style = UIButton.Configuration.prominentGlass()
        style.image = UIImage(systemName: symbol,
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        style.baseForegroundColor = onTint
        style.baseBackgroundColor = tint
        button.configuration = style
        button.tintColor = tint
        button.accessibilityLabel = label
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        button.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            button.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
        trailingButton = button
    }

    // MARK: Building blocks

    /// Legibility backing under the content: canvas at 72% (light) or a
    /// raised graphite at 62% (dark). Reduce Transparency is opaque anyway.
    static func backingColor() -> UIColor {
        UIColor { traits in
            if UIAccessibility.isReduceTransparencyEnabled {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.125, green: 0.129, blue: 0.149, alpha: 1)
                    : UIColor(red: 0.949, green: 0.953, blue: 0.965, alpha: 1)
            }
            return traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.118, green: 0.122, blue: 0.141, alpha: 0.62)
                : UIColor(red: 0.949, green: 0.953, blue: 0.965, alpha: 0.72)
        }
    }

    /// Small text only ever sits on a tray, never straight on the glass.
    static func trayColor() -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.07)
                : UIColor(white: 1, alpha: 0.92)
        }
    }

    func tray(_ rows: [UIView], separatorInset: CGFloat = 14) -> UIView {
        let tray = UIView()
        tray.backgroundColor = Self.trayColor()
        tray.layer.cornerRadius = 18
        tray.layer.cornerCurve = .continuous
        tray.clipsToBounds = true
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let line = UIView()
                line.backgroundColor = .separator
                line.translatesAutoresizingMaskIntoConstraints = false
                let holder = UIView()
                holder.addSubview(line)
                NSLayoutConstraint.activate([
                    holder.heightAnchor.constraint(equalToConstant: 1 / max(1, traitCollection.displayScale)),
                    line.topAnchor.constraint(equalTo: holder.topAnchor),
                    line.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
                    line.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: separatorInset),
                    line.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
                ])
                stack.addArrangedSubview(holder)
            }
            stack.addArrangedSubview(row)
        }
        tray.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tray.topAnchor),
            stack.bottomAnchor.constraint(equalTo: tray.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: tray.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: tray.trailingAnchor),
        ])
        return tray
    }

    func sectionLabel(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(
            for: .systemFont(ofSize: 13, weight: .semibold))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.accessibilityTraits = .header
        let holder = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: holder.topAnchor, constant: 18),
            label.bottomAnchor.constraint(equalTo: holder.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: holder.trailingAnchor, constant: -6),
        ])
        return holder
    }

    func spacer(_ height: CGFloat) -> UIView {
        let view = UIView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    /// Four equal tonal capsule buttons for First / Prev / Next / Last navigation.
    func jumpNavRow(canPrev: Bool, canNext: Bool, onSelect: @escaping (String) -> Void) -> UIView {
        func navButton(_ title: String, symbol: String, trailing: Bool,
                       enabled: Bool, action: String) -> UIButton {
            var style = UIButton.Configuration.filled()
            style.cornerStyle = .capsule
            style.baseBackgroundColor = enabled ? tint.withAlphaComponent(0.14) : .tertiarySystemFill
            style.baseForegroundColor = enabled ? tint : .tertiaryLabel
            style.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 6, bottom: 7, trailing: 6)
            style.image = UIImage(systemName: symbol,
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
            style.imagePlacement = trailing ? .trailing : .leading
            style.imagePadding = 3
            style.titleLineBreakMode = .byTruncatingTail
            style.attributedTitle = AttributedString(title, attributes: AttributeContainer([
                .font: UIFontMetrics(forTextStyle: .footnote).scaledFont(
                    for: .systemFont(ofSize: 12.5, weight: .semibold), maximumPointSize: 15)
            ]))
            let button = UIButton(configuration: style, primaryAction: UIAction { _ in onSelect(action) })
            button.isEnabled = enabled
            button.accessibilityLabel = title
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
            return button
        }
        let stack = UIStackView(arrangedSubviews: [
            navButton(string("navFirst"), symbol: "backward.end", trailing: false, enabled: canPrev, action: "first"),
            navButton(string("navPrev"), symbol: "chevron.left", trailing: false, enabled: canPrev, action: "prev"),
            navButton(string("navNext"), symbol: "chevron.right", trailing: true, enabled: canNext, action: "next"),
            navButton(string("navLast"), symbol: "forward.end", trailing: true, enabled: canNext, action: "last"),
        ])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.distribution = .fillEqually
        return stack
    }

    /// Accent text on a soft accent fill, or a neutral fill when unselected.
    func tonalButton(_ title: String, selected: Bool = true,
                     action: @escaping () -> Void) -> UIButton {
        var style = UIButton.Configuration.filled()
        style.cornerStyle = .capsule
        style.baseBackgroundColor = selected ? tint.withAlphaComponent(0.14) : .tertiarySystemFill
        style.baseForegroundColor = selected ? tint : .secondaryLabel
        style.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        style.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFontMetrics(forTextStyle: .subheadline).scaledFont(
                for: .systemFont(ofSize: 14, weight: .semibold))
        ]))
        let button = UIButton(configuration: style, primaryAction: UIAction { _ in action() })
        return button
    }

    func prominentButton(_ title: String, subtitle: String? = nil, symbol: String? = nil,
                         trailingSymbol: Bool = false, glassOnly: Bool = false,
                         action: @escaping () -> Void) -> UIButton {
        var style = glassOnly ? UIButton.Configuration.glass() : UIButton.Configuration.prominentGlass()
        style.cornerStyle = .capsule
        if !glassOnly {
            style.baseBackgroundColor = tint
            style.baseForegroundColor = onTint
        } else {
            style.baseForegroundColor = .label
        }
        style.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFontMetrics(forTextStyle: .body).scaledFont(
                for: .systemFont(ofSize: 16.5, weight: .semibold))
        ]))
        if let subtitle, !subtitle.isEmpty {
            style.attributedSubtitle = AttributedString(subtitle, attributes: AttributeContainer([
                .font: UIFontMetrics(forTextStyle: .caption2).scaledFont(
                    for: .monospacedDigitSystemFont(ofSize: 11, weight: .medium))
            ]))
            style.titleAlignment = trailingSymbol ? .trailing : .leading
        }
        if let symbol {
            style.image = UIImage(systemName: symbol,
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
            style.imagePlacement = trailingSymbol ? .trailing : .leading
            style.imagePadding = 8
        }
        style.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
        let button = UIButton(configuration: style, primaryAction: UIAction { _ in action() })
        if !glassOnly {
            button.tintColor = tint
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        return button
    }

    func shake(_ target: UIView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-8, 8, -6, 6, -3, 3, 0]
        animation.duration = 0.35
        target.layer.add(animation, forKey: "shake")
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Rate

@available(iOS 26.0, *)
final class ErosStarRating: UIControl {
    private(set) var value: Double = 0
    private var views: [UIImageView] = []
    private let feedback = UISelectionFeedbackGenerator()
    var starColor: UIColor = .systemOrange { didSet { refresh() } }
    private let starSize: CGFloat = 36
    private let gap: CGFloat = 10

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = gap
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        for _ in 0..<5 {
            let image = UIImageView()
            image.contentMode = .scaleAspectFit
            image.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: starSize, weight: .regular)
            image.widthAnchor.constraint(equalToConstant: starSize + 4).isActive = true
            image.heightAnchor.constraint(equalToConstant: starSize + 4).isActive = true
            views.append(image)
            stack.addArrangedSubview(image)
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(track(_:))))
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(track(_:))))
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setValue(_ newValue: Double, notify: Bool) {
        let clamped = min(5, max(0.5, (newValue * 2).rounded(.up) / 2))
        guard clamped != value else { return }
        value = clamped
        refresh()
        if notify {
            feedback.selectionChanged()
            sendActions(for: .valueChanged)
        }
    }

    @objc private func track(_ gesture: UIGestureRecognizer) {
        let total = CGFloat(views.count) * (starSize + 4) + CGFloat(views.count - 1) * gap
        let originX = (bounds.width - total) / 2
        let x = gesture.location(in: self).x - originX
        let unit = starSize + 4 + gap
        let index = floor(x / unit)
        let within = min(1, max(0, (x - index * unit) / (starSize + 4)))
        setValue(Double(index) + (within <= 0.5 ? 0.5 : 1), notify: true)
    }

    private func refresh() {
        for (index, view) in views.enumerated() {
            let position = Double(index) + 1
            let name: String
            if value >= position {
                name = "star.fill"
            } else if value >= position - 0.5 {
                name = "star.leadinghalf.filled"
            } else {
                name = "star.fill"
            }
            view.image = UIImage(systemName: name)
            view.tintColor = value >= position - 0.5 ? starColor : .tertiaryLabel
        }
        accessibilityValue = String(format: "%.1f / 5", value)
    }

    override func accessibilityIncrement() { setValue(value + 0.5, notify: true) }
    override func accessibilityDecrement() { setValue(value - 0.5, notify: true) }
}

@available(iOS 26.0, *)
final class ErosRateSheet: ErosSheetController {
    private let stars = ErosStarRating()
    private let scoreLabel = UILabel()
    private let summaryLabel = UILabel()
    private var submit: UIButton!
    private var initialRating = 0.5

    override func buildContent() {
        stars.starColor = color("star", .systemOrange)
        stars.accessibilityLabel = string("title")
        stars.setValue(number("rating") ?? 0, notify: false)
        initialRating = stars.value
        stars.addAction(UIAction { [weak self] _ in self?.refreshScore() }, for: .valueChanged)
        scoreLabel.textAlignment = .center
        scoreLabel.adjustsFontForContentSizeCategory = true
        summaryLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 13, weight: .medium))
        summaryLabel.adjustsFontForContentSizeCategory = true
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.textAlignment = .center
        summaryLabel.numberOfLines = 0
        submit = prominentButton(string("submit")) { [weak self] in
            guard let self else { return }
            self.finishWith("submit", self.stars.value)
        }
        content.addArrangedSubview(spacer(18))
        content.addArrangedSubview(stars)
        content.addArrangedSubview(spacer(10))
        content.addArrangedSubview(scoreLabel)
        content.addArrangedSubview(spacer(2))
        content.addArrangedSubview(summaryLabel)
        content.addArrangedSubview(spacer(22))
        content.addArrangedSubview(submit)
        refreshScore()
    }

    override func apply() {
        summaryLabel.text = string("summary")
        summaryLabel.isHidden = summaryLabel.text?.isEmpty ?? true
    }

    private func refreshScore() {
        submit.isEnabled = stars.value != initialRating
        let text = NSMutableAttributedString(
            string: String(format: "%.1f", stars.value),
            attributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 44, weight: .semibold),
                         .foregroundColor: UIColor.label])
        text.append(NSAttributedString(
            string: " / 5",
            attributes: [.font: UIFont.systemFont(ofSize: 17, weight: .medium),
                         .foregroundColor: UIColor.secondaryLabel]))
        scoreLabel.attributedText = text
        scoreLabel.accessibilityLabel = String(format: "%.1f / 5", stars.value)
    }
}

// MARK: - Page jump

@available(iOS 26.0, *)
final class ErosPageJumpSheet: ErosSheetController, UITextFieldDelegate {
    private let field = UITextField()
    private let underline = UIView()
    private let ofLabel = UILabel()
    private let slider = UISlider()
    private let minLabel = UILabel()
    private let maxLabel = UILabel()
    private var maxPage = 1
    private var lastSliderPage = 0
    private let feedback = UISelectionFeedbackGenerator()
    /// The first keystroke replaces the shown page instead of appending.
    private var replaceOnType = true

    override func buildContent() {
        maxPage = max(1, Int(number("max") ?? 1))
        let current = min(maxPage, max(1, Int(number("current") ?? 1)))
        setTrailing(symbol: "arrow.right", label: string("go")) { [weak self] in self?.go() }

        field.text = "\(current)"
        field.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 46, weight: .semibold), maximumPointSize: 60)
        field.adjustsFontForContentSizeCategory = true
        field.textAlignment = .center
        field.keyboardType = .numberPad
        field.tintColor = tint
        field.delegate = self
        field.accessibilityLabel = string("title")
        field.addAction(UIAction { [weak self] _ in self?.textChanged() }, for: .editingChanged)
        underline.backgroundColor = tint
        underline.layer.cornerRadius = 1
        ofLabel.text = "/ \(maxPage)"
        ofLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 17, weight: .medium))
        ofLabel.adjustsFontForContentSizeCategory = true
        ofLabel.textColor = .secondaryLabel

        let number = UIView()
        [field, underline, ofLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            number.addSubview($0)
        }
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: number.topAnchor, constant: 10),
            field.centerXAnchor.constraint(equalTo: number.centerXAnchor, constant: -24),
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            underline.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 2),
            underline.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 8),
            underline.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -8),
            underline.heightAnchor.constraint(equalToConstant: 2),
            underline.bottomAnchor.constraint(equalTo: number.bottomAnchor),
            ofLabel.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 2),
            ofLabel.firstBaselineAnchor.constraint(equalTo: field.firstBaselineAnchor),
        ])

        slider.minimumValue = 1
        slider.maximumValue = Float(maxPage)
        slider.value = Float(current)
        slider.isEnabled = maxPage > 1
        slider.minimumTrackTintColor = tint
        slider.accessibilityLabel = string("title")
        slider.addAction(UIAction { [weak self] _ in self?.sliderChanged() }, for: .valueChanged)
        lastSliderPage = current

        for (label, text) in [(minLabel, "1"), (maxLabel, "\(maxPage)")] {
            label.text = text
            label.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
                for: .monospacedDigitSystemFont(ofSize: 12, weight: .medium))
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
        }
        let ends = UIStackView(arrangedSubviews: [minLabel, UIView(), maxLabel])
        ends.axis = .horizontal

        let sliderBox = UIStackView(arrangedSubviews: [slider, ends])
        sliderBox.axis = .vertical
        sliderBox.spacing = 2
        sliderBox.isLayoutMarginsRelativeArrangement = true
        sliderBox.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)

        let navRow = jumpNavRow(canPrev: current > 1, canNext: current < maxPage) { [weak self] action in
            self?.finishWith("nav", action)
        }
        content.addArrangedSubview(spacer(6))
        content.addArrangedSubview(navRow)
        content.addArrangedSubview(spacer(14))
        content.addArrangedSubview(number)
        content.addArrangedSubview(spacer(22))
        content.addArrangedSubview(sliderBox)
        content.addArrangedSubview(spacer(6))
        validate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if bool("autofocus") {
            field.becomeFirstResponder()
        }
    }

    private var page: Int? {
        guard let value = Int(field.text ?? ""), (1...maxPage).contains(value) else { return nil }
        return value
    }

    private func set(_ value: Int) {
        replaceOnType = true
        field.text = "\(value)"
        slider.setValue(Float(value), animated: true)
        lastSliderPage = value
        feedback.selectionChanged()
        validate()
    }

    private func textChanged() {
        if let page {
            slider.setValue(Float(page), animated: true)
            lastSliderPage = page
        }
        validate()
    }

    private func sliderChanged() {
        let value = Int(slider.value.rounded())
        guard value != lastSliderPage else { return }
        lastSliderPage = value
        replaceOnType = true
        field.text = "\(value)"
        feedback.selectionChanged()
        validate()
    }

    private func validate() {
        let valid = page != nil
        field.textColor = valid ? .label : .systemRed
        underline.backgroundColor = valid ? tint : .systemRed
        trailingButton?.isEnabled = valid
    }

    private func go() {
        guard let page else {
            shake(field)
            return
        }
        finishWith("jump", page)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard string.allSatisfy(\.isNumber) else { return false }
        if replaceOnType && !string.isEmpty {
            replaceOnType = false
            textField.text = String(string.prefix(6))
            textChanged()
            return false
        }
        replaceOnType = false
        return ((textField.text ?? "") as NSString)
            .replacingCharacters(in: range, with: string).count <= 6
    }
}

// MARK: - Date / GID seek

@available(iOS 26.0, *)
final class ErosSeekSheet: ErosSheetController, UITextFieldDelegate {
    private let dateField = UITextField()
    private let gidField = UITextField()
    private let pickerToggle = UIButton(type: .system)
    private let picker = UIDatePicker()
    private let pickerRow = UIView()
    private let hint = UILabel()
    private var prevButton: UIButton!
    private var nextButton: UIButton!
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    override func buildContent() {
        configureField(dateField, placeholder: string("datePlaceholder"))
        dateField.text = string("text")
        dateField.returnKeyType = .next
        configureField(gidField, placeholder: string("gidPlaceholder"))
        gidField.text = string("gid")
        gidField.keyboardType = .numbersAndPunctuation
        gidField.returnKeyType = .go

        var toggle = UIButton.Configuration.plain()
        toggle.image = UIImage(systemName: "calendar",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        toggle.cornerStyle = .capsule
        pickerToggle.configuration = toggle
        pickerToggle.accessibilityLabel = string("pickerLabel")
        pickerToggle.addAction(UIAction { [weak self] _ in self?.togglePicker() }, for: .primaryActionTriggered)
        pickerToggle.widthAnchor.constraint(equalToConstant: 36).isActive = true
        pickerToggle.heightAnchor.constraint(equalToConstant: 36).isActive = true

        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.calendar = Calendar(identifier: .gregorian)
        picker.minimumDate = Self.formatter.date(from: "2007-03-20")
        picker.maximumDate = Date().addingTimeInterval(60)
        if let date = Self.formatter.date(from: string("pickerDate")) {
            picker.date = date
        }
        picker.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.dateField.text = Self.formatter.string(from: self.picker.date)
            self.clearError()
        }, for: .valueChanged)
        picker.translatesAutoresizingMaskIntoConstraints = false
        pickerRow.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: pickerRow.topAnchor),
            picker.bottomAnchor.constraint(equalTo: pickerRow.bottomAnchor),
            picker.leadingAnchor.constraint(equalTo: pickerRow.leadingAnchor, constant: 8),
            picker.trailingAnchor.constraint(equalTo: pickerRow.trailingAnchor, constant: -8),
            picker.heightAnchor.constraint(equalToConstant: 150),
        ])
        pickerRow.isHidden = !bool("pickerVisible")

        let dateRow = row(label: string("dateLabel"), field: dateField, accessory: pickerToggle)
        let gidRow = row(label: "GID", field: gidField, accessory: nil)
        // The picker carries its own bottom hairline so hiding it never
        // leaves two separators stacked in the tray.
        let pickerLine = UIView()
        pickerLine.backgroundColor = .separator
        pickerLine.translatesAutoresizingMaskIntoConstraints = false
        pickerRow.addSubview(pickerLine)
        NSLayoutConstraint.activate([
            pickerLine.bottomAnchor.constraint(equalTo: pickerRow.bottomAnchor),
            pickerLine.leadingAnchor.constraint(equalTo: pickerRow.leadingAnchor, constant: 14),
            pickerLine.trailingAnchor.constraint(equalTo: pickerRow.trailingAnchor),
            pickerLine.heightAnchor.constraint(equalToConstant: 1 / max(1, traitCollection.displayScale)),
        ])
        let lower = UIStackView(arrangedSubviews: [pickerRow, gidRow])
        lower.axis = .vertical
        let navRow = jumpNavRow(canPrev: bool("canPrev"), canNext: bool("canNext")) { [weak self] action in
            self?.finishWith("nav", action)
        }
        content.addArrangedSubview(spacer(6))
        content.addArrangedSubview(navRow)
        content.addArrangedSubview(sectionLabel(string("section")))
        content.addArrangedSubview(tray([dateRow, lower]))

        hint.numberOfLines = 0
        hint.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(
            for: .systemFont(ofSize: 12.5, weight: .medium))
        hint.adjustsFontForContentSizeCategory = true
        let hintBox = UIView()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hintBox.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: hintBox.topAnchor, constant: 10),
            hint.bottomAnchor.constraint(equalTo: hintBox.bottomAnchor),
            hint.leadingAnchor.constraint(equalTo: hintBox.leadingAnchor, constant: 6),
            hint.trailingAnchor.constraint(equalTo: hintBox.trailingAnchor, constant: -6),
        ])
        content.addArrangedSubview(hintBox)
        content.addArrangedSubview(spacer(18))

        prevButton = prominentButton(string("newer"),
                                     symbol: "arrow.up", glassOnly: true) { [weak self] in
            self?.go("prev")
        }
        nextButton = prominentButton(string("older"),
                                     symbol: "arrow.down", trailingSymbol: true) { [weak self] in
            self?.go("next")
        }
        let pair = UIStackView(arrangedSubviews: [prevButton, nextButton])
        pair.axis = .horizontal
        pair.spacing = 10
        pair.distribution = .fillEqually
        content.addArrangedSubview(pair)
        clearError()
        refreshToggle()
    }

    private func configureField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 16, weight: .regular))
        field.adjustsFontForContentSizeCategory = true
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.tintColor = tint
        field.delegate = self
        field.addAction(UIAction { [weak self] _ in self?.clearError() }, for: .editingChanged)
    }

    private func row(label: String, field: UITextField, accessory: UIView?) -> UIView {
        let title = UILabel()
        title.text = label
        title.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: .systemFont(ofSize: 14, weight: .medium))
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .secondaryLabel
        title.setContentHuggingPriority(.required, for: .horizontal)
        title.widthAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        field.accessibilityLabel = label
        var views: [UIView] = [title, field]
        if let accessory { views.append(accessory) }
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 14,
                                                                 bottom: 4, trailing: accessory == nil ? 14 : 8)
        stack.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        return stack
    }

    private func togglePicker() {
        UISelectionFeedbackGenerator().selectionChanged()
        view.endEditing(true)
        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseInOut]) {
            self.pickerRow.isHidden.toggle()
            self.pickerRow.alpha = self.pickerRow.isHidden ? 0 : 1
            self.content.layoutIfNeeded()
        }
        refreshToggle()
        emit("pickerVisible", !pickerRow.isHidden)
        view.setNeedsLayout()
    }

    private func refreshToggle() {
        var style = pickerToggle.configuration ?? .plain()
        let on = !pickerRow.isHidden
        style.baseForegroundColor = on ? tint : .secondaryLabel
        style.background.backgroundColor = on ? tint.withAlphaComponent(0.14) : .clear
        pickerToggle.configuration = style
        pickerToggle.isSelected = on
    }

    private func clearError() {
        hint.text = string("hint")
        hint.textColor = .secondaryLabel
    }

    private func showError(_ text: String) {
        hint.text = text
        hint.textColor = .systemRed
        shake(hint)
        view.setNeedsLayout()
    }

    private func go(_ direction: String) {
        let text = (dateField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let gid = (gidField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty && gid.isEmpty {
            showError(string("errorEmpty"))
            return
        }
        if !text.isEmpty && !Self.valid(text) {
            showError(string("errorFormat"))
            return
        }
        finishWith(direction, ["text": text, "gid": gid])
    }

    static func valid(_ text: String) -> Bool {
        let patterns = [#"^\d+[wmy]?$"#, #"^\d{4}(-\d{2}){0,2}$"#, #"^\d{2}(-\d{2}){1,2}$"#]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === dateField {
            gidField.becomeFirstResponder()
        } else {
            go("next")
        }
        return false
    }
}

// MARK: - Archiver

@available(iOS 26.0, *)
final class ErosArchiverSheet: ErosSheetController {
    override var allowsLarge: Bool { true }
    private var signature = ""

    override func apply() {
        let state = string("state")
        let local = config["local"] as? [[String: Any]] ?? []
        let hath = config["hath"] as? [[String: Any]] ?? []
        let next = "\(state)|\(string("gp"))|\(string("credits"))|\(local.count)|\(hath.count)|"
            + local.map { "\($0["id"] ?? "")\($0["size"] ?? "")" }.joined()
            + hath.map { "\($0["id"] ?? "")\($0["caption"] ?? "")" }.joined()
        guard next != signature else { return }
        signature = next
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch state {
        case "ready":
            buildReady(local: local, hath: hath)
        case "error":
            buildMessage(symbol: "exclamationmark.triangle", text: string("errorText"), retry: true)
        default:
            buildMessage(symbol: nil, text: string("loadingText"), retry: false)
        }
        UIAccessibility.post(notification: .layoutChanged, argument: content)
    }

    private func buildMessage(symbol: String?, text: String, retry: Bool) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        if let symbol {
            let image = UIImageView(image: UIImage(systemName: symbol))
            image.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
            image.tintColor = .secondaryLabel
            stack.addArrangedSubview(image)
        } else {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            stack.addArrangedSubview(spinner)
        }
        let label = UILabel()
        label.text = text
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: .systemFont(ofSize: 14, weight: .medium))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        stack.addArrangedSubview(label)
        if retry {
            stack.addArrangedSubview(tonalButton(string("retryLabel")) { [weak self] in
                self?.emit("retry", nil)
            })
        }
        content.addArrangedSubview(spacer(26))
        content.addArrangedSubview(stack)
        content.addArrangedSubview(spacer(30))
    }

    private func buildReady(local: [[String: Any]], hath: [[String: Any]]) {
        let gp = string("gp")
        let credits = string("credits")
        if !gp.isEmpty || !credits.isEmpty {
            let chips = UIStackView(arrangedSubviews: [
                balanceChip(letter: "G", value: gp, label: "GP"),
                balanceChip(letter: "C", value: credits, label: "Credits"),
            ])
            chips.axis = .horizontal
            chips.spacing = 8
            let holder = UIView()
            chips.translatesAutoresizingMaskIntoConstraints = false
            holder.addSubview(chips)
            NSLayoutConstraint.activate([
                chips.topAnchor.constraint(equalTo: holder.topAnchor),
                chips.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
                chips.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
            ])
            content.addArrangedSubview(holder)
        }
        if !local.isEmpty {
            content.addArrangedSubview(sectionLabel(string("localTitle")))
            content.addArrangedSubview(tray(local.map(localRow), separatorInset: 58))
        }
        if !hath.isEmpty {
            content.addArrangedSubview(sectionLabel(string("hathTitle")))
            let grid = UIStackView()
            grid.axis = .vertical
            grid.spacing = 8
            stride(from: 0, to: hath.count, by: 3).forEach { start in
                let line = UIStackView()
                line.axis = .horizontal
                line.spacing = 8
                line.distribution = .fillEqually
                for index in start..<(start + 3) {
                    line.addArrangedSubview(index < hath.count ? hathTile(hath[index]) : UIView())
                }
                grid.addArrangedSubview(line)
            }
            content.addArrangedSubview(grid)
        }
    }

    private func balanceChip(letter: String, value: String, label: String) -> UIView {
        // SF Symbols already carry the lettered coin (g.circle.fill …).
        let badge = UIImageView(image: UIImage(systemName: "\(letter.lowercased()).circle.fill"))
        badge.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        badge.tintColor = .label
        badge.contentMode = .center
        badge.widthAnchor.constraint(equalToConstant: 20).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 20).isActive = true
        let text = UILabel()
        text.text = value
        text.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 13.5, weight: .semibold))
        text.adjustsFontForContentSizeCategory = true
        text.textColor = .label
        let stack = UIStackView(arrangedSubviews: [badge, text])
        stack.spacing = 7
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 12)
        stack.backgroundColor = Self.trayColor()
        stack.layer.cornerRadius = 14
        stack.isAccessibilityElement = true
        stack.accessibilityLabel = "\(label) \(value)"
        return stack
    }

    private func localRow(_ item: [String: Any]) -> UIView {
        let id = item["id"] as? String ?? ""
        var style = UIButton.Configuration.plain()
        style.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        let button = UIButton(configuration: style, primaryAction: UIAction { [weak self] _ in
            self?.finishWith("local", id)
        })
        let icon = UIImageView(image: UIImage(systemName: item["symbol"] as? String ?? "archivebox"))
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        icon.tintColor = tint
        icon.contentMode = .center
        icon.backgroundColor = tint.withAlphaComponent(0.14)
        icon.layer.cornerRadius = 10
        icon.layer.cornerCurve = .continuous
        icon.widthAnchor.constraint(equalToConstant: 32).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
        let title = UILabel()
        title.text = item["title"] as? String
        title.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 15.5, weight: .semibold))
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .label
        let size = UILabel()
        size.text = item["size"] as? String
        size.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 12.5, weight: .medium))
        size.adjustsFontForContentSizeCategory = true
        size.textColor = .secondaryLabel
        let texts = UIStackView(arrangedSubviews: [title, size])
        texts.axis = .vertical
        texts.spacing = 1
        let price = UILabel()
        price.text = item["price"] as? String
        price.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold))
        price.adjustsFontForContentSizeCategory = true
        price.textColor = item["free"] as? Bool == true ? .systemGreen : .secondaryLabel
        price.setContentHuggingPriority(.required, for: .horizontal)
        price.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [icon, texts, price])
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: button.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
        ])
        button.accessibilityLabel = [title.text, size.text, price.text].compactMap { $0 }.joined(separator: ", ")
        return button
    }

    private func hathTile(_ item: [String: Any]) -> UIView {
        let id = item["id"] as? String ?? ""
        var style = UIButton.Configuration.filled()
        style.baseBackgroundColor = Self.trayColor()
        style.baseForegroundColor = .label
        style.background.cornerRadius = 14
        style.cornerStyle = .fixed
        style.titleAlignment = .leading
        style.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 11, bottom: 10, trailing: 8)
        style.attributedTitle = AttributedString(item["title"] as? String ?? "", attributes: AttributeContainer([
            .font: UIFontMetrics(forTextStyle: .body).scaledFont(
                for: .monospacedDigitSystemFont(ofSize: 15.5, weight: .semibold))
        ]))
        style.attributedSubtitle = AttributedString(item["caption"] as? String ?? "", attributes: AttributeContainer([
            .font: UIFontMetrics(forTextStyle: .caption2).scaledFont(
                for: .monospacedDigitSystemFont(ofSize: 11, weight: .medium)),
            .foregroundColor: UIColor.secondaryLabel,
        ]))
        style.titlePadding = 2
        let button = UIButton(configuration: style, primaryAction: UIAction { [weak self] _ in
            self?.finishWith("hath", id)
        })
        button.contentHorizontalAlignment = .leading
        return button
    }
}

// MARK: - Torrent

@available(iOS 26.0, *)
final class ErosTorrentSheet: ErosSheetController {
    override var allowsLarge: Bool { true }
    private var signature = ""

    override func apply() {
        let state = string("state")
        let torrents = config["torrents"] as? [[String: Any]] ?? []
        let next = "\(state)|\(string("title"))|\(torrents.count)|"
            + torrents.map { "\($0["hash"] ?? "")\($0["seeds"] ?? "")\($0["peers"] ?? "")" }.joined()
        guard next != signature else { return }
        signature = next
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch state {
        case "ready":
            buildReady(torrents: torrents)
        case "empty":
            buildMessage(symbol: "tray", text: string("emptyText"), retry: false)
        case "error":
            buildMessage(symbol: "exclamationmark.triangle", text: string("errorText"), retry: true)
        default:
            buildMessage(symbol: nil, text: string("loadingText"), retry: false)
        }
        UIAccessibility.post(notification: .layoutChanged, argument: content)
    }

    private func buildMessage(symbol: String?, text: String, retry: Bool) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        if let symbol {
            let image = UIImageView(image: UIImage(systemName: symbol))
            image.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
            image.tintColor = .secondaryLabel
            stack.addArrangedSubview(image)
        } else {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            stack.addArrangedSubview(spinner)
        }
        let label = UILabel()
        label.text = text
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: .systemFont(ofSize: 14, weight: .medium))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        stack.addArrangedSubview(label)
        if retry {
            stack.addArrangedSubview(tonalButton(string("retryLabel")) { [weak self] in
                self?.emit("retry", nil)
            })
        }
        content.addArrangedSubview(spacer(26))
        content.addArrangedSubview(stack)
        content.addArrangedSubview(spacer(30))
    }

    private func buildReady(torrents: [[String: Any]]) {
        content.addArrangedSubview(spacer(4))
        for (index, item) in torrents.enumerated() {
            if index > 0 {
                content.addArrangedSubview(spacer(10))
            }
            content.addArrangedSubview(tray([torrentCard(item, primary: index == 0)]))
        }
    }

    private func torrentCard(_ item: [String: Any], primary: Bool) -> UIView {
        let hash = item["hash"] as? String ?? ""
        let title = UILabel()
        title.text = item["name"] as? String ?? ""
        title.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .systemFont(ofSize: 15, weight: .semibold))
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .label
        title.numberOfLines = 3

        let metaText = item["meta"] as? String ?? ""
        let meta = UILabel()
        meta.text = metaText
        meta.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 12.5, weight: .medium))
        meta.adjustsFontForContentSizeCategory = true
        meta.textColor = .secondaryLabel
        meta.isHidden = metaText.isEmpty

        func stat(_ symbol: String, _ value: String, _ label: String) -> UIView {
            let icon = UIImageView(image: UIImage(systemName: symbol))
            icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12.5, weight: .medium)
            icon.tintColor = .secondaryLabel
            let text = UILabel()
            text.text = value
            text.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
                for: .monospacedDigitSystemFont(ofSize: 12.5, weight: .medium))
            text.adjustsFontForContentSizeCategory = true
            text.textColor = .secondaryLabel
            let row = UIStackView(arrangedSubviews: [icon, text])
            row.spacing = 4
            row.alignment = .center
            row.isAccessibilityElement = true
            row.accessibilityLabel = "\(label) \(value)"
            return row
        }

        let stats = UIStackView(arrangedSubviews: [
            stat("arrow.up.circle", item["seeds"] as? String ?? "0", string("seedsLabel")),
            stat("arrow.down.circle", item["peers"] as? String ?? "0", string("peersLabel")),
            stat("checkmark.circle", item["downloads"] as? String ?? "0", string("completedLabel")),
            UIView(),
        ])
        stats.axis = .horizontal
        stats.spacing = 14
        stats.alignment = .center

        let download = actionButton(
            title: string("downloadLabel"),
            symbol: "arrow.down.circle",
            prominent: primary
        ) { [weak self] in
            self?.finishWith("download", hash)
        }
        let magnet = actionButton(
            title: string("magnetLabel"),
            symbol: "link",
            prominent: false,
            neutral: true
        ) { [weak self] in
            self?.finishWith("magnet", hash)
        }
        let buttons = UIStackView(arrangedSubviews: [download, magnet])
        buttons.axis = .horizontal
        buttons.spacing = 10
        buttons.distribution = .fillEqually

        let card = UIStackView(arrangedSubviews: [title, meta, stats, buttons])
        card.axis = .vertical
        card.spacing = 8
        card.setCustomSpacing(4, after: title)
        card.setCustomSpacing(12, after: stats)
        card.isLayoutMarginsRelativeArrangement = true
        card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        return card
    }

    private func actionButton(title: String, symbol: String, prominent: Bool,
                              neutral: Bool = false, action: @escaping () -> Void) -> UIButton {
        var style: UIButton.Configuration
        if prominent {
            style = .prominentGlass()
            style.baseBackgroundColor = tint
            style.baseForegroundColor = onTint
        } else {
            style = .filled()
            style.baseBackgroundColor = neutral ? .tertiarySystemFill : tint.withAlphaComponent(0.14)
            style.baseForegroundColor = neutral ? .secondaryLabel : tint
        }
        style.cornerStyle = .capsule
        style.image = UIImage(systemName: symbol,
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 13.5, weight: .semibold))
        style.imagePadding = 5
        style.titleLineBreakMode = .byTruncatingTail
        style.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 10, bottom: 9, trailing: 10)
        style.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFontMetrics(forTextStyle: .subheadline).scaledFont(
                for: .systemFont(ofSize: 13.5, weight: .semibold))
        ]))
        let button = UIButton(configuration: style, primaryAction: UIAction { _ in action() })
        if prominent {
            button.tintColor = tint
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        return button
    }
}

// MARK: - Action & Option List

@available(iOS 26.0, *)
final class ErosActionListSheet: ErosSheetController {
    override func buildContent() {
        let items = config["items"] as? [[String: Any]] ?? []
        let selectedId = string("selected")
        let showChevrons = bool("showChevrons")
        content.addArrangedSubview(spacer(4))
        let rows = items.map { item in
            let id = item["id"] as? String ?? ""
            return optionRow(
                item,
                selected: !selectedId.isEmpty && id == selectedId,
                showChevron: showChevrons
            )
        }
        content.addArrangedSubview(tray(rows, separatorInset: 58))
    }

    private func optionRow(
        _ item: [String: Any],
        selected: Bool,
        showChevron: Bool
    ) -> UIView {
        let id = item["id"] as? String ?? ""
        let titleText = item["title"] as? String ?? ""
        let enabled = item["enabled"] as? Bool ?? true
        var style = UIButton.Configuration.plain()
        style.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        let button = UIButton(configuration: style, primaryAction: UIAction { [weak self] _ in
            guard enabled else { return }
            self?.finishWith("select", id)
        })
        button.isEnabled = enabled
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true

        let icon = UIImageView(image: UIImage(systemName: item["symbol"] as? String ?? "ellipsis"))
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        icon.tintColor = selected
            ? tint
            : UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 1, alpha: 0.68)
                    : UIColor(white: 0, alpha: 0.56)
            }
        icon.contentMode = .center
        icon.backgroundColor = selected
            ? tint.withAlphaComponent(0.14)
            : UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 1, alpha: 0.08)
                    : UIColor(white: 0, alpha: 0.05)
            }
        icon.layer.cornerRadius = 10
        icon.layer.cornerCurve = .continuous
        icon.widthAnchor.constraint(equalToConstant: 32).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let title = UILabel()
        title.text = titleText
        title.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .systemFont(ofSize: 15.5, weight: selected ? .semibold : .medium))
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .label
        title.numberOfLines = 0

        var arranged: [UIView] = [icon, title]
        if selected {
            let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            check.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            check.tintColor = tint
            check.contentMode = .scaleAspectFit
            check.setContentHuggingPriority(.required, for: .horizontal)
            check.setContentCompressionResistancePriority(.required, for: .horizontal)
            arranged.append(check)
        } else if showChevron && enabled {
            let chevron = UIImageView(image: UIImage(systemName: "chevron.forward"))
            chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            chevron.tintColor = .tertiaryLabel
            chevron.contentMode = .scaleAspectFit
            chevron.setContentHuggingPriority(.required, for: .horizontal)
            chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
            arranged.append(chevron)
        }

        let row = UIStackView(arrangedSubviews: arranged)
        row.spacing = 12
        row.alignment = .center
        row.alpha = enabled ? 1.0 : 0.38
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: button.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
        ])
        button.accessibilityLabel = titleText
        var traits: UIAccessibilityTraits = .button
        if selected {
            traits.insert(.selected)
        }
        if !enabled {
            traits.insert(.notEnabled)
        }
        button.accessibilityTraits = traits
        return button
    }
}
