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

// MARK: - Tab 0: Expert C summary — tappable cards → full-screen detail
struct ExpertCSummaryTab: View {
    @Environment(AppState.self) private var appState

    var selectedProblems: [Problem] { appState.problems.filter(\.isSelected) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(selectedProblems) { problem in
                    if let sol = appState.solution(for: problem, expert: .c), !sol.content.isEmpty {
                        NavigationLink(destination: ExpertCDetailView(problem: problem, content: sol.content)) {
                            HStack(spacing: 12) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("题目 \(problem.number) · 专家总评")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(sol.content.prefix(60).replacingOccurrences(of: "\n", with: " ") + "…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                            }
                            .padding(14)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Full-screen Expert C detail (KaTeX rendered)
struct ExpertCDetailView: View {
    let problem: Problem
    let content: String

    var body: some View {
        FullPageKaTeXView(content: content)
            .navigationTitle("题目 \(problem.number) · 专家总评")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom)
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
                if let sol = appState.solution(for: problem, expert: selectedExpert),
                   !sol.content.isEmpty {
                    FullPageKaTeXView(content: sol.content)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    Spacer()
                    Text("暂无内容").foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}
