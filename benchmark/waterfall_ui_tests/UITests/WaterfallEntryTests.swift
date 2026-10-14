import XCTest

final class WaterfallEntryTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["--eros-test-semantics"]
        app.launch()
    }

    private func record(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func tapText(_ label: String) {
        let text = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
        for _ in 0..<7 {
            if text.exists && text.isHittable { break }
            scrollSettings()
        }
        XCTAssertTrue(text.waitForExistence(timeout: 5),
                      "Missing \(label): \(app.debugDescription)")
        XCTAssertTrue(text.isHittable, "Not hittable: \(label)")
        text.tap()
    }

    private func scrollSettings() {
        // iPad's right pane is empty; scroll the real settings pane, not the
        // center of the full application window.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8))
            .press(forDuration: 0.05, thenDragTo:
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.35)))
    }

    private func openLayout() {
        if app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "列表样式")).firstMatch.exists {
            return
        }
        let settings = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "设置")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 15), app.debugDescription)
        settings.tap()
        tapText("样式")
    }

    private func openGallery() {
        // Restart through the production entry, also exercising persisted mode.
        app.terminate()
        app.launch()
        let gallery = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "画廊")).firstMatch
        XCTAssertTrue(gallery.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(gallery.isHittable, app.debugDescription)
        gallery.tap()
        XCTAssertTrue(firstGallery.waitForExistence(timeout: 15),
                      "Offline production cards missing: \(app.debugDescription)")
    }

    private var firstGallery: XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", "offline-gallery-9100000"))
            .firstMatch
    }

    private func viewportPixels() -> Data {
        let image = XCUIScreen.main.screenshot().image.cgImage!
        return image.dataProvider!.data! as Data
    }

    private func waitForViewportToSettle() {
        var previous = viewportPixels()
        for _ in 0..<25 {
            Thread.sleep(forTimeInterval: 0.15)
            let next = viewportPixels()
            if next == previous { return }
            previous = next
        }
        XCTFail("Production viewport did not settle after scrolling")
    }

    private func assertScrollReturn(_ name: String) {
        let first = firstGallery
        XCTAssertTrue(first.waitForExistence(timeout: 5), app.debugDescription)
        waitForViewportToSettle()
        let before = first.frame
        XCTAssertGreaterThan(before.width, 0)
        XCTAssertGreaterThan(before.height, 0)
        let beforePixels = viewportPixels()
        let height = app.frame.height
        let x = before.midX
        let top = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: height * 0.3))
        let bottom = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: height * 0.75))
        for _ in 0..<4 { bottom.press(forDuration: 0.05, thenDragTo: top) }
        waitForViewportToSettle()
        // Flutter removes/recycles offscreen semantics nodes asynchronously.
        // Inspect the rendered viewport instead of querying a recycled node.
        XCTAssertNotEqual(viewportPixels(), beforePixels,
                          "Scroll gestures did not change the viewport")
        record("\(name)-scrolled")
        for _ in 0..<5 { top.press(forDuration: 0.05, thenDragTo: bottom) }
        waitForViewportToSettle()
        XCTAssertTrue(first.waitForExistence(timeout: 5), app.debugDescription)
        record("\(name)-returned")
        XCTAssertEqual(first.frame.width, before.width, accuracy: 2)
        XCTAssertEqual(first.frame.height, before.height, accuracy: 2)
        XCTAssertEqual(first.frame.minY, before.minY, accuracy: 2)
    }

    func testProductionWaterfallScrollMatrix() {
        for (mode, name) in [("瀑布流", "waterfall"), ("瀑布流 - 大", "waterfall-large")] {
            openLayout()
            tapText("列表样式")
            // Exact matching avoids choosing the large-mode row by prefix.
            let selection = app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", mode)).firstMatch
            XCTAssertTrue(selection.waitForExistence(timeout: 5), app.debugDescription)
            selection.tap()
            openGallery()
            assertScrollReturn("\(name)-portrait")
            XCUIDevice.shared.orientation = .landscapeLeft
            assertScrollReturn("\(name)-landscape")
            XCUIDevice.shared.orientation = .portrait
        }
    }

    func testMainEntryModePersistenceAndLandscape() {
        let gallery = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "画廊")).firstMatch
        XCTAssertTrue(gallery.waitForExistence(timeout: 20), app.debugDescription)
        record("production-entry-portrait")
        openLayout()
        tapText("列表样式")
        tapText("瀑布流 - 大")
        record("waterfall-large-selected")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "设置")).firstMatch
            .waitForExistence(timeout: 15))
        openLayout()
        let restored = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@",
                        "列表样式", "瀑布流 - 大")).firstMatch
        for _ in 0..<7 {
            if restored.exists && restored.isHittable { break }
            scrollSettings()
        }
        XCTAssertTrue(restored.waitForExistence(timeout: 5),
                      "List mode did not persist after restart")
        record("mode-restored-after-restart")
        XCUIDevice.shared.orientation = .landscapeLeft
        record("production-settings-landscape")
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "improper use")).firstMatch.exists)
        XCUIDevice.shared.orientation = .portrait
    }
}
