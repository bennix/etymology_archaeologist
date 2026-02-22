import Foundation

struct ProblemParser {
    /// Parse GPT response (JSON array possibly wrapped in markdown code fences) into Problem array
    static func parse(from response: String) -> [Problem] {
        // Strip markdown code fences if present
        var cleaned = response
        if let start = response.range(of: "["),
           let end = response.range(of: "]", options: .backwards) {
            cleaned = String(response[start.lowerBound...end.upperBound])
        }

        guard let data = cleaned.data(using: .utf8),
              let rawList = try? JSONDecoder().decode([RawProblem].self, from: data),
              !rawList.isEmpty else {
            // Fallback: treat entire response as single problem
            return [Problem(number: 1, fullLatexText: response, knownDataMarkdown: "")]
        }

        return rawList.map {
            Problem(number: $0.number, fullLatexText: $0.fullLatexText, knownDataMarkdown: $0.knownDataMarkdown)
        }
    }

    private struct RawProblem: Decodable {
        let number: Int
        let fullLatexText: String
        let knownDataMarkdown: String
    }
}
