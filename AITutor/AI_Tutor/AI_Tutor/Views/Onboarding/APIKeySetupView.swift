import SwiftUI

struct APIKeySetupView: View {
    @Environment(AppState.self) private var appState

    @State private var tuziKeyInput   = ""
    @State private var zenmuxKeyInput = ""
    @State private var isSaving = false
    @State private var saveResult: SaveResult? = nil

    enum SaveResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        Text("欢迎使用 AI 数学导师")
                            .font(.title.bold())
                        Text("配置至少一个 API Key 即可开始使用")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .padding(.top, 40)

                    // Provider recommendation card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("推荐服务商")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 24)

                        VStack(spacing: 0) {
                            Link(destination: URL(string: "https://store.tu-zi.com?from=1304")!) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("兔子").font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                                        Text("推荐 · 国内稳定高速").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text("注册获取 Key").font(.caption).foregroundStyle(.blue)
                                        Image(systemName: "arrow.up.right.square").font(.caption).foregroundStyle(.blue)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            }
                            Divider().padding(.leading, 16)
                            Link(destination: URL(string: "https://zenmux.ai/invite/GBQMC5")!) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("ZenMux").font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                                        Text("支持图片提取").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text("注册获取 Key").font(.caption).foregroundStyle(.blue)
                                        Image(systemName: "arrow.up.right.square").font(.caption).foregroundStyle(.blue)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)
                    }

                    // Tu-zi section (recommended)
                    providerCard(
                        title: "Tu-zi API",
                        badge: "推荐",
                        badgeColor: .orange,
                        registerLabel: "还没有 Tu-zi Key？点此购买",
                        registerURL: URL(string: "https://store.tu-zi.com?from=1304")!,
                        placeholder: "输入 Tu-zi API Key...",
                        keyInput: $tuziKeyInput
                    )

                    // Divider
                    HStack {
                        Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                        Text("或").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
                        Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                    }
                    .padding(.horizontal, 24)

                    // Zenmux section
                    providerCard(
                        title: "Zenmux API",
                        badge: nil,
                        badgeColor: .blue,
                        registerLabel: "还没有 Zenmux Key？立即注册",
                        registerURL: URL(string: "https://zenmux.ai/invite/GBQMC5")!,
                        placeholder: "输入 Zenmux API Key...",
                        keyInput: $zenmuxKeyInput
                    )

                    // Result feedback
                    if let result = saveResult {
                        Group {
                            switch result {
                            case .success:
                                Label("已保存，正在进入应用...", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            case .failure(let msg):
                                Label(msg, systemImage: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 24)
                    }

                    // CTA button
                    Button {
                        Task { await saveKeys() }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.white).scaleEffect(0.9)
                                Text("验证中...")
                            } else {
                                Text("开始使用")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canProceed)
                    .padding(.horizontal, 24)
                    .animation(.easeInOut, value: isSaving)

                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Provider card
    @ViewBuilder
    private func providerCard(
        title: String,
        badge: String?,
        badgeColor: Color,
        registerLabel: String,
        registerURL: URL,
        placeholder: String,
        keyInput: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title).font(.headline)
                if let badge {
                    Text(badge)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(badgeColor.opacity(0.15))
                        .foregroundStyle(badgeColor)
                        .clipShape(Capsule())
                }
            }
            Link(destination: registerURL) {
                HStack(spacing: 4) {
                    Text(registerLabel).foregroundStyle(.secondary)
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.blue)
                }
                .font(.subheadline)
            }
            SecureInputField(text: keyInput, placeholder: placeholder)
        }
        .padding(.horizontal, 24)
    }

    private var canProceed: Bool {
        let hasTuzi   = !tuziKeyInput.trimmingCharacters(in: .whitespaces).isEmpty
        let hasZenmux = !zenmuxKeyInput.trimmingCharacters(in: .whitespaces).isEmpty
        return (hasTuzi || hasZenmux) && !isSaving
    }

    private func saveKeys() async {
        isSaving = true
        saveResult = nil

        let tuziTrimmed   = tuziKeyInput.trimmingCharacters(in: .whitespaces)
        let zenmuxTrimmed = zenmuxKeyInput.trimmingCharacters(in: .whitespaces)

        var verified = false
        var errorMsg = ""

        // Try Tu-zi first
        if !tuziTrimmed.isEmpty {
            do {
                if try await ZenmuxService.testConnection(config: .tuzi(apiKey: tuziTrimmed)) {
                    verified = true
                } else { errorMsg = "Tu-zi Key 无效，请检查后重试" }
            } catch { errorMsg = "Tu-zi 连接失败：\(error.localizedDescription)" }
        }

        // Try Zenmux if Tu-zi not verified
        if !verified && !zenmuxTrimmed.isEmpty {
            do {
                if try await ZenmuxService.testConnection(config: .zenmux(apiKey: zenmuxTrimmed)) {
                    verified = true
                } else { errorMsg = "Zenmux Key 无效，请检查后重试" }
            } catch { errorMsg = "Zenmux 连接失败：\(error.localizedDescription)" }
        }

        if verified {
            saveResult = .success
            try? await Task.sleep(for: .milliseconds(600))
            if !tuziTrimmed.isEmpty   { appState.settings.tuziApiKey   = tuziTrimmed }
            if !zenmuxTrimmed.isEmpty { appState.settings.zenmuxApiKey = zenmuxTrimmed }
        } else {
            saveResult = .failure(errorMsg.isEmpty ? "请输入有效的 API Key" : errorMsg)
        }
        isSaving = false
    }
}

// MARK: - Reusable secure input field
struct SecureInputField: View {
    @Binding var text: String
    let placeholder: String
    @State private var isSecure = true

    var body: some View {
        HStack {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                TextField(placeholder, text: $text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye" : "eye.slash")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}
