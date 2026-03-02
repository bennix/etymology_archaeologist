// AI_Tutor/Views/Components/CollapsibleBlock.swift
import SwiftUI

/// Collapsible card used in ProblemConfirmationView for MetaPost and figure-description blocks.
struct CollapsibleBlock<Label: View, Content: View>: View {
    let label: String
    @ViewBuilder let icon: () -> Label
    @ViewBuilder let content: () -> Content

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Tap-to-toggle header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    icon()
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Divider()
                content()
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
