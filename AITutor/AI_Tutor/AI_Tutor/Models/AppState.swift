// AI_Tutor/Models/AppState.swift
import Foundation
import Observation
import UIKit

@Observable
class AppState {
    var settings = AppSettings()
    var capturedImages: [UIImage] = []
    var problems: [Problem] = []
    var solutions: [UUID: [ExpertSolution]] = [:]
    var reportMessages: [ChatMessage] = []
    var isExtracting = false
    var extractionError: String? = nil

    func reset() {
        problems = []
        solutions = [:]
        reportMessages = []
        isExtracting = false
        extractionError = nil
    }

    func solution(for problem: Problem, expert: ExpertType) -> ExpertSolution? {
        solutions[problem.id]?.first { $0.expert == expert }
    }

    func fullReport() -> String {
        var md = "# AI 数学/物理解题报告\n\n"
        for problem in problems where problem.isSelected {
            md += "---\n## 【题目 \(problem.number)】\n\n"
            md += problem.fullLatexText + "\n\n"
            if let a = solution(for: problem, expert: .a), !a.content.isEmpty {
                md += "### 解法一\n" + a.content + "\n\n"
            }
            if let b = solution(for: problem, expert: .b), !b.content.isEmpty {
                md += "### 解法二\n" + b.content + "\n\n"
            }
            if let c = solution(for: problem, expert: .c), !c.content.isEmpty {
                md += "### 专家总评\n" + c.content + "\n\n"
            }
        }
        return md
    }
}
