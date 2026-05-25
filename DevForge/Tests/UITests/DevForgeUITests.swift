import XCTest

final class DevForgeUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testAppLaunches() throws {
        XCTAssertTrue(app.windows.count > 0)
    }

    func testSidebarNavigation() throws {
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        let processManager = sidebar.staticTexts["Process Manager"]
        XCTAssertTrue(processManager.exists)

        let envVault = sidebar.staticTexts["Env Vault"]
        XCTAssertTrue(envVault.exists)

        let dockerConsole = sidebar.staticTexts["Docker Console"]
        XCTAssertTrue(dockerConsole.exists)

        let gitWorkspace = sidebar.staticTexts["Git Workspace"]
        XCTAssertTrue(gitWorkspace.exists)
    }

    func testSelectSectionChangesDetail() throws {
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        sidebar.staticTexts["System Health"].click()
        let healthTitle = app.staticTexts["Loading Metrics"]
        XCTAssertTrue(healthTitle.waitForExistence(timeout: 3))
    }

    func testNewProcessButtonAccessible() throws {
        let toolbar = app.toolbars.firstMatch
        let newButton = toolbar.buttons["New Process"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
    }

    func testWindowMinimumSize() throws {
        let window = app.windows.firstMatch
        let originalFrame = window.frame
        window.resize(to: CGSize(width: 400, height: 300))
        // Verify window snaps back to minimum size
        let resizedFrame = window.frame
        XCTAssertTrue(resizedFrame.width >= 1000 || resizedFrame.height >= 600)
    }
}
