// AI_Tutor/Models/AppSettings.swift
import Foundation
import Observation

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

@Observable
class AppSettings {
    var apiKey: String = "" {
        didSet { KeychainService.save(apiKey, account: KeychainService.apiKeyAccount) }
    }
    var outputLanguage: OutputLanguage = .chinese

    init() {
        apiKey = KeychainService.load(account: KeychainService.apiKeyAccount) ?? ""
    }

    var hasApiKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }
}
