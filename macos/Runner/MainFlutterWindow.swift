import Cocoa
import FlutterMacOS
import bitsdojo_window_macos

class MainFlutterWindow: BitsdojoWindow {
  private static let trafficLightLeft: CGFloat = 22.0
  private static let trafficLightCenterY: CGFloat = 32.0

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
}
