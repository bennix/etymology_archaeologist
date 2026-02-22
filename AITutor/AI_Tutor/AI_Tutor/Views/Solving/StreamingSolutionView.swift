import SwiftUI

struct StreamingSolutionView: View {
    let problem: Problem
    let expert: ExpertType
    @Environment(AppState.self) private var appState

    var solution: ExpertSolution? {
        appState.solutions[problem.id]?.first { $0.expert == expert }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Problem header
                    HStack {
                        Text("【题目 \(problem.number)】")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let sol = solution {
                            statusBadge(sol)
                        }
                    }
                    .padding(.top, 4)

                    Divider()

                    if let sol = solution {
                        if sol.content.isEmpty && sol.isStreaming {
                            // Waiting state
                            HStack(spacing: 10) {
                                ProgressView().tint(.blue)
                                Text("\(modelLabel) 正在思考...")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                            .padding(.top, 8)
                        } else if !sol.content.isEmpty {
                            DynamicKaTeXView(content: sol.content)

                            if sol.isStreaming {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.7).tint(.blue)
                                    Text("正在生成...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .id("streamingIndicator")
                            }
                        }

                        if let errMsg = sol.errorMessage {
                            Label(errMsg, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                                .padding(.top, 4)
                        }
                    }

                    Color.clear.frame(height: 20).id("bottom")
                }
                .padding()
            }
            .onChange(of: solution?.content) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private var modelLabel: String {
        switch expert {
        case .a, .b: return "Gemini 3 Pro"
        case .c:     return "Claude Sonnet 4.5"
        }
    }

    @ViewBuilder
    private func statusBadge(_ sol: ExpertSolution) -> some View {
        if sol.isComplete {
            Label("完成", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        } else if sol.isStreaming {
            Label("生成中", systemImage: "circle.dotted")
                .foregroundStyle(.blue)
                .font(.caption)
        }
    }
}
