import XCTest

final class IntentCalendarUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPlannerLaunchesInSeededPreviewMode() {
        let app = XCUIApplication()
        app.launchArguments.append("-intentcalendar-ui-testing")
        app.launch()

        XCTAssertTrue(app.staticTexts["planner.headline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["planner.planDay"].exists)
        XCTAssertTrue(app.buttons["planner.applyPreview"].exists)
    }
}
