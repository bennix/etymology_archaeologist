// AI_Tutor/Models/Problem.swift
import Foundation
import Observation

@Observable
class Problem: Identifiable {
    let id = UUID()
    var number: Int
    var fullLatexText: String
    var knownDataMarkdown: String
    var isSelected: Bool = true

    init(number: Int, fullLatexText: String, knownDataMarkdown: String) {
        self.number = number
        self.fullLatexText = fullLatexText
        self.knownDataMarkdown = knownDataMarkdown
    }
}
