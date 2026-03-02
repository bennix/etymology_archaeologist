import SwiftUI

struct SolvingContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var currentProblemIndex = 0
    @State private var selectedExpert: ExpertType = .a
    @State private var navigateToReport = false
    @State private var solvingStarted = false
    @State private var expertsPermanentlyFailed = false
    @State private var showExpertFailureAlert = false

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
                Text("解法一 (\(appState.settings.expertADisplayName))").tag(ExpertType.a)
                Text("解法二 (\(appState.settings.expertBDisplayName))").tag(ExpertType.b)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            // Only render the selected solution — background Tasks write to AppState regardless
            if let problem = currentProblem {
                if selectedExpert == .a {
                    StreamingSolutionView(problem: problem, expert: .a)
                        .transition(.opacity)
                        .id("sol-a-\(problem.id)")
                } else {
                    StreamingSolutionView(problem: problem, expert: .b)
                        .transition(.opacity)
                        .id("sol-b-\(problem.id)")
                }
            }
        }
        .navigationTitle("AI 专家解题")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if allABComplete {
                    Button {
                        navigateToReport = true
                    } label: {
                        Label("查看报告", systemImage: "doc.text.fill")
                            .foregroundStyle(.blue)
                    }
                } else {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7).tint(.blue)
                        Text("解题中...").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToReport) {
            ReportView()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            guard !solvingStarted else { return }
            solvingStarted = true
            Task { await solveAllProblems() }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: allABComplete) { _, complete in
            if complete && !expertsPermanentlyFailed {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    if !navigateToReport && !expertsPermanentlyFailed {
                        buildInitialReport()
                        navigateToReport = true
                    }
                }
            }
        }
        .alert("AI 解题失败", isPresented: $showExpertFailureAlert) {
            Button("重新录入题目") {
                appState.resetToInput()
            }
        } message: {
            Text("AI 解题请求连续失败，无法完成解题。\n请检查网络连接和 API Key 后重新尝试。")
        }
        .onChange(of: allCComplete) { _, complete in
            if complete {
                // All three experts done — allow screen to sleep again
                UIApplication.shared.isIdleTimerDisabled = false
                let updated = appState.fullReport()
                if appState.reportMessages.isEmpty {
                    appState.reportMessages = [ChatMessage(role: .assistant, content: updated)]
                } else {
                    // Update in-place: preserves the message ID and any ongoing Q&A
                    appState.reportMessages[0].content = updated
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

    private var allCComplete: Bool {
        selectedProblems.allSatisfy { problem in
            appState.solutions[problem.id]?
                .first(where: { $0.expert == .c })?
                .isComplete ?? false
        }
    }

    private func buildInitialReport() {
        let reportContent = appState.fullReport()
        appState.reportMessages = [ChatMessage(role: .assistant, content: reportContent)]
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
                    // C requires both A and B to have content
                    let (failed, aEmpty, bEmpty) = await MainActor.run {
                        (self.expertsPermanentlyFailed, solA.content.isEmpty, solB.content.isEmpty)
                    }
                    if failed {
                        await MainActor.run { solC.isComplete = true }
                    } else if aEmpty || bEmpty {
                        let missing = aEmpty && bEmpty ? "解法一和解法二均"
                                    : (aEmpty ? "解法一" : "解法二")
                        await MainActor.run {
                            solC.errorMessage = "\(missing)未返回解题内容，缺少待评审的解法，无法进行专家总评。请返回重新尝试解题。"
                            solC.isComplete = true
                        }
                    } else {
                        await self.runExpert(solution: solC, problem: problem)
                    }
                }
            }
        }
    }

    @MainActor
    private func runExpert(solution: ExpertSolution, problem: Problem) async {
        guard let config = appState.settings.activeConfig else {
            solution.errorMessage = "未配置 API Key"
            solution.isStreaming = false
            solution.isComplete = true
            return
        }

        solution.isStreaming = true

        // Resolve per-expert model ID from settings (provider-aware)
        let modelId: String
        switch solution.expert {
        case .a: modelId = appState.settings.expertAModelId
        case .b: modelId = appState.settings.expertBModelId
        case .c: modelId = appState.settings.expertCModelId
        }

        // A/B get up to 5 attempts; C gets 2
        let maxAttempts = (solution.expert == .a || solution.expert == .b) ? 5 : 2
        var lastError: Error?

        for attempt in 1...maxAttempts {
            if attempt > 1 {
                solution.content = ""
                let backoff = Double(attempt - 1) * 3.0   // 3s, 6s, 9s, 12s
                solution.errorMessage = "第 \(attempt - 1) 次失败，\(Int(backoff))s 后重试…"
                try? await Task.sleep(for: .seconds(backoff))
            }

            var solutionA = ""
            var solutionB = ""
            if solution.expert == .c {
                let existing = appState.solutions[problem.id] ?? []
                solutionA = existing.first(where: { $0.expert == .a })?.content ?? ""
                solutionB = existing.first(where: { $0.expert == .b })?.content ?? ""
            }

            // Declared outside do so catch blocks can access buffer
            var buffer = ""
            var lastFlush = Date()

            do {
                try await ZenmuxService.streamSolution(
                    problem: problem,
                    expert: solution.expert,
                    modelId: modelId,
                    config: config,
                    subject: appState.settings.selectedSubject,
                    language: appState.settings.outputLanguage,
                    solutionA: solutionA,
                    solutionB: solutionB
                ) { chunk in
                    buffer += chunk
                    if Date().timeIntervalSince(lastFlush) >= 0.05 {
                        solution.content += buffer
                        buffer = ""
                        lastFlush = Date()
                    }
                }
                // Flush any tokens that arrived in the last partial interval
                if !buffer.isEmpty {
                    solution.content += buffer
                    buffer = ""
                }
                // Treat an empty response as a failure (API returned 200 but no usable content)
                if solution.content.isEmpty {
                    throw NSError(domain: "ZenmuxService", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "模型未返回内容，请检查模型名称或 API Key"])
                }
                lastError = nil
                solution.errorMessage = nil
                break  // success
            } catch let nsErr as NSError where nsErr.domain == "ZenmuxService" && nsErr.code == -3 {
                // Token limit hit — flush remaining buffer, keep content, show warning
                if !buffer.isEmpty { solution.content += buffer; buffer = "" }
                solution.errorMessage = nsErr.localizedDescription
                lastError = nil  // don't treat as a retryable failure
                break
            } catch {
                lastError = error
                buffer = ""
                solution.content = ""   // clear partial content before retry
                solution.errorMessage = attempt < maxAttempts
                    ? "第 \(attempt) 次失败，重试中..."
                    : error.localizedDescription
            }
        }

        // If all retries exhausted for A/B expert, trigger global failure
        if lastError != nil && (solution.expert == .a || solution.expert == .b) {
            expertsPermanentlyFailed = true
            showExpertFailureAlert = true
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
