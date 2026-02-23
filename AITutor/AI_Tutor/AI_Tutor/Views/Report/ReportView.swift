import SwiftUI

struct ReportView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("⭐ 专家总评").tag(0)
                Text("📐 解法详情").tag(1)
                Text("💬 追问 AI").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            switch selectedTab {
            case 0: ExpertCSummaryTab()
            case 1: SolutionsDetailTab()
            default: ChatFollowUpView()
            }
        }
        .navigationTitle("解题报告")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: appState.fullReport(),
                    preview: SharePreview("AI 解题报告")
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

// MARK: - Tab 0: Expert C synthesis (rendered KaTeX)
struct ExpertCSummaryTab: View {
    @Environment(AppState.self) private var appState

    var selectedProblems: [Problem] { appState.problems.filter(\.isSelected) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(selectedProblems) { problem in
                    if let sol = appState.solution(for: problem, expert: .c), !sol.content.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                                Text("题目 \(problem.number) · 专家总评")
                                    .font(.subheadline.bold())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.08))

                            DynamicKaTeXView(content: sol.content)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Tab 1: Expert A/B solutions (switchable)
struct SolutionsDetailTab: View {
    @Environment(AppState.self) private var appState
    @State private var selectedExpert: ExpertType = .a
    @State private var currentProblemIndex = 0

    var selectedProblems: [Problem] { appState.problems.filter(\.isSelected) }
    var currentProblem: Problem? { selectedProblems[safe: currentProblemIndex] }

    var body: some View {
        VStack(spacing: 0) {
            // Problem picker (if multiple)
            if selectedProblems.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedProblems.enumerated()), id: \.offset) { idx, p in
                            Button("题目 \(p.number)") { currentProblemIndex = idx }
                                .font(.subheadline)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(currentProblemIndex == idx ? Color.blue : Color.blue.opacity(0.1))
                                .foregroundStyle(currentProblemIndex == idx ? .white : .blue)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }

            // Expert A / B picker
            Picker("", selection: $selectedExpert) {
                Text("解法一 (Gemini)").tag(ExpertType.a)
                Text("解法二 (Gemini)").tag(ExpertType.b)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            Divider()

            // Content
            if let problem = currentProblem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let sol = appState.solution(for: problem, expert: selectedExpert) {
                            if sol.content.isEmpty {
                                Text("暂无内容")
                                    .foregroundStyle(.secondary)
                                    .padding()
                            } else {
                                DynamicKaTeXView(content: sol.content)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
    }
}
