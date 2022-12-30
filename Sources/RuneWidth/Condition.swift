//
//  File.swift
//  
//
//  Created by Kazuki Yamamoto on 2022/12/30.
//

import Foundation

public struct Condition {
    public static let `default`: Condition = makeDefaultCondition()
    var combinedLUT: [UInt8]
    public var eastAsianWidth: Bool {
        didSet {
            setupLUT()
        }
    }
    public var strictEmojiNeutral: Bool {
        didSet {
            setupLUT()
        }
    }

    public mutating func setupLUT() {
        let max = 0x110000
        let lut = combinedLUT.isEmpty ? [UInt8].init(repeating: 0, count: max / 2) : combinedLUT

        combinedLUT = lut.enumerated().map { (i, _) in
            let i = UInt32(i * 2)
            let x0 = runeWidth(i)
            let x1 = runeWidth(i + 1)
            return UInt8(x0) | UInt8(x1) << 4
        }
    }


    public func runeWidth(_ rune: UInt32) -> Int {
        guard rune >= 0 && rune <= 0x10FFFF else {
            return 0
        }

        guard combinedLUT.isEmpty else {
            return Int(combinedLUT[Int(rune) >> 1] >> (UInt(rune & 1) * 4)) & 3
        }

        if !eastAsianWidth {
            if rune < 0x20 || (rune >= 0x7f && rune <= 0x9f) || rune == 0xad {
                return 0
            } else if rune < 0x300 || inTable(rune: rune, table: Table.narrow) {
                return 1
            } else if inTables(rune: rune, tables: [Table.nonprint, Table.combing]) {
                return 0
            } else if inTable(rune: rune, table: Table.doubleWidth) {
                return 2
            } else {
                return 1
            }
        } else {
            if inTables(rune: rune, tables: [Table.nonprint, Table.combing]) {
                return 0
            } else if inTable(rune: rune, table: Table.narrow) {
                return 1
            } else if inTables(rune: rune, tables: [Table.ambiguous, Table.doubleWidth]) {
                return 2
            } else if !strictEmojiNeutral && inTables(rune: rune, tables: [Table.ambiguous, Table.emoji, Table.narrow]) {
                return 2
            } else {
                return 1
            }
        }
    }

    public func characterWidth(_ character: Character) -> Int {
        character.unicodeScalars
            .map { runeWidth($0.value) }
            .reduce(0, +)
    }

    public func stringWidth(_ string: String) -> Int {
        string.map { characterWidth($0) }
            .reduce(0, +)
    }

    public func truncate(string: String, width: Int, tail: String) -> String {
        guard stringWidth(string) > width else {
            return string
        }

        let width = width - stringWidth(tail)
        var partialWidth = 0
        var offset = string.count
        for (index, character) in string.enumerated() {
            let characterWidth = character.runeWidth.width()
            if characterWidth + partialWidth > width {
                offset = index
                break
            }
            partialWidth += characterWidth
        }
        return String(string.prefix(offset)) + tail
    }

    public func truncateLeft(string: String, width: Int, prefix: String) -> String {
        guard stringWidth(string) > width else {
            return prefix
        }

        var partialWidth = 0
        var offset = 0
        for (index, character) in string.enumerated() {
            let characterWidth = character.runeWidth.width()
            if partialWidth + characterWidth >= width {
                offset = index
                break
            }
            partialWidth += characterWidth
        }

        return prefix + string.dropFirst(offset + 1)
    }

    public func wrap(string: String, width: Int) -> String {
        var result = ""
        var partialWidth = 0

        for character in string {
            if character == "\n" {
                result += String(character)
                partialWidth = 0
                continue
            }
            let caracterWidth = character.runeWidth.width()
            if partialWidth + caracterWidth > width {
                result += "\n" + String(character)
                partialWidth = caracterWidth
            } else {
                result += String(character)
                partialWidth += caracterWidth
            }
        }

        return result
    }

    public func fillLeft(string: String, width: Int) -> String {
        let stringWidth = string.runeWidth.width()
        let count = width - stringWidth

        guard count > 0 else {
            return string
        }

        return String(repeating: " ", count: count) + string
    }
}

private func makeDefaultCondition() -> Condition {
    var condition = Condition(
        combinedLUT: [],
        eastAsianWidth: RuneWidth.eastAsianWidth,
        strictEmojiNeutral: false
    )
    condition.setupLUT()

    return condition
}
