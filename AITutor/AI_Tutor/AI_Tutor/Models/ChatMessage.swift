// AI_Tutor/Models/ChatMessage.swift
import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    var role: Role
    var content: String
    var isStreaming: Bool = false

    enum Role { case user, assistant }
}
