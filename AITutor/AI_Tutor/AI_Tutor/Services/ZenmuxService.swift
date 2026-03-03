// AI_Tutor/Services/ZenmuxService.swift
import Foundation
import UIKit

struct ZenmuxService {

    // MARK: - Non-streaming extraction
    static func extractProblems(
        from images: [UIImage],
        config: APIConfig,
        subject: Subject,
        language: OutputLanguage
    ) async throws -> String {
        let extractionPrompt = buildExtractionPrompt(subject: subject, language: language)
        var parts: [ExtractionContentPart] = [.text(extractionPrompt)]

        for image in images {
            if let b64 = encodeImage(image) {
                parts.append(.image(url: "data:image/jpeg;base64,\(b64)"))
            }
        }

        let body = ExtractionBody(
            model: config.extractionModel,
            messages: [.init(role: "user", content: parts)]
        )
        let request = try buildRequest(config: config, bodyData: try JSONEncoder().encode(body))
        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        if let http = urlResponse as? HTTPURLResponse, http.statusCode != 200 {
            let msg = (try? JSONDecoder().decode(APIError.self, from: data))?.error.message
                ?? String(data: data, encoding: .utf8)
                ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "ZenmuxService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }

    // MARK: - Streaming for experts
    @MainActor
    static func streamSolution(
        problem: Problem,
        expert: ExpertType,
        modelId: String,
        config: APIConfig,
        subject: Subject,
        language: OutputLanguage,
        solutionA: String = "",
        solutionB: String = "",
        images: [UIImage] = [],
        onChunk: (String) -> Void
    ) async throws {
        let systemPrompt = buildExpertSystemPrompt(expert: expert, subject: subject, language: language)
        let userPrompt = buildExpertUserPrompt(problem: problem, subject: subject, solutionA: solutionA, solutionB: solutionB)

        // Expert C reviews A/B solutions — images not needed; A/B get original problem images
        let userContent: Any
        if !images.isEmpty && expert != .c {
            var parts: [[String: Any]] = [["type": "text", "text": userPrompt]]
            for image in images {
                if let b64 = encodeImage(image) {
                    parts.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]])
                }
            }
            userContent = parts
        } else {
            userContent = userPrompt
        }

