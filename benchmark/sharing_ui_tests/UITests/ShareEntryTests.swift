import XCTest
import UIKit

final class ShareEntryTests: XCTestCase {
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

    private func prefix(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    private func record(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func nativeSheet(_ name: String) {
        let activity = app.otherElements["ActivityListView"].firstMatch
        XCTAssertTrue(activity.waitForExistence(timeout: 20), app.debugDescription)
        let close = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Close", "关闭"] as NSArray)).firstMatch
        record(name)
        if close.exists {
            close.tap()
        } else {
            let dismiss = app.otherElements["PopoverDismissRegion"].firstMatch
            XCTAssertTrue(dismiss.exists, app.debugDescription)
            dismiss.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        }
        XCTAssertTrue(activity.waitForNonExistence(timeout: 10))
    }

    private func tapNavigationShare(reader: Bool = false) {
        if reader {
            if readerShareButton == nil {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.readerShareButton?.isHittable == true
            }, object: app)
            wait(for: [visible], timeout: 15)
            record("production-reader-toolbar")
            readerShareButton!.tap()
            return
        }
        let y: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 48 : 84
        app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: app.frame.width - 28, dy: y)).tap()
    }

    private var readerShareButton: XCUIElement? {
        let minimumY: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 20 : 60
        return app.otherElements.allElementsBoundByIndex.first {
            let frame = $0.frame
            return abs(frame.width - 40) < 0.5 && abs(frame.height - 54) < 0.5 &&
                frame.minX > app.frame.width / 2 &&
                frame.minY >= minimumY && frame.maxY < 150
        }
    }

    func testProductionGalleryLink() {
        let tab = element("画廊")
        XCTAssertTrue(tab.waitForExistence(timeout: 60), app.debugDescription)
        tab.tap()
        let card = prefix("Offline gallery 0 -")
        XCTAssertTrue(card.waitForExistence(timeout: 20), app.debugDescription)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.3))
            .press(forDuration: 0.05)
        tapNavigationShare()
        nativeSheet("production-gallery-link-share")
        // Cancellation must release the guard so the next real tap can present.
        tapNavigationShare()
        nativeSheet("production-gallery-link-share-after-cancel")
    }

    func testProductionProfileExport() {
        let tab = element("设置")
        XCTAssertTrue(tab.waitForExistence(timeout: 60), app.debugDescription)
        tab.tap()
        let advanced = element("高级")
        for _ in 0..<6 {
            if advanced.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(advanced.waitForExistence(timeout: 10), app.debugDescription)
        advanced.tap()
        let export = prefix("导出应用数据")
        for _ in 0..<6 {
            if export.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(export.waitForExistence(timeout: 10), app.debugDescription)
        export.tap()
        nativeSheet("production-profile-file-export")
    }

    func testProductionLocalImage() {
        let tab = element("下载")
        XCTAssertTrue(tab.waitForExistence(timeout: 60), app.debugDescription)
        tab.tap()
        let card = prefix("Offline sharing image fixture")
        XCTAssertTrue(card.waitForExistence(timeout: 20), app.debugDescription)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.3))
            .press(forDuration: 0.05)
        XCTAssertTrue(element("1/1").waitForExistence(timeout: 20), app.debugDescription)
        tapNavigationShare(reader: true)
        let resampled = element("重采样图片")
        XCTAssertTrue(resampled.waitForExistence(timeout: 10), app.debugDescription)
        resampled.tap()
        nativeSheet("production-reader-image-after-modal-dismissal")
        XCUIDevice.shared.orientation = .landscapeLeft
        record("production-reader-share-landscape")
        XCUIDevice.shared.orientation = .portrait
    }

    func testProductionDownloadArchive() {
        let tab = element("下载")
        XCTAssertTrue(tab.waitForExistence(timeout: 60), app.debugDescription)
        tab.tap()
        let card = prefix("Offline sharing image fixture")
        XCTAssertTrue(card.waitForExistence(timeout: 20), app.debugDescription)
        for format in ["ZIP", "EPUB"] {
            card.press(forDuration: 0.8)
            let export = element("导出")
            XCTAssertTrue(export.waitForExistence(timeout: 10), app.debugDescription)
            export.tap()
            let action = element(format)
            XCTAssertTrue(action.waitForExistence(timeout: 10), app.debugDescription)
            action.tap()
            nativeSheet("production-download-\(format)-after-modal-dismissal")
        }
    }
}
