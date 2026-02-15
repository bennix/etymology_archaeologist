# EnglishAI macOS 原生应用设计方案

**日期**: 2026-02-16
**项目**: 中考英语教学助手 macOS 版
**目标**: 将 Flask Web 应用完整移植到 macOS 原生应用

---

## 1. 整体架构

### 架构选型决策

| 决策点 | 选择 | 原因 |
|--------|------|------|
| 开发模式 | 纯原生 Swift 重写 | 最佳用户体验，无需嵌入 Python |
| TTS/STT | macOS 原生能力 | 免费、离线、隐私保护 |
| 数据存储 | UserDefaults + 本地文件 | 简单、轻量、符合数据规模 |
| UI 风格 | 纯 macOS 原生风格 | 符合平台规范，开发效率高 |
| 词汇库 | 完整移植（Bundle 打包） | 保持功能一致性 |
| 引导流程 | 首次启动强制引导 | 确保用户正确配置 API key |
| 导航结构 | Sidebar + Detail | 最符合 macOS 应用习惯 |

### MVVM + Clean Architecture

```
┌─────────────────────────────────────────────────┐
│                  SwiftUI Views                  │
│  (OnboardingView, MainView, 练习 Views)         │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│              ViewModels (ObservableObject)       │
│  - OnboardingViewModel                          │
│  - ListeningViewModel                           │
│  - SpeakingViewModel                            │
│  - ReadingViewModel, WritingViewModel           │
│  - HistoryViewModel                             │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│                Services Layer                    │
│  - ZenMuxService (API 调用)                     │
│  - TTSService (AVSpeechSynthesizer)             │
│  - STTService (Speech Framework)                │
│  - StorageService (UserDefaults + FileManager)  │
│  - VocabService (词汇库管理)                    │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│               Models & Data                     │
│  - APIKey, UserSettings                         │
│  - Exercise (听说读写通用模型)                  │
│  - VocabWord (词汇数据)                         │
│  - ExerciseHistory (历史记录)                   │
└─────────────────────────────────────────────────┘
```

**关键设计原则：**
1. **分层清晰**: View 不直接调用 Service，通过 ViewModel 中介
2. **依赖注入**: Service 层通过协议定义，便于测试和替换
3. **单一职责**: 每个 ViewModel 只负责一个功能模块
4. **数据驱动**: 使用 `@Published` 属性让 UI 自动响应数据变化

---

## 2. 核心组件设计

### 2.1 ZenMuxService（API 调用层）

```swift
protocol ZenMuxServiceProtocol {
    func generateListeningContent() async throws -> ListeningExercise
    func generateReadingContent() async throws -> ReadingExercise
    func evaluateWriting(_ text: String, prompt: String) async throws -> WritingFeedback
    func evaluateSpeaking(_ transcript: String, topic: String) async throws -> SpeakingScore
}

class ZenMuxService: ZenMuxServiceProtocol {
    private let apiKey: String
    private let baseURL = "https://api.zenmux.ai/v1"

    // 使用 URLSession 发送请求
    // 根据原应用配置：
    // - Kimi K2 Thinking Turbo (生成内容)
    // - Claude Opus 4.5 (批改评估)
    // - MiniMax M2.1 (题目生成)
}
```

**API 模型映射：**
- 内容生成: `moonshotai/kimi-k2-thinking-turbo`
- 批改评估: `anthropic/claude-opus-4.5`
- 题目生成: `minimax/minimax-m2.1`

### 2.2 TTSService（原生语音合成）

```swift
class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var onFinished: (() -> Void)?

    func speak(text: String, voice: String = "en-US") async throws {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voice)
        utterance.rate = 0.5 // 适合学习的语速
        synthesizer.speak(utterance)
    }

    // 支持保存为音频文件（用于听力练习）
    func generateAudioFile(text: String) async throws -> URL
}
```

**语音配置：**
- 语言: `en-US` (美式英语)
- 语速: 0.5 (可在设置中调节 0.4-0.6)
- 音质: 使用系统最高质量语音

