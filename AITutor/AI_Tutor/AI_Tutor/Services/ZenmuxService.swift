// AI_Tutor/Services/ZenmuxService.swift
import Foundation
import UIKit

struct ZenmuxService {
    static let baseURL = "https://zenmux.ai/api/v1/chat/completions"

    // MARK: - Non-streaming extraction
    static func extractProblems(
        from images: [UIImage],
        apiKey: String,
        language: OutputLanguage
    ) async throws -> String {
        let extractionPrompt = buildExtractionPrompt(language: language)
        var contentArray: [[String: Any]] = [
            ["type": "text", "text": extractionPrompt]
        ]
        for image in images {
            guard let jpeg = image.jpegData(compressionQuality: 0.8) else { continue }
            let base64 = jpeg.base64EncodedString()
            contentArray.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
            ])
        }
        let body: [String: Any] = [
            "model": "openai/gpt-5.2",
            "messages": [["role": "user", "content": contentArray]]
        ]
        let request = try buildRequest(apiKey: apiKey, body: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }

    // MARK: - Streaming for experts
    static func streamSolution(
        problem: Problem,
        expert: ExpertType,
        apiKey: String,
        language: OutputLanguage,
        onChunk: @escaping (String) -> Void
    ) async throws {
        let systemPrompt = buildExpertSystemPrompt(expert: expert, language: language)
        let userPrompt = buildExpertUserPrompt(problem: problem)
        let body: [String: Any] = [
            "model": expert.modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ],
            "stream": true
        ]
        var request = try buildRequest(apiKey: apiKey, body: body)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let (asyncBytes, _) = try await URLSession.shared.bytes(for: request)
        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            if jsonString == "[DONE]" { break }
            guard let data = jsonString.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                  let delta = chunk.choices.first?.delta.content else { continue }
            onChunk(delta)
        }
    }

    // MARK: - Streaming chat follow-up
    static func streamChat(
        messages: [ChatMessage],
        apiKey: String,
        language: OutputLanguage,
        onChunk: @escaping (String) -> Void
    ) async throws {
        let apiMessages: [[String: String]] = messages.map {
            ["role": $0.role == .user ? "user" : "assistant", "content": $0.content]
        }
        let body: [String: Any] = [
            "model": "anthropic/claude-sonnet-4.5",
            "messages": apiMessages,
            "stream": true
        ]
        var request = try buildRequest(apiKey: apiKey, body: body)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let (asyncBytes, _) = try await URLSession.shared.bytes(for: request)
        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            if jsonString == "[DONE]" { break }
            guard let data = jsonString.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                  let delta = chunk.choices.first?.delta.content else { continue }
            onChunk(delta)
        }
    }

    // MARK: - Test connection
    static func testConnection(apiKey: String) async throws -> Bool {
        let body: [String: Any] = [
            "model": "anthropic/claude-sonnet-4.5",
            "messages": [["role": "user", "content": "Reply with OK only."]]
        ]
        let request = try buildRequest(apiKey: apiKey, body: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    // MARK: - Private helpers
    private static func buildRequest(apiKey: String, body: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func buildExtractionPrompt(language: OutputLanguage) -> String {
        """
        1. **设定角色**：你是一个严谨的数学/物理数据审计员和录入员。请务必二次核对图片中所有的上标、下标和单位，确保带有指数的数据绝对不被提取错误！
        2. **多题拆分与版面分析**：如果上传的图片包含多道独立的题目（如填空题、选择题、解答题相互独立），你必须将它们**拆分为单独的题目**，并编号：【题目 1】、【题目 2】...
        3. **强制 LaTeX 输出约束**：请将所有物理量、单位和科学记数法严格使用 LaTeX 格式（如 `$8 \\times 10^6\\text{ kg}$`）输出，**绝不允许省略、降级指数或改变数量级**。
        4. **多步结构化提取**：针对**每一道拆分后的题**，单独整理出一个"**已知条件数据表**"（包含物理量/变量名、数值与单位、备注），以及完整的**文字题目**。
        5. **严格输出格式**：每道题必须严格按照以下 JSON 数组格式输出，不要输出任何其他内容：
        ```json
        [
          {
            "number": 1,
            "fullLatexText": "完整题目文字，包含LaTeX公式",
            "knownDataMarkdown": "| 物理量 | 数值与单位 | 备注 |\\n|---|---|---|\\n| ... | ... | ... |"
          }
        ]
        ```
        \(language.systemPromptSuffix)
        """
    }

    private static func buildExpertSystemPrompt(expert: ExpertType, language: OutputLanguage) -> String {
        let base: String
        switch expert {
        case .a:
            base = "你是一位严谨的数学/物理专家。请给出第一种解法，步骤清晰，使用LaTeX公式。"
        case .b:
            base = "你是一位严谨的数学/物理专家。请给出与解法一**不同思路**的第二种解法，并在最后验证答案正确性。"
        case .c:
            base = "你是一位资深数学/物理教授。请综合评估两种解法，指出各自优缺点，并给出最优解推荐。"
        }
        return base + language.systemPromptSuffix
    }

    private static func buildExpertUserPrompt(problem: Problem) -> String {
        """
        【题目 \(problem.number)】

        \(problem.fullLatexText)

        已知条件：
        \(problem.knownDataMarkdown)
        """
    }
}

// MARK: - Response decodable models
private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
        struct Message: Decodable { let content: String }
    }
}

private struct StreamChunk: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let delta: Delta
        struct Delta: Decodable { let content: String? }
    }
}
