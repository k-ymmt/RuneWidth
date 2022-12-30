import Foundation
import Stencil
import PathKit

@main
public struct Generator {
    struct Variable {
        let name: String
        let value: [(first: UInt32, last: UInt32)]
    }

    static let variables: [Variable] = [
        .init(name: "`private`", value: [
            (0x00e00, 0x00f8ff),
            (0x0f0000, 0x0ffffd),
            (0x100000, 0x10fffd),
        ]),
        .init(name: "nonprint", value: [
            (0x0000, 0x001f),
            (0x007f, 0x009f),
            (0x00ad, 0x00ad),
            (0x070f, 0x070f),
            (0x180b, 0x180e),
            (0x200b, 0x200f),
            (0x2028, 0x202e),
            (0x206a, 0x206f),
            (0xd800, 0xdfff),
            (0xfeff, 0xfeff),
            (0xfff9, 0xfffb),
            (0xfffe, 0xffff),
        ])
    ]

    static let unicodeVersion = "15.0.0"

    public static func main() async throws {
        let currentDir = Path.current
        let templateDir = currentDir + "templates"
        let outputDir = currentDir + "../Sources/RuneWidth"

        guard templateDir.exists else {
            fatalError("\(templateDir) dir is not exists")
        }
        guard outputDir.exists else {
            fatalError("\(outputDir) dir is not exists")
        }

        let eastasian = try await eastasian()
        let emoji = try await emoji()
        let context: [String: Any] = [
            "variables": variables + eastasian + [emoji]
        ]

        var ext: Extension {
            let ext = Extension()
            ext.registerFilter("trimmingNewline") { value in
                guard let value = value as? String else {
                    return value
                }

                var string = String.SubSequence(stringLiteral: value)
                string = string.hasPrefix("\n") ? string.dropFirst() : string
                string = string.hasSuffix("\n") ? string.dropLast() : string
                return String(string)
            }
            ext.registerFilter("hexValue") { value in
                guard let value = value as? UInt32 else {
                    return value
                }

                return String(format: "0x%04x", value)
            }
            return ext
        }

        let environmnet = Environment(
            loader: FileSystemLoader(paths: [templateDir]),
            extensions: [ext]
        )

        let name = "Table"
        let rendered = try environmnet.renderTemplate(name: "\(name).stencil", context: context)
        let output = outputDir + "\(name).swift"
        try output.write(rendered.replacingOccurrences(of: ",\n\n", with: ",\n"))
    }
}
struct RuneRange {
    var low: UInt32
    var high: UInt32
}

private func shapeup(array: [RuneRange]) -> [RuneRange] {
    var array = array
    var index = 0
    while index < array.count - 1 {
        if array[index].high + 1 == array[index + 1].low {
            let low = array[index].low
            array.remove(at: index)
            array[index].low = low
            index -= 1
        }
        index += 1
    }

    return array
}

func eastasian() async throws -> [Generator.Variable] {
    let eastAsianWidth = try await get(url: "https://unicode.org/Public/\(Generator.unicodeVersion)/ucd/EastAsianWidth.txt")
    var combing: [RuneRange] = []
    var doubleWidth: [RuneRange] = []
    var ambiguous: [RuneRange] = []
    var narrow: [RuneRange] = []
    var neutral: [RuneRange] = []
    for line in eastAsianWidth.split(separator: "\n") {
        guard !line.hasPrefix("#") else {
            continue
        }

        let range = line.components(separatedBy: "..")
        let ranged = range.count > 1
        let index = ranged ? 1 : 0
        let separeted = range[index].split(separator: ";")
        guard separeted.count > 1 else {
            continue
        }
        let low = ranged ? range[0] : String(separeted[0])
        let high = ranged ? String(separeted[0]) : low
        let propertyAndComment = separeted[1].split(separator: " ")
        let property = String(propertyAndComment[0])

        let runeRange = RuneRange(low: low, high: high)
        if line.contains("COMBINING") {
            combing.append(runeRange)
        }

        switch property {
        case "W", "F":
            doubleWidth.append(runeRange)
        case "A":
            ambiguous.append(runeRange)
        case "Na":
            narrow.append(runeRange)
        case "N":
            neutral.append(runeRange)
        default:
            break
        }
    }

    return [
        .init(name: "combing", value: shapeup(array: combing)),
        .init(name: "doubleWidth", value: shapeup(array: doubleWidth)),
        .init(name: "ambiguous", value: shapeup(array: ambiguous)),
        .init(name: "narrow", value: shapeup(array: narrow)),
        .init(name: "neutral", value: shapeup(array: neutral))
    ]
}

func emoji() async throws -> Generator.Variable {
    let emoji = try await get(url: "https://unicode.org/Public/\(Generator.unicodeVersion)/ucd/emoji/emoji-data.txt")

    let lines = emoji.split(separator: "\n")
    let ranges = lines[lines.firstIndex(of: lines.first { $0.contains("Extended_Pictographic=No") }!)!...]
        .filter { !$0.hasPrefix("#") }
        .map(String.init)
        .compactMap { line -> RuneRange? in
            let valueAndComment = line.split(separator: " ")
            guard valueAndComment.count > 1 else {
                return nil
            }
            let separated = String(valueAndComment[0]).components(separatedBy: "..")
            let ranged = separated.count > 1
            let low = separated[0]
            let high = ranged ? separated[1] : low

            guard let h = UInt32(high, radix: 16), h >= 0xff else {
                return nil
            }

            return RuneRange(low: low, high: high)
        }

    return .init(name: "emoji", value: shapeup(array: ranges))
}

func get(url: String) async throws -> String {
    struct InvalidStatusCodeError: LocalizedError {
        let code: Int
        var errorDescription: String? {
            "invalid status code(\(code))"
        }
    }
    let (data, response) = try await URLSession.shared.data(for: .init(url: URL(string: url)!)) as! (Data, HTTPURLResponse)

    guard response.statusCode == 200 else {
        throw InvalidStatusCodeError(code: response.statusCode)
    }

    return String(data: data, encoding: .utf8)!
}

func +(lhs: Unicode.Scalar, rhs: UInt32) -> Unicode.Scalar {
    return Unicode.Scalar(lhs.value + rhs)!
}

private extension RuneRange {
    init(low: String, high: String) {
        self.init(low: UInt32(low, radix: 16)!, high: UInt32(high, radix: 16)!)
    }
}

private extension Generator.Variable {
    init(name: String, value: [RuneRange]) {
        self.init(name: name, value: value.map { ($0.low, $0.high) })
    }
}
