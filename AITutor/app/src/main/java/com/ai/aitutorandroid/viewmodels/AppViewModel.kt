package com.ai.aitutorandroid.viewmodels

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.ai.aitutorandroid.models.*
import com.ai.aitutorandroid.services.KeystoreService
import com.ai.aitutorandroid.services.ProblemParser
import com.ai.aitutorandroid.services.ZenmuxService
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AppViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val zenmuxService: ZenmuxService,
    private val keystoreService: KeystoreService
) : ViewModel() {

    private val prefs = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)

    // ─── Settings ─────────────────────────────────────────────────────────────
    private val _settings = MutableStateFlow(loadSettings())
    val settings: StateFlow<AppSettings> = _settings.asStateFlow()

    fun updateSettings(update: (AppSettings) -> AppSettings) {
        _settings.update(update)
        saveSettings(_settings.value)
    }

    private fun loadSettings() = AppSettings(
        zenmuxApiKey = keystoreService.load(KeystoreService.ZENMUX_API_KEY) ?: "",
        tuziApiKey = keystoreService.load(KeystoreService.TUZI_API_KEY) ?: "",
        preferredProvider = APIProvider.fromRawValue(prefs.getString("preferredProvider", APIProvider.TUZI.rawValue) ?: ""),
        selectedSubject = Subject.fromRawValue(prefs.getString("selectedSubject", Subject.MATH.rawValue) ?: ""),
        outputLanguage = OutputLanguage.fromRawValue(prefs.getString("outputLanguage", OutputLanguage.CHINESE.rawValue) ?: ""),
        zenmuxExpertAModel = ZenmuxModel.fromRawValue(prefs.getString("zenmuxExpertAModel", ZenmuxModel.GEMINI31PRO.rawValue) ?: ""),
        zenmuxExpertBModel = ZenmuxModel.fromRawValue(prefs.getString("zenmuxExpertBModel", ZenmuxModel.CLAUDE_SONNET46.rawValue) ?: ""),
        zenmuxExpertCModel = ZenmuxModel.fromRawValue(prefs.getString("zenmuxExpertCModel", ZenmuxModel.QWEN35PLUS.rawValue) ?: ""),
        tuziExpertAModel = TuziModel.fromRawValue(prefs.getString("tuziExpertAModel", TuziModel.GEMINI3PRO.rawValue) ?: ""),
        tuziExpertBModel = TuziModel.fromRawValue(prefs.getString("tuziExpertBModel", TuziModel.CLAUDE_SONNET46.rawValue) ?: ""),
        tuziExpertCModel = TuziModel.fromRawValue(prefs.getString("tuziExpertCModel", TuziModel.GEMINI3PRO.rawValue) ?: "")
    )

    private fun saveSettings(s: AppSettings) {
        keystoreService.save(s.zenmuxApiKey, KeystoreService.ZENMUX_API_KEY)
        keystoreService.save(s.tuziApiKey, KeystoreService.TUZI_API_KEY)
        prefs.edit()
            .putString("preferredProvider", s.preferredProvider.rawValue)
            .putString("selectedSubject", s.selectedSubject.rawValue)
            .putString("outputLanguage", s.outputLanguage.rawValue)
            .putString("zenmuxExpertAModel", s.zenmuxExpertAModel.rawValue)
            .putString("zenmuxExpertBModel", s.zenmuxExpertBModel.rawValue)
            .putString("zenmuxExpertCModel", s.zenmuxExpertCModel.rawValue)
            .putString("tuziExpertAModel", s.tuziExpertAModel.rawValue)
            .putString("tuziExpertBModel", s.tuziExpertBModel.rawValue)
            .putString("tuziExpertCModel", s.tuziExpertCModel.rawValue)
            .apply()
    }

    // ─── Image state ──────────────────────────────────────────────────────────
    private val _capturedImages = MutableStateFlow<List<Bitmap>>(emptyList())
    val capturedImages: StateFlow<List<Bitmap>> = _capturedImages.asStateFlow()

    fun addImages(bitmaps: List<Bitmap>) {
        _capturedImages.update { current -> (current + bitmaps).take(5) }
    }

    fun removeImage(index: Int) {
        _capturedImages.update { it.toMutableList().also { list -> list.removeAt(index) } }
    }

    fun loadBitmapFromUri(uri: Uri): Bitmap? = try {
        context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) }
    } catch (e: Exception) { null }

    // ─── Extraction state ─────────────────────────────────────────────────────
    private val _isExtracting = MutableStateFlow(false)
    val isExtracting: StateFlow<Boolean> = _isExtracting.asStateFlow()

    private val _extractionError = MutableStateFlow<String?>(null)
    val extractionError: StateFlow<String?> = _extractionError.asStateFlow()

    private val _problems = MutableStateFlow<List<Problem>>(emptyList())
    val problems: StateFlow<List<Problem>> = _problems.asStateFlow()

    fun extractProblems(onSuccess: () -> Unit) {
        val cfg = _settings.value.extractionConfig ?: return
        val images = _capturedImages.value
        _problems.value = emptyList()   // clear stale results from any previous run
        _isExtracting.value = true
        _extractionError.value = null
        viewModelScope.launch {
            try {
                val raw = zenmuxService.extractProblems(images, cfg, _settings.value.selectedSubject, _settings.value.outputLanguage)
                _problems.value = ProblemParser.parse(raw)
                onSuccess()
            } catch (e: Exception) {
                _extractionError.value = e.message ?: "提取失败"
            } finally {
                _isExtracting.value = false
            }
        }
    }

    fun clearExtractionError() { _extractionError.value = null }

    // ─── Problem editing ──────────────────────────────────────────────────────
    fun toggleProblemSelection(problemId: String) {
        _problems.update { list -> list.map { if (it.id == problemId) it.copy(isSelected = !it.isSelected) else it } }
    }

    fun mergeProblems(index1: Int, index2: Int) {
        _problems.update { list ->
            if (index1 >= list.size || index2 >= list.size) return@update list
            val p1 = list[index1]; val p2 = list[index2]
            val merged = p1.copy(
                fullLatexText = "${p1.fullLatexText}\n\n${p2.fullLatexText}",
                knownDataMarkdown = listOf(p1.knownDataMarkdown, p2.knownDataMarkdown).filter { it.isNotEmpty() }.joinToString("\n")
            )
            val newList = list.toMutableList()
            newList[index1] = merged
            newList.removeAt(index2)
            newList.mapIndexed { i, p -> p.copy(number = i + 1) }
        }
    }

    // ─── Solution state ───────────────────────────────────────────────────────
    private val _solutions = MutableStateFlow<Map<String, List<ExpertSolution>>>(emptyMap())
    val solutions: StateFlow<Map<String, List<ExpertSolution>>> = _solutions.asStateFlow()

    private var solvingJobs = mutableListOf<Job>()

    fun solution(problemId: String, expert: ExpertType): ExpertSolution? =
        _solutions.value[problemId]?.find { it.expert == expert }

    fun startSolving(onAllComplete: () -> Unit) {
        val cfg = _settings.value.activeConfig ?: return
        val selectedProblems = _problems.value.filter { it.isSelected }
        if (selectedProblems.isEmpty()) return

        // Initialise solution slots
        _solutions.value = selectedProblems.associate { problem ->
            problem.id to listOf(
                ExpertSolution(expert = ExpertType.A),
                ExpertSolution(expert = ExpertType.B),
                ExpertSolution(expert = ExpertType.C)
            )
        }

        selectedProblems.forEach { problem ->
            val jobA = viewModelScope.launch { streamExpert(problem, ExpertType.A, cfg) }
            val jobB = viewModelScope.launch { streamExpert(problem, ExpertType.B, cfg) }
            solvingJobs += jobA; solvingJobs += jobB

            // After A and B complete, stream Expert C
            viewModelScope.launch {
                jobA.join(); jobB.join()
                val sA = solution(problem.id, ExpertType.A)?.content ?: ""
                val sB = solution(problem.id, ExpertType.B)?.content ?: ""
                streamExpert(problem, ExpertType.C, cfg, solutionA = sA, solutionB = sB)
                // Check if all problems done
                if (selectedProblems.all { p ->
                    solution(p.id, ExpertType.C)?.isComplete == true ||
                    solution(p.id, ExpertType.C)?.errorMessage != null
                }) { onAllComplete() }
            }
        }
    }

    private suspend fun streamExpert(
        problem: Problem, expert: ExpertType, config: APIConfig,
        solutionA: String = "", solutionB: String = ""
    ) {
        val modelId = when (expert) {
            ExpertType.A -> _settings.value.expertAModelId
            ExpertType.B -> _settings.value.expertBModelId
            ExpertType.C -> _settings.value.expertCModelId
        }
        updateSolution(problem.id, expert) { it.copy(isStreaming = true) }
        try {
            zenmuxService.streamSolution(problem, expert, modelId, config,
                _settings.value.selectedSubject, _settings.value.outputLanguage,
                solutionA, solutionB
            ).collect { chunk ->
                updateSolution(problem.id, expert) { it.copy(content = it.content + chunk) }
            }
            updateSolution(problem.id, expert) { it.copy(isStreaming = false, isComplete = true) }
        } catch (e: Exception) {
            updateSolution(problem.id, expert) { it.copy(isStreaming = false, errorMessage = e.message) }
        }
    }

    private fun updateSolution(problemId: String, expert: ExpertType, update: (ExpertSolution) -> ExpertSolution) {
        _solutions.update { map ->
            val list = map[problemId] ?: return@update map
            map + (problemId to list.map { if (it.expert == expert) update(it) else it })
        }
    }

    fun cancelSolving() { solvingJobs.forEach { it.cancel() }; solvingJobs.clear() }

    // ─── Chat state ───────────────────────────────────────────────────────────
    private val _reportMessages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val reportMessages: StateFlow<List<ChatMessage>> = _reportMessages.asStateFlow()

    fun sendChatMessage(userText: String) {
        val cfg = _settings.value.activeConfig ?: return
        _reportMessages.update { it + ChatMessage(role = ChatRole.USER, content = userText) }
        val assistantMsg = ChatMessage(role = ChatRole.ASSISTANT, content = "", isStreaming = true)
        _reportMessages.update { it + assistantMsg }
        viewModelScope.launch {
            try {
                val allMessages = _reportMessages.value.dropLast(1) // exclude the empty assistant slot
                zenmuxService.streamChat(
                    allMessages, cfg, _settings.value.expertCModelId,
                    _settings.value.selectedSubject, _settings.value.outputLanguage,
                    reportContext = fullReport()
                ).collect { chunk ->
                    _reportMessages.update { list ->
                        list.map { if (it.id == assistantMsg.id) it.copy(content = it.content + chunk) else it }
                    }
                }
                _reportMessages.update { list ->
                    list.map { if (it.id == assistantMsg.id) it.copy(isStreaming = false) else it }
                }
            } catch (e: Exception) {
                _reportMessages.update { list ->
                    list.map { if (it.id == assistantMsg.id) it.copy(content = "错误: ${e.message}", isStreaming = false) else it }
                }
            }
        }
    }

    // ─── Report ───────────────────────────────────────────────────────────────
    fun fullReport(): String {
        val sb = StringBuilder()
        _problems.value.filter { it.isSelected }.forEach { problem ->
            sb.appendLine("## 题目 ${problem.number}")
            sb.appendLine(problem.fullLatexText)
            if (problem.knownDataMarkdown.isNotEmpty()) {
                sb.appendLine("\n**已知条件：**\n${problem.knownDataMarkdown}")
            }
            solution(problem.id, ExpertType.A)?.let {
                sb.appendLine("\n### 解法一\n${it.content}")
            }
            solution(problem.id, ExpertType.B)?.let {
                sb.appendLine("\n### 解法二\n${it.content}")
            }
            solution(problem.id, ExpertType.C)?.let {
                sb.appendLine("\n### 专家点评\n${it.content}")
            }
            sb.appendLine()
        }
        return sb.toString()
    }

    // ─── Reset ────────────────────────────────────────────────────────────────
    fun resetToInput() {
        cancelSolving()
        _capturedImages.value = emptyList()
        _problems.value = emptyList()
        _solutions.value = emptyMap()
        _reportMessages.value = emptyList()
        _isExtracting.value = false
        _extractionError.value = null
    }

    // ─── API key test ─────────────────────────────────────────────────────────
    private val _testConnectionResult = MutableStateFlow<Boolean?>(null)
    val testConnectionResult: StateFlow<Boolean?> = _testConnectionResult.asStateFlow()

    private val _isTestingConnection = MutableStateFlow(false)
    val isTestingConnection: StateFlow<Boolean> = _isTestingConnection.asStateFlow()

    fun testConnection(config: APIConfig) {
        viewModelScope.launch {
            _isTestingConnection.value = true
            _testConnectionResult.value = null
            _testConnectionResult.value = zenmuxService.testConnection(config)
            _isTestingConnection.value = false
        }
    }
    fun clearTestResult() { _testConnectionResult.value = null }
}
