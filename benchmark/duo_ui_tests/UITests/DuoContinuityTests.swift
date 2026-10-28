import XCTest
import UIKit

final class DuoContinuityTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")

    override func setUp() {
        continueAfterFailure = false
        app.activate()
    }

    override func tearDown() {
        let health = app.descendants(matching: .any)["offline-duo-health-probe"]
        XCTAssertTrue(health.exists, "Acceptance must observe Flutter health")
        XCTAssertEqual(health.label, "framework=0;platform=0", app.debugDescription)
        super.tearDown()
    }

    private func probe(_ route: String) -> XCUIElement {
        app.descendants(matching: .any)["offline-glass-probe-\(route)"]
    }

    private func data(_ route: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: probe(route).label.split(separator: ";").compactMap {
            let pair = $0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return pair.count == 2 ? (String(pair[0]), String(pair[1])) : nil
        })
    }

    private func awaitPage(_ route: String, _ page: String? = nil) {
        XCTAssertTrue(probe(route).waitForExistence(timeout: 30), app.debugDescription)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let values = self.data(route)
            return values["targetLive"] == "true" &&
                (page == nil || values["page"] == page)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed,
                       probe(route).label)
    }

    private func tab(_ route: String) {
        let item = app.descendants(matching: .any)["native-tab-/\(route)"]
        XCTAssertTrue(item.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(item.frame.isEmpty)
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists && keyboard.frame.intersects(item.frame) {
            nativeAction("dismissKeyboard")
            let hidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !self.app.keyboards.firstMatch.exists
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 10), .completed,
                           "Do not tap destination coordinates through the software keyboard")
        }
        XCTAssertTrue(item.isHittable, app.debugDescription)
        item.tap()
    }

    private func record(_ name: String) {
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let shot = XCTAttachment(screenshot: screen.screenshot())
            shot.name = "\(name)-display-\(index)"
            shot.lifetime = .keepAlways
            add(shot)
        }
    }

    private func stableScrollData(_ route: String) -> [String: String] {
        var previous: [String: String] = [:]
        var stableSince = Date()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let values = self.data(route)
            if values["inner"] != previous["inner"] ||
                values["outer"] != previous["outer"] ||
                values["first"] != previous["first"] {
                previous = values
                stableSince = Date()
                return false
            }
            return Date().timeIntervalSince(stableSince) >= 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed,
                       "Scroll did not settle: \(probe(route).label)")
        return data(route)
    }

    func testNativeTabContinuity() {
        app.terminate()
        app.launchArguments = ["--eros-test-semantics"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        awaitPage("gallery")
        let group = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Group B")).firstMatch
        XCTAssertTrue(group.waitForExistence(timeout: 20), app.debugDescription)
        group.tap()
        awaitPage("gallery", "glass-b")
        _ = stableScrollData("gallery")
        let window = app.windows.firstMatch
        print("EROS_SCROLL_FRAMES app=\(app.frame) window=\(window.frame) scrolls=\(app.scrollViews.allElementsBoundByIndex.map(\.frame))")
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.78))
            .press(forDuration: 0.05, thenDragTo:
                window.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)))
        var before = stableScrollData("gallery")
        if (Double(before["inner"] ?? "") ?? 0) < 40 {
            let scroll = app.scrollViews.allElementsBoundByIndex.first {
                $0.frame.height > window.frame.height * 0.5
            }
            XCTAssertNotNil(scroll, app.debugDescription)
            scroll!.swipeUp()
            before = stableScrollData("gallery")
        }
        XCTAssertGreaterThan(
            max(Double(before["inner"] ?? "") ?? 0,
                Double(before["outer"] ?? "") ?? 0), 40,
            "Continuity must start from a genuinely scrolled list: \(before)")
        print("EROS_DUO_BEFORE=\(before)")
        record("duo-before-tab-rotation-loop")
        for iteration in 0..<20 {
            tab("favorite")
            awaitPage("favorite")
            XCUIDevice.shared.orientation = iteration.isMultiple(of: 2)
                ? .landscapeLeft : .portrait
            tab("gallery")
            awaitPage("gallery", "glass-b")
            XCTAssertEqual(data("gallery")["requests"], before["requests"],
                           "Tab round trips must not recreate or refresh the list")
            print("EROS_DUO_ITERATION_\(iteration + 1)=\(data("gallery"))")
        }
        XCUIDevice.shared.orientation = .portrait
        awaitPage("gallery", "glass-b")
        let after = stableScrollData("gallery")
        XCTAssertEqual(after["outer"], before["outer"])
        XCTAssertEqual(after["inner"], before["inner"])
        record("duo-after-20-tab-rotation-round-trips")
    }

    func testExpandedLandscapeSafeAreaChrome() {
        app.terminate()
        app.launchArguments = ["--eros-test-semantics"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        tab("gallery")
        awaitPage("gallery")
        let gallery = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Glass A gallery 0")).firstMatch
        XCTAssertTrue(gallery.waitForExistence(timeout: 20), app.debugDescription)
        gallery.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        awaitNavigation(["gallery": "9500000", "detailDepth": "2"])
        record("expanded-gallery-safe-area")
        print("EROS_SAFEAREA_GALLERY_TREE=\n\(app.debugDescription)")
        nativeAction("native-back")
        openDownloadedFixture("Offline Duo reader fixture (11 pages)")
        readerSettings()
        for title in ["横屏铺满全屏", "竖屏铺满全屏"] {
            let toggle = app.switches.matching(
                NSPredicate(format: "label CONTAINS %@", title)).firstMatch
            XCTAssertTrue(toggle.exists, app.debugDescription)
            if (toggle.value as? String) == "0" {
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            }
            let enabled = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "1"), object: toggle)
            XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed,
                           "Full-screen switch must actually be enabled: \(title)")
        }
        nativeAction("native-back")
        let settings = app.descendants(matching: .any)["阅读设置"]
        if !settings.exists {
            app.descendants(matching: .any)["offline-duo-health-probe"]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(readerProbe.label.contains("size=951.0x669.0"), readerProbe.label)
        record("expanded-landscape-reader-chrome")
        print("EROS_SAFEAREA_READER_TREE=\n\(app.debugDescription)")
        let viewport = app.descendants(matching: .any)["offline-duo-scroll-probe"]
        XCTAssertTrue(viewport.label.contains("viewport=951.0x669.0"), viewport.label)
        // Insets and material pixels are covered by reader_layout_test.dart.
        // Do not count requested hardware orientations as observed rotations:
        // this test accepts only the actual expanded landscape dimensions.
    }

    func testColdStartAndFallback() {
        XCUIDevice.shared.orientation = .portrait
        awaitPage("gallery")
        if #available(iOS 27.1, *) {
            XCTAssertTrue(app.descendants(matching: .any)["native-tab-/gallery"].exists)
        } else {
            XCTAssertFalse(app.descendants(matching: .any)["native-tab-/gallery"].exists)
        }
        record("production-home-startup")
        print("EROS_HOME_TREE=\n\(app.debugDescription)")
    }

    func testDownloadedReaderContinuity() {
        app.terminate()
        app.launchArguments = ["--eros-test-semantics"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        tab("download")
        let fixture = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@",
                        "Offline Duo reader fixture (11 pages)")).firstMatch
        XCTAssertTrue(fixture.waitForExistence(timeout: 30), app.debugDescription)
        fixture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        let position = app.descendants(matching: .any)["offline-duo-reader-probe"]
        XCTAssertTrue(position.waitForExistence(timeout: 30), app.debugDescription)
        func index() -> Int {
            let field = position.label.split(separator: ";").first {
                $0.hasPrefix("index=")
            }
            return Int(field?.dropFirst("index=".count) ?? "") ?? -1
        }
        let initial = index()
        XCTAssertGreaterThanOrEqual(initial, 0)
        XCTAssertTrue(position.label.contains("interval=true"), position.label)
        XCTAssertTrue(position.label.contains("backend=extendedImageGesturePageView"),
                      position.label)
        if initial < 5 {
            for expected in (initial + 1)...5 {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.73, dy: 0.5)).tap()
                let moved = XCTNSPredicateExpectation(predicate: NSPredicate {
                    _, _ in index() == expected
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 10), .completed,
                               position.label)
            }
        }
        if initial > 5 {
            for expected in stride(from: initial - 1, through: 5, by: -1) {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
                let moved = XCTNSPredicateExpectation(predicate: NSPredicate {
                    _, _ in index() == expected
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 10), .completed,
                               position.label)
            }
        }
        let anchor = index()
        XCTAssertEqual(anchor, 5)
        for iteration in 0..<20 {
            XCUIDevice.shared.orientation = iteration.isMultiple(of: 2)
                ? .landscapeLeft : .portrait
            XCTAssertTrue(position.waitForExistence(timeout: 15))
            XCTAssertEqual(index(), anchor, position.label)
            print("EROS_READER_ITERATION_\(iteration + 1)=\(position.label)")
        }
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(index(), anchor)
        XCTAssertFalse(app.descendants(matching: .any)["native-tab-/gallery"].exists,
                       "Reader must not keep the native tab rail")
        record("production-reader-after-20-rotations")
        print("EROS_READER_POSE_ANCHOR=\(position.label)")
    }

    func testReaderReopenFreshSession() {
        // Regression: a revived zombie reader controller used to leave every
        // later session with count=0 and a black page. Both sessions here run
        // inside one app lifetime, exactly the sequence that used to break.
        app.terminate()
        app.launchArguments = ["--eros-test-semantics"]
        app.launch()
        tab("download")
        for session in 1...2 {
            let fixture = app.descendants(matching: .any).matching(
                NSPredicate(format: "label BEGINSWITH %@",
                            "Offline Duo reader fixture (11 pages)")).firstMatch
            XCTAssertTrue(fixture.waitForExistence(timeout: 30),
                          app.debugDescription)
            fixture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
                .tap()
            XCTAssertTrue(readerProbe.waitForExistence(timeout: 30),
                          app.debugDescription)
            awaitReader(["count": "11"])
            record("reader-reopen-session-\(session)")
            // The reader opens immersive; tap the content center to raise the
            // system bars, then leave through the reader's own back button.
            var back = app.buttons["native-back"]
            if !back.waitForExistence(timeout: 3) {
                let health = app.descendants(matching: .any)["offline-duo-health-probe"]
                XCTAssertTrue(health.waitForExistence(timeout: 10),
                              app.debugDescription)
                health.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    .tap()
                back = app.buttons["native-back"]
            }
            XCTAssertTrue(back.waitForExistence(timeout: 10),
                          app.debugDescription)
            back.tap()
            XCTAssertTrue(fixture.waitForExistence(timeout: 30),
                          "Session \(session) must return to the download tab\n"
                              + app.debugDescription)
        }
    }

    private var readerProbe: XCUIElement {
        app.descendants(matching: .any)["offline-duo-reader-probe"]
    }

    private func readerData() -> [String: String] {
        fields(readerProbe.label)
    }

    private func zoomRatio(for image: XCUIElement) -> Double? {
        let values = fields(image.label)
        guard let scale = Double(values["scale"] ?? ""),
              let initial = Double(values["initial"] ?? ""),
              initial > 0 else {
            return nil
        }
        return scale / initial
    }

    private func fields(_ label: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: label.split(separator: ";").compactMap {
            let pair = $0.split(separator: "=", maxSplits: 1,
                               omittingEmptySubsequences: false)
            return pair.count == 2 ? (String(pair[0]), String(pair[1])) : nil
        })
    }

    private func awaitReader(_ expected: [String: String]) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.readerProbe.exists && expected.allSatisfy {
                self.readerData()[$0.key] == $0.value
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed,
                       "Expected \(expected), actual \(readerProbe.label)")
    }

    private func openDownloadedFixture(_ title: String) {
        app.terminate()
        app.launchArguments = ["--eros-test-semantics"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        tab("download")
        let fixture = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        XCTAssertTrue(fixture.waitForExistence(timeout: 30), app.debugDescription)
        fixture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(readerProbe.waitForExistence(timeout: 30), app.debugDescription)
    }

    private func readerSettings() {
        let settings = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "阅读设置")).firstMatch
        if !settings.waitForExistence(timeout: 2) {
            app.descendants(matching: .any)["offline-duo-health-probe"]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 10), app.debugDescription)
        settings.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["native-back"].waitForExistence(timeout: 15),
                      app.debugDescription)
    }

    private func selectReadingRow(_ prefix: String, option: String) {
        let row = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription)
        row.tap()
        let choice = app.buttons[option]
        XCTAssertTrue(choice.waitForExistence(timeout: 10), app.debugDescription)
        choice.tap()
        XCTAssertTrue(app.buttons["native-back"].waitForExistence(timeout: 10))
    }

    private func configureReader(direction: String, column: String = "自动（宽屏双页）") {
        readerSettings()
        selectReadingRow("阅读方向", option: direction)
        selectReadingRow("双页模式", option: column)
        app.buttons["native-back"].tap()
        XCTAssertTrue(readerProbe.waitForExistence(timeout: 15))
    }

    private func selectOriginalImage(_ number: Int) {
        let thumb = app.images.matching(
            NSPredicate(format: "label == %@", "\(number)")).allElementsBoundByIndex
            .first { $0.isHittable }
        XCTAssertNotNil(thumb, "A visible production thumbnail is required\n\(app.debugDescription)")
        thumb!.tap()
        awaitReader(["index": "\(number - 1)"])
    }

    private func prepareRTLReader(verifySwipe: Bool = true) -> XCUIElement {
        openDownloadedFixture("Offline Duo reader fixture (11 pages)")
        configureReader(direction: "从右到左")
        awaitReader(["direction": "rightToLeft", "preference": "automatic",
                     "column": "single", "interval": "true"])
        selectOriginalImage(6)
        let sixth = app.descendants(matching: .any)["offline-duo-image-6"]
        XCTAssertTrue(sixth.waitForExistence(timeout: 15), app.debugDescription)
        if !verifySwipe { return sixth }
        // XCTest's default swipe can end before half a page at zero velocity.
        // Drive a full, deterministic drag and retain the original page checks.
        print("EROS_RTL_DRAG_FRAME=\(sixth.frame)")
        sixth.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo:
                sixth.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)))
        awaitReader(["index": "6"])
        let seventh = app.descendants(matching: .any)["offline-duo-image-7"]
        XCTAssertTrue(seventh.waitForExistence(timeout: 15), app.debugDescription)
        seventh.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo:
                seventh.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)))
        awaitReader(["index": "5"])
        return sixth
    }

    func testRTLReaderAndZoomReadyForPoses() {
        let sixth = prepareRTLReader()
        sixth.pinch(withScale: 2, velocity: 1)
        let zoomed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Double(self.fields(sixth.label)["scale"] ?? "") ?? 0) > 1.5
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [zoomed], timeout: 15), .completed,
                       "Pinch must change the observed image scale: \(sixth.label)")
        awaitReader(["index": "5", "direction": "rightToLeft"])
        record("rtl-reader-observed-pinch-before-poses")
        print("EROS_RTL_ZOOM_READY=\(readerProbe.label);image=\(sixth.label)")
    }

    func testRTLReaderDoubleTapReadyForPoses() {
        let sixth = prepareRTLReader(verifySwipe: false)
        sixth.doubleTap()
        let zoomed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Double(self.fields(sixth.label)["scale"] ?? "") ?? 0) > 1.5
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [zoomed], timeout: 15), .completed,
                       "Double tap must change the observed image scale: \(sixth.label)")
        awaitReader(["index": "5", "direction": "rightToLeft"])
        record("rtl-reader-observed-double-tap-before-poses")
        print("EROS_RTL_DOUBLE_TAP_READY=\(readerProbe.label);image=\(sixth.label)")
    }

    func testRTLReaderPinchWithoutPriorSwipe() {
        let sixth = prepareRTLReader(verifySwipe: false)
        sixth.pinch(withScale: 2, velocity: 1)
        let zoomed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Double(self.fields(sixth.label)["scale"] ?? "") ?? 0) > 1.5
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [zoomed], timeout: 15), .completed,
                       "Pinch must change the observed image scale: \(sixth.label)")
        awaitReader(["index": "5", "direction": "rightToLeft"])
        record("rtl-reader-pinch-without-prior-swipe")
        print("EROS_RTL_ISOLATED_PINCH=\(readerProbe.label);image=\(sixth.label)")
    }

    func testRTLReaderLargePinchReadyForPoses() {
        let sixth = prepareRTLReader()
        // Keep the ordinary 2x case separate. This input checks whether the
        // simulator can deliver motion beyond the recognizer's touch slop.
        sixth.pinch(withScale: 6, velocity: 1)
        let zoomed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Double(self.fields(sixth.label)["scale"] ?? "") ?? 0) > 1.5
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [zoomed], timeout: 15), .completed,
                       "Large pinch must change the observed image scale: \(sixth.label)")
        awaitReader(["index": "5", "direction": "rightToLeft"])
        record("rtl-reader-large-pinch-before-poses")
        print("EROS_RTL_LARGE_PINCH=\(readerProbe.label);image=\(sixth.label)")
    }

    func testRTLReaderLargePinchRemainsZoomed() {
        testRTLReaderLargePinchReadyForPoses()
        let sixth = app.descendants(matching: .any)["offline-duo-image-6"]
        let instance = fields(sixth.label)["instance"]
        for sample in 0..<8 {
            Thread.sleep(forTimeInterval: 1)
            let values = fields(sixth.label)
            print("EROS_RTL_SETTLED_ZOOM sample=\(sample);reader=\(readerProbe.label);image=\(sixth.label)")
            XCTAssertEqual(values["instance"], instance,
                           "Zoom validation must observe the same mounted image")
            XCTAssertGreaterThan(Double(values["scale"] ?? "") ?? 0, 1.5,
                                 "Zoom must persist after the native gesture ends")
        }
        record("rtl-reader-large-pinch-settled")
    }

    func testRTLReaderZoomSurvivesSingleSpreadRemaps() {
        let sixth = prepareRTLReader()
        sixth.pinch(withScale: 6, velocity: 1)
        let zoomed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let values = self.fields(sixth.label)
            return (Double(values["scale"] ?? "") ?? 0) > 1.5 &&
                (Double(values["initial"] ?? "") ?? 0) > 0
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [zoomed], timeout: 15), .completed,
                       "Pinch must establish a fitted-scale-relative zoom: \(sixth.label)")

        var remapCount = 0
        var previousGeneration = self.readerData()["generation"] ?? ""
        var previousRatio = self.zoomRatio(for: sixth)
        XCTAssertGreaterThan(previousRatio ?? 0, 1.5, sixth.label)

        for iteration in 0..<5 {
            configureReader(direction: "从右到左", column: "模式 A")
            awaitReader(["index": "5", "column": "oddLeft"])
            let spreadGeneration = readerData()["generation"] ?? ""
            configureReader(direction: "从右到左", column: "关闭")
            awaitReader(["index": "5", "column": "single"])
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let reader = self.readerData()
                let image = self.app.descendants(matching: .any)["offline-duo-image-6"]
                guard reader["index"] == "5",
                      let ratio = self.zoomRatio(for: image),
                      ratio > 1.5,
                      let generation = reader["generation"] else {
                    return false
                }
                if spreadGeneration != previousGeneration {
                    remapCount += 1
                }
                previousGeneration = generation
                previousRatio = ratio
                return true
            }, object: nil)
            let result = XCTWaiter.wait(for: [settled], timeout: 20)
            let remappedImage = app.descendants(matching: .any)["offline-duo-image-6"]
            XCTAssertEqual(result, .completed,
                           "Zoom must survive single/spread remap cycle \(iteration + 1): "
                           + "reader=\(readerProbe.label);image=\(remappedImage.label)")
            print("EROS_READER_ZOOM_REMAP_CYCLE_\(iteration + 1)="
                + "ratio=\(previousRatio ?? 0);reader=\(readerProbe.label)")
        }
        XCTAssertGreaterThan(remapCount, 0,
                             "The test must observe at least one pagination remap")
    }

    func testContinuousReaderReadyForPoses() {
        openDownloadedFixture("Offline Duo continuous fixture (9 pages)")
        configureReader(direction: "从上到下")
        awaitReader(["direction": "topToBottom", "preference": "automatic",
                     "column": "single", "count": "9"])
        let rails = app.scrollViews.allElementsBoundByIndex.filter {
            $0.frame.height > 90 && $0.frame.height < 180 &&
                $0.frame.width > 250
        }
        print("EROS_CONTINUOUS_SCROLL_FRAMES=\(app.scrollViews.allElementsBoundByIndex.map(\.frame))")
        XCTAssertEqual(rails.count, 1,
                       "Use the visible production thumbnail rail\n\(app.debugDescription)")
        // Reveal page six completely before tapping; a clipped thumbnail's
        // accessibility frame is not a reliable native hit target.
        let rail = rails[0].frame
        let origin = app.windows.firstMatch.coordinate(
            withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: rail.minX + rail.width * 0.8, dy: rail.midY))
            .press(forDuration: 0.05, thenDragTo:
                origin.withOffset(CGVector(dx: rail.minX + rail.width * 0.2,
                                           dy: rail.midY)))
        selectOriginalImage(6)
        let sixth = app.descendants(matching: .any)["offline-duo-image-6"]
        XCTAssertTrue(sixth.waitForExistence(timeout: 15), app.debugDescription)
        let settings = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "阅读设置")).firstMatch
        let contentTop = settings.frame.maxY + 8
        let contentHeight = rail.minY - contentTop
        XCTAssertGreaterThan(contentHeight, 150,
                             "Drag inside the image, not through the controls")
        origin.withOffset(CGVector(dx: rail.midX,
                                   dy: contentTop + contentHeight * 0.8))
            .press(forDuration: 0.05, thenDragTo:
                origin.withOffset(CGVector(dx: rail.midX,
                                           dy: contentTop + contentHeight * 0.2)))
        let scroll = app.descendants(matching: .any)["offline-duo-scroll-probe"]
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let items = self.fields(scroll.label)["items"] ?? ""
            guard let item = items.split(separator: "|").first(where: {
                $0.hasPrefix("5:")
            }) else { return false }
            let values = item.split(separator: ":")
            return values.count == 3 && (Double(values[1]) ?? 0) < -0.1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 20), .completed,
                       "Long-image acceptance must start genuinely scrolled: \(scroll.label)")
        awaitReader(["index": "5", "column": "single"])
        record("continuous-long-image-before-poses")
        print("EROS_CONTINUOUS_READY=\(readerProbe.label);scroll=\(scroll.label)")
    }

    private func navigationData() -> [String: String] {
        let element = app.descendants(matching: .any)["offline-duo-navigation-probe"]
        return Dictionary(uniqueKeysWithValues: element.label.split(separator: ";").compactMap {
            let pair = $0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return pair.count == 2 ? (String(pair[0]), String(pair[1])) : nil
        })
    }

    private func awaitNavigation(_ expected: [String: String]) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let values = self.navigationData()
            return expected.allSatisfy { values[$0.key] == $0.value }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed,
                       "Expected \(expected), actual \(navigationData())\n\(app.debugDescription)")
    }

    private func nativeAction(_ id: String) {
        let action = app.buttons[id]
        XCTAssertTrue(action.waitForExistence(timeout: 15), app.debugDescription)
        action.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func searchEditor() -> XCUIElement {
        let multiline = app.textViews.firstMatch
        return multiline.exists ? multiline : app.textFields.firstMatch
    }

    private func routeData(_ name: String) -> [String: String] {
        let element = app.descendants(matching: .any)["offline-duo-\(name)-probe"]
        return Dictionary(uniqueKeysWithValues: element.label.split(separator: ";").compactMap {
            let pair = $0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return pair.count == 2 ? (String(pair[0]), String(pair[1])) : nil
        })
    }

    func testRootReplacementChromeHandoff() {
        app.terminate()
        app.launchArguments = ["--eros-test-semantics"]
        app.launch()
        var tags = Set<String>()
        for iteration in 1...5 {
            awaitPage("gallery")
            nativeAction("offline-root-gallery")
            let root = app.descendants(matching: .any)["offline-duo-gallery-probe"]
            XCTAssertTrue(root.waitForExistence(timeout: 20), app.debugDescription)
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.routeData("gallery")["root"] == "true" &&
                    self.routeData("gallery")["gallery"] == "9500001"
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed,
                           root.label)
            let state = routeData("gallery")
            XCTAssertEqual(
                app.descendants(matching: .any)["offline-duo-health-probe"].label,
                "framework=0;platform=0", app.debugDescription)
            XCTAssertEqual(state["scope"], state["tag"])
            XCTAssertTrue(tags.insert(state["tag"] ?? "").inserted,
                          "Each replacement owns a fresh controller slot")
            XCTAssertFalse(app.descendants(matching: .any)["native-tab-/gallery"].exists)
            XCTAssertTrue(app.buttons["share"].exists)
            XCTAssertFalse(app.buttons["search"].exists)
            print("EROS_ROOT_REPLACEMENT_\(iteration)=\(root.label)")
            if iteration == 1 { record("root-gallery-managed-native-chrome") }
            nativeAction("home")
            awaitPage("gallery")
            XCTAssertFalse(root.exists)
            tab("favorite")
            awaitPage("favorite")
            tab("gallery")
            awaitPage("gallery")
        }
        record("home-after-5-forced-root-replacements")
    }

    func testSearchChromeReadyForPoses() {
        app.terminate()
        app.launchArguments = ["--eros-test-semantics"]
        app.launch()
        awaitPage("gallery")
        nativeAction("search")
        awaitNavigation(["tab": "/gallery", "primary": "/search"])
        let editor = searchEditor()
        XCTAssertTrue(editor.waitForExistence(timeout: 20), app.debugDescription)
        editor.tap()
        editor.typeText("duo chrome retained draft")
        let keyboard = app.keyboards.firstMatch
        // XCTest may retain an offscreen UIKeyboardLayoutStar Preview while
        // typing through the hardware keyboard. Only dismiss a visible one.
        if keyboard.exists && keyboard.frame.intersects(app.windows.firstMatch.frame) {
            if app.buttons["dismissKeyboard"].waitForExistence(timeout: 5) {
                nativeAction("dismissKeyboard")
            } else {
                let dismiss = app.descendants(matching: .any).matching(
                    NSPredicate(format: "label == %@", "收起键盘")).firstMatch
                XCTAssertTrue(dismiss.exists, app.debugDescription)
                dismiss.tap()
            }
            let hidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !keyboard.exists || !keyboard.frame.intersects(self.app.windows.firstMatch.frame)
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 10), .completed)
        }
        let probe = app.descendants(matching: .any)["offline-duo-search-probe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertEqual(routeData("search")["draft"], "duo chrome retained draft")
        print("EROS_SEARCH_READY_FOR_ACTUAL_POSES=\(probe.label)")
        record("search-ready-for-actual-pose-chrome-check")
    }

    func testIndependentTabNavigation() {
        app.terminate()
        app.launchArguments = ["--eros-test-semantics"]
        app.launch()
        awaitPage("gallery")
        let groupA = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Group A")).firstMatch
        XCTAssertTrue(groupA.waitForExistence(timeout: 20))
        groupA.tap()
        awaitPage("gallery", "glass-a")
        let gallery = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Glass A gallery 0")).firstMatch
        XCTAssertTrue(gallery.waitForExistence(timeout: 20))
        gallery.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        awaitNavigation(["tab": "/gallery", "gallery": "9500000", "detailDepth": "2"])
        tab("favorite")
        awaitPage("favorite")
        awaitNavigation(["tab": "/favorite", "detailDepth": "1"])
        let favorite = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "gallery 0 - neutral layout fixture")).firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 20), app.debugDescription)
        favorite.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        awaitNavigation(["tab": "/favorite", "gallery": "9600000", "detailDepth": "2"])
        for iteration in 1...20 {
            tab("gallery")
            awaitNavigation(["tab": "/gallery", "gallery": "9500000", "detailDepth": "2"])
            tab("favorite")
            awaitNavigation(["tab": "/favorite", "gallery": "9600000", "detailDepth": "2"])
            print("EROS_INDEPENDENT_DETAIL_\(iteration)=\(navigationData())")
        }
        record("two-independent-details-after-20-tab-round-trips")
        nativeAction("native-back")
        awaitNavigation(["tab": "/favorite", "detailDepth": "1"])
        tab("gallery")
        awaitNavigation(["tab": "/gallery", "gallery": "9500000", "detailDepth": "2"])
        nativeAction("native-back")
        awaitNavigation(["tab": "/gallery", "detailDepth": "1"])

        nativeAction("search")
        awaitNavigation(["tab": "/gallery", "primary": "/search", "primaryDepth": "2"])
        XCTAssertTrue(searchEditor().waitForExistence(timeout: 20))
        searchEditor().tap()
        searchEditor().typeText("gallery unsent draft")
        let gallerySearch = navigationData()["search"]
        XCTAssertNotEqual(gallerySearch, "0")
        tab("favorite")
        awaitNavigation(["tab": "/favorite", "primaryDepth": "1"])
        nativeAction("search")
        awaitNavigation(["tab": "/favorite", "primary": "/search", "primaryDepth": "2"])
        XCTAssertTrue(searchEditor().waitForExistence(timeout: 20))
        searchEditor().tap()
        searchEditor().typeText("favorite unsent draft")
        let favoriteSearch = navigationData()["search"]
        XCTAssertNotEqual(gallerySearch, favoriteSearch)
        for iteration in 1...20 {
            tab("gallery")
            awaitNavigation(["tab": "/gallery", "primary": "/search", "search": gallerySearch!])
            XCTAssertEqual(searchEditor().value as? String, "gallery unsent draft")
            tab("favorite")
            awaitNavigation(["tab": "/favorite", "primary": "/search", "search": favoriteSearch!])
            XCTAssertEqual(searchEditor().value as? String, "favorite unsent draft")
            print("EROS_INDEPENDENT_SEARCH_\(iteration)=\(navigationData())")
        }
        record("two-independent-search-drafts-after-20-tab-round-trips")
        nativeAction("native-back")
        awaitNavigation(["tab": "/favorite", "primaryDepth": "1"])
        tab("gallery")
        awaitNavigation(["tab": "/gallery", "primary": "/search", "search": gallerySearch!])
        XCTAssertEqual(searchEditor().value as? String, "gallery unsent draft")
        record("gallery-search-retained-after-other-tab-pop")
        print("EROS_INDEPENDENT_FINAL=\(navigationData())")
    }
}
