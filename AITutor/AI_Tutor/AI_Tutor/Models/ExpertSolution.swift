// AI_Tutor/Models/ExpertSolution.swift
import Foundation
import Observation

enum ExpertType: Equatable, Hashable {
    case a, b, c

    var displayName: String {
        switch self {
        case .a: return "解法一"
        case .b: return "解法二"
        case .c: return "专家总评"
        }
    }

    var modelName: String {
        switch self {
        case .a, .b: return "google/gemini-3-pro-preview"
        case .c:     return "anthropic/claude-sonnet-4.5"
        }
    }
}

@Observable
class ExpertSolution: Identifiable {
    let id = UUID()
    var expert: ExpertType
    var content: String = ""
    var isStreaming: Bool = false
    var isComplete: Bool = false
    var errorMessage: String? = nil

    init(expert: ExpertType) {
        self.expert = expert
    }
}
