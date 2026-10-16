import XCTest

final class FavoriteEntryTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["--eros-test-semantics"]
        app.activate()
        enableGlassForIntegration(app)
    }

    private func element(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", text)).firstMatch
    }

    private func record(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var noteField: XCUIElement {
        let types = [NSNumber(value: XCUIElement.ElementType.textField.rawValue),
                     NSNumber(value: XCUIElement.ElementType.textView.rawValue)]
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@", types as NSArray)).firstMatch
    }

    private var selectedCategory: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ OR value == %@", "Offline folder 7", "Offline folder 7")).firstMatch
    }

    private func openDialog() {
        let gallery = element("画廊")
        XCTAssertTrue(gallery.waitForExistence(timeout: 60), app.debugDescription)
        if !tapNativeTabIfPresent(app, label: "画廊") { gallery.tap() }
        let card = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Offline gallery 0 -")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), app.debugDescription)
        card.press(forDuration: 0.8)
        let change = element("修改收藏夹")
        XCTAssertTrue(change.waitForExistence(timeout: 10), app.debugDescription)
        change.tap()
        XCTAssertTrue(noteField.waitForExistence(timeout: 15), app.debugDescription)
    }

    private func cancelDialog() {
        let cancel = element("取消")
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), app.debugDescription)
        cancel.tap()
        XCTAssertTrue(element("添加收藏夹").waitForNonExistence(timeout: 10))
    }

    func testProductionFavoriteForms() {
        openDialog()
        let field = noteField
        let loaded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "Offline server note"),
            object: field)
        wait(for: [loaded], timeout: 15)
        let firstWasPicker = element("确定").exists
        field.tap()
        let keyboardIntroduction = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Continue", "继续"] as NSArray)).firstMatch
        if keyboardIntroduction.waitForExistence(timeout: 10) {
            keyboardIntroduction.tap()
            field.tap()
        }
        field.typeText(" QA42")
        let edited = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "QA42"), object: field)
        wait(for: [edited], timeout: 15)
        record("production-favorite-form-edit")
        cancelDialog()
        // Reopen without the keyboard so the title gesture has a visible target.
        openDialog()
        // The existing title gesture switches the style for the next dialog.
        element("添加收藏夹").press(forDuration: 0.8)
        cancelDialog()
        openDialog()
        XCTAssertTrue(selectedCategory.waitForExistence(timeout: 10), app.debugDescription)
        let alternateIsPicker = element("确定").exists
        XCTAssertNotEqual(alternateIsPicker, firstWasPicker)
        record("production-favorite-alternate-form")
        if !alternateIsPicker {
            element("添加收藏夹").press(forDuration: 0.8)
            cancelDialog()
            openDialog()
            XCTAssertTrue(element("确定").waitForExistence(timeout: 10))
        }
        cancelDialog()
        app.terminate()
    }

    // The host script terminates and starts a fresh process between cases.
    func testProductionFavoriteStyleRestored() {
        openDialog()
        XCTAssertTrue(selectedCategory.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(element("确定").waitForExistence(timeout: 10), app.debugDescription)
        record("production-favorite-style-restored")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(noteField.waitForExistence(timeout: 10))
        record("production-favorite-landscape")
        cancelDialog()
        XCUIDevice.shared.orientation = .portrait
    }
}