### 2.3 STTService（原生语音识别）

```swift
class STTService: NSObject, SFSpeechRecognizerDelegate {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()

    func startRecording() async throws -> AsyncStream<String>
    func stopRecording() async throws -> String // 返回最终转录文本
}
```

**识别配置：**
- 语言: `en-US`
- 实时转录: 支持
- 离线模式: 支持（需要下载语音模型）

---

## 3. 数据模型与存储

### 3.1 核心数据模型

```swift
// 统一的练习结果模型
struct ExerciseResult: Codable, Identifiable {
    let id: UUID
    let type: ExerciseType // .listening, .speaking, .reading, .writing
    let score: Double
    let maxScore: Double
    let date: Date
    let details: String // JSON 存储具体内容
}

enum ExerciseType: String, Codable {
    case listening = "听力"
    case speaking = "口语"
    case reading = "阅读"
    case writing = "写作"
}

// 听力练习模型
struct ListeningExercise: Codable {
    let dialogue: String // 对话文本
    let audioURL: URL? // 音频文件路径
    let questions: [Question]
}

// 口语练习模型
struct SpeakingExercise: Codable {
    let topic: String
    let transcript: String? // 用户录音转录
    let score: SpeakingScore?
}

struct SpeakingScore: Codable {
    let fluency: Double // 流利度 /10
    let grammar: Double // 语法 /10
    let vocabulary: Double // 词汇 /10
    let content: Double // 内容 /10
    let feedback: String
}

// 阅读理解模型
struct ReadingExercise: Codable {
    let article: String
    let questions: [Question]
}

struct Question: Codable, Identifiable {
    let id: Int
    let type: QuestionType // .multipleChoice, .shortAnswer
    let question: String
    let options: [String]? // 选择题选项
    let correctAnswer: String
    let explanation: String
}

// 写作练习模型
struct WritingExercise: Codable {
    let prompt: String
    let userText: String?
    let feedback: WritingFeedback?
}

struct WritingFeedback: Codable {
    let content: Double // 内容 /5
    let structure: Double // 结构 /5
    let grammar: Double // 语法 /5
    let vocabulary: Double // 词汇 /5
    let comments: [String] // 逐段点评
    let suggestions: [String] // 改进建议
}
```

### 3.2 StorageService（数据持久化）

```swift
class StorageService {
    private let defaults = UserDefaults.standard

    // API Key 存储
    var apiKey: String? {
        get { defaults.string(forKey: "zenmux_api_key") }
        set { defaults.set(newValue, forKey: "zenmux_api_key") }
    }

    // 历史记录（最近 10 次）
    func saveResult(_ result: ExerciseResult) {
        var history = getHistory()
        history.insert(result, at: 0)
        if history.count > 10 { history.removeLast() }

        // 编码为 JSON 并存储
        if let encoded = try? JSONEncoder().encode(history) {
            defaults.set(encoded, forKey: "exercise_history")
        }
    }

    func getHistory() -> [ExerciseResult] {
        guard let data = defaults.data(forKey: "exercise_history"),
              let history = try? JSONDecoder().decode([ExerciseResult].self, from: data) else {
            return []
        }
        return history
    }

    func getStatistics() -> [ExerciseType: Double] {
        let history = getHistory()
        var stats: [ExerciseType: [Double]] = [:]

        for result in history {
            stats[result.type, default: []].append(result.score)
        }

        return stats.mapValues { scores in
            scores.reduce(0, +) / Double(scores.count)
        }
    }

    // 音频文件管理
    func saveAudioFile(_ data: Data) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = UUID().uuidString + ".caf"
        let fileURL = tempDir.appendingPathComponent(filename)
        try? data.write(to: fileURL)
        return fileURL
    }

    func cleanupOldAudio() {
        // 删除超过 24 小时的音频文件
        let tempDir = FileManager.default.temporaryDirectory
        let fileManager = FileManager.default

        if let files = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey]) {
            for file in files where file.pathExtension == "caf" {
                if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
                   let creationDate = attrs[.creationDate] as? Date,
                   Date().timeIntervalSince(creationDate) > 86400 {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
    }
}
```

