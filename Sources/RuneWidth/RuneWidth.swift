import Foundation

func inTables(rune: UInt32, tables: [[Interval]]) -> Bool {
    tables.contains { inTable(rune: rune, table: $0) }
}

func inTable(rune: UInt32, table: [Interval]) -> Bool {
    guard table[0].first < rune else {
        return false
    }

    var bot = 0
    var top = table.count - 1

    while top >= bot {
        let mid = (bot + top) >> 1

        if table[mid].last < rune {
            bot = mid + 1
        } else if table[mid].first > rune {
            top = mid - 1
        } else {
            return true
        }
    }

    return false
}

private let mblenTable: [String: Int] = [
    "utf-8": 6,
    "utf8": 6,
    "jis": 8,
    "eucjp": 3,
    "euckr": 2,
    "euccn": 2,
    "sjis": 2,
    "cp932": 2,
    "cp51932": 2,
    "cp936": 2,
    "cp949": 2,
    "cp950": 2,
    "big5": 2,
    "gbk": 2,
    "gb2312": 2,
]


func isEastAsianWidth() -> Bool {
    let env = ProcessInfo.processInfo.environment
    let runeWidthEastAsian = env["RUNEWIDTH_EASTASIAN"]
    if let runeWidthEastAsian {
        return runeWidthEastAsian == "1"
    }
    guard let locale = env["LC_ALL"] ?? env["LC_CTYPE"] ?? env["LANG"] else {
        return false
    }
    if locale == "POSIX" || locale == "C" {
        return false
    }
    if locale.count > 1 {
        let startIndex = locale.startIndex
        let nextIndex = locale.index(locale.startIndex, offsetBy: 1)
        if locale[startIndex] == "C", (locale[nextIndex] == "." || locale[nextIndex] == "-") {
            return false
        }
    }

    var charset = locale.lowercased()
    let pattern = try! NSRegularExpression(pattern: "^[a-z][a-z][a-z]?(?:_[A-Z][A-Z])?\\.(.+)")
    let matches = pattern.matches(in: locale, range: NSRange(location: 0, length: locale.count))
    if let match = matches.first, match.numberOfRanges == 2 {
        let range = match.range(at: 1)
        let startIndex = locale.startIndex
        charset = String(locale[locale.index(startIndex, offsetBy: range.location)...locale.index(startIndex, offsetBy: range.location + range.length - 1)]).lowercased()
    }

    guard !charset.hasSuffix("@cjk_narrow") else {
        return false
    }

    if let firstIndex = charset.firstIndex(of: "@") {
        charset = String(charset[..<firstIndex])
    }

    let max: Int
    if let value = mblenTable[charset] {
        max = value
    } else {
        max = 1
    }

    return max > 1 && (
        charset.first != "u"
        || locale.hasPrefix("ja")
        || locale.hasPrefix("ko")
        || locale.hasPrefix("zh")
    )
}

public enum RuneWidth {
    public static let eastAsianWidth: Bool = isEastAsianWidth()
}

public extension UInt32 {
    struct RuneWidth {
        public let rawValue: UInt32

        public func width() -> Int {
            Condition.default.runeWidth(rawValue)
        }
    }

    var runeWidth: RuneWidth {
        RuneWidth(rawValue: self)
    }
}

public extension Character {
    struct RuneWidth {
        public let rawValue: Character

        public func width() -> Int {
            Condition.default.characterWidth(rawValue)
        }
    }

    var runeWidth: RuneWidth {
        RuneWidth(rawValue: self)
    }
}

public extension String {
    struct RuneWidth {
        public let rawValue: String

        public func width() -> Int {
            Condition.default.stringWidth(rawValue)
        }

        public func truncate(width: Int, tail: String) -> String {
            Condition.default.truncate(string: rawValue, width: width, tail: tail)
        }

        public func truncateLeft(width: Int, prefix: String) -> String {
            Condition.default.truncateLeft(string: rawValue, width: width, prefix: prefix)
        }

        public func wrap(width: Int) -> String {
            Condition.default.wrap(string: rawValue, width: width)
        }

        public func fillLeft(width: Int) -> String {
            Condition.default.fillLeft(string: rawValue, width: width)
        }
    }

    var runeWidth: RuneWidth {
        RuneWidth(rawValue: self)
    }
}
