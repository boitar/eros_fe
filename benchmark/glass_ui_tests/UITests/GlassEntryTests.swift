import XCTest
import UIKit

final class GlassEntryTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "cn.honjow.fehv")
    private let routes = ["gallery", "favorite", "toplist"]
    private let titles = ["画廊", "收藏", "排行", "下载", "设置"]
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.activate()
    }

    private func element(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ OR label BEGINSWITH %@", label, label + "\n")).firstMatch
    }

    private func tap(_ label: String) {
        let target = element(label)
        XCTAssertTrue(target.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(target.isHittable, app.debugDescription)
        target.tap()
    }

    private func record(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func probe(_ tab: Int) -> XCUIElement {
        let result = app.descendants(matching: .any)["offline-glass-probe-" + routes[tab]]
        XCTAssertTrue(result.exists || result.waitForExistence(timeout: 40),
                      app.debugDescription)
        return result
    }

    private func data(_ tab: Int) -> [String: String] {
        Dictionary(uniqueKeysWithValues: probe(tab).label.split(separator: ";").compactMap {
            let parts = $0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return parts.count == 2 ? (String(parts[0]), String(parts[1])) : nil
        })
    }

    private func awaitState(_ tab: Int, _ message: String,
                            predicate: @escaping ([String: String]) -> Bool) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in predicate(self.data(tab)) },
            object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 30), .completed,
                       message + ": " + probe(tab).label)
    }

    private func requests(_ tab: Int) -> Int { Int(data(tab)["requests"] ?? "") ?? -1 }

    private func actualFirstCard(_ tab: Int) -> XCUIElement {
        let page = data(tab)["page"] ?? ""
        let prefix = tab == 0
            ? "Glass \(page == "glass-a" ? "A" : "B") gallery 0 -"
            : "\(routes[tab]) \(page) gallery 0 -"
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func initialTop(_ tab: Int) -> Double {
        awaitState(tab, "First actual card must be laid out") {
            ($0["first"].flatMap(Double.init) ?? -1) > 0 &&
                (Int($0["requests"] ?? "") ?? 0) > 0 &&
                $0["targetLive"] == "true" && $0["targetCallback"] == "true"
        }
        let card = actualFirstCard(tab)
        XCTAssertTrue(card.waitForExistence(timeout: 20), app.debugDescription)
        awaitState(tab, "The rendered first card and measured anchor must agree") {
            guard let first = $0["first"].flatMap(Double.init) else { return false }
            return !card.frame.isEmpty && abs(card.frame.minY - first) < 4
        }
        print("EROS_INITIAL_\(routes[tab])=" + probe(tab).label +
              ";nativeCardFrame=\(card.exists ? String(describing: card.frame) : "missing")")
        record("initial-\(routes[tab])-physical-card")
        return Double(data(tab)["first"]!)!
    }

    private func tabPoint(_ tab: Int) -> XCUICoordinate {
        let native = app.buttons["liquid-glass-tab-\(tab)"]
        var target: XCUIElement?
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            // UITabBar's selected glass lens can make XCTest report its
            // underlying item as non-hittable. Tap its real on-screen frame;
            // page identity, request counts and scroll state verify the hit.
            if native.exists && !native.frame.isEmpty &&
                self.app.frame.contains(CGPoint(x: native.frame.midX,
                                                y: native.frame.midY)) {
                target = native
                return true
            }
            target = self.app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", self.titles[tab]))
                .allElementsBoundByIndex.last(where: {
                    // Flutter exposes the selected Cupertino tab as Other;
                    // XCTest can report that semantics node as non-hittable.
                    // Press its real visible frame and verify the page/scroll
                    // response, as for the native selected glass lens above.
                    let frame = $0.frame
                    return !frame.isEmpty &&
                        frame.minY > self.app.frame.height - 110 &&
                        self.app.frame.contains(CGPoint(x: frame.midX,
                                                        y: frame.midY))
                })
            return target != nil
        }, object: nil)
        guard XCTWaiter.wait(for: [ready], timeout: 15) == .completed,
              let target else {
            XCTFail("No actual tab control: \(titles[tab])\n" + app.debugDescription)
            return app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.95))
        }
        return app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: target.frame.midX, dy: target.frame.midY))
    }

    private func tapTab(_ tab: Int, twice: Bool = false) {
        let point = tabPoint(tab)
        if twice { point.doubleTap() } else { point.press(forDuration: 0.15) }
    }

    private func scrollDeep() {
        let x = isPad ? 0.18 : 0.5
        // The translucent bar overlaps the scroll view's semantic frame.
        // Keep both endpoints inside its visible body and move before the
        // production card's long-press timeout.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.7))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.35))
        start.press(forDuration: 0.01, thenDragTo: end,
                    withVelocity: .fast, thenHoldForDuration: 0)
    }

    private func selectTraditionalPage(_ tab: Int, page: String, label: String) {
        if UIFont.preferredFont(forTextStyle: .body).pointSize <= 25 {
            tap(label)
            return
        }
        // Master's LinkScrollBar measures unscaled text. Its accessibility
        // frame can extend beyond the actual large-type hit region. Use the
        // existing PageView gesture and still assert the actual page below.
        func index(_ value: String) -> Int {
            tab == 0 ? (value == "glass-b" ? 1 : 0)
                : (Int(value).map { $0 + 1 } ?? 0)
        }
        for _ in 0..<12 {
            let current = data(tab)["page"] ?? ""
            if current == page { return }
            let left = index(page) > index(current)
            let width = isPad ? min(420, app.frame.width * 0.46) : app.frame.width
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let prefix = tab == 0 ? "Glass " : "favorite "
            let titles = app.descendants(matching: .any).matching(NSPredicate(
                format: "label BEGINSWITH %@ AND label CONTAINS %@", prefix, "gallery"))
            guard let title = titles.allElementsBoundByIndex.first(where: {
                $0.isHittable && $0.frame.minY > app.frame.height * 0.16 &&
                    $0.frame.maxY < app.frame.height * 0.8
            }) else {
                XCTFail("No visible title for a real PageView gesture: " + app.debugDescription)
                return
            }
            // Gallery tags have their own horizontal scrolling. Start in a
            // visible card's title, as the group-index native verifier does.
            let y = title.frame.minY + min(16, title.frame.height * 0.2)
            let start = origin.withOffset(CGVector(dx: width * (left ? 0.8 : 0.2), dy: y))
            let end = origin.withOffset(CGVector(dx: width * (left ? 0.2 : 0.8), dy: y))
            start.press(forDuration: 0.01, thenDragTo: end,
                        withVelocity: .fast, thenHoldForDuration: 0)
            awaitState(tab, "The real PageView must change category") {
                $0["page"] != current
            }
        }
        XCTFail("Could not select actual page \(page)")
    }

    private func scrollDeep(_ tab: Int, from initial: Double) {
        for _ in 0..<3 {
            scrollDeep()
            let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let state = self.data(tab)
                guard let first = state["first"].flatMap(Double.init) else { return true }
                return first < initial - 30
            }, object: nil)
            if XCTWaiter.wait(for: [moved], timeout: 3) == .completed { return }
        }
    }

    private func assertTop(_ tab: Int, _ initial: Double) {
        var last = ""
        awaitState(tab, "Actual outer/inner list must return to its initial card") {
            let observation = "\($0["first"] ?? "missing")/\($0["outer"] ?? "")/\($0["inner"] ?? "")"
            if observation != last {
                last = observation
                let card = self.actualFirstCard(tab)
                print("EROS_RETURN_\(self.routes[tab])=\(observation);nativeCardFrame=\(card.exists ? String(describing: card.frame) : "missing")")
            }
            guard let first = $0["first"].flatMap(Double.init) else { return false }
            let card = self.actualFirstCard(tab)
            return card.exists && !card.frame.isEmpty &&
                abs(card.frame.minY - initial) < 4 &&
                abs(first - initial) < 4 &&
                ($0["outer"] ?? "").split(separator: ",").allSatisfy {
                    abs(Double($0) ?? 100) < 1
                } &&
                ($0["inner"] ?? "").split(separator: ",").allSatisfy {
                    abs(Double($0) ?? 100) < 1
                }
        }
    }

    private func findSettingsRow(_ label: String) -> XCUIElement {
        let row = element(label)
        let x = isPad ? 0.70 : 0.5
        for _ in 0..<12 {
            if row.exists && row.isHittable { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.75))
                .press(forDuration: 0.05,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.35)))
        }
        XCTAssertTrue(row.isHittable, app.debugDescription)
        return row
    }

    private func setGlass(_ enabled: Bool, inline: Bool = false, twoRow: Bool = false) {
        tapTab(4)
        tap("样式")
        findSettingsRow("iOS 液态玻璃").tap()
        let wrapper = app.descendants(matching: .any)["offline-glass-control-enabled"]
        XCTAssertTrue(wrapper.waitForExistence(timeout: 20), app.debugDescription)
        let toggle = wrapper.switches.firstMatch
        if toggle.exists {
            if (toggle.value as? String == "1") != enabled {
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            }
            XCTAssertEqual(toggle.value as? String, enabled ? "1" : "0")
        } else {
            // Flutter can merge the switch into the wrapper semantics.
            let current = wrapper.value as? String
            if (current == "1") != enabled {
                wrapper.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            }
        }
        if inline || twoRow {
            findSettingsRow("顶栏分组布局").tap()
            tap(inline ? "单行紧凑" : "两行展开（默认）")
            record(inline ? "glass-settings-inline-layout" : "glass-settings-two-row-layout")
        }
        let back = app.buttons.matching(
            NSPredicate(format: "label == '返回' OR label == 'Back'")).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 15), app.debugDescription)
        back.tap()
        tapTab(0)
        awaitState(0, "Rendered navigation mode must match the switch") {
            $0["glass"] == (enabled ? "true" : "false")
        }
    }

    private func setAppTheme(_ title: String) {
        tapTab(4)
        tap("样式")
        findSettingsRow("主题").tap()
        tap(title)
        let back = app.buttons.matching(
            NSPredicate(format: "label == '返回' OR label == 'Back'")).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 15), app.debugDescription)
        back.tap()
        tapTab(0)
        XCTAssertTrue(app.buttons["liquid-glass-tab-0"].waitForExistence(timeout: 15),
                      app.debugDescription)
        record("glass-native-appearance-" + title)
    }

    private func traditionalSequence(_ tab: Int) {
        tapTab(tab)
        let initial = initialTop(tab)
        let before = requests(tab)
        scrollDeep(tab, from: initial)
        awaitState(tab, "Real content must scroll") {
            guard let top = $0["first"].flatMap(Double.init) else { return true }
            return abs(top - initial) > 30
        }
        tapTab(tab)
        assertTop(tab, initial)
        XCTAssertEqual(requests(tab), before, "Single reselection must not refresh")
        Thread.sleep(forTimeInterval: 1)
        tapTab(tab, twice: true)
        awaitState(tab, "Two taps within 800ms must refresh the actual current page") {
            Int($0["requests"] ?? "") == before + 1
        }
        assertTop(tab, initial)
        Thread.sleep(forTimeInterval: 1)
        let after = requests(tab)
        tapTab(tab)
        Thread.sleep(forTimeInterval: 1)
        tapTab(tab)
        assertTop(tab, initial)
        XCTAssertEqual(requests(tab), after, "Expired taps must start a new sequence")
        record("traditional-\(routes[tab])-actual-scroll-and-request-counts")
    }

    func testProductionNativeCategoryAfterModeSwitch() {
        setGlass(false)
        setGlass(true)
        tapTab(0)
        for (label, page) in [("Group B", "glass-b"), ("Group A", "glass-a")] {
            let category = app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND label == %@",
                "liquid-glass-category-", label)).firstMatch
            XCTAssertTrue(category.waitForExistence(timeout: 20), app.debugDescription)
            let rail = app.scrollViews["liquid-glass-category-scroll"]
            XCTAssertTrue(rail.exists)
            // UIKit reports the full button frame even when it is clipped by
            // the horizontal viewport. Reveal its center before pressing it;
            // an off-viewport center can overlap an adjacent history action.
            for _ in 0..<6 {
                let point = CGPoint(x: category.frame.midX, y: category.frame.midY)
                if rail.frame.insetBy(dx: 2, dy: 2).contains(point) { break }
                let revealEarlier = point.x < rail.frame.minX
                rail.coordinate(withNormalizedOffset: CGVector(
                    dx: revealEarlier ? 0.2 : 0.8, dy: 0.5)).press(forDuration: 0.05,
                    thenDragTo: rail.coordinate(withNormalizedOffset: CGVector(
                        dx: revealEarlier ? 0.8 : 0.2, dy: 0.5)))
            }
            let point = CGPoint(x: category.frame.midX, y: category.frame.midY)
            XCTAssertTrue(rail.frame.insetBy(dx: 2, dy: 2).contains(point),
                          "Category center must be inside its actual native viewport")
            print("EROS_NATIVE_CATEGORY_CENTER=\(point);viewport=\(rail.frame)")
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: point.x, dy: point.y)).press(forDuration: 0.15)
            awaitState(0, "Native category must change the actual page after a mode switch") {
                $0["page"] == page
            }
            _ = initialTop(0)
            record("native-category-after-mode-switch-" + page)
        }
        setGlass(false)
    }

    func testProductionTraditionalNavigation() {
        setGlass(false)
        for tab in 0..<3 { traditionalSequence(tab) }
    }

    func testProductionTraditionalCachedNavigation() {
        setGlass(false)
        tapTab(0)
        selectTraditionalPage(0, page: "glass-b", label: "Group B")
        awaitState(0, "Group B must be the real active page") { $0["page"] == "glass-b" }
        let second = initialTop(0)
        let secondCount = requests(0)
        scrollDeep(0, from: second)
        awaitState(0, "Cached sibling must really scroll before switching") {
            ($0["first"].flatMap(Double.init) ?? second) < second - 30
        }
        var previousInner: [Double] = []
        var secondInner: [Double] = []
        awaitState(0, "Capture B's actual inner position after drag inertia settles") {
            let current = ($0["inner"] ?? "").split(separator: ",")
                .compactMap { Double($0) }
            defer { previousInner = current }
            guard !current.isEmpty, current.count == previousInner.count,
                  zip(current, previousInner).allSatisfy({ abs($0 - $1) < 0.5 })
            else { return false }
            secondInner = current
            return true
        }
        XCTAssertFalse(secondInner.isEmpty)
        print("EROS_CACHED_B_BEFORE=" + secondInner.map { String($0) }.joined(separator: ","))
        selectTraditionalPage(0, page: "glass-a", label: "Group A")
        awaitState(0, "Cached Group A must be restored") { $0["page"] == "glass-a" }
        let first = initialTop(0)
        let count = requests(0)
        scrollDeep(0, from: first)
        awaitState(0, "Group A must really scroll before reselection") {
            ($0["first"].flatMap(Double.init) ?? first - 100) < first - 30
        }
        tapTab(0)
        assertTop(0, first)
        XCTAssertEqual(requests(0), count)
        selectTraditionalPage(0, page: "glass-b", label: "Group B")
        awaitState(0, "A's reselection must preserve B's cached inner position") {
            guard $0["page"] == "glass-b" else { return false }
            let restored = ($0["inner"] ?? "").split(separator: ",")
                .compactMap { Double($0) }
            return restored.count == secondInner.count &&
                zip(restored, secondInner).allSatisfy { abs($0 - $1) < 4 }
        }
        XCTAssertEqual(requests(0), secondCount, "Cached sibling must not refresh")
        print("EROS_CACHED_B_RESTORED=" + (data(0)["inner"] ?? ""))
        tapTab(1)
        selectTraditionalPage(1, page: "0", label: "Folder 0")
        awaitState(1, "Actual favorite folder selection") { $0["page"] == "0" }
        traditionalSequence(1)
        selectTraditionalPage(1, page: "1", label: "Folder 1")
        awaitState(1, "Cache a second real favorite page") { $0["page"] == "1" }
        selectTraditionalPage(1, page: "0", label: "Folder 0")
        awaitState(1, "Return to actual favorite folder 0") { $0["page"] == "0" }
        traditionalSequence(1)
        tapTab(0)
        XCUIDevice.shared.orientation = .landscapeLeft
        _ = probe(0)
        record("traditional-production-landscape")
        XCUIDevice.shared.orientation = .portrait
    }

    func testProductionGlassNavigationAndForms() {
        setGlass(true)
        for tab in 0..<3 {
            if tab != 0 { tapTab(tab) }
            let initial = initialTop(tab)
            let before = requests(tab)
            scrollDeep(tab, from: initial)
            awaitState(tab, "The actual glass page must scroll before reselection") {
                ($0["first"].flatMap(Double.init) ?? initial - 100) < initial - 30
            }
            tapTab(tab)
            awaitState(tab, "Glass reselection refreshes the current page") {
                Int($0["requests"] ?? "") == before + 1
            }
            assertTop(tab, initial)
            record("glass-\(routes[tab])-actual-scroll-and-refresh")
        }
        tapTab(0)
        let first = initialTop(0)
        let x = isPad ? app.frame.width * 0.18 : app.frame.width * 0.5
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: first + 80)).press(forDuration: 1.2)
        tap("添加收藏夹")
        let lastFolder = element("Folder 9")
        XCTAssertTrue(lastFolder.waitForExistence(timeout: 20), app.debugDescription)
        for _ in 0..<4 {
            if lastFolder.isHittable { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
        XCTAssertTrue(lastFolder.isHittable, app.debugDescription)
        let note = app.textViews.firstMatch.exists
            ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(note.exists, app.debugDescription)
        record("glass-favorite-form-all-ten-folders")
        tap("取消")
        tapTab(3)
        record("glass-production-download-layout")
        setGlass(true, inline: true)
        XCUIDevice.shared.orientation = .landscapeLeft
        _ = probe(0)
        record("glass-production-inline-landscape")
        XCUIDevice.shared.orientation = .portrait
        setAppTheme("浅色模式")
        setAppTheme("深色模式")
        setAppTheme("跟随系统")
        let search = app.buttons["liquid-glass-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 20), app.debugDescription)
        search.tap()
        let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20), app.debugDescription)
        record("glass-production-native-search-entry")
        let back = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["返回", "取消", "Back", "Cancel"])).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 15), app.debugDescription)
        back.tap()
        // Repeated real center presses must keep selecting the intended page.
        // This catches stale native recognizers after route and theme changes.
        for _ in 0..<2 {
            tapTab(4)
            XCTAssertTrue(element("样式").waitForExistence(timeout: 15),
                          app.debugDescription)
            for tab in 0..<3 {
                tapTab(tab)
                _ = initialTop(tab)
            }
        }
    }

    func testProductionLandscapeSafeArea() {
        for inline in [false, true] {
            setGlass(true, inline: inline, twoRow: !inline)
            XCUIDevice.shared.orientation = .landscapeLeft
            let rail = app.scrollViews["liquid-glass-category-scroll"]
            awaitState(0, "Landscape rail and first card must clear the actual window safe area") {
                guard $0["orientation"] == "landscape",
                      let safe = $0["systemTop"].flatMap(Double.init),
                      let first = $0["first"].flatMap(Double.init),
                      self.app.frame.width > self.app.frame.height,
                      rail.exists, !rail.frame.isEmpty else { return false }
                return (!self.isPad || safe > 0) &&
                    rail.frame.minY >= safe - 1 && first >= safe + 44
            }
            record(inline ? "landscape-safe-inline" : "landscape-safe-two-row")
            XCUIDevice.shared.orientation = .portrait
            awaitState(0, "Portrait geometry must restore after rotation") {
                $0["orientation"] == "portrait"
            }
        }
    }

    func testProductionRestoredGlassLayout() {
        awaitState(0, "Glass mode must survive process restart") { $0["glass"] == "true" }
        _ = initialTop(0)
        tapTab(4)
        tap("样式")
        XCTAssertTrue(findSettingsRow("顶栏分组布局").label.contains("单行紧凑"),
                      app.debugDescription)
        record("glass-production-restored-inline-layout")
        let back = app.buttons.matching(
            NSPredicate(format: "label == '返回' OR label == 'Back'")).firstMatch
        back.tap()
        tapTab(0)
        setGlass(false)
        traditionalSequence(0)
    }

}
