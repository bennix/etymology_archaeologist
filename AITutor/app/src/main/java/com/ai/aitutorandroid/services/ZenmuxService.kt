package com.ai.aitutorandroid.services

import android.graphics.Bitmap
import com.ai.aitutorandroid.models.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.Base64
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ZenmuxService @Inject constructor() {

    private val client = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.MINUTES)
        .readTimeout(10, TimeUnit.MINUTES)
        .writeTimeout(5, TimeUnit.MINUTES)
        .build()

    private val json = Json { ignoreUnknownKeys = true }

    // ─── Non-streaming extraction ────────────────────────────────────────────

    suspend fun extractProblems(
        images: List<Bitmap>,
        config: APIConfig,
        subject: Subject,
        language: OutputLanguage
    ): String = withContext(Dispatchers.IO) {
        val prompt = buildExtractionPrompt(subject, language)

        val contentArray = JSONArray()
        // Text part
        contentArray.put(JSONObject().put("type", "text").put("text", prompt))
        // Image parts
        for (image in images) {
            val resized = resizeBitmap(image, 1536)
            val base64 = bitmapToBase64(resized)
            contentArray.put(
                JSONObject()
                    .put("type", "image_url")
                    .put("image_url", "data:image/jpeg;base64,$base64")
            )
        }

        val body = JSONObject()
            .put("model", config.gptModel)
            .put("messages", JSONArray().put(
                JSONObject().put("role", "user").put("content", contentArray)
            ))

        val request = buildRequest(config, body.toString())
        val response = client.newCall(request).execute()

        if (!response.isSuccessful) {
            val errorBody = response.body?.string() ?: "HTTP ${response.code}"
            val msg = try {
                json.decodeFromString<ApiError>(errorBody).error.message
            } catch (e: Exception) { errorBody }
            throw Exception(msg)
        }

        val responseBody = response.body?.string() ?: throw Exception("Empty response")
        val parsed = json.decodeFromString<ChatCompletionResponse>(responseBody)
        parsed.choices.firstOrNull()?.message?.content ?: ""
    }

    // ─── Streaming solution ───────────────────────────────────────────────────

    fun streamSolution(
        problem: Problem,
        expert: ExpertType,
        modelId: String,
        config: APIConfig,
        subject: Subject,
        language: OutputLanguage,
        solutionA: String = "",
        solutionB: String = ""
    ): Flow<String> = flow {
        val systemPrompt = buildExpertSystemPrompt(expert, subject, language)
        val userPrompt = buildExpertUserPrompt(problem, subject, solutionA, solutionB)

        val body = JSONObject()
            .put("model", modelId)
            .put("messages", JSONArray()
                .put(JSONObject().put("role", "system").put("content", systemPrompt))
                .put(JSONObject().put("role", "user").put("content", userPrompt))
            )
            .put("max_tokens", 65000)
            .put("stream", true)

        val request = buildRequest(config, body.toString(), streaming = true)
        val response = client.newCall(request).execute()

        if (!response.isSuccessful) {
            val errorBody = response.body?.string() ?: "HTTP ${response.code}"
            val msg = try {
                json.decodeFromString<ApiError>(errorBody).error.message
            } catch (e: Exception) { errorBody }
            throw Exception(msg)
        }

        val source = response.body?.source() ?: throw Exception("Empty response body")
        var doneSeen = false
        var hitTokenLimit = false

        while (!source.exhausted()) {
            val line = source.readUtf8Line() ?: break
            if (!line.startsWith("data: ")) continue
            val jsonStr = line.removePrefix("data: ")
            if (jsonStr == "[DONE]") { doneSeen = true; break }

            val chunk = try {
                json.decodeFromString<StreamChunk>(jsonStr)
            } catch (e: Exception) { continue }

            val choice = chunk.choices.firstOrNull() ?: continue
            if (choice.finishReason == "length") hitTokenLimit = true
            choice.delta.reasoning?.takeIf { it.isNotEmpty() }?.let { emit(it) }
            choice.delta.content?.takeIf { it.isNotEmpty() }?.let { emit(it) }
        }

        if (hitTokenLimit) throw Exception("输出已达 token 上限，解答不完整")
        // Note: some servers omit the [DONE] sentinel — treat as normal completion
    }.flowOn(Dispatchers.IO)

    // ─── Streaming chat ───────────────────────────────────────────────────────

    fun streamChat(
        messages: List<ChatMessage>,
        config: APIConfig,
        modelId: String,
        subject: Subject,
        language: OutputLanguage
    ): Flow<String> = flow {
        val allMessages = JSONArray()
        allMessages.put(
            JSONObject()
                .put("role", "system")
                .put("content", "你是一个${subject.rawValue}解题助手。以下是刚刚生成的解题报告，用户可能对报告中的内容进行追问。请基于报告内容回答。${language.systemPromptSuffix}")
        )
        for (msg in messages) {
            allMessages.put(
                JSONObject()
                    .put("role", if (msg.role == ChatRole.USER) "user" else "assistant")
                    .put("content", msg.content)
            )
        }
        val body = JSONObject()
            .put("model", modelId)
            .put("messages", allMessages)
            .put("stream", true)

        val request = buildRequest(config, body.toString(), streaming = true)
        val response = client.newCall(request).execute()

        if (!response.isSuccessful) {
            val errorBody = response.body?.string() ?: "HTTP ${response.code}"
            val msg = try {
                json.decodeFromString<ApiError>(errorBody).error.message
            } catch (e: Exception) { errorBody }
            throw Exception(msg)
        }

        val source = response.body?.source() ?: throw Exception("Empty response")
        while (!source.exhausted()) {
            val line = source.readUtf8Line() ?: break
            if (!line.startsWith("data: ")) continue
            val jsonStr = line.removePrefix("data: ")
            if (jsonStr == "[DONE]") break
            val chunk = try {
                json.decodeFromString<StreamChunk>(jsonStr)
            } catch (e: Exception) { continue }
            chunk.choices.firstOrNull()?.delta?.content?.takeIf { it.isNotEmpty() }?.let { emit(it) }
        }
    }.flowOn(Dispatchers.IO)

    // ─── Test connection ──────────────────────────────────────────────────────

    suspend fun testConnection(config: APIConfig): Boolean = withContext(Dispatchers.IO) {
        val body = JSONObject()
            .put("model", config.defaultModel)
            .put("messages", JSONArray().put(
                JSONObject().put("role", "user").put("content", "Reply with OK only.")
            ))
        val request = buildRequest(config, body.toString())
        try {
            val response = client.newCall(request).execute()
            response.isSuccessful
        } catch (e: Exception) { false }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private fun buildRequest(config: APIConfig, bodyJson: String, streaming: Boolean = false): Request {
        val mediaType = "application/json".toMediaType()
        return Request.Builder()
            .url(config.baseURL)
            .addHeader("Authorization", "Bearer ${config.apiKey}")
            .addHeader("Content-Type", "application/json")
            .apply { if (streaming) addHeader("Accept", "text/event-stream") }
            .post(bodyJson.toRequestBody(mediaType))
            .build()
    }

    private fun resizeBitmap(bitmap: Bitmap, maxPx: Int): Bitmap {
        val longest = maxOf(bitmap.width, bitmap.height)
        if (longest <= maxPx) return bitmap
        val scale = maxPx.toFloat() / longest
        val w = (bitmap.width * scale).toInt()
        val h = (bitmap.height * scale).toInt()
        return Bitmap.createScaledBitmap(bitmap, w, h, true)
    }

    private fun bitmapToBase64(bitmap: Bitmap): String {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 75, stream)
        return Base64.getEncoder().encodeToString(stream.toByteArray())
    }

    // ─── Prompt builders (exact copy from iOS ZenmuxService.swift) ────────────

    private fun buildExtractionPrompt(subject: Subject, language: OutputLanguage): String {
        val rules = when (subject) {
            Subject.MATH -> """
                1. **角色**：你是一个严谨的数学题目录入员。
                2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
                3. **LaTeX 格式**：所有数学符号、公式必须用 LaTeX：
                   - 行内公式：${'$'}x^2 + y^2 = r^2${'$'}、${'$'}\frac{a}{b}${'$'}、${'$'}\sqrt{n}${'$'}
                   - 分数、根号、求和、积分、极限等必须用命令
                   - 集合、向量、矩阵保留完整格式
                4. **已知条件表**：整理变量名、数值、条件及备注
            """.trimIndent()
            Subject.PHYSICS -> """
                1. **角色**：你是一个严谨的物理题目数据审计员，**必须反复核查所有上标和单位**，科学计数法的指数绝对不允许出错！
                2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
                3. **科学计数法（极其重要）**：
                   - 精确写出指数：${'$'}3 \times 10^8\ \text{m/s}${'$'}、${'$'}6.67 \times 10^{-11}\ \text{N·m}^2/\text{kg}^2${'$'}
                   - 负指数不得丢失负号：${'$'}10^{-3}${'$'} 绝不能写成 ${'$'}10^3${'$'}
                   - 数量级不得降级或升级（如 ${'$'}10^6${'$'} 不能变成 ${'$'}10^3${'$'}）
                4. **单位**：用 \text{} 包裹：${'$'}\text{m/s}^2${'$'}、${'$'}\text{kg·m/s}${'$'}
                5. **物理量**：下标区分方向与编号：${'$'}v_0${'$'}、${'$'}a_x${'$'}、${'$'}F_{\text{合}}${'$'}；矢量保留方向说明
                6. **已知条件表**：物理量 | 数值与单位（含科学计数法） | 备注
            """.trimIndent()
            Subject.CHEMISTRY -> """
                1. **角色**：你是一个严谨的化学题目录入员，**化学式的上下标必须精确无误**！
                2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
                3. **分子式下标（极其重要）**：
                   - 原子个数必须用 _{}：${'$'}\text{H}_2\text{O}${'$'}、${'$'}\text{CO}_2${'$'}、${'$'}\text{H}_2\text{SO}_4${'$'}
                   - 多位下标：${'$'}\text{C}_6\text{H}_{12}\text{O}_6${'$'}
                4. **离子上标（极其重要）**：
                   - 化合价/电荷用 ^{}：${'$'}\text{Fe}^{2+}${'$'}、${'$'}\text{SO}_4^{2-}${'$'}、${'$'}\text{OH}^-${'$'}
                5. **化学方程式**：不可逆 \rightarrow；可逆 \rightleftharpoons；沉淀 ↓；气体 ↑
                6. **已知条件表**：化学量 | 数值与单位 | 状态/备注
            """.trimIndent()
            Subject.BIOLOGY -> """
                1. **角色**：你是一个严谨的生物题目录入员。
                2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
                3. **生物化学符号**：
                   - 生物大分子化学式精确处理下标：${'$'}\text{C}_6\text{H}_{12}\text{O}_6${'$'}、${'$'}\text{CO}_2${'$'}
                   - 遗传比例用分数：${'$'}\frac{3}{4}${'$'}、${'$'}\frac{1}{4}${'$'}；基因型用正体：${'$'}AaBb${'$'}
                   - ATP/ADP 等缩写直接使用
                4. **实验数据**：表格数据、坐标轴数值、实验组/对照组忠实提取
                5. **已知条件表**：实验条件、数值与单位、变量说明
            """.trimIndent()
            Subject.INTERDISCIPLINARY -> """
                1. **角色**：你是一个严谨的跨学科（生物+地理）题目录入员。
                2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
                3. **生物化学内容**：涉及化学式时精确处理下标/上标
                4. **地理内容**：地名、方位、气候、地形、数据（温度/降水/海拔）忠实提取
                5. **背景材料**：图文说明、图例、阅读材料提取到 knownDataMarkdown 字段
            """.trimIndent()
            Subject.GEOGRAPHY -> """
                1. **角色**：你是一个严谨的地理题目录入员。
                2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
                3. **内容提取**：完整保留地名、方位、气候/地形/地貌描述；数值数据（温度、降水量、海拔、时区、经纬度等）直接提取
                4. **背景材料**：图文说明、统计表、阅读材料提取到 knownDataMarkdown 字段
            """.trimIndent()
            Subject.HISTORY -> """
                1. **角色**：你是一个严谨的历史题目录入员。
                2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
                3. **内容提取**：完整保留人名、地名、年代、史料引文，不得修改或简化；保留原文标点、格式和段落结构
                4. **史料材料**：阅读材料、史料引文、图片说明提取到 knownDataMarkdown 字段
            """.trimIndent()
            Subject.CHINESE -> """
                1. **角色**：你是一个严谨的语文题目录入员。
                2. **多题拆分**：图片中所有独立题目分开编号：【题目 1】、【题目 2】…
                3. **内容提取**：完整保留诗文原文、作者、朝代、题干及所有小题；保留原文标点、段落结构和格式
                4. **阅读材料**：诗歌、古文、现代文阅读原文提取到 knownDataMarkdown 字段
            """.trimIndent()
            Subject.ENGLISH -> """
                1. **Role**: You are a meticulous English question transcriber.
                2. **Split questions**: Number all independent questions: [Q1], [Q2]…
                3. **Content rules**:
                   - Preserve complete text: reading passages, grammar questions, all options (A/B/C/D) with exact wording
                   - Maintain original formatting, punctuation and paragraph structure
                   - Vocabulary and cloze blanks: use underscores ____
                4. **Reading material**: Extract any reading passage or text to the knownDataMarkdown field
            """.trimIndent()
        }

        val jsonFormat = """

            **严格输出格式**：每道题必须按以下 JSON 数组输出，不要输出任何其他内容：
            ```json
            [
              {
                "number": 1,
                "fullLatexText": "完整题目文字（含小题和选项）",
                "knownDataMarkdown": "已知条件表或背景材料（无则留空\"\"）"
              }
            ]
            ```
            ${language.systemPromptSuffix}
        """.trimIndent()

        return rules + jsonFormat
    }

    private fun buildExpertSystemPrompt(expert: ExpertType, subject: Subject, language: OutputLanguage): String {
        val base = when (subject) {
            Subject.MATH, Subject.PHYSICS, Subject.CHEMISTRY -> when (expert) {
                ExpertType.A -> "你是一位严谨的${subject.rawValue}专家。请给出第一种解法，步骤清晰，使用 LaTeX 公式。"
                ExpertType.B -> "你是一位严谨的${subject.rawValue}专家。请给出与解法一**不同思路**的第二种解法，并在最后验证答案正确性。"
                ExpertType.C -> "你是一位资深${subject.rawValue}教授。请综合评估两种解法，指出各自优缺点，并给出最优解推荐。"
            }
            Subject.BIOLOGY, Subject.INTERDISCIPLINARY -> when (expert) {
                ExpertType.A -> "你是一位资深的${subject.rawValue}专家。请给出第一种分析思路和详细解答，关键步骤用 LaTeX 标注化学式或数据。"
                ExpertType.B -> "你是一位资深的${subject.rawValue}专家。请从**不同角度**给出第二种解答，与解法一互补，并点明评分要点。"
                ExpertType.C -> "你是一位资深${subject.rawValue}教研员。请综合评估两种解答，指出知识点覆盖情况，并给出最优参考答案。"
            }
            else -> when (expert) {
                ExpertType.A -> "你是一位资深的${subject.rawValue}教师。请给出第一种解题思路和详细参考答案，分析清晰，语言规范。"
                ExpertType.B -> "你是一位资深的${subject.rawValue}教师。请从**不同角度或切入点**给出第二种解答，与解法一互补，并点明评分要点。"
                ExpertType.C -> "你是一位经验丰富的${subject.rawValue}教研员。请综合评估两种解答的优缺点，指出答题规范性，并给出最优参考答案和得分建议。"
            }
        }
        return base + language.systemPromptSuffix
    }

    private fun buildExpertUserPrompt(problem: Problem, subject: Subject, solutionA: String = "", solutionB: String = ""): String {
        var prompt = if (subject.isSTEM) {
            "【题目 ${problem.number}】\n\n${problem.fullLatexText}\n\n已知条件：\n${problem.knownDataMarkdown}"
        } else {
            "【题目 ${problem.number}】\n\n${problem.fullLatexText}".let {
                if (problem.knownDataMarkdown.isNotEmpty()) "$it\n\n【背景材料】\n${problem.knownDataMarkdown}" else it
            }
        }
        if (solutionA.isNotEmpty() && solutionB.isNotEmpty()) {
            prompt += "\n\n---\n【解法一】\n$solutionA\n\n---\n【解法二】\n$solutionB"
        }
        return prompt
    }

    // ─── Response models ──────────────────────────────────────────────────────

    @Serializable
    private data class ApiError(val error: ErrorBody) {
        @Serializable data class ErrorBody(val message: String)
    }

    @Serializable
    private data class ChatCompletionResponse(val choices: List<Choice>) {
        @Serializable data class Choice(val message: Message)
        @Serializable data class Message(val content: String)
    }

    @Serializable
    private data class StreamChunk(val choices: List<Choice>) {
        @Serializable
        data class Choice(
            val delta: Delta,
            @SerialName("finish_reason") val finishReason: String? = null
        )
        @Serializable
        data class Delta(
            val content: String? = null,
            val reasoning: String? = null
        )
    }
}
