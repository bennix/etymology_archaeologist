// AI_Tutor/Models/AppSettings.swift
import Foundation
import Observation

// MARK: - Subject
enum Subject: String, CaseIterable, Identifiable {
    case math             = "数学"
    case physics          = "物理"
    case chemistry        = "化学"
    case biology          = "生物"
    case interdisciplinary = "跨学科"
    case chinese          = "语文"
    case english          = "英语"
    case history          = "历史"
    case geography        = "地理"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .math:              return "function"
        case .physics:           return "atom"
        case .chemistry:         return "flask.fill"
        case .biology:           return "leaf.fill"
        case .interdisciplinary: return "puzzlepiece.fill"
        case .chinese:           return "character.book.closed.fill"
        case .english:           return "a.book.closed.fill"
        case .history:           return "clock.arrow.circlepath"
        case .geography:         return "globe.asia.australia.fill"
        }
    }

    /// Whether the expert system prompt should use "专家/教授" framing (vs "教师/教研员")
    var isSTEM: Bool {
        switch self {
        case .math, .physics, .chemistry, .biology, .interdisciplinary: return true
        default: return false
        }
    }
}

// MARK: - Zenmux model options
enum ZenmuxModel: String, CaseIterable, Identifiable {
    case gemini31Pro    = "google/gemini-3-pro-preview"
    case claudeSonnet46 = "anthropic/claude-sonnet-4.6"
    case qwen35Plus     = "qwen/qwen3.5-plus"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini31Pro:    return "Gemini 3.1 Pro"
        case .claudeSonnet46: return "Claude Sonnet 4.6"
        case .qwen35Plus:     return "Qwen 3.5 Plus"
        }
    }
}

// MARK: - Tu-zi model options
enum TuziModel: String, CaseIterable, Identifiable {
    case gemini3Pro     = "gemini-3-pro-preview-thinking"
    case claudeSonnet46 = "claude-sonnet-4-6"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini3Pro:     return "Gemini 3 Pro"
        case .claudeSonnet46: return "Claude Sonnet 4.6"
        }
    }
}

// MARK: - API provider configuration
struct APIConfig {
    let baseURL: String
    let apiKey: String
    let extractionModel: String  // Gemini model used for image extraction
    let defaultModel: String     // used for connection test and follow-up chat fallback
    let providerName: String

    static func tuzi(apiKey: String) -> APIConfig {
        APIConfig(
            baseURL: "https://api.tu-zi.com/v1/chat/completions",
            apiKey: apiKey,
            extractionModel: "gemini-3-pro-preview-thinking",
            defaultModel: "claude-sonnet-4-6",
            providerName: "Tu-zi"
        )
    }

    static func zenmux(apiKey: String) -> APIConfig {
        APIConfig(
            baseURL: "https://zenmux.ai/api/v1/chat/completions",
            apiKey: apiKey,
            // GPT-4o for extraction: Zenmux's Gemini proxy converts base64 to a temp
            // file path which Vertex AI rejects (requires gs:// or HTTPS URI).
            // GPT-4o accepts base64 inline images directly.
            extractionModel: "openai/gpt-4o",
            defaultModel: "anthropic/claude-sonnet-4.6",
            providerName: "Zenmux"
        )
    }
}

// MARK: - Output language
enum OutputLanguage: String, CaseIterable, Identifiable {
    case chinese  = "中文"
    case english  = "English"
    case japanese = "日本語"
    case french   = "Français"
    case spanish  = "Español"
    case german   = "Deutsch"

    var id: String { rawValue }

    var systemPromptSuffix: String {
        switch self {
        case .chinese:  return "\n\n请务必用中文回答。"
        case .english:  return "\n\nPlease answer in English."
        case .japanese: return "\n\n必ず日本語で回答してください。"
        case .french:   return "\n\nVeuillez répondre en français."
        case .spanish:  return "\n\nPor favor responde en español."
        case .german:   return "\n\nBitte antworte auf Deutsch."
        }
    }
}

// MARK: - API provider selection
enum APIProvider: String, CaseIterable, Identifiable {
    case tuzi   = "Tu-zi"
    case zenmux = "Zenmux"
    var id: String { rawValue }
}

// MARK: - AppSettings
@Observable
class AppSettings {
    /// Zenmux API key (existing users' key is preserved — same Keychain account)
    var zenmuxApiKey: String = "" {
        didSet { KeychainService.save(zenmuxApiKey, account: KeychainService.zenmuxApiKeyAccount) }
    }
    /// Tu-zi API key
    var tuziApiKey: String = "" {
        didSet { KeychainService.save(tuziApiKey, account: KeychainService.tuziApiKeyAccount) }
    }
    /// User-selected provider; stored in UserDefaults
    var preferredProvider: APIProvider = .tuzi {
        didSet { UserDefaults.standard.set(preferredProvider.rawValue, forKey: "preferredProvider") }
    }

    var outputLanguage: OutputLanguage = .chinese

    /// Currently selected subject (affects extraction + solving prompts)
    var selectedSubject: Subject = .math {
        didSet { UserDefaults.standard.set(selectedSubject.rawValue, forKey: "selectedSubject") }
    }

    // MARK: Zenmux per-expert model selections
    var zenmuxExpertAModel: ZenmuxModel = .gemini31Pro {
        didSet { UserDefaults.standard.set(zenmuxExpertAModel.rawValue, forKey: "zenmuxExpertAModel") }
    }
    var zenmuxExpertBModel: ZenmuxModel = .claudeSonnet46 {
        didSet { UserDefaults.standard.set(zenmuxExpertBModel.rawValue, forKey: "zenmuxExpertBModel") }
    }
    var zenmuxExpertCModel: ZenmuxModel = .qwen35Plus {
        didSet { UserDefaults.standard.set(zenmuxExpertCModel.rawValue, forKey: "zenmuxExpertCModel") }
    }

