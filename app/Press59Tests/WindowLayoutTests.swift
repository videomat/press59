import XCTest

final class WindowLayoutTests: XCTestCase {
    /// A 1512 × 945 screen's usable area below a 37 pt menu bar, in AppKit coordinates.
    private let visible = CGRect(x: 0, y: 0, width: 1512, height: 945)

    func testArrowKeys() {
        XCTAssertEqual(WindowPosition(keyCode: 123), .leftHalf)
        XCTAssertEqual(WindowPosition(keyCode: 124), .rightHalf)
        XCTAssertEqual(WindowPosition(keyCode: 126), .fill)
        XCTAssertEqual(WindowPosition(keyCode: 125), .center)
        XCTAssertNil(WindowPosition(keyCode: 0))
    }

    func testHalvesMeetWithoutGapOrOverlap() {
        let odd = CGRect(x: 100, y: 50, width: 1511, height: 900)
        let left = WindowPosition.leftHalf.frame(in: odd)
        let right = WindowPosition.rightHalf.frame(in: odd)
        XCTAssertEqual(left, CGRect(x: 100, y: 50, width: 755, height: 900))
        XCTAssertEqual(right, CGRect(x: 855, y: 50, width: 756, height: 900))
        XCTAssertEqual(left.maxX, right.minX)
        XCTAssertEqual(right.maxX, odd.maxX)
    }

    func testThirdsSitAtTheEdges() {
        XCTAssertEqual(WindowPosition.leftThird.frame(in: visible), CGRect(x: 0, y: 0, width: 504, height: 945))
        XCTAssertEqual(WindowPosition.rightThird.frame(in: visible), CGRect(x: 1008, y: 0, width: 504, height: 945))
    }

    func testPressingAgainGoesFromHalfToThirdAndBack() {
        XCTAssertEqual(WindowPosition.leftHalf.repeated(after: nil), .leftHalf)
        XCTAssertEqual(WindowPosition.leftHalf.repeated(after: .leftHalf), .leftThird)
        XCTAssertEqual(WindowPosition.leftHalf.repeated(after: .leftThird), .leftHalf)
        XCTAssertEqual(WindowPosition.rightHalf.repeated(after: .rightHalf), .rightThird)
        XCTAssertEqual(WindowPosition.rightHalf.repeated(after: .leftHalf), .rightHalf)
        XCTAssertEqual(WindowPosition.fill.repeated(after: .fill), .fill)
    }

    func testFillUsesTheWholeArea() {
        XCTAssertEqual(WindowPosition.fill.frame(in: visible), visible)
    }

    func testCenterIsCenteredAndSmaller() {
        let frame = WindowPosition.center.frame(in: visible)
        XCTAssertEqual(frame.size, CGSize(width: 1008, height: 709))
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
