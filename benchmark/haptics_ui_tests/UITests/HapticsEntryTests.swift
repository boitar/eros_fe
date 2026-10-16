import XCTest
import UIKit

final class HapticsEntryTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.activate()
        enableGlassForIntegration(app)
    }
    private func element(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
    private func record(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func probe(_ enabled: Bool) {
        let status = app.descendants(matching: .any)["offline-haptics-ready-\(enabled ? "on" : "off")"]
        XCTAssertTrue(status.waitForExistence(timeout: 60), app.debugDescription)
        XCTAssertTrue(status.label.contains("accepted prepare=\(enabled ? 1 : 0)"), status.label)
        XCTAssertTrue(status.label.contains("accepted tick=\(enabled ? 2 : 0)"), status.label)
        XCTAssertTrue(status.label.contains("accepted feedback=\(enabled ? 6 : 0)"), status.label)
        // These are accepted method calls, never a claim of physical vibration.
        print("HAPTICS_NATIVE_PROBE: " + status.label)
    }
    private func scroll(advanced: Bool) {
        let ipad = UIDevice.current.userInterfaceIdiom == .pad
        let x = app.frame.width * (ipad ? (advanced ? 0.7 : 0.18) : 0.5)
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: app.frame.height * 0.75))
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: app.frame.height * 0.35))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
    private func openToggle() -> XCUIElement {
        let settings = element("设置")
        XCTAssertTrue(settings.waitForExistence(timeout: 20), app.debugDescription)
        if !tapNativeTabIfPresent(app, label: "设置") { settings.tap() }
        let advanced = element("高级")
        for _ in 0..<6 {
            if advanced.exists && advanced.isHittable { break }
            scroll(advanced: false)
        }
        XCTAssertTrue(advanced.isHittable, app.debugDescription); advanced.tap()
        let toggle = app.descendants(matching: .any)["offline-haptics-toggle"]
        for _ in 0..<6 {
            if toggle.exists && toggle.isHittable { break }
            scroll(advanced: true)
        }
        XCTAssertTrue(toggle.isHittable, app.debugDescription)
        return toggle
    }
    func testProductionEnabledBridgeAndDisable() {
        probe(true)
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Offline gallery 0 -")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), app.debugDescription)
        for _ in 0..<2 {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).press(forDuration: 0.1,
                thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.2)))
        }
        record("haptics-two-production-pulls")
        let toggle = openToggle()
        XCTAssertEqual(toggle.value as? String, "1", app.debugDescription)
        toggle.tap()
        expectation(for: NSPredicate(format: "value == %@", "0"), evaluatedWith: toggle)
        waitForExpectations(timeout: 10)
        record("haptics-disabled-in-production-settings")
    }
    func testProductionRestoredDisabledAndEnable() {
        probe(false)
        let toggle = openToggle()
        XCTAssertEqual(toggle.value as? String, "0", app.debugDescription)
        toggle.tap()
        expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: toggle)
        waitForExpectations(timeout: 10)
        record("haptics-restored-disabled-then-enabled")
    }
    func testProductionRestoredEnabledAndRotation() {
        probe(true)
        XCUIDevice.shared.orientation = .landscapeLeft
        probe(true)
        record("haptics-enabled-after-restart-landscape")
        XCUIDevice.shared.orientation = .portrait
    }
}
