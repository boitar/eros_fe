import Cocoa
import FlutterMacOS

/// AppKit factories are registered only on a real macOS host. Availability is
/// negotiated before Dart creates a view; old systems keep the Flutter renderer.
final class AppKitGlassPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "eros/appkit-glass", binaryMessenger: registrar.messenger)
    AppKitMenuPlugin.register(with: registrar)
    let plugin = AppKitGlassPlugin()
    registrar.addMethodCallDelegate(plugin, channel: channel)
    registrar.register(AppKitGlassFactory(messenger: registrar.messenger), withId: "eros/appkit-glass-view")
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "capabilities" else { result(FlutterMethodNotImplemented); return }
    if #available(macOS 26.0, *) {
      result(["apiVersion": 1, "backend": "appKit", "menu": true])
    } else { result(["apiVersion": 1, "backend": "none", "menu": true]) }
  }
}

private final class AppKitGlassFactory: NSObject, FlutterPlatformViewFactory {
  let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? { FlutterStandardMessageCodec.sharedInstance() }
  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    AppKitGlassHost(id: viewId, messenger: messenger, configuration: args as? [String: Any] ?? [:])
  }
}

private final class AppKitGlassHost: NSView {
  private let channel: FlutterMethodChannel
  private var configuration: [String: Any]
  private var accessibilityObserver: NSObjectProtocol?
  private var buttons: [NSButton] = []
  private var backing: NSView?
  private var content: NSView?
  private var decorative: Bool { configuration["kind"] as? String == "surface" }
  override var isFlipped: Bool { true }

  init(id: Int64, messenger: FlutterBinaryMessenger, configuration: [String: Any]) {
    self.configuration = configuration
    channel = FlutterMethodChannel(name: "eros/appkit-glass/\(id)", binaryMessenger: messenger)
    super.init(frame: NSRect(x: 0, y: 0, width: 600, height: 68))
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      guard call.method == "update", let config = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented); return
      }
      if !NSDictionary(dictionary: self.configuration).isEqual(to: config) {
        var previous = self.configuration
        var updated = config
        previous.removeValue(forKey: "selectedIndex")
        updated.removeValue(forKey: "selectedIndex")
        self.configuration = config
        if NSDictionary(dictionary: previous).isEqual(to: updated) {
          // Keep NSButton identity and keyboard/VoiceOver focus on selection.
          self.syncSelection()
        } else {
          self.rebuild()
        }
      }
      result(nil)
    }
    accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: nil, queue: .main) { [weak self] _ in self?.rebuild() }
    rebuild()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
  deinit {
    channel.setMethodCallHandler(nil)
    if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver) }
  }
  // A decorative platform view must not steal Flutter toolbar input. Flutter's
  // GestureArena accept/reject is not implemented by the macOS embedder.
  override func hitTest(_ point: NSPoint) -> NSView? {
    decorative ? nil : super.hitTest(point)
  }
  private func rebuild() {
    subviews.forEach { $0.removeFromSuperview() }
    buttons.removeAll()
    appearance = NSAppearance(named: configuration["dark"] as? Bool == true ? .darkAqua : .aqua)
    let follow = configuration["followSystemTransparency"] as? Bool ?? true
    let opaque = follow && (NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
    let body = NSView(frame: bounds)
    if #available(macOS 26.0, *), !opaque {
      let glass = NSGlassEffectView(frame: bounds)
      glass.style = .regular
      glass.cornerRadius = decorative ? 0 : 24
      glass.contentView = body
      if #available(macOS 27.0, *) { glass.effectIsInteractive = !decorative && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
      backing = glass
    } else {
      let plain = NSView(frame: bounds)
      plain.wantsLayer = true
      plain.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
      plain.addSubview(body)
      backing = plain
    }
    content = body
    if let backing { addSubview(backing) }
    if !decorative {
      let items = configuration["items"] as? [[String: Any]] ?? []
      let selected = configuration["selectedIndex"] as? Int ?? 0
      for (index, item) in items.enumerated() {
        let label = item["label"] as? String ?? ""
        let button = NSButton(title: label, target: self, action: #selector(selectTab(_:)))
        button.tag = index
        button.setButtonType(.toggle)
        button.bezelStyle = .rounded
        button.state = selected == index ? .on : .off
        button.contentTintColor = selected == index ? .controlAccentColor : .labelColor
        if let symbol = item["fallbackSymbol"] as? String,
           let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label) {
          button.image = image
          button.imagePosition = .imageAbove
        }
        button.setAccessibilityLabel(label)
        button.setAccessibilityValue(selected == index ? "1" : "0")
        button.toolTip = label
        body.addSubview(button)
        buttons.append(button)
      }
      if configuration["search"] as? Bool == true {
        let label = configuration["searchLabel"] as? String ?? "Search"
        let button = NSButton(title: label, target: self, action: #selector(search))
        button.tag = -1
        button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: label)
        button.imagePosition = .imageAbove
        button.bezelStyle = .rounded
        body.addSubview(button)
        buttons.append(button)
      }
    }
    needsLayout = true
  }
  override func layout() {
    super.layout()
    let inset: CGFloat = decorative ? 0 : 6
    backing?.frame = bounds.insetBy(dx: inset, dy: inset)
    content?.frame = NSRect(origin: .zero, size: backing?.bounds.size ?? bounds.size)
    guard !buttons.isEmpty, let content else { return }
    let width = max(0, (content.bounds.width - 12) / CGFloat(buttons.count))
    for (index, button) in buttons.enumerated() {
      button.frame = NSRect(x: 6 + CGFloat(index) * width, y: 5, width: max(0,width - 4), height: max(0,content.bounds.height - 10))
    }
  }
  @objc private func selectTab(_ sender: NSButton) {
    channel.invokeMethod("select", arguments: sender.tag)
    // Selection remains Dart-owned, including tab reselection/navigation guards.
    syncSelection()
  }
  private func syncSelection() {
    let selected = configuration["selectedIndex"] as? Int ?? 0
    for button in buttons {
      let active = button.tag >= 0 && button.tag == selected
      button.state = active ? .on : .off
      button.contentTintColor = active ? .controlAccentColor : .labelColor
      button.setAccessibilityValue(active ? "1" : "0")
    }
  }
  @objc private func search() { channel.invokeMethod("search", arguments: nil) }
}

