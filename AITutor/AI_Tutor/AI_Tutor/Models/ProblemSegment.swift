// AI_Tutor/Models/ProblemSegment.swift
import Foundation

enum ProblemSegment {
    case body(String)
    case metaPost(code: String)
    case figureDesc(desc: String)
}

extension ProblemSegment {
    // Compiled once at first use
    private static let segmentRegex: NSRegularExpression = {
        let pattern = "(`{3}metapost[\\s\\S]*?`{3})|(【图形描述】[\\s\\S]*?【/图形描述】)"
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

    /// Split raw problem text into typed segments.
    /// MetaPost code fences and figure-description brackets become collapsible blocks;
    /// everything else is a `.body` segment for KaTeX rendering.
    static func parse(_ raw: String) -> [ProblemSegment] {
        guard !raw.isEmpty else { return [] }
        var result: [ProblemSegment] = []
        let ns = raw as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        var cursor = 0

        for match in segmentRegex.matches(in: raw, options: [], range: fullRange) {
            // Body text before this match
            if match.range.location > cursor {
                let before = ns.substring(with: NSRange(location: cursor,
                                                        length: match.range.location - cursor))
                               .trimmingCharacters(in: .whitespacesAndNewlines)
                if !before.isEmpty { result.append(.body(before)) }
            }

            var matched = ns.substring(with: match.range)
            if matched.hasPrefix("```metapost") {
                // Precisely strip the opening fence and closing fence
                if matched.hasPrefix("```metapost") { matched = String(matched.dropFirst("```metapost".count)) }
                if matched.hasSuffix("```")         { matched = String(matched.dropLast(3)) }
                let code = matched.trimmingCharacters(in: .whitespacesAndNewlines)
                result.append(.metaPost(code: code))
            } else {
                // Figure description
                if matched.hasPrefix("【图形描述】")  { matched = String(matched.dropFirst("【图形描述】".count)) }
                if matched.hasSuffix("【/图形描述】") { matched = String(matched.dropLast("【/图形描述】".count)) }
                let desc = matched.trimmingCharacters(in: .whitespacesAndNewlines)
                result.append(.figureDesc(desc: desc))
            }

            cursor = match.range.location + match.range.length
        }

        // Tail body text after last match
        if cursor < ns.length {
            let tail = ns.substring(from: cursor).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { result.append(.body(tail)) }
        }

        return result.isEmpty ? [.body(raw)] : result
    }
}
