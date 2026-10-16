import XCTest
import UIKit

/// Run existing business scenarios with glass enabled through the real settings.
/// Each fixture keeps its own account; this does not enable the glass seed data.
func tapNativeTabIfPresent(_ app: XCUIApplication, label: String) -> Bool {
    guard ["画廊", "收藏", "排行", "下载", "设置"].contains(label) else { return false }
    let button = app.buttons.matching(NSPredicate(
        format: "identifier BEGINSWITH %@ AND label == %@", "liquid-glass-tab-", label)).firstMatch
    guard button.exists, !button.frame.isEmpty else { return false }
    XCTAssertTrue(app.frame.contains(CGPoint(x: button.frame.midX, y: button.frame.midY)))
    app.coordinate(withNormalizedOffset: .zero).withOffset(
        CGVector(dx: button.frame.midX, dy: button.frame.midY)).press(forDuration: 0.15)
    return true
}

extension XCTestCase {
    func enableGlassForIntegration(_ app: XCUIApplication) {
        guard ProcessInfo.processInfo.environment["EROS_VERIFY_GLASS"] == "1" else { return }
        if app.buttons["liquid-glass-tab-0"].exists {
            print("EROS_CROSS_GLASS_ACTIVE")
            return
        }
        let settings = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "设置")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 40), app.debugDescription)
        if !tapNativeTabIfPresent(app, label: "设置") { settings.tap() }
        let style = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "样式")).firstMatch
        XCTAssertTrue(style.waitForExistence(timeout: 20), app.debugDescription)
        style.tap()
        let wrapper = app.descendants(matching: .any)["offline-glass-control-enabled"]
        let x = UIDevice.current.userInterfaceIdiom == .pad ? 0.70 : 0.5
        for _ in 0..<12 {
            if wrapper.exists && wrapper.isHittable { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                    withNormalizedOffset: CGVector(dx: x, dy: 0.35)))
        }
        XCTAssertTrue(wrapper.exists && wrapper.isHittable, app.debugDescription)
        let toggle = wrapper.switches.firstMatch
        let value = toggle.exists ? toggle.value as? String : wrapper.value as? String
        if value != "1" {
            wrapper.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        if toggle.exists { XCTAssertEqual(toggle.value as? String, "1") }
        let back = app.buttons.matching(NSPredicate(
            format: "label == '返回' OR label == 'Back'")).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 15), app.debugDescription)
        back.tap()
        XCTAssertTrue(app.buttons["liquid-glass-tab-0"].waitForExistence(timeout: 20),
                      "The actual rendered navigation must be native glass: " + app.debugDescription)
        XCTAssertTrue(tapNativeTabIfPresent(app, label: "画廊"))
        print("EROS_CROSS_GLASS_ACTIVE")
    }
}
