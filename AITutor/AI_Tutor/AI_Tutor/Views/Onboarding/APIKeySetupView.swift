import SwiftUI

struct APIKeySetupView: View {
    @Environment(AppState.self) private var appState
    @State private var keyInput = ""
    @State private var isTesting = false
    @State private var testResult: TestResult? = nil

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Icon + title
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    Text("欢迎使用 AI 数学导师")
                        .font(.title.bold())
                    Text("请输入你的 Zenmux API Key\n密钥将永久安全存储在本设备上")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                // Input field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zenmux API Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureInputField(text: $keyInput, placeholder: "输入你的 API Key...")
                }
                .padding(.horizontal, 24)

                // Test result feedback
                if let result = testResult {
                    Group {
                        switch result {
                        case .success:
                            Label("连接成功！正在进入应用...", systemImage: "checkmark.circle.fill")
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
                    Task { await saveAndTest() }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView().tint(.white).scaleEffect(0.9)
                            Text("验证中...")
                        } else {
                            Text("验证并保存")
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
                .animation(.easeInOut, value: isTesting)

                Spacer()
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }

    private var canProceed: Bool {
        !keyInput.trimmingCharacters(in: .whitespaces).isEmpty && !isTesting
    }

    private func saveAndTest() async {
        isTesting = true
        testResult = nil
        let trimmedKey = keyInput.trimmingCharacters(in: .whitespaces)
        do {
            let ok = try await ZenmuxService.testConnection(apiKey: trimmedKey)
            if ok {
                testResult = .success
                // Short delay so user sees the success message
                try? await Task.sleep(for: .milliseconds(800))
                appState.settings.apiKey = trimmedKey
            } else {
                testResult = .failure("Key 无效，请检查后重试")
            }
        } catch {
            testResult = .failure("连接失败：\(error.localizedDescription)")
        }
        isTesting = false
    }
}

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