        let body: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userContent]
            ],
            "max_tokens": 65000,
            "stream": true
        ]
        var request = try buildRequest(config: config, body: body)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let (asyncBytes, urlResponse) = try await streamingSession.bytes(for: request)
        if let http = urlResponse as? HTTPURLResponse, http.statusCode != 200 {
            var bodyLines: [String] = []
            for try await line in asyncBytes.lines { bodyLines.append(line) }
            let body2 = bodyLines.joined()
            let msg = (try? JSONDecoder().decode(APIError.self, from: Data(body2.utf8)))?.error.message
                ?? body2
            throw NSError(domain: "ZenmuxService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg.isEmpty ? "API 错误 HTTP \(http.statusCode)" : msg])
        }
        var doneSeen = false
        var hitTokenLimit = false
        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            if jsonString == "[DONE]" { doneSeen = true; break }
            guard let data = jsonString.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) else { continue }
            if chunk.choices.first?.finishReason == "length" { hitTokenLimit = true }
            let delta = chunk.choices.first?.delta
            // Thinking models (e.g. qwen3.5-plus) stream the chain-of-thought in
            // `delta.reasoning` while `delta.content` stays nil until the final answer.
            // Forward both so the user sees progress during the thinking phase.
            if let reasoning = delta?.reasoning, !reasoning.isEmpty { onChunk(reasoning) }
            if let content  = delta?.content,   !content.isEmpty  { onChunk(content) }
        }
        if hitTokenLimit {
            throw NSError(domain: "ZenmuxService", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "输出已达 token 上限，解答不完整"])
        }
        if !doneSeen {
            throw NSError(domain: "ZenmuxService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "响应流意外中断"])
        }
    }

    // MARK: - Streaming chat follow-up
    @MainActor
    static func streamChat(
        messages: [ChatMessage],
        config: APIConfig,
        modelId: String,
        subject: Subject,
        language: OutputLanguage,
        onChunk: (String) -> Void
    ) async throws {
        let apiMessages: [[String: String]] = messages.map {
            ["role": $0.role == .user ? "user" : "assistant", "content": $0.content]
        }
        var allMessages: [[String: String]] = [
            ["role": "system", "content": "你是一个\(subject.rawValue)解题助手。以下是刚刚生成的解题报告，用户可能对报告中的内容进行追问。请基于报告内容回答。" + language.systemPromptSuffix]
        ]
        allMessages += apiMessages
        let body: [String: Any] = [
            "model": modelId,
            "messages": allMessages,
            "stream": true
        ]
        var request = try buildRequest(config: config, body: body)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let (asyncBytes, urlResponse) = try await streamingSession.bytes(for: request)
        if let http = urlResponse as? HTTPURLResponse, http.statusCode != 200 {
            var bodyLines: [String] = []
            for try await line in asyncBytes.lines { bodyLines.append(line) }
            let body2 = bodyLines.joined()
            let msg = (try? JSONDecoder().decode(APIError.self, from: Data(body2.utf8)))?.error.message
                ?? body2
            throw NSError(domain: "ZenmuxService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg.isEmpty ? "API 错误 HTTP \(http.statusCode)" : msg])
        }
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
    static func testConnection(config: APIConfig) async throws -> Bool {
        let body: [String: Any] = [
            "model": config.defaultModel,
            "messages": [["role": "user", "content": "Reply with OK only."]]
        ]
        let request = try buildRequest(config: config, body: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    // MARK: - Private helpers

    /// Shared URLSession for streaming requests.
    /// Uses .ephemeral so cached Alt-Svc headers (HTTP/3 upgrade hints) from previous
    /// sessions don't force QUIC connections — Tu-zi's QUIC is unstable on some networks.
    private static let streamingSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest  = 300   // 5 min: time to receive first bytes
        config.timeoutIntervalForResource = 600   // 10 min: total resource lifetime
        return URLSession(configuration: config)
    }()

    private static func buildRequest(config: APIConfig, body: [String: Any]) throws -> URLRequest {
        guard let url = URL(string: config.baseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300   // 5 min — overrides default 60 s
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func buildRequest(config: APIConfig, bodyData: Data) throws -> URLRequest {
        guard let url = URL(string: config.baseURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        return request
    }

    // MARK: - Image encoding helper

    /// Resize and JPEG-encode a UIImage for multimodal API requests.
    /// Returns base64 string, or nil if encoding fails.
    private static func encodeImage(_ image: UIImage, maxPx: CGFloat = 1536) -> String? {
        let longest = max(image.size.width, image.size.height)
        let scale: CGFloat = longest > maxPx ? maxPx / longest : 1.0
        let resized: UIImage
        if scale < 1.0 {
            let targetSize = CGSize(width: floor(image.size.width * scale),
                                    height: floor(image.size.height * scale))
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
        } else {
            resized = image
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.75), !jpeg.isEmpty else { return nil }
        return jpeg.base64EncodedString()
    }

    // MARK: - Prompt builders

    private static func buildExtractionPrompt(subject: Subject, language: OutputLanguage) -> String {
        let rules: String
        switch subject {

        case .math:
            rules = """
            1. **角色**：你是一个严谨的数学题目录入员。
            2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
            3. **LaTeX 格式**：所有数学符号、公式必须用 LaTeX：
               - 行内公式：$x^2 + y^2 = r^2$、$\\frac{a}{b}$、$\\sqrt{n}$
               - 分数、根号、求和、积分、极限等必须用命令
               - 集合、向量、矩阵保留完整格式
            4. **已知条件表**：整理变量名、数值、条件及备注
            """

        case .physics:
            rules = """
            1. **角色**：你是一个严谨的物理题目数据审计员，**必须反复核查所有上标和单位**，科学计数法的指数绝对不允许出错！
            2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
            3. **科学计数法（极其重要）**：
               - 精确写出指数：$3 \\times 10^8\\ \\text{m/s}$、$6.67 \\times 10^{-11}\\ \\text{N·m}^2/\\text{kg}^2$
               - 负指数不得丢失负号：$10^{-3}$ 绝不能写成 $10^3$
               - 数量级不得降级或升级（如 $10^6$ 不能变成 $10^3$）
            4. **单位**：用 \\text{} 包裹：$\\text{m/s}^2$、$\\text{kg·m/s}$、$\\text{J}$、$\\text{N}$、$\\text{Pa}$
            5. **物理量**：下标区分方向与编号：$v_0$、$a_x$、$F_{\\text{合}}$；矢量保留方向说明
            6. **已知条件表**：物理量 | 数值与单位（含科学计数法） | 备注
            """

        case .chemistry:
            rules = """
            1. **角色**：你是一个严谨的化学题目录入员，**化学式的上下标必须精确无误**！
            2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
            3. **分子式下标（极其重要）**：
               - 原子个数必须用 _{}：$\\text{H}_2\\text{O}$、$\\text{CO}_2$、$\\text{H}_2\\text{SO}_4$、$\\text{Fe}_3\\text{O}_4$
               - 多位下标：$\\text{C}_6\\text{H}_{12}\\text{O}_6$
            4. **离子上标（极其重要）**：
               - 化合价/电荷用 ^{}：$\\text{Fe}^{2+}$、$\\text{Fe}^{3+}$、$\\text{Ca}^{2+}$、$\\text{SO}_4^{2-}$、$\\text{OH}^-$、$\\text{CO}_3^{2-}$
               - 复杂离子：$\\text{MnO}_4^-$、$\\text{Cr}_2\\text{O}_7^{2-}$、$\\text{NH}_4^+$
            5. **化学方程式**：
               - 不可逆：\\rightarrow；可逆：\\rightleftharpoons
               - 条件：$\\xrightarrow{\\Delta}$、$\\xrightarrow{\\text{光照}}$、$\\overset{\\text{催化剂}}{\\rightarrow}$
               - 沉淀符号 ↓、气体符号 ↑ 需保留
            6. **化学量**：$n = 2\\ \\text{mol}$、$c = 0.1\\ \\text{mol/L}$、$M = 98\\ \\text{g/mol}$、$V_m = 22.4\\ \\text{L/mol}$
            7. **已知条件表**：化学量 | 数值与单位 | 状态/备注
            """

        case .biology:
            rules = """
            1. **角色**：你是一个严谨的生物题目录入员。
            2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
            3. **生物化学符号**：
               - 生物大分子化学式精确处理下标：$\\text{C}_6\\text{H}_{12}\\text{O}_6$、$\\text{CO}_2$、$\\text{O}_2$
               - 遗传比例用分数：$\\frac{3}{4}$、$\\frac{1}{4}$；基因型用正体：$AaBb$、$X^AX^a$
               - ATP/ADP 等缩写直接使用，无需 LaTeX
            4. **实验数据**：表格数据、坐标轴数值、实验组/对照组忠实提取
            5. **已知条件表**：实验条件、数值与单位、变量说明
            """

        case .interdisciplinary:
            rules = """
            1. **角色**：你是一个严谨的跨学科（生物+地理）题目录入员。
            2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
            3. **生物化学内容**：
               - 涉及化学式时精确处理下标/上标：$\\text{CO}_2$、$\\text{O}_2$、$\\text{H}_2\\text{O}$
               - 遗传、细胞、生态等生物学内容完整提取
            4. **地理内容**：
               - 地名、方位、气候、地形、数据（温度/降水/海拔）忠实提取
               - 有图表/坐标轴时，用文字描述横纵轴含义及数值范围
            5. **背景材料**：图文说明、图例、阅读材料提取到 knownDataMarkdown 字段
            """

        case .geography:
            rules = """
            1. **角色**：你是一个严谨的地理题目录入员。
            2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
            3. **内容提取**：
               - 完整保留地名、方位、气候/地形/地貌描述
               - 数值数据（温度、降水量、海拔、时区、经纬度等）直接提取
               - 有图表或坐标轴时，文字描述轴含义和数值范围
            4. **背景材料**：图文说明、统计表、阅读材料提取到 knownDataMarkdown 字段
            """

        case .history:
            rules = """
            1. **角色**：你是一个严谨的历史题目录入员。
            2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
            3. **内容提取**：
               - 完整保留人名、地名、年代、史料引文，不得修改或简化
               - 保留原文标点、格式和段落结构
            4. **史料材料**：阅读材料、史料引文、图片说明提取到 knownDataMarkdown 字段
            """

        case .chinese:
            rules = """
            1. **角色**：你是一个严谨的语文题目录入员。
            2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
            3. **内容提取**：
               - 完整保留诗文原文、作者、朝代、题干及所有小题
               - 保留原文标点、段落结构和格式
            4. **阅读材料**：诗歌、古文、现代文阅读原文提取到 knownDataMarkdown 字段
            """

        case .english:
            rules = """
            1. **Role**: You are a meticulous English question transcriber.
            2. **Split questions**: Number all independent questions: [Q1], [Q2]…
            3. **Content rules**:
               - Preserve complete text: reading passages, grammar questions, all options (A/B/C/D) with exact wording
               - Maintain original formatting, punctuation and paragraph structure
               - Vocabulary and cloze blanks: use underscores ____
            4. **Reading material**: Extract any reading passage or text to the knownDataMarkdown field
            """
        }

        // Universal figure-description rule — applies to every subject
        let figureRule = """

        **图形与图像描述（所有科目通用，极其重要）**：凡题目图片中包含任何图形或图像（包括但不限于：坐标轴图、折线图、柱状图、饼图等统计图表；几何图形；物理实验装置图、电路图、光路图；化学结构式图、实验步骤图；地图、等高线图；生物细胞结构图、遗传图谱；跨学科综合图等），**必须**在该图形出现的对应位置，按以下标签格式进行详细文字描述，将其作为题目的已知条件嵌入 fullLatexText：

        【图形描述】（详细文字描述图形的全部关键信息，须包含以下所有适用内容：① 坐标轴：横纵轴标签、单位、数值范围；② 曲线/折线/柱/区域：形状走势、极值点/峰谷值、交点及对应坐标；③ 图例与颜色：各颜色/线型代表的物理量或组别；④ 标注：图中字母、数字、符号及其含义；⑤ 几何图形：各边、角、点的标注及相互关系；⑥ 特殊标记：箭头方向、阴影区域含义。描述须使读者仅凭文字即可完整还原图形信息。）【/图形描述】

        **严格禁止**直接写"见图"、"如图所示"、"图中所示"等指代性文字，必须将图形信息完整展开为文字。
        """

        // Shared JSON output format appended to every subject prompt
        let jsonFormat = """

        **严格输出格式**：每道题必须按以下 JSON 数组输出，不要输出任何其他内容：
        ```json
        [
          {
            "number": 1,
            "fullLatexText": "完整题目文字（含小题和选项）",
            "knownDataMarkdown": "已知条件表或背景材料（无则留空\\"\\"）"
          }
        ]
        ```
        \(language.systemPromptSuffix)
        """

        return rules + figureRule + jsonFormat
    }

    private static func buildExpertSystemPrompt(expert: ExpertType, subject: Subject, language: OutputLanguage) -> String {
        let base: String
        switch subject {

        case .math, .physics, .chemistry:
            switch expert {
            case .a:
                base = "你是一位严谨的\(subject.rawValue)专家。请给出第一种解法，步骤清晰，使用 LaTeX 公式。"
            case .b:
                base = "你是一位严谨的\(subject.rawValue)专家。请给出与解法一**不同思路**的第二种解法，并在最后验证答案正确性。"
            case .c:
                base = "你是一位资深\(subject.rawValue)教授。请综合评估两种解法，指出各自优缺点，并给出最优解推荐。"
            }

        case .biology, .interdisciplinary:
            switch expert {
            case .a:
                base = "你是一位资深的\(subject.rawValue)专家。请给出第一种分析思路和详细解答，关键步骤用 LaTeX 标注化学式或数据。"
            case .b:
                base = "你是一位资深的\(subject.rawValue)专家。请从**不同角度**给出第二种解答，与解法一互补，并点明评分要点。"
            case .c:
                base = "你是一位资深\(subject.rawValue)教研员。请综合评估两种解答，指出知识点覆盖情况，并给出最优参考答案。"
            }

        case .chinese, .english, .history, .geography:
            switch expert {
            case .a:
                base = "你是一位资深的\(subject.rawValue)教师。请给出第一种解题思路和详细参考答案，分析清晰，语言规范。"
            case .b:
                base = "你是一位资深的\(subject.rawValue)教师。请从**不同角度或切入点**给出第二种解答，与解法一互补，并点明评分要点。"
            case .c:
                base = "你是一位经验丰富的\(subject.rawValue)教研员。请综合评估两种解答的优缺点，指出答题规范性，并给出最优参考答案和得分建议。"
            }
        }
        return base + language.systemPromptSuffix
    }

    private static func buildExpertUserPrompt(problem: Problem, subject: Subject, solutionA: String = "", solutionB: String = "") -> String {
        var prompt: String
        if subject.isSTEM {
            prompt = """
            【题目 \(problem.number)】

            \(problem.fullLatexText)

            已知条件：
            \(problem.knownDataMarkdown)
            """
        } else {
            prompt = "【题目 \(problem.number)】\n\n\(problem.fullLatexText)"
            if !problem.knownDataMarkdown.isEmpty {
                prompt += "\n\n【背景材料】\n\(problem.knownDataMarkdown)"
            }
        }

        if !solutionA.isEmpty && !solutionB.isEmpty {
            prompt += """


            ---
            【解法一】
            \(solutionA)

            ---
            【解法二】
            \(solutionB)
            """
        }
        return prompt
    }
}

// MARK: - Extraction request Codable types
private struct ExtractionBody: Encodable {
    let model: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: [ExtractionContentPart]
    }
}

private enum ExtractionContentPart: Encodable {
    case text(String)
    case image(url: String)

    private enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let t):
            try c.encode("text", forKey: .type)
            try c.encode(t, forKey: .text)
        case .image(let url):
            try c.encode("image_url", forKey: .type)
            // Zenmux GPT-4o expects image_url as a plain string data URI.
            // (Standard {"url":"..."} object format is rejected by this endpoint.)
            try c.encode(url, forKey: .imageURL)
        }
    }
}

// MARK: - Response decodable models
private struct APIError: Decodable {
    struct ErrorBody: Decodable { let message: String }
    let error: ErrorBody
}

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
        let finishReason: String?
        struct Delta: Decodable {
            let content: String?
            let reasoning: String?
        }
        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }
}