### 3.3 VocabService（词汇库）

```swift
struct VocabWord: Codable {
    let word: String
    let meanings: [String]
    let isPolysemous: Bool
}

class VocabService {
    private var vocab: [String: VocabWord] = [:]

    init() {
        loadVocabFromBundle()
    }

    private func loadVocabFromBundle() {
        guard let url = Bundle.main.url(forResource: "gaokao_vocab", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: VocabWord].self, from: data) else {
            print("❌ 词汇库加载失败")
            return
        }
        vocab = decoded
        print("✅ 词汇库加载完成: \(vocab.count) 词")
    }

    func getRandomWords(count: Int, polysemousOnly: Bool = false) -> [VocabWord] {
        let filtered = polysemousOnly ? vocab.values.filter { $0.isPolysemous } : Array(vocab.values)
        return Array(filtered.shuffled().prefix(count))
    }

    func getVocabPrompt() -> String {
        """
        请基于高考 3500 词汇范围生成内容，特别关注一词多义现象。
        词汇难度应适合中国初三学生（中考水平）。
        """
    }
}
```

---

## 4. UI 组件结构

### 4.1 应用入口

```swift
@main
struct EnglishAILearningApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.needsOnboarding {
                OnboardingView()
                    .environmentObject(appState)
            } else {
                MainView()
                    .environmentObject(appState)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("练习") {
                Button("生成新听力") { /* ... */ }
                    .keyboardShortcut("1", modifiers: .command)
                Button("生成新口语") { /* ... */ }
                    .keyboardShortcut("2", modifiers: .command)
                // ...
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var needsOnboarding: Bool
    private let storage = StorageService()

    init() {
        needsOnboarding = storage.apiKey == nil
    }

    func completeOnboarding() {
        needsOnboarding = false
    }
}
```

### 4.2 OnboardingView（引导页面）

```swift
struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 30) {
            // 应用图标 + 标题
            Image(systemName: "book.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("中考英语教学助手")
                .font(.largeTitle.bold())

            Text("开始使用前，请先获取 ZenMux API 密钥")
                .foregroundColor(.secondary)

            // ZenMux 注册引导
            GroupBox("获取 API 密钥") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("1.")
                        Link("访问 ZenMux 注册",
                             destination: URL(string: "https://zenmux.ai/invite/GBQMC5")!)
                            .font(.headline)
                    }

                    HStack {
                        Text("2.")
                        Text("支持支付宝订阅 API 服务")
                    }

                    HStack {
                        Text("3.")
                        Text("获取 API 密钥后粘贴到下方")
                    }
                }
                .padding()
            }
            .frame(maxWidth: 500)

            // API Key 输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("API 密钥")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("sk-ss-v1-...", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(maxWidth: 500)

            // 验证状态
            if let error = viewModel.validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // 开始使用按钮
            Button(action: {
                Task {
                    if await viewModel.saveAndValidate() {
                        appState.completeOnboarding()
                    }
                }
            }) {
                if viewModel.isValidating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("开始使用")
                        .frame(width: 120)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.apiKey.isEmpty || viewModel.isValidating)
        }
        .padding(60)
        .frame(width: 700, height: 600)
    }
}

class OnboardingViewModel: ObservableObject {
    @Published var apiKey = ""
    @Published var isValidating = false
    @Published var validationError: String?

    private let storage = StorageService()
    private let zenmuxService: ZenMuxService

    init() {
        zenmuxService = ZenMuxService(apiKey: "")
    }

    func saveAndValidate() async -> Bool {
        isValidating = true
        validationError = nil

        // 简单验证 API key 格式
        guard apiKey.hasPrefix("sk-") else {
            validationError = "API 密钥格式不正确"
            isValidating = false
            return false
        }

        // 保存到 UserDefaults
        storage.apiKey = apiKey

        // TODO: 可选 - 实际调用 API 验证

        isValidating = false
        return true
    }
}
```

