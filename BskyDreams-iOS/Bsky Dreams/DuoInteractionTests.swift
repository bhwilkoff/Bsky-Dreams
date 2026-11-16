import XCTest

/// Drives the app on a real device the way a person would (taps, not launch doors), so
/// interaction bugs can be found without asking anyone to tap. Run with
/// `xcodebuild test -scheme BskyDreamsScreenshots -only-testing:BskyDreamsScreenshots/DuoInteractionTests`.
/// The app must already be signed in on the device.
final class DuoInteractionTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private func launch(_ env: [String: String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = env
        app.launch()
        return app
    }

    private func report(_ app: XCUIApplication, _ label: String) {
        let shot = app.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = label
        a.lifetime = .keepAlways
        add(a)
    }

    /// Messages: tap a chat row; the chat should open (its message field appears).
    func testMessagesRowOpensChat() throws {
        let app = launch(["BSKY_START_VIEW": "dms", "BSKY_SECOND_COLUMN": "none"])
        sleep(8)
        report(app, "messages-before")
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Kee")).firstMatch
        let rowExists = row.waitForExistence(timeout: 10)
        print("[DuoTest] messages row exists=\(rowExists) frame=\(row.frame) hittable=\(row.isHittable)")
        if rowExists {
            row.tap()
        } else {
            // Fall back to a coordinate tap where the second row sits.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.33)).tap()
        }
        sleep(3)
        report(app, "messages-after-tap")
        let field = app.textFields["Message..."]
        print("[DuoTest] chat field exists=\(field.exists)")
        XCTAssertTrue(field.exists, "Tapping a chat row should open the chat")
    }

    /// Messages: switch between chats (pane layout, then One Column).
    func testMessagesSwitchChats() throws {
        for layout in ["none", "single"] {
            let app = launch(["BSKY_START_VIEW": "dms", "BSKY_SECOND_COLUMN": layout])
            sleep(8)
            for name in ["Kee", "Zoe", "Test"] {
                let row = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
                let found = row.waitForExistence(timeout: 6)
                print("[DuoTest] \(layout) row \(name) found=\(found) hittable=\(found && row.isHittable)")
                if found && row.isHittable { row.tap() } else { print("[DuoTest] \(layout) could not tap \(name)") }
                sleep(3)
                let field = app.textFields["Message..."].exists
                let title = app.navigationBars.allElementsBoundByIndex.map { $0.identifier }.joined(separator: " | ")
                print("[DuoTest] \(layout) after \(name): chatField=\(field) navBars=\(title)")
                report(app, "\(layout)-after-\(name)")
                if layout == "single" {
                    let labels = app.buttons.allElementsBoundByIndex.prefix(40).map { "\($0.label)[\($0.identifier)]@\(Int($0.frame.minX)),\(Int($0.frame.minY))" }
                    print("[DuoTest] single navbar buttons: \(labels)")
                    // Back to the list for the next tap: the system back button.
                    let back = app.buttons.matching(NSPredicate(format: "label IN %@ OR identifier == %@", ["Back", "Messages"], "BackButton")).firstMatch
                    if back.exists { back.tap(); sleep(2) } else {
                        // Edge swipe back.
                        app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
                            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
                        sleep(2)
                    }
                    print("[DuoTest] single after back: list visible=\(app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Zoe")).firstMatch.exists)")
                }
            }
            app.terminate()
        }
    }

    /// Constellation: tap a person by name, drag the background, pinch.
    func testConstellationTapSelectsNode() throws {
        let app = launch(["BSKY_START_VIEW": "constellation"])
        let seed = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", "the center")).firstMatch
        let found = seed.waitForExistence(timeout: 30)
        sleep(4)   // let the simulation settle
        print("[DuoTest] seed found=\(found) frame=\(seed.frame)")
        report(app, "constellation-before")
        guard found else { XCTFail("No center node"); return }
        seed.tap()
        sleep(2)
        let panel = app.staticTexts["VIEW PROFILE"].exists || app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "profile")).firstMatch.exists
        print("[DuoTest] after tap: panel=\(panel) selected=\(seed.isSelected)")
        report(app, "constellation-after-tap")
        XCTAssertTrue(panel, "Tapping a person should open their panel")
        // Drags are not asserted here: synthetic drags near the leading edge or the top
        // band are claimed by the system's sidebar and bar gestures (2026-11-16); the owner
        // verified drag and pan by hand.
    }

    /// GIFs in a list (Search): scroll through and capture; every GIF should be drawn.
    func testGifsInList() throws {
        let app = launch(["BSKY_SEARCH_QUERY": "domain:static.klipy.com"])
        sleep(10)
        report(app, "gifs-top")
        let scroll = app.scrollViews.firstMatch
        for i in 0..<4 { scroll.swipeUp(); sleep(2); report(app, "gifs-scroll-\(i)") }
        for _ in 0..<4 { scroll.swipeDown() }
        sleep(3)
        report(app, "gifs-back-top")
        let gifs = app.descendants(matching: .any).matching(identifier: "gif").count
        print("[DuoTest] gif elements now: \(gifs)")
    }
}
