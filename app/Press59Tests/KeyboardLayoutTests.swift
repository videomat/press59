import XCTest

final class KeyboardLayoutTests: XCTestCase {
    /// What each key in `KeyboardLayout.letterRowKeyCodes` types, row by row.
    private func layout(_ rows: [String]) -> (UInt16) -> String? {
        var typed: [UInt16: String] = [:]
        for (keyCodes, characters) in zip(KeyboardLayout.letterRowKeyCodes, rows) {
            for (keyCode, character) in zip(keyCodes, characters) {
                typed[keyCode] = String(character)
            }
        }
        return { typed[$0] }
    }

    func testQwerty() {
        let rows = KeyboardLayout.letterRows(typedBy: layout(["qwertyuiop[]", "asdfghjkl;'", "zxcvbnm,./"]))
        XCTAssertEqual(rows, ["qwertyuiop", "asdfghjkl", "zxcvbnm"])
    }

    func testColemak() {
        let rows = KeyboardLayout.letterRows(typedBy: layout(["qwfpgjluy;[]", "arstdhneio'", "zxcvbkm,./"]))
        XCTAssertEqual(rows, ["qwfpgjluy", "arstdhneio", "zxcvbkm"])
    }

    func testAzertyKeepsMOnTheMiddleRow() {
        let rows = KeyboardLayout.letterRows(typedBy: layout(["azertyuiop^$", "qsdfghjklmù", "wxcvbn,;:="]))
        XCTAssertEqual(rows, ["azertyuiop", "qsdfghjklm", "wxcvbn"])
    }

    func testDvorak() {
        let rows = KeyboardLayout.letterRows(typedBy: layout(["',.pyfgcrl/=", "aoeuidhtns-", ";qjkxbmwvz"]))
        XCTAssertEqual(rows, ["pyfgcrl", "aoeuidhtns", "qjkxbmwvz"])
    }

    func testNonLatinLayoutHasNoLetterRows() {
        let rows = KeyboardLayout.letterRows(typedBy: layout(["йцукенгшщзхъ", "фывапролджэ", "ячсмитьбю."]))
        XCTAssertEqual(rows.joined(), "")
    }

    func testALetterOnlyShowsOnce() {
        let rows = KeyboardLayout.letterRows(typedBy: { _ in "a" })
        XCTAssertEqual(rows, ["a", "", ""])
    }
}