### 4.3 MainView（主界面 - Sidebar）

```swift
enum NavigationItem: Hashable {
    case listening
    case speaking
    case reading
    case writing
    case history
    case settings
}

struct MainView: View {
    @State private var selection: NavigationItem? = .listening

    var body: some View {
        NavigationSplitView {
            // 左侧边栏
            List(selection: $selection) {
                Section("练习模块") {
                    NavigationLink(value: NavigationItem.listening) {
                        Label("听力练习", systemImage: "waveform")
                    }
                    NavigationLink(value: NavigationItem.speaking) {
                        Label("口语练习", systemImage: "mic.fill")
                    }
                    NavigationLink(value: NavigationItem.reading) {
                        Label("阅读理解", systemImage: "book.fill")
                    }
                    NavigationLink(value: NavigationItem.writing) {
                        Label("写作批改", systemImage: "pencil")
                    }
                }

                Section("数据") {
                    NavigationLink(value: NavigationItem.history) {
                        Label("学习历史", systemImage: "clock.fill")
                    }
                }

                Section {
                    NavigationLink(value: NavigationItem.settings) {
                        Label("设置", systemImage: "gear")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: toggleSidebar) {
                        Image(systemName: "sidebar.left")
                    }
                }
            }
        } detail: {
            // 右侧详情区域
            Group {
                switch selection {
                case .listening:
                    ListeningView()
                case .speaking:
                    SpeakingView()
                case .reading:
                    ReadingView()
                case .writing:
                    WritingView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                case .none:
                    EmptyStateView()
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("选择一个模块开始练习")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}
```

### 4.4 ListeningView（听力练习界面）

```swift
struct ListeningView: View {
    @StateObject private var viewModel = ListeningViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Button(action: {
                    Task { await viewModel.generateExercise() }
                }) {
                    Label("生成新练习", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.state == .generating)

                Spacer()

                if viewModel.state == .ready || viewModel.state == .answering {
                    Button(action: { viewModel.playAudio() }) {
                        Label("播放对话", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 内容区域
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.state == .generating {
                        ProgressView("正在生成听力内容...")
                            .padding(60)
                    } else if let exercise = viewModel.exercise {
                        // 音频播放器
                        if let audioURL = exercise.audioURL {
                            AudioPlayerView(url: audioURL)
                                .padding()
                        }

                        // 题目列表
                        ForEach(Array(exercise.questions.enumerated()), id: \.element.id) { index, question in
                            QuestionCard(
                                number: index + 1,
                                question: question,
                                answer: Binding(
                                    get: { viewModel.userAnswers[question.id] ?? "" },
                                    set: { viewModel.userAnswers[question.id] = $0 }
                                ),
                                showResult: viewModel.state == .completed,
                                isCorrect: viewModel.results[question.id]
                            )
                        }

                        // 提交按钮
                        if viewModel.state == .answering {
                            Button("提交答案") {
                                Task { await viewModel.submitAnswers() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.userAnswers.count < exercise.questions.count)
                            .padding()
                        }

                        // 结果展示
                        if viewModel.state == .completed, let result = viewModel.result {
                            ResultCard(result: result)
                                .padding()
                        }
                    } else {
                        EmptyExerciseView(
                            icon: "waveform",
                            title: "点击「生成新练习」开始",
                            description: "AI 将生成真实对话场景和理解题"
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle("听力练习")
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
```

---

## 5. 关键功能实现

### 5.1 听力练习完整流程

