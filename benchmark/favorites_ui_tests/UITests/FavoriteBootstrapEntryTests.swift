import XCTest

final class FavoriteBootstrapEntryTests: XCTestCase {
    func testProductionColdSettingsBeforeFavorite() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")
        app.activate()
        func element(_ label: String) -> XCUIElement {
            app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", label)).firstMatch
        }
        let card = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Offline gallery 0 -")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 60), app.debugDescription)
        let settings = element("设置")
        XCTAssertTrue(settings.waitForExistence(timeout: 15), app.debugDescription)
        settings.tap()
        // Opening settings before any favorite action used to initialize the
        // account from UserWidget.build and invalidate mounted gallery Obx nodes.
        let userSurface = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Offline acceptance")).firstMatch
        XCTAssertTrue(userSurface.waitForExistence(timeout: 20),
                      "The first user surface must render without a build error: \(app.debugDescription)")
        let favorite = element("收藏")
        XCTAssertTrue(favorite.waitForExistence(timeout: 15), app.debugDescription)
        favorite.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 30), app.debugDescription)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "favorite-cold-settings-and-real-list"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
