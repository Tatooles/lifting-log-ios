import XCTest

final class LiftingLogUITests: XCTestCase {
    @MainActor
    func testAppLaunchesIntoWorkoutTab() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.textFields["WorkoutTitle"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testTabNavigationShowsHistoryAndProfile() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["HistoryTab"].tap()
        XCTAssertTrue(app.staticTexts["HistoryTitle"].waitForExistence(timeout: 3))

        app.buttons["ProfileTab"].tap()
        XCTAssertTrue(app.staticTexts["ProfileTitle"].waitForExistence(timeout: 3))

        app.buttons["WorkoutTab"].tap()
        XCTAssertTrue(app.textFields["WorkoutTitle"].waitForExistence(timeout: 3))
    }
}