```swift
class ListeningViewModel: ObservableObject {
    @Published var state: ExerciseState = .initial
    @Published var exercise: ListeningExercise?
    @Published var userAnswers: [Int: String] = [:]
    @Published var results: [Int: Bool] = [:]
    @Published var result: ExerciseResult?
    @Published var showError = false
    @Published var errorMessage = ""

    private let zenmuxService: ZenMuxServiceProtocol
    private let ttsService: TTSService
    private let storageService: StorageService

    enum ExerciseState {
        case initial
        case generating
        case ready
        case playing
        case answering
        case submitted
        case completed
    }

    init(
        zenmuxService: ZenMuxServiceProtocol = ZenMuxService.shared,
        ttsService: TTSService = TTSService.shared,
        storageService: StorageService = StorageService.shared
    ) {
        self.zenmuxService = zenmuxService
        self.ttsService = ttsService
        self.storageService = storageService
    }

    @MainActor
    func generateExercise() async {
        state = .generating
        userAnswers.removeAll()
        results.removeAll()
        result = nil

        do {
            // 1. 调用 API 生成听力内容
            exercise = try await zenmuxService.generateListeningContent()

            // 2. 使用 TTS 生成音频
            if let dialogue = exercise?.dialogue {
                let audioURL = try await ttsService.generateAudioFile(text: dialogue)
                exercise?.audioURL = audioURL
            }

            state = .ready
        } catch {
            handleError(error)
        }
    }

    func playAudio() {
        guard let audioURL = exercise?.audioURL else { return }
        state = .playing

        Task {
            do {
                try await ttsService.play(url: audioURL)
                await MainActor.run {
                    state = .answering
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }

    @MainActor
    func submitAnswers() async {
        guard let exercise = exercise else { return }
        state = .submitted

        do {
            // 批改答案
            var correct = 0
            for question in exercise.questions {
                let userAnswer = userAnswers[question.id] ?? ""
                let isCorrect = userAnswer.lowercased() == question.correctAnswer.lowercased()
                results[question.id] = isCorrect
                if isCorrect { correct += 1 }
            }

            // 创建结果记录
            let score = Double(correct) / Double(exercise.questions.count) * 10
            result = ExerciseResult(
                id: UUID(),
                type: .listening,
                score: score,
                maxScore: 10,
                date: Date(),
                details: try JSONEncoder().encode(exercise).base64EncodedString()
            )

            // 保存到历史记录
            storageService.saveResult(result!)

            state = .completed
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        state = .initial
    }
}
```

### 5.2 口语练习完整流程

```swift
class SpeakingViewModel: ObservableObject {
    @Published var state: RecordingState = .initial
    @Published var topic: String?
    @Published var transcript: String = ""
    @Published var score: SpeakingScore?
    @Published var result: ExerciseResult?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var recordingDuration: TimeInterval = 0

    private let sttService: STTService
    private let zenmuxService: ZenMuxServiceProtocol
    private let storageService: StorageService
    private let permissionManager = PermissionManager()
    private var recordingTimer: Timer?

    enum RecordingState {
        case initial
        case generatingTopic
        case ready
        case recording
        case transcribing
        case evaluating
        case completed
    }

    @MainActor
    func generateTopic() async {
        state = .generatingTopic

        do {
            topic = try await zenmuxService.generateSpeakingTopic()
            state = .ready
        } catch {
            handleError(error)
        }
    }

    @MainActor
    func startRecording() async {
        // 1. 请求权限
        let hasMicPermission = await permissionManager.requestMicrophonePermission()
        let hasSpeechPermission = await permissionManager.requestSpeechRecognitionPermission()

        guard hasMicPermission && hasSpeechPermission else {
            errorMessage = "需要麦克风和语音识别权限"
            showError = true
            return
        }

        // 2. 开始录音
        state = .recording
        transcript = ""
        recordingDuration = 0

        // 启动计时器
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }

        do {
            // 3. 实时转录
            for await partialTranscript in try await sttService.startRecording() {
                await MainActor.run {
                    transcript = partialTranscript
                }
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }

    @MainActor
    func stopRecordingAndEvaluate() async {
        recordingTimer?.invalidate()
        recordingTimer = nil

        state = .transcribing

        do {
            // 1. 获取最终转录
            let finalTranscript = try await sttService.stopRecording()
            transcript = finalTranscript

            // 2. 调用 API 评分
            state = .evaluating
            score = try await zenmuxService.evaluateSpeaking(
                finalTranscript,
                topic: topic ?? ""
            )

            // 3. 保存结果
            let totalScore = (score?.fluency ?? 0) +
                           (score?.grammar ?? 0) +
                           (score?.vocabulary ?? 0) +
                           (score?.content ?? 0)

            result = ExerciseResult(
                id: UUID(),
                type: .speaking,
                score: totalScore,
                maxScore: 40,
                date: Date(),
                details: try JSONEncoder().encode(score).base64EncodedString()
            )

            storageService.saveResult(result!)
            state = .completed
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        recordingTimer?.invalidate()
        errorMessage = error.localizedDescription
        showError = true
        state = .ready
    }
}
```

