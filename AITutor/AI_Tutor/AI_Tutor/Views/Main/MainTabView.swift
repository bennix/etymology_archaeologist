import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ImageInputView()
            }
            .tabItem {
                Label("分析", systemImage: "camera.viewfinder")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape.fill")
            }
        }
    }
}
