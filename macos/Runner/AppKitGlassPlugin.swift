import Cocoa
import QuartzCore
import FlutterMacOS

/// AppKit factories are registered only on a real macOS host. Availability is
/// negotiated before Dart creates a view; old systems keep the Flutter renderer.
final class AppKitGlassPlugin: NSObject, FlutterPlugin {
  fileprivate static var interactive = true

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "eros/appkit-glass", binaryMessenger: registrar.messenger)
    MacOSWindowChromePlugin.register(with: registrar)
    AppKitMenuPlugin.register(with: registrar)
    let plugin = AppKitGlassPlugin()
    registrar.addMethodCallDelegate(plugin, channel: channel)
    registrar.register(AppKitGlassFactory(messenger: registrar.messenger), withId: "eros/appkit-glass-view")
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "setInteractive", let value = call.arguments as? Bool {
      Self.interactive = value
      result(nil)
      return
    }
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
  private var selection: NSView?
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
    decorative || !AppKitGlassPlugin.interactive ? nil : super.hitTest(point)
  }
  private func rebuild() {
    subviews.forEach { $0.removeFromSuperview() }
    buttons.removeAll()
    selection = nil
    appearance = NSAppearance(named: configuration["dark"] as? Bool == true ? .darkAqua : .aqua)
    // The Dart key keeps its name; it now carries the glass material:
    // true is Liquid Glass, false is the frosted blur. Both honour the
    // system's Reduce Transparency and Increase Contrast.
    let liquid = configuration["followSystemTransparency"] as? Bool ?? true
    let opaque = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    let body = NSView(frame: bounds)
    if decorative && !opaque {
      // Navigation backgrounds use window chrome material. NSGlassEffectView
      // is a floating control surface and adds a rectangular lens rim here.
      let chrome = NSVisualEffectView(frame: bounds)
      chrome.material = .headerView
      chrome.blendingMode = .withinWindow
      chrome.state = .followsWindowActiveState
      chrome.addSubview(body)
      backing = chrome
    } else if !opaque && !liquid {
      let frosted = NSVisualEffectView(frame: bounds)
      frosted.material = .popover
      frosted.blendingMode = .withinWindow
      frosted.state = .active
      frosted.wantsLayer = true
      frosted.layer?.masksToBounds = true
      frosted.addSubview(body)
      backing = frosted
    } else if #available(macOS 26.0, *), !opaque {
      let glass = NSGlassEffectView(frame: bounds)
      glass.style = .regular
      glass.cornerRadius = decorative ? 0 : bounds.height / 2
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
      let highlight = NSView()
      highlight.wantsLayer = true
      highlight.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
      body.addSubview(highlight)
      selection = highlight
      for (index, item) in items.enumerated() {
        let label = item["label"] as? String ?? ""
        let button = GlassTabButton(label:label,symbol:item["fallbackSymbol"] as? String)
        button.target = self
        button.action = #selector(selectTab(_:))
        button.tag = index
        body.addSubview(button)
        buttons.append(button)
      }
      if configuration["search"] as? Bool == true {
        let label = configuration["searchLabel"] as? String ?? "Search"
        let button = GlassTabButton(label:label,symbol:"magnifyingglass")
        button.target = self
        button.action = #selector(search)
        button.tag = -1
        body.addSubview(button)
        buttons.append(button)
      }
      syncSelection(animated:false)
    }
    needsLayout = true
  }
  override func layout() {
    super.layout()
    let inset: CGFloat = decorative ? 0 : 6
    backing?.frame = bounds.insetBy(dx: inset, dy: inset)
    if let frosted = backing as? NSVisualEffectView, !decorative {
      frosted.layer?.cornerRadius = frosted.bounds.height / 2
    }
    content?.frame = NSRect(origin: .zero, size: backing?.bounds.size ?? bounds.size)
    guard !buttons.isEmpty, let content else { return }
    let width = max(0, (content.bounds.width - 12) / CGFloat(buttons.count))
    for (index, button) in buttons.enumerated() {
      button.frame = NSRect(x: 6 + CGFloat(index) * width, y: 5, width: max(0,width - 4), height: max(0,content.bounds.height - 10))
    }
    updateSelectionFrame(animated:false)
  }
  @objc private func selectTab(_ sender: NSButton) {
    guard AppKitGlassPlugin.interactive else { return }
    channel.invokeMethod("select", arguments: sender.tag)
    // Selection remains Dart-owned, including tab reselection/navigation guards.
    syncSelection()
  }
  private func syncSelection(animated: Bool = true) {
    let selected = configuration["selectedIndex"] as? Int ?? 0
    for button in buttons {
      let active = button.tag >= 0 && button.tag == selected
      button.state = active ? .on : .off
      (button as? GlassTabButton)?.setSelected(active)
      button.setAccessibilityValue(active ? "1" : "0")
    }
    updateSelectionFrame(animated:animated)
  }
  private func updateSelectionFrame(animated:Bool) {
    guard let selection else { return }
    let selected = configuration["selectedIndex"] as? Int ?? 0
    guard let button = buttons.first(where: { $0.tag == selected }) else { selection.isHidden = true; return }
    selection.isHidden = false
    selection.layer?.cornerRadius = button.bounds.height / 2
    if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && !selection.frame.isEmpty {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.2
        context.timingFunction = CAMediaTimingFunction(name:.easeInEaseOut)
        selection.animator().frame = button.frame
      }
    } else { selection.frame = button.frame }
  }
  @objc private func search() {
    guard AppKitGlassPlugin.interactive else { return }
    channel.invokeMethod("search", arguments: nil)
  }
}

