import SwiftUI

struct ExpertCView: View {
    @Environment(AppState.self) private var appState
    @State private var currentProblemIndex = 0
    @State private var navigateToReport = false

    var selectedProblems: [Problem] {
        appState.problems.filter(\.isSelected)
    }

    var currentProblem: Problem? {
        selectedProblems[safe: currentProblemIndex]
    }

    var allCComplete: Bool {
        selectedProblems.allSatisfy { problem in
            appState.solutions[problem.id]?
                .first(where: { $0.expert == .c })?
                .isComplete ?? false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Problem tab bar for multiple problems
            if selectedProblems.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedProblems.enumerated()), id: \.offset) { idx, problem in
                            Button("题目 \(problem.number)") {
                                currentProblemIndex = idx
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                currentProblemIndex == idx
                                ? Color.purple
                                : Color.purple.opacity(0.1)
                            )
                            .foregroundStyle(currentProblemIndex == idx ? .white : .purple)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }

            // Expert C streaming content
            if let problem = currentProblem {
                expertCContent(for: problem)
            }
        }
        .navigationTitle("专家总评")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToReport) {
            ReportView()
        }
        .onChange(of: allCComplete) { _, complete in
            if complete && !navigateToReport {
                buildInitialReport()
                navigateToReport = true
            }
        }
    }

    @ViewBuilder
    private func expertCContent(for problem: Problem) -> some View {
        if let solution = appState.solutions[problem.id]?.first(where: { $0.expert == .c }) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header banner
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("专家总评 · 题目 \(problem.number)")
                                    .font(.headline)
                                Text("Claude Sonnet 4.5")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if solution.isComplete {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text(solution.content.isEmpty ? "等待中" : "生成中")
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                            }
                        }
                        .padding(14)
                        .background(Color.purple.opacity(0.08))

                        Divider()

                        // Content — plain text while streaming, KaTeX after complete
                        if solution.content.isEmpty && solution.isStreaming {
                            HStack(spacing: 8) {
                                Circle().frame(width: 7, height: 7)
                                    .foregroundStyle(.purple).opacity(0.8)
                                Text("Claude Sonnet 4.5 正在综合评估两种解法...")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 40)
                            .padding(.horizontal, 16)
                        } else if !solution.content.isEmpty {
                            if solution.isStreaming {
                                Text(solution.content)
                                    .font(.system(.body, design: .default))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)

                                Text("▌")
                                    .foregroundStyle(.purple)
                                    .font(.body)
                                    .padding(.leading, 12)
                                    .id("cursor")
                            } else {
                                DynamicKaTeXView(content: solution.content)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                        }

                        Color.clear.frame(height: 16).id("cEnd")
                    }
                }
                .onChange(of: solution.content) { _, _ in
                    withAnimation { proxy.scrollTo("cEnd", anchor: .bottom) }
                }
            }
        }
    }

    private func buildInitialReport() {
        let reportContent = appState.fullReport()
        appState.reportMessages = [ChatMessage(role: .assistant, content: reportContent)]
    }
}