---

## 6. 错误处理与用户体验

### 6.1 统一错误处理

```swift
enum AppError: LocalizedError {
    case networkError(String)
    case apiKeyInvalid
    case apiQuotaExceeded
    case ttsError(String)
    case sttError(String)
    case storageError(String)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "网络错误：\(message)"
        case .apiKeyInvalid:
            return "API 密钥无效"
        case .apiQuotaExceeded:
            return "API 配额已用完"
        case .ttsError(let message):
            return "语音合成失败：\(message)"
        case .sttError(let message):
            return "语音识别失败：\(message)"
        case .storageError(let message):
            return "存储错误：\(message)"
        case .permissionDenied(let permission):
            return "需要\(permission)权限"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .apiKeyInvalid:
            return "前往「设置」重新配置 API 密钥"
        case .apiQuotaExceeded:
            return "访问 https://zenmux.ai 查看余额并充值"
        case .networkError:
            return "检查网络连接后重试"
        case .permissionDenied:
            return "前往「系统偏好设置」> 「安全性与隐私」中授予权限"
        default:
            return "请重试或联系支持"
        }
    }
}
```

### 6.2 权限管理

```swift
class PermissionManager {
    // 请求麦克风权限
    func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // 请求语音识别权限
    func requestSpeechRecognitionPermission() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
```

### 6.3 音频播放器服务

```swift
class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func play(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()

        duration = player?.duration ?? 0
        player?.play()
        isPlaying = true

        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            DispatchQueue.main.async {
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }
}
```

---

## 7. 项目结构

```
EnglishAILearning/
├── EnglishAILearning/
│   ├── App/
│   │   ├── EnglishAILearningApp.swift
│   │   └── AppState.swift
│   │
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift
│   │   │   └── OnboardingViewModel.swift
│   │   ├── Main/
│   │   │   └── MainView.swift
│   │   ├── Listening/
│   │   │   ├── ListeningView.swift
│   │   │   ├── ListeningViewModel.swift
│   │   │   └── AudioPlayerView.swift
│   │   ├── Speaking/
│   │   │   ├── SpeakingView.swift
│   │   │   ├── SpeakingViewModel.swift
│   │   │   └── RecordingControlView.swift
│   │   ├── Reading/
│   │   │   ├── ReadingView.swift
│   │   │   └── ReadingViewModel.swift
│   │   ├── Writing/
│   │   │   ├── WritingView.swift
│   │   │   └── WritingViewModel.swift
│   │   ├── History/
│   │   │   ├── HistoryView.swift
│   │   │   └── HistoryViewModel.swift
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   └── Components/
│   │       ├── ErrorBanner.swift
│   │       ├── LoadingOverlay.swift
│   │       ├── QuestionCard.swift
│   │       ├── ResultCard.swift
│   │       └── EmptyExerciseView.swift
│   │
│   ├── Services/
│   │   ├── ZenMuxService.swift
│   │   ├── TTSService.swift
│   │   ├── STTService.swift
│   │   ├── StorageService.swift
│   │   ├── VocabService.swift
│   │   ├── AudioPlayerService.swift
│   │   └── PermissionManager.swift
│   │
│   ├── Models/
│   │   ├── ExerciseModels.swift
│   │   ├── VocabModels.swift
│   │   ├── ScoreModels.swift
│   │   └── AppError.swift
│   │
│   ├── Resources/
│   │   ├── gaokao_vocab.json
│   │   └── Assets.xcassets/
│   │       ├── AppIcon.appiconset/
│   │       └── AccentColor.colorset/
│   │
│   └── Utils/
│       ├── NetworkClient.swift
│       └── Extensions.swift
│
├── EnglishAILearningTests/
│   ├── ServiceTests/
│   ├── ViewModelTests/
│   └── MockServices/
│
└── EnglishAILearning.xcodeproj
```

