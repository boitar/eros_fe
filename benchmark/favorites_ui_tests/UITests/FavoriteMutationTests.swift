import XCTest

final class FavoriteMutationTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")

    private func element(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", label)).firstMatch
    }

    private var note: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "elementType IN %@",
            [NSNumber(value: XCUIElement.ElementType.textField.rawValue),
             NSNumber(value: XCUIElement.ElementType.textView.rawValue)] as NSArray)).firstMatch
    }

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["--eros-test-semantics"]
        app.activate()
        enableGlassForIntegration(app)
        goTab("画廊")
    }

    private func goTab(_ label: String) {
        let matches = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", label)).allElementsBoundByIndex
        let tab = matches.last ?? element(label)
        XCTAssertTrue(tab.waitForExistence(timeout: 50), app.debugDescription)
        if !tapNativeTabIfPresent(app, label: label) { tab.tap() }
    }

    private func card(_ index: Int = 0) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@", "Offline gallery \(index) -")).firstMatch
    }

    private var galleryBodyX: Double {
        app.frame.width > 600 ? 0.19 : 0.50
    }

    private func openMenu(_ index: Int = 0) {
        _ = card(index).waitForExistence(timeout: 15)
        for _ in 0..<5 {
            if card(index).exists && card(index).isHittable { break }
            let start = index == 0 ? 0.35 : 0.72
            let end = index == 0 ? 0.75 : 0.40
            app.coordinate(withNormalizedOffset: CGVector(dx: galleryBodyX, dy: start))
                .press(forDuration: 0.1, thenDragTo:
                    app.coordinate(withNormalizedOffset: CGVector(dx: galleryBodyX, dy: end)))
        }
        XCTAssertTrue(card(index).waitForExistence(timeout: 30), app.debugDescription)
        // Keep the long press above the native bar covering the last visible card.
        card(index).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(forDuration: 0.8)
    }

    private func openForm(existing: Bool, index: Int = 0) {
        openMenu(index)
        let action = element(existing ? "修改收藏夹" : "添加收藏夹")
        XCTAssertTrue(action.waitForExistence(timeout: 15), app.debugDescription)
        action.tap()
        XCTAssertTrue(note.waitForExistence(timeout: 15), app.debugDescription)
    }

    private func waitNote(_ value: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value), object: note)
        wait(for: [expectation], timeout: 15)
    }

    private func ensureStyle(picker: Bool, existing: Bool) {
        if element("确定").exists == picker { return }
        element("添加收藏夹").press(forDuration: 0.8)
        element("取消").tap()
        openForm(existing: existing)
        XCTAssertEqual(element("确定").exists, picker, app.debugDescription)
    }

    private func tapFolder(_ category: Int) {
        let row = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Offline folder \(category)")).firstMatch
        for _ in 0..<8 {
            if row.exists && row.isHittable { break }
            let visible = app.descendants(matching: .any).matching(
                NSPredicate(format: "label BEGINSWITH %@", "Offline folder "))
                .allElementsBoundByIndex.first { !$0.frame.isEmpty && $0.isHittable }
            XCTAssertNotNil(visible, app.debugDescription)
            let reference = visible!.frame
            let content = app.scrollViews.allElementsBoundByIndex.filter {
                $0.frame.height > 100 &&
                    $0.frame.contains(CGPoint(x: reference.midX, y: reference.midY))
            }.min { $0.frame.height < $1.frame.height }
            XCTAssertNotNil(content, app.debugDescription)
            if category < 5 {
                content!.swipeDown()
            } else {
                content!.swipeUp()
            }
        }
        XCTAssertTrue(row.exists && row.isHittable, app.debugDescription)
        row.tap()
    }

    private func choose(_ category: Int) {
        tapFolder(category)
        XCTAssertTrue(note.waitForNonExistence(timeout: 20), app.debugDescription)
    }

    private func verifyList(category: Int, containsGallery: Bool) {
        goTab("收藏")
        let selector = element("选择收藏夹")
        XCTAssertTrue(selector.waitForExistence(timeout: 20), app.debugDescription)
        selector.tap()
        let folder = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Offline folder \(category)")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 15), app.debugDescription)
        tapFolder(category)
        XCTAssertTrue(selector.waitForExistence(timeout: 15), app.debugDescription)
        app.coordinate(withNormalizedOffset: CGVector(dx: galleryBodyX, dy: 0.32))
            .press(forDuration: 0.1, thenDragTo:
                app.coordinate(withNormalizedOffset: CGVector(dx: galleryBodyX, dy: 0.80)))
        if containsGallery {
            XCTAssertTrue(card().waitForExistence(timeout: 30), app.debugDescription)
        } else {
            XCTAssertTrue(card().waitForNonExistence(timeout: 20), app.debugDescription)
        }
        record("favorite-list-\(category)-present-\(containsGallery)")
        goTab("画廊")
    }

    private func record(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testMutationCycle() {
        openForm(existing: false)
        ensureStyle(picker: false, existing: false)
        waitNote("")
        note.tap()
        let introduction = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Continue", "继续"] as NSArray)).firstMatch
        if introduction.waitForExistence(timeout: 10) || introduction.exists {
            introduction.tap()
            note.tap()
        }
        app.typeText("QA68")
        waitNote("QA68")
        choose(0)
        verifyList(category: 0, containsGallery: true)

        openForm(existing: true)
        waitNote("QA68")
        record("favorite-zero-saved-and-read-back")
        choose(7)
        verifyList(category: 0, containsGallery: false)
        verifyList(category: 7, containsGallery: true)

        app.terminate()
        app.activate()
        enableGlassForIntegration(app)
        goTab("画廊")

        openForm(existing: true)
        waitNote("QA68")
        ensureStyle(picker: true, existing: true)
        waitNote("QA68")
        note.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        app.typeText(" EDIT")
        element("确定").tap()
        XCTAssertTrue(note.waitForNonExistence(timeout: 20))
        openForm(existing: true)
        waitNote("QA68 EDIT")
        record("favorite-nonzero-note-updated")
        note.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        element("确定").tap()
        XCTAssertTrue(note.waitForNonExistence(timeout: 20))
        openForm(existing: true)
        waitNote("")
        element("取消").tap()

        openMenu()
        let remove = element("从收藏夹中删除")
        XCTAssertTrue(remove.waitForExistence(timeout: 15), app.debugDescription)
        remove.tap()
        XCTAssertTrue(remove.waitForNonExistence(timeout: 20))
        openMenu()
        XCTAssertTrue(element("添加收藏夹").waitForExistence(timeout: 15), app.debugDescription)
        record("favorite-removed-without-default-zero-false-success")
        element("取消").tap()
        verifyList(category: 7, containsGallery: false)
    }

    func testRestartAndRejection() {
        openMenu()
        XCTAssertTrue(element("添加收藏夹").waitForExistence(timeout: 15), app.debugDescription)
        element("取消").tap()
        openForm(existing: false, index: 2)
        if element("确定").exists {
            element("确定").tap()
        } else {
            choose(0)
        }
        let refusal = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "HTTP 403")).firstMatch
        XCTAssertTrue(refusal.waitForExistence(timeout: 15), app.debugDescription)
        record("favorite-403-short-error-no-stack")
        openMenu(2)
        XCTAssertTrue(element("添加收藏夹").waitForExistence(timeout: 15), app.debugDescription)
        element("取消").tap()
    }
}
