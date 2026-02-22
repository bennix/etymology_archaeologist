import SwiftUI

struct SolvingContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var currentProblemIndex = 0
    @State private var selectedExpert: ExpertType = .a
    @State private var navigateToExpertC = false
    @State private var solvingStarted = false

    var selectedProblems: [Problem] {
        appState.problems.filter(\.isSelected)
    }

    var currentProblem: Problem? {
        selectedProblems[safe: currentProblemIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Problem selector tab bar (only shown if multiple problems)
            if selectedProblems.count > 1 {
                problemTabBar
            }

            // Expert A / B segmented picker
            Picker("解法", selection: $selectedExpert) {
                Text("解法一 (Gemini)").tag(ExpertType.a)
                Text("解法二 (Gemini)").tag(ExpertType.b)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            // Streaming content — both views exist simultaneously, only one is visible
            if let problem = currentProblem {
                ZStack {
                    StreamingSolutionView(problem: problem, expert: .a)
                        .opacity(selectedExpert == .a ? 1 : 0)
                    StreamingSolutionView(problem: problem, expert: .b)
                        .opacity(selectedExpert == .b ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.15), value: selectedExpert)
            }
        }
        .navigationTitle("AI 专家解题")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if allABComplete {
                    Button {
                        navigateToExpertC = true
                    } label: {
                        Label("专家总评", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                } else {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7).tint(.blue)
                        Text("解题中...").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToExpertC) {
            ExpertCView()
        }
        .task {
            guard !solvingStarted else { return }
            solvingStarted = true
            await solveAllProblems()
        }
        .onChange(of: allABComplete) { _, complete in
            if complete {
                // Auto-navigate after short delay
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    navigateToExpertC = true
                }
            }
        }
    }

    private var problemTabBar: some View {
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
                        ? Color.blue
                        : Color.blue.opacity(0.1)
                    )
                    .foregroundStyle(currentProblemIndex == idx ? .white : .blue)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private var allABComplete: Bool {
        selectedProblems.allSatisfy { problem in
            let solutions = appState.solutions[problem.id] ?? []
            let aOk = solutions.first(where: { $0.expert == .a })?.isComplete ?? false
            let bOk = solutions.first(where: { $0.expert == .b })?.isComplete ?? false
            return aOk && bOk
        }
    }

    private func solveAllProblems() async {
        await withTaskGroup(of: Void.self) { group in
            for problem in selectedProblems {
                // Initialize solution slots for this problem
                let solA = ExpertSolution(expert: .a)
                let solB = ExpertSolution(expert: .b)
                let solC = ExpertSolution(expert: .c)
                appState.solutions[problem.id] = [solA, solB, solC]

                group.addTask {
                    // A and B run concurrently
                    async let taskA: Void = self.runExpert(solution: solA, problem: problem)
                    async let taskB: Void = self.runExpert(solution: solB, problem: problem)
                    _ = await (taskA, taskB)
                    // C starts only after both A and B complete
                    await self.runExpert(solution: solC, problem: problem)
                }
            }
        }
    }

    @MainActor
    private func runExpert(solution: ExpertSolution, problem: Problem) async {
        solution.isStreaming = true
        do {
            try await ZenmuxService.streamSolution(
                problem: problem,
                expert: solution.expert,
                apiKey: appState.settings.apiKey,
                language: appState.settings.outputLanguage
            ) { chunk in
                solution.content += chunk
            }
        } catch {
            solution.errorMessage = error.localizedDescription
        }
        solution.isStreaming = false
        solution.isComplete = true
    }
}

// MARK: - Collection safe subscript
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
