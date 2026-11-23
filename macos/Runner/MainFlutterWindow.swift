import Cocoa
import FlutterMacOS
import bitsdojo_window_macos

class MainFlutterWindow: BitsdojoWindow {
  private static let trafficLightLeft: CGFloat = 22.0
  private static let trafficLightCenterY: CGFloat = 32.0
  private var appIconChannel: FlutterMethodChannel?
  private var appliedAppIconImage: NSImage?
  private var didFinishLaunchingObserver: NSObjectProtocol?

  deinit {
    if let observer = didFinishLaunchingObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  override func bitsdojo_window_configure() -> UInt {
    return BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    if #available(macOS 11.0, *) {
      // A hidden unified toolbar expands NSTitlebarContainerView so lowered
      // traffic lights fit cleanly inside the floating sidebar header without clipping.
      let toolbar = NSToolbar(identifier: "ErosDesktopTitlebar")
      toolbar.showsBaselineSeparator = false
      self.toolbar = toolbar
      self.toolbarStyle = .unified
      self.titlebarSeparatorStyle = .none
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    AppKitGlassPlugin.register(with: flutterViewController.registrar(forPlugin: "AppKitGlassPlugin"))
    registerAppIconChannel(with: flutterViewController)

    super.awakeFromNib()
    positionTrafficLights()
    DispatchQueue.main.async { [weak self] in
      self?.positionTrafficLights()
    }
  }

  override func makeKeyAndOrderFront(_ sender: Any?) {
    super.makeKeyAndOrderFront(sender)
    positionTrafficLights()
    DispatchQueue.main.async { [weak self] in
      self?.positionTrafficLights()
    }
  }

  override func orderFront(_ sender: Any?) {
    super.orderFront(sender)
    positionTrafficLights()
    DispatchQueue.main.async { [weak self] in
      self?.positionTrafficLights()
    }
  }

  override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    super.setFrame(frameRect, display: flag)
    positionTrafficLights()
  }

  override func layoutIfNeeded() {
    super.layoutIfNeeded()
    positionTrafficLights()
  }

  func positionTrafficLights() {
    guard !styleMask.contains(.fullScreen),
          let contentView,
          let close = standardWindowButton(.closeButton),
          let mini = standardWindowButton(.miniaturizeButton),
          let zoom = standardWindowButton(.zoomButton),
          let titlebarView = close.superview else {
      return
    }
    let measuredPitch = mini.frame.minX - close.frame.minX
    let pitch: CGFloat = (measuredPitch >= 16.0 && measuredPitch <= 28.0) ? measuredPitch : 20.0
    let buttons = [close, mini, zoom]
    let contentHeight = contentView.bounds.height
    for (index, button) in buttons.enumerated() {
      guard !button.isHidden else { continue }
      let size = button.frame.size
      guard size.width > 0, size.height > 0 else { continue }
      let centerX = Self.trafficLightLeft + CGFloat(index) * pitch + size.width / 2.0
      let pointInContent = contentView.isFlipped
        ? NSPoint(x: centerX, y: Self.trafficLightCenterY)
        : NSPoint(x: centerX, y: contentHeight - Self.trafficLightCenterY)
      let centerInTitlebar = titlebarView.convert(pointInContent, from: contentView)
      let targetOrigin = NSPoint(
        x: centerInTitlebar.x - size.width / 2.0,
        y: centerInTitlebar.y - size.height / 2.0
      )
      if abs(button.frame.origin.x - targetOrigin.x) > 0.25 ||
          abs(button.frame.origin.y - targetOrigin.y) > 0.25 {
        button.setFrameOrigin(targetOrigin)
      }
    }
  }

  private static func loadAppIconImage(
    assetPath: String,
    controller: FlutterViewController
  ) -> (image: NSImage?, candidatePaths: [String]) {
    let assetKey = controller.lookupKey(forAsset: assetPath)
    let bundlePath = Bundle.main.bundlePath as NSString
    let resourcePath = Bundle.main.resourcePath as NSString?
    var candidatePaths: [String] = []
    if (assetKey as NSString).isAbsolutePath {
      candidatePaths.append(assetKey)
    } else {
      // On macOS, FlutterViewController.lookupKey(forAsset:) already returns
      // "Contents/Frameworks/App.framework/Resources/flutter_assets/<assetPath>".
      candidatePaths.append(bundlePath.appendingPathComponent(assetKey))
      if let resourcePath {
        candidatePaths.append(resourcePath.appendingPathComponent(assetKey))
      }
    }
    candidatePaths.append(
      bundlePath.appendingPathComponent(
        "Contents/Frameworks/App.framework/Resources/flutter_assets/\(assetPath)"
      )
    )
    if let resourcePath {
      candidatePaths.append(resourcePath.appendingPathComponent("flutter_assets/\(assetPath)"))
    }
    guard let imagePath = candidatePaths.first(where: { FileManager.default.fileExists(atPath: $0) }),
          let image = NSImage(contentsOfFile: imagePath) else {
      return (nil, candidatePaths)
    }
    return (image, candidatePaths)
  }

  private func applyAppIconImage(_ image: NSImage?) {
    appliedAppIconImage = image
    // Note: setting `applicationIconImage` internally manages `dockTile.contentView`
    // (creating an NSImageView for custom icons and clearing it to nil when reset).
    // Never clear `dockTile.contentView = nil` after assigning a custom image, or
    // AppKit reverts the Dock tile back to the default bundle icon.
    NSApplication.shared.applicationIconImage = image
    NSApplication.shared.dockTile.display()
  }

  private func registerAppIconChannel(with flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "eros/app_icon",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    appIconChannel = channel
    if didFinishLaunchingObserver == nil {
      didFinishLaunchingObserver = NotificationCenter.default.addObserver(
        forName: NSApplication.didFinishLaunchingNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self, let image = self.appliedAppIconImage else { return }
        self.applyAppIconImage(image)
      }
    }
    channel.setMethodCallHandler { [weak self, weak flutterViewController] call, result in
      guard call.method == "setAppIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let style = call.arguments as? String else {
        result(FlutterError(
          code: "invalid_arguments",
          message: "Expected app icon style string",
          details: nil
        ))
        return
      }
      let assetPath: String
      switch style {
      case "auto", "monochrome":
        DispatchQueue.main.async {
          self?.applyAppIconImage(nil)
          result(nil)
        }
        return
      case "light":
        assetPath = "assets/images/app_icon_light_macos.png"
      case "dark":
        assetPath = "assets/images/app_icon_dark_macos.png"
      case "purple":
        assetPath = "assets/images/app_icon_purple_macos.png"
      default:
        result(FlutterError(
          code: "invalid_app_icon",
          message: "Expected auto, light, dark, or purple",
          details: nil
        ))
        return
      }
      guard let controller = flutterViewController else {
        result(FlutterError(
          code: "unavailable",
          message: "FlutterViewController is unavailable",
          details: nil
        ))
        return
      }
      let (image, candidatePaths) = Self.loadAppIconImage(
        assetPath: assetPath,
        controller: controller
      )
      guard let image else {
        result(FlutterError(
          code: "asset_not_found",
          message: "Could not load \(style) macOS app icon asset",
          details: candidatePaths
        ))
        return
      }
      DispatchQueue.main.async {
        self?.applyAppIconImage(image)
        result(nil)
      }
    }
  }
}
