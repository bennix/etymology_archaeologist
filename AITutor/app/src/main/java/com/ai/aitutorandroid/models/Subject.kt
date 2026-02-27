package com.ai.aitutorandroid.models

enum class Subject(val rawValue: String, val icon: String, val isSTEM: Boolean) {
    MATH("数学", "calculate", true),
    PHYSICS("物理", "science", true),
    CHEMISTRY("化学", "biotech", true),
    BIOLOGY("生物", "eco", true),
    INTERDISCIPLINARY("跨学科", "extension", true),
    CHINESE("语文", "menu_book", false),
    ENGLISH("英语", "translate", false),
    HISTORY("历史", "history", false),
    GEOGRAPHY("地理", "public", false);

    companion object {
        fun fromRawValue(value: String) = entries.find { it.rawValue == value } ?: MATH
    }
}

enum class APIProvider(val rawValue: String) {
    TUZI("Tu-zi"),
    ZENMUX("Zenmux");
    companion object {
        fun fromRawValue(value: String) = entries.find { it.rawValue == value } ?: TUZI
    }
}

enum class OutputLanguage(val rawValue: String, val systemPromptSuffix: String) {
    CHINESE("中文", "\n\n请务必用中文回答。"),
    ENGLISH("English", "\n\nPlease answer in English."),
    JAPANESE("日本語", "\n\n必ず日本語で回答してください。"),
    FRENCH("Français", "\n\nVeuillez répondre en français."),
    SPANISH("Español", "\n\nPor favor responde en español."),
    GERMAN("Deutsch", "\n\nBitte antworte auf Deutsch.");
    companion object {
        fun fromRawValue(value: String) = entries.find { it.rawValue == value } ?: CHINESE
    }
}

enum class ZenmuxModel(val rawValue: String, val displayName: String) {
    GEMINI31PRO("google/gemini-3-pro-preview", "Gemini 3 Pro"),
    CLAUDE_SONNET46("anthropic/claude-sonnet-4.6", "Claude Sonnet 4.6"),
    QWEN35PLUS("qwen/qwen3.5-plus", "Qwen 3.5 Plus");
    companion object {
        fun fromRawValue(value: String) = entries.find { it.rawValue == value } ?: GEMINI31PRO
    }
}

enum class TuziModel(val rawValue: String, val displayName: String) {
    GEMINI3PRO("gemini-3-pro-preview-thinking", "Gemini 3 Pro"),
    CLAUDE_SONNET46("claude-sonnet-4-6", "Claude Sonnet 4.6");
    companion object {
        fun fromRawValue(value: String) = entries.find { it.rawValue == value } ?: GEMINI3PRO
    }
}

data class APIConfig(
    val baseURL: String,
    val apiKey: String,
    val gptModel: String,
    val defaultModel: String,
    val providerName: String
) {
    companion object {
        fun tuzi(apiKey: String) = APIConfig(
            baseURL = "https://api.tu-zi.com/v1/chat/completions",
            apiKey = apiKey,
            gptModel = "chatgpt-4o-latest",
            defaultModel = "claude-sonnet-4-6",
            providerName = "Tu-zi"
        )
        fun zenmux(apiKey: String) = APIConfig(
            baseURL = "https://zenmux.ai/api/v1/chat/completions",
            apiKey = apiKey,
            gptModel = "openai/gpt-4o",
            defaultModel = "anthropic/claude-sonnet-4.6",
            providerName = "Zenmux"
        )
    }
}