    // MARK: Tu-zi per-expert model selections
    var tuziExpertAModel: TuziModel = .gemini3Pro {
        didSet { UserDefaults.standard.set(tuziExpertAModel.rawValue, forKey: "tuziExpertAModel") }
    }
    var tuziExpertBModel: TuziModel = .claudeSonnet46 {
        didSet { UserDefaults.standard.set(tuziExpertBModel.rawValue, forKey: "tuziExpertBModel") }
    }
    var tuziExpertCModel: TuziModel = .gemini3Pro {
        didSet { UserDefaults.standard.set(tuziExpertCModel.rawValue, forKey: "tuziExpertCModel") }
    }

    // MARK: Convenience — active provider's model IDs (used by ZenmuxService)
    var expertAModelId: String {
        switch preferredProvider {
        case .zenmux: return zenmuxExpertAModel.rawValue
        case .tuzi:   return tuziExpertAModel.rawValue
        }
    }
    var expertBModelId: String {
        switch preferredProvider {
        case .zenmux: return zenmuxExpertBModel.rawValue
        case .tuzi:   return tuziExpertBModel.rawValue
        }
    }
    var expertCModelId: String {
        switch preferredProvider {
        case .zenmux: return zenmuxExpertCModel.rawValue
        case .tuzi:   return tuziExpertCModel.rawValue
        }
    }

    // MARK: Convenience — display names for UI labels
    var expertADisplayName: String {
        switch preferredProvider {
        case .zenmux: return zenmuxExpertAModel.displayName
        case .tuzi:   return tuziExpertAModel.displayName
        }
    }
    var expertBDisplayName: String {
        switch preferredProvider {
        case .zenmux: return zenmuxExpertBModel.displayName
        case .tuzi:   return tuziExpertBModel.displayName
        }
    }
    var expertCDisplayName: String {
        switch preferredProvider {
        case .zenmux: return zenmuxExpertCModel.displayName
        case .tuzi:   return tuziExpertCModel.displayName
        }
    }

    init() {
        zenmuxApiKey = KeychainService.load(account: KeychainService.zenmuxApiKeyAccount) ?? ""
        tuziApiKey   = KeychainService.load(account: KeychainService.tuziApiKeyAccount)   ?? ""

        if let saved = UserDefaults.standard.string(forKey: "preferredProvider"),
           let provider = APIProvider(rawValue: saved) {
            preferredProvider = provider
        }
        if let saved = UserDefaults.standard.string(forKey: "selectedSubject"),
           let subject = Subject(rawValue: saved) {
            selectedSubject = subject
        }
        if let saved = UserDefaults.standard.string(forKey: "zenmuxExpertAModel"),
           let model = ZenmuxModel(rawValue: saved) {
            zenmuxExpertAModel = model
        }
        if let saved = UserDefaults.standard.string(forKey: "zenmuxExpertBModel"),
           let model = ZenmuxModel(rawValue: saved) {
            zenmuxExpertBModel = model
        }
        if let saved = UserDefaults.standard.string(forKey: "zenmuxExpertCModel"),
           let model = ZenmuxModel(rawValue: saved) {
            zenmuxExpertCModel = model
        }
        if let saved = UserDefaults.standard.string(forKey: "tuziExpertAModel"),
           let model = TuziModel(rawValue: saved) {
            tuziExpertAModel = model
        }
        if let saved = UserDefaults.standard.string(forKey: "tuziExpertBModel"),
           let model = TuziModel(rawValue: saved) {
            tuziExpertBModel = model
        }
        if let saved = UserDefaults.standard.string(forKey: "tuziExpertCModel"),
           let model = TuziModel(rawValue: saved) {
            tuziExpertCModel = model
        }
    }

    /// True when at least one key is configured
    var hasAnyApiKey: Bool {
        !zenmuxApiKey.trimmingCharacters(in: .whitespaces).isEmpty ||
        !tuziApiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Returns config for the preferred provider, falling back to whichever key is available
    var activeConfig: APIConfig? {
        let t = tuziApiKey.trimmingCharacters(in: .whitespaces)
        let z = zenmuxApiKey.trimmingCharacters(in: .whitespaces)

        switch preferredProvider {
        case .tuzi:
            if !t.isEmpty { return .tuzi(apiKey: t) }
            if !z.isEmpty { return .zenmux(apiKey: z) }
        case .zenmux:
            if !z.isEmpty { return .zenmux(apiKey: z) }
            if !t.isEmpty { return .tuzi(apiKey: t) }
        }
        return nil
    }

    /// Config for image extraction — prefers Zenmux (GPT-4o, base64 works).
    /// Falls back to Tu-zi (Gemini 3 Pro Thinking) when Zenmux is unconfigured.
    /// Note: Zenmux's Gemini proxy cannot handle base64 images (Vertex AI rejects temp file URIs),
    /// so extraction on Zenmux stays on GPT-4o; Tu-zi uses Gemini.
    var extractionConfig: APIConfig? {
        let z = zenmuxApiKey.trimmingCharacters(in: .whitespaces)
        let t = tuziApiKey.trimmingCharacters(in: .whitespaces)
        if !z.isEmpty { return .zenmux(apiKey: z) }
        if !t.isEmpty { return .tuzi(apiKey: t) }
        return nil
    }
}
