import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settings

        Form {
            // Recommended provider links
            Section("推荐服务商") {
                Link(destination: URL(string: "https://store.tu-zi.com?from=1304")!) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("兔子").font(.subheadline.weight(.medium))
                            Text("推荐 · 国内稳定高速").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square").foregroundStyle(.blue)
                    }
                }
                Link(destination: URL(string: "https://zenmux.ai/invite/GBQMC5")!) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ZenMux").font(.subheadline.weight(.medium))
                            Text("支持图片提取").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square").foregroundStyle(.blue)
                    }
                }
            }

            // Tu-zi API section
            APIKeySection(
                providerName: "Tu-zi API",
                footerText: "购买或注册：",
                footerURL: URL(string: "https://store.tu-zi.com?from=1304")!,
                footerLinkLabel: "store.tu-zi.com",
                apiKey: $settings.tuziApiKey,
                configFactory: { .tuzi(apiKey: $0) }
            )

            // Zenmux API section
            APIKeySection(
                providerName: "Zenmux API",
                footerText: "注册获取：",
                footerURL: URL(string: "https://zenmux.ai/invite/GBQMC5")!,
                footerLinkLabel: "zenmux.ai/invite/GBQMC5",
                apiKey: $settings.zenmuxApiKey,
                configFactory: { .zenmux(apiKey: $0) }
            )

            // Provider selection
            Section {
                Picker("使用的 API 服务", selection: $settings.preferredProvider) {
                    ForEach(APIProvider.allCases) { provider in
                        HStack {
                            Text(provider.rawValue)
                            if provider == .tuzi {
                                Text("推荐").font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.menu)

                // Show the key status for each provider
                HStack {
                    Image(systemName: settings.tuziApiKey.isEmpty ? "xmark.circle" : "checkmark.circle.fill")
                        .foregroundStyle(settings.tuziApiKey.isEmpty
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(Color.green))
                    Text("Tu-zi Key")
                    Spacer()
                    Text(settings.tuziApiKey.isEmpty ? "未配置" : "已配置")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                HStack {
                    Image(systemName: settings.zenmuxApiKey.isEmpty ? "xmark.circle" : "checkmark.circle.fill")
                        .foregroundStyle(settings.zenmuxApiKey.isEmpty
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(Color.green))
                    Text("Zenmux Key")
                    Spacer()
                    Text(settings.zenmuxApiKey.isEmpty ? "未配置" : "已配置")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                if let config = appState.settings.activeConfig {
                    LabeledContent("当前实际使用", value: config.providerName)
                        .foregroundStyle(.blue)
                }
            } header: {
                Text("API 服务")
            } footer: {
                Text("首选服务不可用时（未配置 Key），自动切换到另一个服务。")
            }

            // Expert model selection (provider-aware)
            if settings.preferredProvider == .zenmux {
                Section {
                    Picker("解法一", selection: $settings.zenmuxExpertAModel) {
                        ForEach(ZenmuxModel.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("解法二", selection: $settings.zenmuxExpertBModel) {
                        ForEach(ZenmuxModel.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("专家总评", selection: $settings.zenmuxExpertCModel) {
                        ForEach(ZenmuxModel.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("解题模型（Zenmux）")
                } footer: {
                    Text("图像识别固定使用 GPT-4o。")
                }
            } else {
                Section {
                    Picker("解法一", selection: $settings.tuziExpertAModel) {
                        ForEach(TuziModel.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("解法二", selection: $settings.tuziExpertBModel) {
                        ForEach(TuziModel.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("专家总评", selection: $settings.tuziExpertCModel) {
                        ForEach(TuziModel.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("解题模型（Tu-zi）")
                } footer: {
                    Text("图像识别固定使用 GPT-4o。")
                }
            }

            // Output language
            Section("输出语言") {
                Picker("语言", selection: $settings.outputLanguage) {
                    ForEach(OutputLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }

            // About
            Section("关于") {
                LabeledContent("版本", value: "1.0.0")
            }
        }
        .navigationTitle("设置")
    }
}

// MARK: - Reusable API key section
private struct APIKeySection: View {
    let providerName: String
    let footerText: String
    let footerURL: URL
    let footerLinkLabel: String
    @Binding var apiKey: String
    let configFactory: (String) -> APIConfig

    @State private var keyInput = ""
    @State private var showKey = false
    @State private var isTesting = false
    @State private var testMessage = ""
    @State private var testSuccess: Bool? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        Section {
            // Key input row
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
                apiKey = trimmed
                testMessage = "✅ 密钥已保存"
                testSuccess = true
            }
            .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)

            Button {
                Task { await runTest() }
            } label: {
                HStack {
                    if isTesting { ProgressView().scaleEffect(0.8) }
                    Text(isTesting ? "测试中..." : "测试连接")
                }
            }
            .disabled(apiKey.isEmpty || isTesting)

            if !testMessage.isEmpty {
                Text(testMessage)
                    .font(.caption)
                    .foregroundStyle(testSuccess == true ? .green : .red)
            }

            Button("删除 API Key", role: .destructive) {
                showDeleteConfirm = true
            }
            .disabled(apiKey.isEmpty)

        } header: {
            Text(providerName)
        } footer: {
            HStack(spacing: 4) {
                Text(footerText)
                Link(footerLinkLabel, destination: footerURL)
            }
            .font(.caption)
        }
        .confirmationDialog(
            "确认删除 \(providerName) Key？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                apiKey = ""
                keyInput = ""
                testMessage = ""
                testSuccess = nil
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("删除后该服务将不再可用，可随时在此页面重新添加。")
        }
        .onAppear { keyInput = apiKey }
    }

    private func runTest() async {
        isTesting = true
        testMessage = ""
        testSuccess = nil
        let config = configFactory(apiKey)
        do {
            let ok = try await ZenmuxService.testConnection(config: config)
            testMessage = ok ? "✅ 连接成功" : "❌ Key 无效"
            testSuccess = ok
        } catch {
            testMessage = "❌ \(error.localizedDescription)"
            testSuccess = false
        }
        isTesting = false
    }
}
