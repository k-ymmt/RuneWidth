import XCTest
@testable import RuneWidth

final class RuneWidthTests: XCTestCase {
    func testStringWidth() {
        let tests: [(text: String, expected: Int, eaExpected: Int)] = [
            ("■㈱の世界①", 10, 12),
            ("スター☆", 7, 8),
            ("つのだ☆HIRO", 11, 12),
        ]

        let condition1 = Condition(combinedLUT: [], eastAsianWidth: false, strictEmojiNeutral: false)

        for test in tests {
            let width = condition1.stringWidth(test.text)
            XCTAssertEqual(width, test.expected)
        }

        let s = "こんにちわ\u{00}世界"
        XCTAssertEqual(condition1.stringWidth(s), 14)

        let condition2 = Condition(combinedLUT: [], eastAsianWidth: true, strictEmojiNeutral: false)
        for test in tests {
            let width = condition2.stringWidth(test.text)
            XCTAssertEqual(width, test.eaExpected)
        }
    }

    func testTruncateSmaller() {
        let s = "あいうえお"
        let expected = s

        XCTAssertEqual(s.runeWidth.truncate(width: 10, tail: "..."), expected)
        XCTAssertEqual(s.runeWidth.truncate(width: 15, tail: "..."), expected)
    }

    func testTruncate() {
        let width = 30 + "...".runeWidth.width()
        let s = "あいうえおかきくけこさしすせそたちつてと"
        let expected = "あいうえおかきくけこさしすせそ..."
        let actual = s.runeWidth.truncate(width: width, tail: "...")
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(actual.runeWidth.width(), width)
    }

    func testTruncateLeft() {
        let tests: [(text: String, width: Int, prefix: String, expected: String)] = [
            ("source", 4, "", "ce"),
            ("source", 4, "...", "...ce"),
            ("あいうえお", 6, "", "えお"),
            ("あいうえお", 6, "...", "...えお"),
            ("あいうえお", 10, "", ""),
            ("あいうえお", 10, "...", "..."),
            ("あいうえお", 5, "", "えお"),
            ("Aあいうえお", 5, "", "うえお"),
        ]

        for test in tests {
            XCTAssertEqual(
                test.text.runeWidth.truncateLeft(width: test.width, prefix: test.prefix),
                test.expected
            )
        }
    }

    func testWrap() {
        let test = """
            東京特許許可局局長はよく柿喰う客だ/東京特許許可局局長はよく柿喰う客だ
            123456789012345678901234567890
            END
            """
        let expected = """
            東京特許許可局局長はよく柿喰う
            客だ/東京特許許可局局長はよく
            柿喰う客だ
            123456789012345678901234567890
            END
            """

        XCTAssertEqual(test.runeWidth.wrap(width: 30), expected)
    }

    func testFillLeft() {
        let tests: [(string: String, width: Int, expected: String)] = [
            ("あxいうえお", 15, "    あxいうえお"),
            ("あいうえお", 10, "あいうえお")
        ]

        for test in tests {
            XCTAssertEqual(
                test.string.runeWidth.fillLeft(width: test.width),
                test.expected
            )
        }
    }
}
