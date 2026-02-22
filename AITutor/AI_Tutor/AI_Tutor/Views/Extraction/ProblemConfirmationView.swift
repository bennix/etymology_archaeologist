import SwiftUI

struct ProblemConfirmationView: View {
    @Environment(AppState.self) private var appState
    @State private var navigateToSolving = false

    var selectedCount: Int {
        appState.problems.filter(\.isSelected).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Header banner
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("成功提取 \(appState.problems.count) 道题目")
                        .font(.subheadline.bold())
                    Spacer()
                    Button("全选") {
                        appState.problems.forEach { $0.isSelected = true }
                    }
                    .font(.caption)
                    Button("清空") {
                        appState.problems.forEach { $0.isSelected = false }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Problem cards
                ForEach(appState.problems) { problem in
                    ProblemCard(problem: problem)
                }

                // Bottom padding for the overlay button
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .navigationTitle("确认题目")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .overlay(alignment: .bottom) {
            sendButtonOverlay
        }
        .navigationDestination(isPresented: $navigateToSolving) {
            SolvingContainerView()
        }
    }

    private var sendButtonOverlay: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                navigateToSolving = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(selectedCount > 0
                         ? "发送 \(selectedCount) 道题给 AI 专家解答"
                         : "请选择至少一道题目")
                    .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedCount > 0 ? Color.blue : Color.gray.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selectedCount == 0)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }
}

// MARK: - Problem Card
struct ProblemCard: View {
    @Bindable var problem: Problem
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(spacing: 10) {
                Image(systemName: problem.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(problem.isSelected ? .blue : .secondary)
                    .font(.title3)
                    .onTapGesture { problem.isSelected.toggle() }

                Text("题目 \(problem.number)")
                    .font(.headline)
                    .foregroundStyle(problem.isSelected ? .primary : .secondary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture { problem.isSelected.toggle() }

            if isExpanded {
                Divider().padding(.horizontal)

                // Full problem text with LaTeX
                DynamicKaTeXView(content: problem.fullLatexText)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                // Known data table
                if !problem.knownDataMarkdown.isEmpty {
                    Divider()
                        .padding(.horizontal)
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已知条件")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                        DynamicKaTeXView(content: problem.knownDataMarkdown)
                            .padding(.horizontal, 8)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    problem.isSelected ? Color.blue.opacity(0.5) : Color(.systemGray4),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .animation(.easeInOut(duration: 0.15), value: problem.isSelected)
    }
}