/// Native action menus use the existing iOS token/index protocol. NSMenu is
/// available on older macOS too and is independent of the glass renderer.
private final class AppKitMenuPlugin: NSObject, FlutterPlugin, NSMenuDelegate {
  private let channel: FlutterMethodChannel
  private weak var host: NSView?
  private var active: NSMenu?
  private var token: Int?
  init(channel: FlutterMethodChannel, host: NSView?) { self.channel = channel; self.host = host }
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "eros/menu", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(AppKitMenuPlugin(channel: channel, host: registrar.view), channel: channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "show" else { result(FlutterMethodNotImplemented); return }
    guard let host, host.window != nil,
          let args = call.arguments as? [String: Any],
          let token = args["token"] as? Int,
          let rect = args["rect"] as? [String: Double],
          let x = rect["x"], let y = rect["y"], let height = rect["height"],
          x.isFinite, y.isFinite, height.isFinite,
          let items = args["items"] as? [[String: Any]], !items.isEmpty else { result(false); return }
    active?.cancelTracking()
    let menu = NSMenu()
    menu.autoenablesItems = false
    menu.delegate = self
    for (index, value) in items.enumerated() {
      let item = NSMenuItem(title: value["title"] as? String ?? "", action: #selector(selected(_:)), keyEquivalent: "")
      item.target = self
      item.tag = index
      item.isEnabled = value["enabled"] as? Bool ?? true
      item.state = value["checked"] as? Bool == true ? .on : .off
      item.toolTip = value["subtitle"] as? String
      if let symbol = value["symbol"] as? String {
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
      }
      menu.addItem(item)
    }
    self.token = token
    active = menu
    // Reply before entering AppKit's menu tracking loop; otherwise Dart cannot
    // distinguish unavailable menus from an already visible native menu.
    result(true)
    DispatchQueue.main.async { [weak self, weak host] in
      guard let self, let host, self.active === menu else { return }
      let point = NSPoint(x: x, y: host.isFlipped ? y + height : host.bounds.height - y - height)
      menu.popUp(positioning: nil, at: point, in: host)
      // Also covers cancellation before menuDidClose.
      if self.active === menu { self.finish() }
    }
  }
  @objc private func selected(_ sender: NSMenuItem) {
    guard let token else { return }
    channel.invokeMethod("selected", arguments: ["token": token, "index": sender.tag])
  }
  func menuDidClose(_ menu: NSMenu) {
    // AppKit may dispatch the selected action immediately after this delegate.
    DispatchQueue.main.async { [weak self] in
      if self?.active === menu { self?.finish() }
    }
  }
  private func finish() {
    if let token { channel.invokeMethod("dismissed", arguments: ["token": token]) }
    token = nil
    active = nil
  }
}
