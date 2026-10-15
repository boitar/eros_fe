import XCTest
import UIKit

final class GridTagsEntryTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.activate()
    }
    private func element(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ OR label BEGINSWITH %@", label, label + "\n")).firstMatch
    }
    private func state(_ mode: String = "gridTags", custom: Bool? = nil) -> XCUIElement {
        let prefix = "offline-grid-ready-" + mode + "-"
        let result = custom == nil
            ? app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
            : app.descendants(matching: .any)[prefix + (custom! ? "custom" : "default")]
        XCTAssertTrue(result.waitForExistence(timeout: 40), app.debugDescription)
        return result
    }
    private func tap(_ label: String) {
        let target = element(label)
        XCTAssertTrue(target.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(target.isHittable, app.debugDescription)
        target.tap()
    }
    private func record(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func findSettingsRow(_ label: String) -> XCUIElement {
        let row = element(label)
        let ipad = UIDevice.current.userInterfaceIdiom == .pad
        let x = app.frame.width * (ipad ? 0.70 : 0.5)
        for _ in 0..<12 {
            if row.exists && row.isHittable { break }
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: app.frame.height * 0.75))
            let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: app.frame.height * 0.35))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(row.isHittable, app.debugDescription)
        return row
    }
    func testProductionGeometryAndRotation() {
        _ = state()
        let first = app.descendants(matching: .any)["offline-gallery-9100000"]
        let second = app.descendants(matching: .any)["offline-gallery-9100001"]
        XCTAssertTrue(first.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(second.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertGreaterThan(first.frame.width, 40)
        XCTAssertEqual(first.frame.height, second.frame.height, accuracy: 2)
        record("grid-tags-production-equal-cards-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        _ = state(); record("grid-tags-production-landscape")
        XCUIDevice.shared.orientation = .portrait
    }
    func testProductionModeWidthAndPersistence() {
        _ = state()
        tap("设置"); tap("样式")
        findSettingsRow("列表样式").tap(); tap("网格")
        _ = state("grid")
        findSettingsRow("列表样式").tap(); tap("网格 - 标签")
        _ = state()
        findSettingsRow("自定义宽度").tap()
        let toggle = app.switches.firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 20), app.debugDescription)
        if toggle.value as? String == "0" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, "1", app.debugDescription)
        let previous = state(custom: true).label
        let slider = app.descendants(matching: .any).matching(
            NSPredicate(format: "value MATCHES %@", "[0-9]+%")).firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 20), app.debugDescription)
        let width = Int(previous.components(separatedBy: "width=").last ?? "") ?? 150
        let start = Double((slider.value as? String ?? "17%").replacingOccurrences(of: "%", with: ""))! / 100
        slider.coordinate(withNormalizedOffset: CGVector(dx: start, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: slider.coordinate(
                withNormalizedOffset: CGVector(dx: width > 250 ? 0.35 : 0.65, dy: 0.5)))
        let current = state(custom: true)
        expectation(for: NSPredicate(format: "label != %@", previous), evaluatedWith: current)
        waitForExpectations(timeout: 15)
        let widthField = app.textFields.firstMatch
        XCTAssertTrue(widthField.waitForExistence(timeout: 15), app.debugDescription)
        let finalWidth = widthField.value as? String ?? ""
        XCTAssertNotNil(Int(finalWidth))
        expectation(for: NSPredicate(format: "label ENDSWITH %@", "width=" + finalWidth),
                    evaluatedWith: current)
        waitForExpectations(timeout: 15)
        XCTAssertFalse(current.label.contains("width=0"), current.label)
        print("EROS_GRID_EXPECTED_WIDTH=" + finalWidth)
        record("grid-tags-real-width-slider-and-preview")
    }
    func testProductionRestoredModeAndWidth() {
        let current = state(custom: true)
        XCTAssertFalse(current.label.contains("width=0"), current.label)
        let width = current.label.components(separatedBy: "width=").last ?? ""
        XCTAssertNotNil(Int(width))
        print("EROS_GRID_RESTORED_WIDTH=" + width)
        let first = app.descendants(matching: .any)["offline-gallery-9100000"]
        XCTAssertTrue(first.waitForExistence(timeout: 30), app.debugDescription)
        record("grid-tags-production-settings-restored")
    }
}
