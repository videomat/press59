import XCTest

final class HyperKeyLogicTests: XCTestCase {
    private let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")
    private var state = HyperKeyState()

    override func setUp() {
        super.setUp()
        state = HyperKeyState()
    }

    private func press(
        _ event: HyperKeyEvent,
        quickTapTogglesCapsLock: Bool = true
    ) -> HyperKeyAction {
        state.handle(event, quickTapTogglesCapsLock: quickTapTogglesCapsLock) { [chrome] key in
            key == "c" ? chrome : nil
        }
    }

    private static let hyperDown = HyperKeyEvent(isDown: true, isHyperKey: true)
    private static let hyperRepeat = HyperKeyEvent(isDown: true, isRepeat: true, isHyperKey: true)
    private static let hyperUp = HyperKeyEvent(isDown: false, isHyperKey: true)
    private static func down(_ character: String) -> HyperKeyEvent { HyperKeyEvent(isDown: true, character: character) }
    private static func up(_ character: String) -> HyperKeyEvent { HyperKeyEvent(isDown: false, character: character) }

    // MARK: - Cheat sheet

    func testHoldingHyperAloneShowsTheCheatSheet() {
        _ = press(Self.hyperDown)
        XCTAssertTrue(state.holdElapsed())
    }

    func testReleasingAfterTheCheatSheetIsNotATap() {
        _ = press(Self.hyperDown)
        _ = state.holdElapsed()
        XCTAssertEqual(press(Self.hyperUp), .swallow)
    }

    func testShortcutDuringTheCheatSheetStillWorks() {
        _ = press(Self.hyperDown)
        _ = state.holdElapsed()
        XCTAssertEqual(press(Self.down("c")), .openApp(chrome))
    }

    func testNoCheatSheetOnceAnotherKeyWasPressed() {
        _ = press(Self.hyperDown)
        _ = press(Self.down("c"))
        XCTAssertFalse(state.holdElapsed())
    }

    func testNoCheatSheetAfterRelease() {
        _ = press(Self.hyperDown)
        _ = press(Self.hyperUp)
        XCTAssertFalse(state.holdElapsed())
    }

    // MARK: - Quick tap

    func testQuickTapTogglesCapsLock() {
        XCTAssertEqual(press(Self.hyperDown), .swallow)
        XCTAssertEqual(press(Self.hyperUp), .toggleCapsLock)
    }

    func testHoldingWithAutoRepeatIsStillATap() {
        XCTAssertEqual(press(Self.hyperDown), .swallow)
        XCTAssertEqual(press(Self.hyperRepeat), .swallow)
        XCTAssertEqual(press(Self.hyperRepeat), .swallow)
        XCTAssertEqual(press(Self.hyperUp), .toggleCapsLock)
    }

    func testQuickTapDoesNothingWhenTurnedOff() {
        XCTAssertEqual(press(Self.hyperDown, quickTapTogglesCapsLock: false), .swallow)
        XCTAssertEqual(press(Self.hyperUp, quickTapTogglesCapsLock: false), .swallow)
    }

    func testUsingHyperIsNotATap() {
        _ = press(Self.hyperDown)
        _ = press(Self.down("j"))
        _ = press(Self.up("j"))
        XCTAssertEqual(press(Self.hyperUp), .swallow)
    }

    func testReleaseWithoutPressIsNotATap() {
        XCTAssertEqual(press(Self.hyperUp), .swallow)
    }

    // MARK: - Assigned keys

    func testAssignedKeyOpensTheApp() {
        _ = press(Self.hyperDown)
        XCTAssertEqual(press(Self.down("c")), .openApp(chrome))
        XCTAssertEqual(press(Self.up("c")), .swallow)
    }

    func testAssignedKeyRepeatDoesNotOpenAgain() {
        _ = press(Self.hyperDown)
        XCTAssertEqual(press(Self.down("c")), .openApp(chrome))
        XCTAssertEqual(press(HyperKeyEvent(isDown: true, isRepeat: true, character: "c")), .swallow)
    }

    func testCommaOpensSettings() {
        _ = press(Self.hyperDown)
        XCTAssertEqual(press(Self.down(",")), .openSettings)
        XCTAssertEqual(press(Self.up(",")), .swallow)
    }

    // MARK: - Unassigned keys and normal typing

    func testUnassignedKeyGetsHyperModifiers() {
        _ = press(Self.hyperDown)
        XCTAssertEqual(press(Self.down("j")), .addHyperModifiers)
        XCTAssertEqual(press(Self.up("j")), .addHyperModifiers)
    }

    func testKeyWithoutCharacterGetsHyperModifiers() {
        _ = press(Self.hyperDown)
        XCTAssertEqual(press(HyperKeyEvent(isDown: true, character: nil)), .addHyperModifiers)
    }

    func testTypingWithoutHyperPassesThrough() {
        XCTAssertEqual(press(Self.down("c")), .passThrough)
        XCTAssertEqual(press(Self.up("c")), .passThrough)
        XCTAssertEqual(press(Self.down(",")), .passThrough)
    }

    func testKeysPassThroughAgainAfterHyperIsReleased() {
        _ = press(Self.hyperDown)
        _ = press(Self.hyperUp)
        XCTAssertEqual(press(Self.down("c")), .passThrough)
    }

    func testOnlyPassingActionsReachOtherApps() {
        XCTAssertTrue(HyperKeyAction.passThrough.passesEvent)
        XCTAssertTrue(HyperKeyAction.addHyperModifiers.passesEvent)
        XCTAssertFalse(HyperKeyAction.swallow.passesEvent)
        XCTAssertFalse(HyperKeyAction.toggleCapsLock.passesEvent)
        XCTAssertFalse(HyperKeyAction.openSettings.passesEvent)
        XCTAssertFalse(HyperKeyAction.openApp(chrome).passesEvent)
    }
}
