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
                            // Waiting for first token
                            HStack(spacing: 8) {
                                Circle().frame(width: 7, height: 7).foregroundStyle(.blue)
                                    .opacity(0.8)
                                Text("\(modelLabel) 正在思考...")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                            .padding(.top, 8)
                        } else if !sol.content.isEmpty {
                            if sol.isStreaming {
                                // Plain text while streaming — renders every chunk instantly
                                Text(sol.content)
                                    .font(.system(.body, design: .default))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)

                                // Blinking cursor
                                Text("▌")
                                    .foregroundStyle(.blue)
                                    .font(.body)
                                    .id("cursor")
                            } else {
                                // Fully streamed — render LaTeX/Markdown
                                DynamicKaTeXView(content: sol.content)
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
            Text(sol.content.isEmpty ? "等待中" : "生成中")
                .font(.caption)
                .foregroundStyle(.blue)
        }
    }
}
