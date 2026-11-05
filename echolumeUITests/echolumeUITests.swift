//
//  echolumeUITests.swift
//  echolumeUITests
//
//  Created by Jarl Lyng on 25/02/2026.
//

import XCTest

final class echolumeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAppLaunchesToForeground() throws {
        // Smoke test: the app launches without crashing and reaches the foreground.
        let app = XCUIApplication()
        app.launchEnvironment["ECHOLUME_UITEST"] = "1"   // app omits the MenuBarExtra under test
        app.launch()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "App did not reach the foreground within 10s"
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchEnvironment["ECHOLUME_UITEST"] = "1"
            app.launch()
        }
    }
}
