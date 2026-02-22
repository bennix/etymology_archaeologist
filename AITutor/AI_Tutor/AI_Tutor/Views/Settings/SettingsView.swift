import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var keyInput = ""
    @State private var showKey = false
    @State private var isTesting = false
    @State private var testMessage = ""
    @State private var testSuccess: Bool? = nil

    var body: some View {
        @Bindable var settings = appState.settings

        Form {
            // API Key section
            Section {
                HStack {
                    if showKey {
                        TextField("API Key", text: $keyInput)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("API Key", text: $keyInput)
                    }
                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("保存密钥") {
                    let trimmed = keyInput.trimmingCharacters(in: .whitespaces)
                    appState.settings.apiKey = trimmed
                    testMessage = "✅ 密钥已保存"
                    testSuccess = true
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    Task { await runConnectionTest() }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView().scaleEffect(0.8)
                        }
                        Text(isTesting ? "测试中..." : "测试连接")
                    }
                }
                .disabled(appState.settings.apiKey.isEmpty || isTesting)

                if !testMessage.isEmpty {
                    Text(testMessage)
                        .font(.caption)
                        .foregroundStyle(testSuccess == true ? .green : .red)
                }
            } header: {
                Text("API 密钥")
            } footer: {
                Text("API Key 加密存储在设备 Keychain 中，不会上传到任何服务器")
            }

            // Output language section
            Section("输出语言") {
                Picker("语言", selection: $settings.outputLanguage) {
                    ForEach(OutputLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }

            // Model info section
            Section("使用的 AI 模型") {
                LabeledContent("题目提取", value: "GPT-5.2")
                LabeledContent("解法 A / B", value: "Gemini 3 Pro")
                LabeledContent("专家总评", value: "Claude Sonnet 4.5")
            }

            // App info
            Section("关于") {
                LabeledContent("版本", value: "1.0.0")
                LabeledContent("API 服务", value: "Zenmux")
            }
        }
        .navigationTitle("设置")
        .onAppear {
            keyInput = appState.settings.apiKey
        }
    }

    private func runConnectionTest() async {
        isTesting = true
        testMessage = ""
        testSuccess = nil
        do {
            let ok = try await ZenmuxService.testConnection(apiKey: appState.settings.apiKey)
            testMessage = ok ? "✅ 连接成功" : "❌ Key 无效"
            testSuccess = ok
        } catch {
            testMessage = "❌ \(error.localizedDescription)"
            testSuccess = false
        }
        isTesting = false
    }
}
