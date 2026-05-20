import XCTest

final class EvenG1CompanionUITests: XCTestCase {
    @MainActor
    func testLaunchShowsControlSurface() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Even G1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Control"].exists)
        XCTAssertTrue(app.tabBars.buttons["Diagnostics"].exists)
        XCTAssertTrue(app.tabBars.buttons["Log"].exists)
    }
}
