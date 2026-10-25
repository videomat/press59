import XCTest

final class WindowLayoutTests: XCTestCase {
    /// A 1512 × 944 usable screen area, in AppKit coordinates.
    private let visible = CGRect(x: 0, y: 0, width: 1512, height: 944)

    private func press(_ keys: WindowKey...) -> WindowPosition? {
        keys.reduce(nil) { previous, key in WindowPosition.next(key, after: previous) }
    }

    func testWindowKeys() {
        XCTAssertEqual(WindowKey(keyCode: 123), .left)
        XCTAssertEqual(WindowKey(keyCode: 124), .right)
        XCTAssertEqual(WindowKey(keyCode: 126), .up)
        XCTAssertEqual(WindowKey(keyCode: 125), .down)
        XCTAssertEqual(WindowKey(keyCode: 36), .fill)
        XCTAssertEqual(WindowKey(keyCode: 76), .fill)
        XCTAssertNil(WindowKey(keyCode: 0))
    }

    // MARK: - Combining arrows

    func testSidesHalfThenThirdThenHalf() {
        XCTAssertEqual(press(.left), .leftHalf)
        XCTAssertEqual(press(.left, .left), .tile(.leftThird, .full))
        XCTAssertEqual(press(.left, .left, .left), .leftHalf)
        XCTAssertEqual(press(.right, .right), .tile(.rightThird, .full))
        XCTAssertEqual(press(.left, .right), .rightHalf)
    }

    func testUpAndDownPickARowOfTheColumn() {
        XCTAssertEqual(press(.left, .up), .tile(.leftHalf, .top))
        XCTAssertEqual(press(.left, .down), .tile(.leftHalf, .bottom))
        XCTAssertEqual(press(.left, .left, .down), .tile(.leftThird, .bottom))
        XCTAssertEqual(press(.left, .up, .up), .leftHalf)
        XCTAssertEqual(press(.left, .up, .down), .tile(.leftHalf, .bottom))
    }

    func testSidesKeepTheRow() {
        XCTAssertEqual(press(.left, .up, .left), .tile(.leftThird, .top))
        XCTAssertEqual(press(.left, .up, .right), .tile(.rightHalf, .top))
    }

    func testUpAndDownPickAHalfOfTheScreen() {
        XCTAssertEqual(press(.up), .tile(.full, .top))
        XCTAssertEqual(press(.down), .tile(.full, .bottom))
        XCTAssertEqual(press(.up, .up), .fill)
        XCTAssertEqual(press(.up, .down), .tile(.full, .bottom))
        XCTAssertEqual(press(.up, .left), .tile(.leftHalf, .top))
    }

    func testReturnFillsFromAnywhereThenCenters() {
        XCTAssertEqual(press(.fill), .fill)
        XCTAssertEqual(press(.left, .fill), .fill)
        XCTAssertEqual(press(.left, .left, .up, .fill), .fill)
        XCTAssertEqual(press(.fill, .fill), .center)
        XCTAssertEqual(press(.fill, .fill, .fill), .fill)
    }

    func testArrowsCombineAfterReturn() {
        XCTAssertEqual(press(.left, .fill, .up), .tile(.full, .top))
        XCTAssertEqual(press(.fill, .fill, .left), .leftHalf)
        XCTAssertEqual(press(.fill, .fill, .down), .tile(.full, .bottom))
    }

    // MARK: - Frames

    func testHalvesMeetWithoutGapOrOverlap() {
        let odd = CGRect(x: 100, y: 50, width: 1511, height: 901)
        let left = WindowPosition.leftHalf.frame(in: odd)
        let right = WindowPosition.rightHalf.frame(in: odd)
        XCTAssertEqual(left, CGRect(x: 100, y: 50, width: 755, height: 901))
        XCTAssertEqual(right, CGRect(x: 855, y: 50, width: 756, height: 901))
        let top = WindowPosition.tile(.full, .top).frame(in: odd)
        let bottom = WindowPosition.tile(.full, .bottom).frame(in: odd)
        XCTAssertEqual(bottom, CGRect(x: 100, y: 50, width: 1511, height: 450))
        XCTAssertEqual(top, CGRect(x: 100, y: 500, width: 1511, height: 451))
    }

    func testThirdsSitAtTheEdges() {
        XCTAssertEqual(WindowPosition.tile(.leftThird, .full).frame(in: visible), CGRect(x: 0, y: 0, width: 504, height: 944))
        XCTAssertEqual(WindowPosition.tile(.rightThird, .full).frame(in: visible), CGRect(x: 1008, y: 0, width: 504, height: 944))
    }

    func testTopIsTheUpperHalfInAppKitCoordinates() {
        XCTAssertEqual(WindowPosition.tile(.leftHalf, .top).frame(in: visible), CGRect(x: 0, y: 472, width: 756, height: 472))
        XCTAssertEqual(WindowPosition.tile(.rightThird, .bottom).frame(in: visible), CGRect(x: 1008, y: 0, width: 504, height: 472))
    }

    func testFillUsesTheWholeArea() {
        XCTAssertEqual(WindowPosition.fill.frame(in: visible), visible)
    }

    func testCenterIsCenteredAndSmaller() {
        let frame = WindowPosition.center.frame(in: visible)
        XCTAssertEqual(frame.size, CGSize(width: 1008, height: 708))
        XCTAssertEqual(frame.midX, visible.midX, accuracy: 1)
        XCTAssertEqual(frame.midY, visible.midY, accuracy: 1)
    }

    func testFlippingCoordinates() {
        let appKit = CGRect(x: 10, y: 100, width: 300, height: 200)
        let accessibility = ScreenCoordinates.flip(appKit, mainScreenHeight: 982)
        XCTAssertEqual(accessibility, CGRect(x: 10, y: 682, width: 300, height: 200))
        XCTAssertEqual(ScreenCoordinates.flip(accessibility, mainScreenHeight: 982), appKit)
    }
}
