import XCTest

final class KeyMappingsTests: XCTestCase {
    /// Right Option → Right Command, as another tool might set it.
    private let otherMapping = KeyMapping(source: 0x7_0000_00E6, destination: 0x7_0000_00E7)

    // MARK: - Reading hidutil output

    func testParsesHidutilOutput() {
        let output = """
        (
                {
                HIDKeyboardModifierMappingDst = 30064771181;
                HIDKeyboardModifierMappingSrc = 30064771129;
            },
                {
                HIDKeyboardModifierMappingDst = 30064771303;
                HIDKeyboardModifierMappingSrc = 30064771302;
            }
        )

        """
        XCTAssertEqual(KeyMappings.parse(output), [KeyMappings.capsLockToF18, otherMapping])
    }

    func testParsesNoMappings() {
        XCTAssertEqual(KeyMappings.parse("(null)\n"), [])
        XCTAssertEqual(KeyMappings.parse(""), [])
        XCTAssertEqual(KeyMappings.parse("(\n)\n"), [])
    }

    func testRejectsUnreadableOutput() {
        XCTAssertNil(KeyMappings.parse("not a property list {"))
        XCTAssertNil(KeyMappings.parse("({ HIDKeyboardModifierMappingSrc = 1; })"))
    }

    // MARK: - Adding and removing

    func testAddingKeepsOtherMappings() {
        XCTAssertEqual(KeyMappings.adding(to: [otherMapping]), [otherMapping, KeyMappings.capsLockToF18])
    }

    func testAddingReplacesAnotherCapsLockMapping() {
        let capsLockToEscape = KeyMapping(source: KeyMappings.capsLock, destination: 0x7_0000_0029)
        XCTAssertEqual(KeyMappings.adding(to: [capsLockToEscape, otherMapping]), [otherMapping, KeyMappings.capsLockToF18])
    }

    func testAddingTwiceDoesNotDuplicate() {
        let once = KeyMappings.adding(to: [otherMapping])
        XCTAssertEqual(KeyMappings.adding(to: once), once)
    }

    func testRemovingKeepsOtherMappings() {
        XCTAssertEqual(KeyMappings.removing(from: [otherMapping, KeyMappings.capsLockToF18]), [otherMapping])
    }

    func testRemovingWithNothingToRemove() {
        XCTAssertEqual(KeyMappings.removing(from: [otherMapping]), [otherMapping])
        XCTAssertEqual(KeyMappings.removing(from: []), [])
    }

    // MARK: - Writing hidutil input

    func testJSONForHidutil() throws {
        let json = KeyMappings.json([otherMapping, KeyMappings.capsLockToF18])
        let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: [[String: UInt64]]]
        XCTAssertEqual(decoded?["UserKeyMapping"], [
            ["HIDKeyboardModifierMappingSrc": 30064771302, "HIDKeyboardModifierMappingDst": 30064771303],
            ["HIDKeyboardModifierMappingSrc": 30064771129, "HIDKeyboardModifierMappingDst": 30064771181],
        ])
    }

    func testJSONForNoMappings() {
        XCTAssertEqual(KeyMappings.json([]), #"{"UserKeyMapping":[]}"#)
    }
}
