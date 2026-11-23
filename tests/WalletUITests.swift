import XCTest
import UIKit

final class WalletUITests: XCTestCase {
    private func wallet() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR", "-monthlyReportEnabled", "NO"]
        app.launch()
        let tab = app.buttons["지갑"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        XCTAssertTrue(app.buttons["wallet.card.select.0"].waitForExistence(timeout: 10))
        return app
    }
    private func waitForDetail(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["wallet.card.reveal"].waitForExistence(timeout: 5))
    }
    private func assertPaintedDeck(_ app: XCUIApplication, name: String) {
        XCTAssertTrue(app.staticTexts["wallet.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["wallet.sections"].exists)
        XCTAssertTrue(app.staticTexts["wallet.hint"].exists)
        for index in 0..<6 {
            let strip = app.buttons["wallet.card.select.\(index)"]
            XCTAssertTrue(strip.waitForExistence(timeout: 5))
            // Compare the actual displayed card identity in each persistent
            // slot, not just the count or touch-region existence. Unlike a
            // post-test JSON read, this runs before XCTest disposes of the
            // simulator application container.
            XCTAssertTrue(strip.label.contains("Demo Card \(index + 1)"),
                "Card order/identity changed at slot \(index) after \(name): \(strip.label)")
            // The regression kept transparent hit buttons alive over a blank
            // background. Test actual rendered pixels, not just AX existence.
            let image = strip.screenshot().image.cgImage!
            let width = image.width, height = image.height
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            pixels.withUnsafeMutableBytes { buffer in
                let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            }
            var colored = 0
            for p in stride(from: 0, to: pixels.count, by: 4) {
                let channels = [Int(pixels[p]), Int(pixels[p + 1]), Int(pixels[p + 2])]
                if channels.max()! - channels.min()! > 30 { colored += 1 }
            }
            XCTAssertGreaterThan(Double(colored) / Double(width * height), 0.15,
                "Card \(index) disappeared after \(name)")
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testRepeatedOpenCloseAndInterruptedOpening() {
        let app = wallet()
        assertPaintedDeck(app, name: "initial")
        for index in [0, 2, 5, 1, 4, 3, 0, 5] {
            app.buttons["wallet.card.select.\(index)"].tap()
            waitForDetail(app)
            app.buttons["wallet.close"].tap()
            assertPaintedDeck(app, name: "returned-\(index)")
        }
        app.buttons["wallet.card.select.2"].tap()
        app.buttons["wallet.close"].tap()
        assertPaintedDeck(app, name: "interrupted-opening")
    }
    func testLongPressReorderPersistsAndRestores() {
        let app = wallet()
        let first = app.buttons["wallet.card.select.0"]
        let last = app.buttons["wallet.card.select.5"]
        first.press(forDuration: 0.4, thenDragTo: last)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(app.buttons["wallet.card.select.5"].label.contains("Demo Card 1"))
        app.buttons["wallet.card.select.5"].press(forDuration: 0.4, thenDragTo: app.buttons["wallet.card.select.0"])
        Thread.sleep(forTimeInterval: 0.8)
        assertPaintedDeck(app, name: "reorder-restored")
    }

    func testDeckBrowsingAndPullDownReturn() {
        let app = wallet()
        let strip = app.buttons["wallet.card.select.3"]
        let start = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.02, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -100)))
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(app.buttons["wallet.close"].exists, "Browsing must not open a detail or reorder")
        assertPaintedDeck(app, name: "after-upward-browse")
        start.press(forDuration: 0.02, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 100)))
        Thread.sleep(forTimeInterval: 0.5)
        assertPaintedDeck(app, name: "after-downward-browse")
        app.buttons["wallet.card.select.5"].tap()
        waitForDetail(app)
        let header = app.otherElements["wallet.detail.header"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        let pull = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        pull.press(forDuration: 0.02, thenDragTo: pull.withOffset(CGVector(dx: 0, dy: 12)))
        waitForDetail(app)
        XCTAssertTrue(app.buttons["wallet.close"].exists)
        pull.press(forDuration: 0.02, thenDragTo: pull.withOffset(CGVector(dx: 0, dy: 180)))
        assertPaintedDeck(app, name: "after-pull-down-return")
    }
}