/// Borderless hit target; AppKit owns focus/keyboard and VoiceOver state.
private final class GlassTabButton: NSButton {
  override var isFlipped: Bool { true }
  private let glyph = NSImageView()
  private let caption: NSTextField
  init(label:String,symbol:String?) {
    caption = NSTextField(labelWithString:label)
    super.init(frame:.zero)
    title = ""
    isBordered = false
    setButtonType(.toggle)
    focusRingType = .exterior
    if let symbol { glyph.image = NSImage(systemSymbolName:symbol,accessibilityDescription:nil) }
    glyph.imageScaling = .scaleProportionallyDown
    caption.alignment = .center
    caption.lineBreakMode = .byTruncatingTail
    glyph.setAccessibilityElement(false)
    caption.setAccessibilityElement(false)
    addSubview(glyph); addSubview(caption)
    toolTip = label
    setAccessibilityLabel(label)
    setSelected(false)
  }
  required init?(coder:NSCoder) { fatalError("init(coder:) not supported") }
  override func hitTest(_ point:NSPoint) -> NSView? {
    bounds.contains(convert(point,from:superview)) ? self : nil
  }
  func setSelected(_ selected:Bool) {
    let color:NSColor = selected ? .controlAccentColor : .secondaryLabelColor
    glyph.contentTintColor = color
    caption.textColor = color
    caption.font = .systemFont(ofSize:13,weight:selected ? .semibold : .regular)
  }
  override func layout() {
    super.layout()
    let total:CGFloat = 20 + 4 + 16
    let bottom = max(0,(bounds.height-total)/2)
    glyph.frame = NSRect(x:(bounds.width-20)/2,y:bottom,width:20,height:20)
    caption.frame = NSRect(x:0,y:bottom+24,width:bounds.width,height:16)
  }
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

/// Geometry is reported by AppKit even when the glass renderer is off/unavailable.
private final class MacOSWindowChromePlugin: NSObject, FlutterPlugin {
  private weak var host: NSView?
  private let channel: FlutterMethodChannel
  private var observers: [NSObjectProtocol] = []
  private var lastGeometry: [String:Any]?
  init(host: NSView?, channel: FlutterMethodChannel) {
    self.host = host; self.channel = channel
    super.init()
    for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification,
                 NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification,
                 NSWindow.didBecomeKeyNotification] {
      observers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] note in
        guard let self, let window = note.object as? NSWindow, window === self.host?.window else { return }
        self.publishGeometryIfChanged()
      })
    }
  }
  deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name:"eros/window-chrome",binaryMessenger:registrar.messenger)
    registrar.addMethodCallDelegate(MacOSWindowChromePlugin(host:registrar.view,channel:channel),channel:channel)
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "get" {
      let current = geometry()
      lastGeometry = current
      result(current)
    } else { result(FlutterMethodNotImplemented) }
  }
  // The app does not independently toggle standardWindowButton.isHidden or
  // change titlebar style at runtime. System fullscreen hiding is covered by
  // enter/exit notifications above. Future custom titlebar mutations must call
  // this refresh method after changing visibility (including hidden ancestors).
  private func publishGeometryIfChanged() {
    let current = geometry()
    if let lastGeometry, NSDictionary(dictionary:lastGeometry).isEqual(to:current) { return }
    lastGeometry = current
    channel.invokeMethod("changed", arguments:current)
  }
  private func geometry() -> [String:Any] {
    guard let host, let window = host.window else { return ["buttons":[]] }
    let fullscreen = window.styleMask.contains(.fullScreen)
    var buttons: [[String:Any]] = []
    if !fullscreen {
      for kind in [NSWindow.ButtonType.closeButton,.miniaturizeButton,.zoomButton] {
        guard let button = window.standardWindowButton(kind), !button.isHiddenOrHasHiddenAncestor else { continue }
        let frame = button.convert(button.bounds,to:host)
        buttons.append(["x":frame.minX,"y":host.isFlipped ? frame.minY : host.bounds.height-frame.maxY,"width":frame.width,"height":frame.height])
      }
    }
    return ["fullscreen":fullscreen,"buttons":buttons]
  }
}