---

## 8. 实施计划

### Phase 1: 基础框架（2-3 天）

**目标**: 搭建项目骨架，实现引导流程

- [ ] 创建项目结构和文件组织
- [ ] 实现数据模型（ExerciseResult, Question 等）
- [ ] 实现 StorageService（UserDefaults + FileManager）
- [ ] 实现 AppState 和应用入口
- [ ] 实现 OnboardingView + OnboardingViewModel
- [ ] 实现 MainView（Sidebar 导航框架）
- [ ] 测试：API key 存储和读取

### Phase 2: API 集成（2-3 天）

**目标**: 实现 ZenMux API 调用

- [ ] 实现 NetworkClient（URLSession 封装）
- [ ] 实现 ZenMuxService（API 调用层）
  - [ ] 听力内容生成 API
  - [ ] 阅读内容生成 API
  - [ ] 口语评分 API
  - [ ] 写作批改 API
- [ ] 实现错误处理（AppError）
- [ ] 实现 API 重试机制
- [ ] 测试：模拟 API 调用和响应

### Phase 3: TTS/STT 集成（2-3 天）

**目标**: 实现语音合成和识别

- [ ] 实现 TTSService（AVSpeechSynthesizer）
  - [ ] 文本转语音
  - [ ] 保存为音频文件
  - [ ] 语速控制
- [ ] 实现 STTService（Speech Framework）
  - [ ] 实时录音和转录
  - [ ] 停止录音并返回结果
- [ ] 实现 AudioPlayerService
  - [ ] 播放/暂停/停止
  - [ ] 进度跟踪
- [ ] 实现 PermissionManager
- [ ] 测试：TTS 音频质量，STT 准确度

### Phase 4: 听力模块（2-3 天）

**目标**: 完整实现听力练习功能

- [ ] 实现 ListeningViewModel
  - [ ] 生成听力内容
  - [ ] TTS 生成音频
  - [ ] 答题逻辑
  - [ ] 批改逻辑
- [ ] 实现 ListeningView
  - [ ] 生成按钮和状态展示
  - [ ] AudioPlayerView 组件
  - [ ] QuestionCard 组件
  - [ ] ResultCard 组件
- [ ] 实现历史记录保存
- [ ] 测试：完整听力练习流程

### Phase 5: 口语模块（2-3 天）

**目标**: 完整实现口语练习功能

- [ ] 实现 SpeakingViewModel
  - [ ] 生成口语话题
  - [ ] 录音和实时转录
  - [ ] 评分逻辑
- [ ] 实现 SpeakingView
  - [ ] 话题展示
  - [ ] RecordingControlView（录音控制）
  - [ ] 转录文本展示
  - [ ] 评分结果展示
- [ ] 实现权限请求流程
- [ ] 测试：完整口语练习流程

### Phase 6: 阅读和写作模块（2-3 天）

**目标**: 实现阅读理解和写作批改

- [ ] 实现 ReadingViewModel + ReadingView
  - [ ] 生成阅读文章
  - [ ] 答题界面
  - [ ] 批改和详解
