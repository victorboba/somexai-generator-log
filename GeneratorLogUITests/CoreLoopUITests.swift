import XCTest

/// Drives the real core loop end to end: add a generator, run its weekly inspection, then run the
/// monthly load test — the screen that computes run time and load percentage against the
/// nameplate live, which is what the app exists to sell — and confirm both land in the
/// generator's history. Every assertion is on content that only appears once the app actually did
/// the work, never merely that a button exists.
final class CoreLoopUITests: XCTestCase {

    /// Closes the keyboard if one is up. An open keyboard covers the lower half of the screen and
    /// holds a Form scrolled to the focused field, so rows below it are neither visible nor realised
    /// in the lazy list — a later assertion then fails on a screen that is working perfectly.
    private func dismissKeyboard(in app: XCUIApplication) {
        guard app.keyboards.element.exists else { return }
        app.typeText("\n")
        _ = app.keyboards.element.waitForNonExistence(timeout: 2)
    }

    /// SwiftUI lists are lazy, so a row outside the viewport is absent from the hierarchy entirely
    /// and `waitForExistence` just burns its timeout. Scans up first, then down, because the target
    /// is as often above the current position as below it.
    @discardableResult
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, swipes: Int = 6) -> Bool {
        dismissKeyboard(in: app)
        if element.exists { return true }
        for _ in 0..<(swipes / 2) {
            app.swipeDown()
            if element.exists { return true }
        }
        for _ in 0..<swipes {
            app.swipeUp()
            if element.exists { return true }
        }
        return element.exists
    }

    override func setUpWithError() throws { continueAfterFailure = false }

    func testAddGeneratorRunWeeklyInspectionAndMonthlyLoadTest() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Generators"].waitForExistence(timeout: 15))

        // Empty board: add the first generator.
        let addGenerator = app.buttons["Add a Generator"].firstMatch
        XCTAssertTrue(addGenerator.waitForExistence(timeout: 5))
        addGenerator.tap()

        XCTAssertTrue(app.navigationBars["Generator Details"].waitForExistence(timeout: 5))
        let unitID = app.textFields["unitIDField"]
        XCTAssertTrue(unitID.waitForExistence(timeout: 5))
        unitID.tap()
        unitID.typeText("UITest EG-1")

        let nameplate = app.textFields["nameplateKWField"]
        nameplate.tap()
        nameplate.typeText("400")

        app.navigationBars["Generator Details"].buttons["Done"].tap()

        // The generator the app just created has to actually appear on the board.
        let generatorRow = app.staticTexts["UITest EG-1"]
        XCTAssertTrue(generatorRow.waitForExistence(timeout: 5))
        generatorRow.tap()
        XCTAssertTrue(app.navigationBars["UITest EG-1"].waitForExistence(timeout: 5))

        // The weekly inspection: mark everything OK and confirm the AUTO state saved.
        let weeklyButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Weekly Inspection")).firstMatch
        XCTAssertTrue(weeklyButton.waitForExistence(timeout: 5))
        weeklyButton.tap()
        XCTAssertTrue(app.navigationBars["Weekly Inspection"].waitForExistence(timeout: 5))

        let weeklyTechnician = app.textFields["weekly.technicianField"]
        XCTAssertTrue(weeklyTechnician.waitForExistence(timeout: 5))
        weeklyTechnician.tap()
        weeklyTechnician.typeText("UITest Tech")

        app.buttons["Mark Remaining Items OK"].tap()
        app.navigationBars["Weekly Inspection"].buttons["Done"].tap()

        // The weekly inspection the app just recorded has to show up in this generator's history.
        let weeklyHistoryRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "nothing flagged")).firstMatch
        XCTAssertTrue(scrollTo(weeklyHistoryRow, in: app),
                      "the weekly inspection just recorded should appear in this generator's history")

        // The screen the app sells: the monthly load test against the nameplate.
        let monthlyButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Monthly Load Test")).firstMatch
        XCTAssertTrue(scrollTo(monthlyButton, in: app), "the monthly load test should be reachable")
        monthlyButton.tap()
        XCTAssertTrue(app.navigationBars["Monthly Load Test"].waitForExistence(timeout: 5))

        let runMinutes = app.textFields["run.runMinutes"]
        XCTAssertTrue(runMinutes.waitForExistence(timeout: 5))
        runMinutes.tap()
        runMinutes.typeText("35")
        let loadKW = app.textFields["run.loadKW"]
        loadKW.tap()
        loadKW.typeText("140")

        // Run time and load percentage appear as soon as the numbers land — arithmetic on the
        // technician's own readings, computed live against this generator's configured target.
        let durationText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "35 min")).firstMatch
        XCTAssertTrue(durationText.waitForExistence(timeout: 5))
        let loadText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "35%")).firstMatch
        XCTAssertTrue(loadText.waitForExistence(timeout: 5))

        let monthlyTechnician = app.textFields["run.technicianField"]
        monthlyTechnician.tap()
        monthlyTechnician.typeText("UITest Tech")

        app.navigationBars["Monthly Load Test"].buttons["Done"].tap()

        // The monthly test the app just recorded also has to show up in the history.
        let monthlyHistoryRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "35 min at 35%")).firstMatch
        XCTAssertTrue(scrollTo(monthlyHistoryRow, in: app),
                      "the monthly load test just recorded should appear in this generator's history")
    }
}
