import XCTest
import UIKit

final class GroupIndexEntryTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.activate()
    }
    private func element(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", text)).firstMatch
    }
    private func control(_ name: String) -> XCUIElement {
        app.descendants(matching: .any)["offline-group-control-\(name)"]
    }
    private func selected(_ uuid: String, _ index: Int) {
        XCTAssertTrue(app.descendants(matching: .any)[
            "offline-group-selection-\(uuid)-\(index)"]
            .waitForExistence(timeout: 20), app.debugDescription)
    }
    private func gallery(_ group: String) {
        let title = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@", "Offline group \(group) gallery 0 -")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30), app.debugDescription)
    }
    private func swipePage(_ group: String, left: Bool) {
        let row = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@", "Offline group \(group) gallery 0 -")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), app.debugDescription)
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.9 : 0.1, dy: 0.12))
        let end = row.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.1 : 0.9, dy: 0.12))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
    private func record(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func openManagement() {
        let manage = control("manage")
        XCTAssertTrue(manage.waitForExistence(timeout: 20), app.debugDescription)
        manage.tap()
        XCTAssertTrue(control("reorder").waitForExistence(timeout: 20), app.debugDescription)
    }
    private func leaveManagement() {
        let header = element("分组")
        XCTAssertTrue(header.waitForExistence(timeout: 10), app.debugDescription)
        app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: 20, dy: header.frame.midY)).tap()
        XCTAssertTrue(control("manage").waitForExistence(timeout: 15), app.debugDescription)
    }
    private func delete(_ name: String) {
        let row = element("Group \(name)")
        XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
        row.swipeLeft()
        let point = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: row.frame.maxX - 22, dy: row.frame.midY))
        point.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 15), app.debugDescription)
    }
    func testProductionColdVisibleSelectionAndRotation() {
        selected("offline-c", 1); gallery("C")
        XCTAssertFalse(element("Group B").exists, app.debugDescription)
        // Master's LinkScrollBar measures unscaled text and clips the right
        // hit region at accessibility sizes. Record that inherited limitation;
        // verify visible-index mapping with the existing PageView gesture there.
        let largeType = UIFont.preferredFont(forTextStyle: .body).pointSize > 25
        if largeType { swipePage("C", left: true) }
        else { element("Group D").tap() }
        selected("offline-d", 2); gallery("D")
        if largeType {
            swipePage("D", left: false); selected("offline-c", 1); gallery("C")
            swipePage("C", left: false)
        } else { element("Group A").tap() }
        selected("offline-a", 0); gallery("A")
        if largeType { swipePage("A", left: true) }
        else { element("Group C").tap() }
        selected("offline-c", 1); gallery("C")
        record("group-hidden-middle-selects-real-page")
        XCUIDevice.shared.orientation = .landscapeLeft
        selected("offline-c", 1); gallery("C")
        record("group-visible-selection-landscape")
        XCUIDevice.shared.orientation = .portrait
    }
    func testProductionReorderAndDeleteCurrent() {
        selected("offline-c", 1); gallery("C"); openManagement()
        control("reorder").tap()
        let start = element("Group D"); let end = element("Group A")
        XCTAssertTrue(start.waitForExistence(timeout: 10), app.debugDescription)
        start.press(forDuration: 1.2, thenDragTo: end,
                    withVelocity: .slow, thenHoldForDuration: 1.0)
        let reordered = NSPredicate { _, _ in start.frame.minY < end.frame.minY }
        expectation(for: reordered, evaluatedWith: nil)
        waitForExpectations(timeout: 10)
        record("group-management-reordered")
        control("reorder").tap(); leaveManagement()
        selected("offline-c", 2); gallery("C")
        openManagement(); delete("C"); leaveManagement()
        selected("offline-a", 1); gallery("A")
        record("group-current-delete-chooses-neighbor")
    }
    func testProductionRestoredSelection() {
        selected("offline-a", 1); gallery("A")
        XCTAssertFalse(element("Group B").exists)
        XCTAssertFalse(element("Group C").exists)
        record("group-restored-visible-index-and-order")
    }
    func testProductionAllHiddenFallback() {
        selected("offline-a", 1); openManagement()
        delete("D"); delete("A"); leaveManagement()
        selected("", 0)
        XCTAssertTrue(element("[ ]").waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(element("Group B").exists)
        record("group-all-hidden-fallback")
    }
    func testProductionRestoredAllHiddenFallback() {
        selected("", 0)
        XCTAssertTrue(element("[ ]").waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(element("Group B").exists)
        record("group-all-hidden-restored")
    }
}
