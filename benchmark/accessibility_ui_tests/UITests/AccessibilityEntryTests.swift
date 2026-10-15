import XCTest
import UIKit

final class AccessibilityEntryTests: XCTestCase {
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
    private func tap(_ label: String) {
        let action = element(label)
        XCTAssertTrue(action.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(action.isHittable, app.debugDescription)
        action.tap()
    }
    private func record(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func openSearch() {
        tap("搜索")
        XCTAssertTrue(element("筛选").waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(element("以图搜图").exists)
        XCTAssertTrue(element("快速搜索列表").exists)
    }
    func testProductionLabeledActionsAndRotation() {
        XCTAssertTrue(element("分组管理").waitForExistence(timeout: 60), app.debugDescription)
        tap("分组管理")
        let header = element("分组")
        XCTAssertTrue(header.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(element("Offline").exists)
        record("accessibility-group-management-route")
        app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: 20, dy: header.frame.midY)).tap()
        tap("跳转/搜寻")
        XCTAssertTrue(element("取消").waitForExistence(timeout: 20), app.debugDescription)
        tap("取消")
        openSearch()
        record("accessibility-search-actions")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(element("筛选").waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(element("以图搜图").exists)
        record("accessibility-search-actions-landscape")
        XCUIDevice.shared.orientation = .portrait
    }
    func testProductionSearchEditingActions() {
        XCTAssertTrue(element("分组管理").waitForExistence(timeout: 60), app.debugDescription)
        openSearch()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15), app.debugDescription)
        field.tap(); field.typeText("neutral query")
        XCTAssertTrue(element("加入快速搜索").waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(element("清空搜索词").exists)
        record("accessibility-edit-actions")
        tap("清空搜索词")
        XCTAssertTrue(element("清空搜索词").waitForNonExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(element("加入快速搜索").waitForNonExistence(timeout: 10), app.debugDescription)
        field.tap(); field.typeText("https://e-hentai.org/g/9100000/0000000000/")
        XCTAssertTrue(element("打开画廊链接").waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(element("加入快速搜索").exists)
        record("accessibility-gallery-url-action")
    }
}
