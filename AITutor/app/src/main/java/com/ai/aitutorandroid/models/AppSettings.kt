package com.ai.aitutorandroid.models

data class AppSettings(
    val zenmuxApiKey: String = "",
    val tuziApiKey: String = "",
    val preferredProvider: APIProvider = APIProvider.TUZI,
    val outputLanguage: OutputLanguage = OutputLanguage.CHINESE,
    val selectedSubject: Subject = Subject.MATH,
    val zenmuxExpertAModel: ZenmuxModel = ZenmuxModel.GEMINI31PRO,
    val zenmuxExpertBModel: ZenmuxModel = ZenmuxModel.CLAUDE_SONNET46,
    val zenmuxExpertCModel: ZenmuxModel = ZenmuxModel.QWEN35PLUS,
    val tuziExpertAModel: TuziModel = TuziModel.GEMINI3PRO,
    val tuziExpertBModel: TuziModel = TuziModel.CLAUDE_SONNET46,
    val tuziExpertCModel: TuziModel = TuziModel.GEMINI3PRO
) {
    val hasAnyApiKey: Boolean
        get() = zenmuxApiKey.isNotBlank() || tuziApiKey.isNotBlank()

    val expertAModelId: String get() = when (preferredProvider) {
        APIProvider.ZENMUX -> zenmuxExpertAModel.rawValue
        APIProvider.TUZI -> tuziExpertAModel.rawValue
    }
    val expertBModelId: String get() = when (preferredProvider) {
        APIProvider.ZENMUX -> zenmuxExpertBModel.rawValue
        APIProvider.TUZI -> tuziExpertBModel.rawValue
    }
    val expertCModelId: String get() = when (preferredProvider) {
        APIProvider.ZENMUX -> zenmuxExpertCModel.rawValue
        APIProvider.TUZI -> tuziExpertCModel.rawValue
    }
    val expertADisplayName: String get() = when (preferredProvider) {
        APIProvider.ZENMUX -> zenmuxExpertAModel.displayName
        APIProvider.TUZI -> tuziExpertAModel.displayName
    }
    val expertBDisplayName: String get() = when (preferredProvider) {
        APIProvider.ZENMUX -> zenmuxExpertBModel.displayName
        APIProvider.TUZI -> tuziExpertBModel.displayName
    }
    val expertCDisplayName: String get() = when (preferredProvider) {
        APIProvider.ZENMUX -> zenmuxExpertCModel.displayName
        APIProvider.TUZI -> tuziExpertCModel.displayName
    }

    val activeConfig: APIConfig? get() {
        val t = tuziApiKey.trim(); val z = zenmuxApiKey.trim()
        return when (preferredProvider) {
            APIProvider.TUZI -> when {
                t.isNotEmpty() -> APIConfig.tuzi(t)
                z.isNotEmpty() -> APIConfig.zenmux(z)
                else -> null
            }
            APIProvider.ZENMUX -> when {
                z.isNotEmpty() -> APIConfig.zenmux(z)
                t.isNotEmpty() -> APIConfig.tuzi(t)
                else -> null
            }
        }
    }

    val extractionConfig: APIConfig? get() {
        val z = zenmuxApiKey.trim(); val t = tuziApiKey.trim()
        return when {
            z.isNotEmpty() -> APIConfig.zenmux(z)
            t.isNotEmpty() -> APIConfig.tuzi(t)
            else -> null
        }
    }
}
