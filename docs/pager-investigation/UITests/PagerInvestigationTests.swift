import XCTest

final class PagerInvestigationTests: XCTestCase {
    private let sync = URL(fileURLWithPath: "/tmp/complex-layout-uitest-sync", isDirectory: true)

    private func checkpoint(_ name: String, app: XCUIApplication) throws {
        // XCTest has already waited for UI idleness; let rotation rendering settle.
        Thread.sleep(forTimeInterval: 1)
        try FileManager.default.createDirectory(at: sync, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: [
            "name": name,
            "orientation": XCUIDevice.shared.orientation.rawValue,
            "runnerPID": ProcessInfo.processInfo.processIdentifier,
            "appFrame": String(describing: app.frame)
        ], options: .prettyPrinted)
        try app.debugDescription.write(to: sync.appendingPathComponent("\(name)-ax.txt"), atomically: true, encoding: .utf8)
        try app.screenshot().pngRepresentation.write(to: sync.appendingPathComponent("\(name).png"))
        try data.write(to: sync.appendingPathComponent("current.json"), options: .atomic)
        let release = sync.appendingPathComponent("\(name).continue")
        let deadline = Date().addingTimeInterval(120)
        while !FileManager.default.fileExists(atPath: release.path) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: release.path), "Host capture did not acknowledge \(name)")
    }

    func testAlternatives() throws {
        continueAfterFailure = false
        for variant in ["baseline", "swiftUIList", "listNoIgnore", "geometryPage", "zeroMargins", "rebuildPage", "rebuildPager"] {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication(bundleIdentifier: "com.example.ComplexLayout")
            app.launchArguments = ["--pager-experiment=\(variant)"]
            app.launch()
            XCTAssertTrue(app.buttons["Featured, 9"].waitForExistence(timeout: 10))
            XCUIDevice.shared.orientation = .landscapeLeft
            try checkpoint("auto-\(variant)-landscape", app: app)
            app.terminate()
        }
    }

    func testFix3RepeatedRotationsAndPaging() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.example.ComplexLayout")
        app.launchArguments = ["--open-overview"]
        app.launch()

        let first = app.buttons["Featured, 9"]
        let second = app.buttons["Collections, 8"]
        let third = app.buttons["Recently Added, 7"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))

        second.tap()
        XCTAssertTrue(second.isSelected)
        try checkpoint("fix3-v2-selected-page-portrait", app: app)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(second.isSelected)
        try checkpoint("fix3-v2-first-landscape", app: app)

        let swipeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.55))
        let swipeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.55))
        swipeStart.press(forDuration: 0.1, thenDragTo: swipeEnd)
        XCTAssertTrue(third.isSelected)
        try checkpoint("fix3-v2-paged-landscape", app: app)

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(third.isSelected)
        try checkpoint("fix3-v2-returned-portrait", app: app)

        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(third.isSelected)
        try checkpoint("fix3-v2-second-landscape", app: app)
    }

    func testFix3ControllerStrategies() throws {
        continueAfterFailure = false
        let strategies = [
            "baseline",
            "invalidatePager",
            "layoutPager",
            "performPagerUpdates",
            "disablePagerAdjustment",
            "compensateChild",
            "repairPageCell"
        ]

        for strategy in strategies {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication(bundleIdentifier: "com.example.ComplexLayout")
            app.launchArguments = ["--open-overview", "--fix3-strategy=\(strategy)"]
            app.launch()
            XCTAssertTrue(app.buttons["Featured, 9"].waitForExistence(timeout: 10))

            XCUIDevice.shared.orientation = .landscapeLeft
            try checkpoint("inside-\(strategy)-landscape", app: app)
            app.terminate()
        }
    }
}
