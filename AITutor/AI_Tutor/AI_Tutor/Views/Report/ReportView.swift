import SwiftUI

struct ReportView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab switcher
            Picker("", selection: $selectedTab) {
                Text("📄 完整报告").tag(0)
                Text("💬 追问 AI").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            if selectedTab == 0 {
                FullReportTab()
            } else {
                ChatFollowUpView()
            }
        }
        .navigationTitle("解题报告")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: appState.fullReport(),
                    preview: SharePreview(
                        "AI 解题报告",
                        systemImage: "doc.richtext"
                    )
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

// MARK: - Full Report Tab
struct FullReportTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DynamicKaTeXView(content: appState.fullReport())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
            }
        }
    }
}
