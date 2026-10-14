import XCTest

final class DownloadEntryTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["--eros-test-semantics"]
        app.launch()
    }

    private func fixture(_ prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func record(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openDownloads() {
        let tab = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "下载")).firstMatch
        // Cold iPad scene startup under concurrent compilation may publish
        // Flutter semantics after the native app becomes idle.
        XCTAssertTrue(tab.waitForExistence(timeout: 60), app.debugDescription)
        tab.tap()
        let first = fixture("Offline v2 paused fixture 3")
        XCTAssertTrue(first.waitForExistence(timeout: 15), app.debugDescription)
    }

    private func scrollPane(up: Bool) {
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.35))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8))
        (up ? bottom : top).press(forDuration: 0.05, thenDragTo: up ? top : bottom)
    }

    private func findFixture(_ prefix: String) {
        let target = fixture(prefix)
        for _ in 0..<5 {
            if target.exists { break }
            scrollPane(up: true)
        }
        XCTAssertTrue(target.waitForExistence(timeout: 5), app.debugDescription)
    }

    func testProductionDownloadRestorationAndRotation() {
        openDownloads()
        findFixture("Offline v2 missing files fixture 2")
        let unavailable = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "文件暂不可用")).firstMatch
        XCTAssertTrue(unavailable.waitForExistence(timeout: 10),
                      "Missing availability state: \(app.debugDescription)")
        findFixture("Offline v2 downloaded fixture 1")
        record("production-downloads-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        findFixture("Offline v2 downloaded fixture 1")
        record("production-downloads-landscape")
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
        app.launch()
        openDownloads()
        findFixture("Offline v2 missing files fixture 2")
        record("production-downloads-restored")
        findFixture("Offline v2 downloaded fixture 1")
        fixture("Offline v2 downloaded fixture 1").tap()
        let pageCount = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "1/1")).firstMatch
        XCTAssertTrue(pageCount.waitForExistence(timeout: 20),
                      "Completed files must open the production reader: \(app.debugDescription)")
        record("production-downloads-local-reader")
    }
}
