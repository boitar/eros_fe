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
        findSettingsRow("卡片大小").tap()
        let previous = state().label
        let size = Int(previous.components(separatedBy: "size=").last ?? "") ?? 2
        // Any step but the one already chosen, and never back to standard.
        let pick = size == 3 ? "较小" : "较大"
        let expected = size == 3 ? "1" : "3"
        tap(pick)
        let current = state(custom: true)
        expectation(for: NSPredicate(format: "label ENDSWITH %@", "size=" + expected),
                    evaluatedWith: current)
        waitForExpectations(timeout: 15)
        print("EROS_GRID_EXPECTED_WIDTH=" + expected)
        record("grid-tags-card-size-and-preview")
    }
    func testProductionRestoredModeAndWidth() {
        let current = state(custom: true)
        let size = current.label.components(separatedBy: "size=").last ?? ""
        XCTAssertNotNil(Int(size), current.label)
        print("EROS_GRID_RESTORED_WIDTH=" + size)
        let first = app.descendants(matching: .any)["offline-gallery-9100000"]
        XCTAssertTrue(first.waitForExistence(timeout: 30), app.debugDescription)
        record("grid-tags-production-settings-restored")
    }
}
