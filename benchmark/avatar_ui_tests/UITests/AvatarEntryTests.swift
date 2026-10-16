import XCTest
import UIKit

final class AvatarEntryTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")
    private var beforeSaveLabel = ""
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.activate()
        enableGlassForIntegration(app)
    }
    private func element(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
    private func tap(_ label: String) {
        if tapNativeTabIfPresent(app, label: label) { return }
        let target = element(label)
        XCTAssertTrue(target.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(target.isHittable, app.debugDescription)
        target.tap()
    }
    private func record(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func ready(_ local: Bool) {
        let id = "offline-avatar-ready-" + (local ? "local" : "empty")
        XCTAssertTrue(app.descendants(matching: .any)[id].waitForExistence(timeout: 40), app.debugDescription)
    }
    private func scrollSettings() {
        let ipad = UIDevice.current.userInterfaceIdiom == .pad
        let x = app.frame.width * (ipad ? 0.70 : 0.5)
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: app.frame.height * 0.75))
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: app.frame.height * 0.35))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
    private func openAvatarSettings() {
        tap("设置"); tap("E·H")
        let avatar = element("上传头像")
        for _ in 0..<8 {
            if avatar.exists && avatar.isHittable { break }
            scrollSettings()
        }
        XCTAssertTrue(avatar.isHittable, app.debugDescription)
        let previews = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "offline-avatar-ready-"))
        beforeSaveLabel = previews.firstMatch.exists ? previews.firstMatch.label : ""
    }
    private func openAvatar() {
        openAvatarSettings(); tap("上传头像")
    }
    private func saveLocal() {
        tap("仅本机使用")
        let preview = app.descendants(matching: .any).matching(identifier: "offline-avatar-ready-local").firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 30), app.debugDescription)
        expectation(for: NSPredicate(format: "label != %@", beforeSaveLabel), evaluatedWith: preview)
        waitForExpectations(timeout: 20)
        ready(true)
    }
    private func first(_ labels: [String]) -> XCUIElement {
        return app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", labels)).firstMatch
    }
    private func enterUrl(_ value: String) {
        tap("图片 URL")
        let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15), app.debugDescription)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        app.typeText(value)
        XCTAssertEqual(field.value as? String, value, "The real URL field must receive the complete input")
        record("avatar-url-input-before-confirmation")
        tap("确定")
    }
    func testProductionLocalUrlAndCancel() {
        openAvatarSettings()
        if beforeSaveLabel.contains("file=/") { ready(true) }
        tap("上传头像")
        tap("取消")
        tap("上传头像")
        enterUrl("http://127.0.0.1/offline-cover/avatar.png")
        saveLocal()
        record("avatar-production-url-local-preview")
        tap("上传头像"); tap("图片 URL"); tap("取消")
        ready(true)
        tap("上传头像"); enterUrl("not-a-url")
        XCTAssertFalse(element("仅本机使用").exists, app.debugDescription)
        ready(true)
    }
    func testProductionRestoredLocalAndAlbum() {
        openAvatarSettings(); ready(true)
        tap("上传头像"); tap("相册")
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 20), app.debugDescription)
        photo.tap()
        let add = app.buttons.matching(NSPredicate(format: "label == 'Add' OR label == '添加'")).firstMatch
        if add.waitForExistence(timeout: 2) { add.tap() }
        let local = element("仅本机使用")
        XCTAssertTrue(local.waitForExistence(timeout: 30), app.debugDescription)
        saveLocal()
        record("avatar-production-album-local-preview")
    }
    func testProductionFilePickerCancelAndRotation() {
        openAvatarSettings(); ready(true)
        tap("上传头像"); tap("文件")
        let cancel = app.buttons.matching(NSPredicate(format: "identifier == 'Cancel' OR label == 'Cancel' OR label == '取消'")).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(first(["浏览", "最近项目", "Browse", "Recents"]).waitForExistence(timeout: 15), app.debugDescription)
        record("avatar-native-document-picker")
        cancel.tap(); ready(true)
        XCUIDevice.shared.orientation = .landscapeLeft
        ready(true); record("avatar-restored-file-landscape")
        XCUIDevice.shared.orientation = .portrait
    }
    func testProductionLocalDocumentSelection() {
        openAvatarSettings(); ready(true)
        tap("上传头像"); tap("文件")
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Avatar Fixture")).firstMatch
        if !file.waitForExistence(timeout: 3) {
            let location = first(["我的iPhone", "我的iPad", "On My iPhone", "On My iPad"])
            if !location.waitForExistence(timeout: 3) {
                let browse = app.buttons.matching(NSPredicate(format: "label IN %@", ["浏览", "Browse"])).firstMatch
                XCTAssertTrue(browse.waitForExistence(timeout: 20), app.debugDescription)
                browse.tap()
            }
            XCTAssertTrue(location.waitForExistence(timeout: 15), app.debugDescription)
            location.tap()
            let folder = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Eros-FE")).firstMatch
            XCTAssertTrue(folder.waitForExistence(timeout: 15), app.debugDescription)
            folder.tap()
        }
        XCTAssertTrue(file.waitForExistence(timeout: 20), app.debugDescription)
        file.tap()
        saveLocal()
        record("avatar-actual-document-file-saved-and-previewed")
    }

}
