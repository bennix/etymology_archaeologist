import SwiftUI

struct ExtractionLoadingView: View {
    @Environment(AppState.self) private var appState
    @State private var navigateToConfirmation = false
    @State private var dots = ""
    @State private var dotTimer: Timer? = nil

    var body: some View {
        Group {
            if appState.isExtracting {
                loadingView
            } else if let error = appState.extractionError {
                errorView(message: error)
            } else if !appState.problems.isEmpty {
                Color.clear
                    .onAppear { navigateToConfirmation = true }
            }
        }
        .navigationTitle("分析中")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToConfirmation) {
            ProblemConfirmationView()
        }
        .task { await runExtraction() }
        .onAppear { startDotAnimation() }
        .onDisappear { dotTimer?.invalidate() }
    }

    private var loadingView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text("GPT-5.2 正在分析\(dots)")
                    .font(.title3.bold())
                Text("识别公式 · 提取已知条件 · 拆分题目")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView()
                .tint(.blue)
                .scaleEffect(1.2)

            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("分析失败").font(.title2.bold())
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }

            Button("返回重试") {
                appState.extractionError = nil
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }

    private func startDotAnimation() {
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                dots = dots.count >= 3 ? "" : dots + "."
            }
        }
    }

    private func runExtraction() async {
        guard !appState.capturedImages.isEmpty else { return }
        appState.isExtracting = true
        appState.extractionError = nil
        do {
            let raw = try await ZenmuxService.extractProblems(
                from: appState.capturedImages,
                apiKey: appState.settings.apiKey,
                language: appState.settings.outputLanguage
            )
            let parsed = ProblemParser.parse(from: raw)
            appState.problems = parsed
        } catch {
            appState.extractionError = error.localizedDescription
        }
        appState.isExtracting = false
    }
}
