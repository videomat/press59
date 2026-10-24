import XCTest

final class KeySuggestionsTests: XCTestCase {
    func testFirstFreeLetterOfTheName() {
        XCTAssertEqual(KeySuggestions.key(for: "Slack", taken: []), "s")
        XCTAssertEqual(KeySuggestions.key(for: "Slack", taken: ["s"]), "l")
    }

    func testVendorNameIsSkipped() {
        XCTAssertEqual(KeySuggestions.key(for: "Google Chrome", taken: []), "c")
        XCTAssertEqual(KeySuggestions.key(for: "Microsoft Word", taken: []), "w")
        XCTAssertEqual(KeySuggestions.key(for: "Google", taken: []), "g")
    }

    func testNoKeyWhenEveryLetterIsTaken() {
        XCTAssertNil(KeySuggestions.key(for: "Mail", taken: ["m", "a", "i", "l"]))
    }

    func testOnlyLettersAndDigits() {
        XCTAssertEqual(KeySuggestions.key(for: "1Password 8", taken: []), "1")
        XCTAssertEqual(KeySuggestions.key(for: ".Net-App", taken: ["n"]), "e")
    }

    func testEarlierAppsGetFirstPick() {
        let keys = KeySuggestions.keys(for: ["Safari", "Slack", "Spotify", "Signal"], taken: ["f"])
        XCTAssertEqual(keys, ["s", "l", "p", "i"])
    }
}
