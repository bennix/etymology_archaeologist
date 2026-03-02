// AI_Tutor/Models/ProblemSegment.swift
import Foundation

enum ProblemSegment {
    case body(String)
    case metaPost(code: String)
    case figureDesc(desc: String)
}

func parseSegments(_ raw: String) -> [ProblemSegment] {
    var result: [ProblemSegment] = []
    // Matches either ```metapost...``` or 【图形描述】...【/图形描述】
    let pattern = "(`{3}metapost[\\s\\S]*?`{3})|(【图形描述】[\\s\\S]*?【/图形描述】)"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
        return [.body(raw)]
    }
    let ns = raw as NSString
    let fullRange = NSRange(location: 0, length: ns.length)
    var cursor = 0

    for match in regex.matches(in: raw, options: [], range: fullRange) {
        // body before this match
        if match.range.location > cursor {
            let before = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                           .trimmingCharacters(in: .whitespacesAndNewlines)
            if !before.isEmpty { result.append(.body(before)) }
        }
        let matched = ns.substring(with: match.range)
        if matched.hasPrefix("```metapost") {
            let code = matched
                .replacingOccurrences(of: "```metapost", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(.metaPost(code: code))
        } else {
            let desc = matched
                .replacingOccurrences(of: "【图形描述】", with: "")
                .replacingOccurrences(of: "【/图形描述】", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(.figureDesc(desc: desc))
        }
        cursor = match.range.location + match.range.length
    }
    // tail
    if cursor < ns.length {
        let tail = ns.substring(from: cursor).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(.body(tail)) }
    }
    return result.isEmpty ? [.body(raw)] : result
}
