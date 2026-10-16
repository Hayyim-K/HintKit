import XCTest

final class HintKitDemoUITests: XCTestCase {
    func testRealTouchesAdvanceCloseAndReplayHints() {
        let app = XCUIApplication()
        app.launchArguments = ["-HintKitDemoResetHistory"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Choose a photo"].waitForExistence(timeout: 10))
        app.buttons["demo.photo"].tap()
        XCTAssertTrue(app.staticTexts["Try the palette"].waitForExistence(timeout: 5))
        app.buttons["HintKit.close"].tap()
        XCTAssertTrue(app.staticTexts["Save your result"].waitForExistence(timeout: 5))
        app.buttons["demo.save"].tap()
        XCTAssertTrue(app.staticTexts["All demo actions completed. Use Show help again to replay the hints."].waitForExistence(timeout: 5))
        app.buttons["demo.help"].tap()
        XCTAssertTrue(app.staticTexts["Choose a photo"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "HintKit Demo"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testPointerModesCanBeSelectedWithoutBlockingThePhotoButton() {
        let app = XCUIApplication()
        app.launchArguments = ["-HintKitDemoResetHistory"]
        app.launch()
        let modes = app.segmentedControls["demo.pointer"]
        XCTAssertTrue(modes.waitForExistence(timeout: 10))
        for name in ["Tail", "Arrows", "Both", "None"] {
            modes.buttons[name].tap()
            XCTAssertTrue(app.staticTexts["Choose a photo"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["demo.photo"].isHittable)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "HintKit pointer \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

}
