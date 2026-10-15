import XCTest
import UIKit

final class HistoryEntryTests: XCTestCase {
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

    private func entry(_ number: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@", "Offline history entry \(number) -")).firstMatch
    }

    private func record(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openHistory() {
        let history = element("历史")
        XCTAssertTrue(history.waitForExistence(timeout: 60), app.debugDescription)
    }

    func testProductionColdHistoryAndRotation() {
        openHistory()
        XCTAssertTrue(app.descendants(matching: .any)["offline-history-ready-8"]
            .waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(entry(8).waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(entry(7).exists, app.debugDescription)
        XCTAssertLessThan(entry(8).frame.minY, entry(7).frame.minY)
        record("production-cold-history-order")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(entry(8).waitForExistence(timeout: 10), app.debugDescription)
        record("production-history-landscape")
        XCUIDevice.shared.orientation = .portrait
    }

    func testProductionClearHistory() {
        openHistory()
        let first = entry(8)
        XCTAssertTrue(first.waitForExistence(timeout: 20), app.debugDescription)
        let y: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 48 : 84
        app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: first.frame.maxX - 16, dy: y)).tap()
        XCTAssertTrue(element("清除所有历史").waitForExistence(timeout: 10),
                      app.debugDescription)
        element("确定").tap()
        XCTAssertTrue(element("清除所有历史").waitForNonExistence(timeout: 20),
                      app.debugDescription)
        XCTAssertTrue(first.waitForNonExistence(timeout: 15), app.debugDescription)
        record("production-history-cleared")
    }

    func testProductionEmptyHistoryAfterRestart() {
        openHistory()
        XCTAssertTrue(app.descendants(matching: .any)["offline-history-ready-0"]
            .waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(entry(8).waitForNonExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(entry(7).waitForNonExistence(timeout: 5), app.debugDescription)
        record("production-cleared-history-restored")
    }
}