- [ ] 实现 WritingViewModel + WritingView
  - [ ] 生成写作题目
  - [ ] 文本输入区域
  - [ ] 批改结果展示（四维度）
- [ ] 集成 VocabService（词汇库）
- [ ] 测试：阅读和写作流程

### Phase 7: 历史和设置（1-2 天）

**目标**: 实现历史记录和设置页面

- [ ] 实现 HistoryViewModel + HistoryView
  - [ ] 历史记录列表
  - [ ] 统计数据展示
  - [ ] 详情查看
- [ ] 实现 SettingsView
  - [ ] API key 管理
  - [ ] TTS 语速设置
  - [ ] 数据清理
- [ ] 实现音频文件清理逻辑
- [ ] 测试：数据统计准确性

### Phase 8: 优化和测试（2-3 天）

**目标**: 性能优化和全面测试

- [ ] UI/UX 优化
  - [ ] 浅色/深色模式适配
  - [ ] 动画和过渡效果
  - [ ] 错误提示优化
- [ ] 性能优化
  - [ ] 音频缓存策略
  - [ ] API 请求优化
  - [ ] 内存管理
- [ ] 单元测试
  - [ ] Service 层测试
  - [ ] ViewModel 测试
- [ ] 集成测试
  - [ ] 完整练习流程测试
- [ ] 边界情况测试

### Phase 9: 打磨和发布（1-2 天）

**目标**: 应用打磨和准备发布

- [ ] 应用图标设计
- [ ] 启动画面
- [ ] 用户文档
  - [ ] 使用说明
  - [ ] 常见问题
- [ ] 打包和签名
- [ ] 发布准备

**总预计时间：14-21 天**

---

## 9. 技术风险与缓解

| 风险 | 影响 | 概率 | 缓解方案 |
|------|------|------|---------|
| AVSpeechSynthesizer 语音质量不符合预期 | 中 | 中 | 1. 提供语速、音调调节<br>2. 后期可选集成云端 TTS |
| Speech Framework 转录准确度低 | 高 | 中 | 1. 提供手动编辑转录文本<br>2. 引导用户清晰发音<br>3. 使用降噪算法 |
| ZenMux API 调用失败或超时 | 高 | 低 | 1. 实现重试机制（3 次）<br>2. 显示详细错误信息<br>3. 缓存已生成内容 |
| 词汇库加载影响启动速度 | 低 | 低 | 1. 异步加载词汇库<br>2. 懒加载策略 |
| 音频文件占用过多存储空间 | 中 | 中 | 1. 定期清理旧音频<br>2. 使用压缩格式 |
| 权限被拒绝导致功能无法使用 | 高 | 低 | 1. 清晰的权限说明<br>2. 引导用户到系统设置 |

---

## 10. 成功指标

### 功能完整性
- ✅ 所有四个练习模块正常工作
- ✅ API key 配置流程顺畅
- ✅ 历史记录准确保存和展示
- ✅ 错误处理完善

### 用户体验
- ✅ 应用启动时间 < 3 秒
- ✅ 练习生成时间 < 10 秒
- ✅ TTS 语音清晰可懂
- ✅ STT 转录准确率 > 85%
- ✅ UI 响应流畅，无卡顿

### 稳定性
- ✅ 无崩溃或严重 bug
- ✅ 网络错误能优雅处理
- ✅ 权限缺失能友好提示
- ✅ 数据不会丢失

---

## 11. 后续扩展方向

### V1.1（短期）
- [ ] 支持导出学习报告（PDF）
- [ ] 错题本功能
- [ ] 更丰富的统计图表

### V1.2（中期）
- [ ] 支持自定义词汇表上传
- [ ] 发音评分（音素级别）
- [ ] 离线模式（缓存已生成内容）

### V2.0（长期）
- [ ] iOS/iPadOS 版本
- [ ] 多用户管理
- [ ] 社区分享功能
- [ ] 教师端（班级管理）

---

**文档版本**: 1.0
**最后更新**: 2026-02-16
**作者**: AI Assistant & User
