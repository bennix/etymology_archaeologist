import SwiftUI

struct ChatFollowUpView: View {
    @Environment(AppState.self) private var appState
    @State private var inputText = ""
    @State private var isStreaming = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Chat messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.reportMessages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: appState.reportMessages.count) { _, _ in
                    if let last = appState.reportMessages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: lastMessageContent) { _, _ in
                    if let last = appState.reportMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // Input bar
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField("追问 AI...", text: $inputText, axis: .vertical)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .disabled(isStreaming)

                Button {
                    Task { await sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty || isStreaming
                            ? AnyShapeStyle(Color.gray.opacity(0.4))
                            : AnyShapeStyle(Color.blue)
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isStreaming)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }

    private var lastMessageContent: String {
        appState.reportMessages.last?.content ?? ""
    }

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false

        let userMsg = ChatMessage(role: .user, content: text)
        appState.reportMessages.append(userMsg)

        var assistantMsg = ChatMessage(role: .assistant, content: "", isStreaming: true)
        appState.reportMessages.append(assistantMsg)
        let assistantIndex = appState.reportMessages.count - 1

        isStreaming = true
        do {
            // Pass all messages except the empty assistant placeholder
            let historyMessages = Array(appState.reportMessages.dropLast())
            try await ZenmuxService.streamChat(
                messages: historyMessages,
                apiKey: appState.settings.apiKey,
                language: appState.settings.outputLanguage
            ) { chunk in
                Task { @MainActor in
                    appState.reportMessages[assistantIndex].content += chunk
                }
            }
        } catch {
            appState.reportMessages[assistantIndex].content = "❌ 出错：\(error.localizedDescription)"
        }
        appState.reportMessages[assistantIndex].isStreaming = false
        isStreaming = false
    }
}

// MARK: - Chat Bubble
struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Role label
                Text(isUser ? "你" : "AI 助手")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Bubble content
                if isUser {
                    Text(message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else if message.isStreaming {
                    // Plain text while streaming — instant per-chunk display
                    VStack(alignment: .leading, spacing: 2) {
                        if message.content.isEmpty {
                            HStack(spacing: 6) {
                                Circle().frame(width: 6, height: 6)
                                    .foregroundStyle(.secondary)
                                Text("AI 思考中...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(message.content)
                                .font(.system(.body, design: .default))
                                .textSelection(.enabled)
                            Text("▌")
                                .foregroundStyle(.blue)
                                .font(.body)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    // Streaming complete — render LaTeX/Markdown
                    DynamicKaTeXView(content: message.content)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }

            if !isUser { Spacer(minLength: 48) }
        }
    }
}
