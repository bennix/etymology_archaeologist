// AI_Tutor/AI_TutorApp.swift
import SwiftUI

@main
struct AI_TutorApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if !appState.settings.hasApiKey {
            APIKeySetupView()
        } else {
            MainTabView()
        }
    }
}
