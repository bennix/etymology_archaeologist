// AI_Tutor/Views/Extraction/ProblemConfirmationView.swift
import SwiftUI
import UIKit

struct ProblemConfirmationView: View {
    @Environment(AppState.self) private var appState
    @State private var navigateToSolving = false
    @State private var isKeyboardVisible = false

    var selectedCount: Int { appState.problems.filter(\.isSelected).count }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top: problem list ────────────────────────────────────────
            ScrollView {
                VStack(spacing: 14) {
                    // Header banner
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("成功提取 \(appState.problems.count) 道题目")
                            .font(.subheadline.bold())
                        Spacer()
                        Button("全选")  { appState.problems.forEach { $0.isSelected = true  } }
                            .font(.caption)
                        Button("清空")  { appState.problems.forEach { $0.isSelected = false } }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Problem cards + merge buttons
                    ForEach(Array(appState.problems.enumerated()), id: \.element.id) { index, problem in
                        ProblemCard(problem: problem)

                        if index < appState.problems.count - 1 {
                            Button {
                                mergeProblems(at: index)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.arrow.down").font(.caption2)
                                    Text("与下题合并").font(.caption)
                                }
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Color.orange.opacity(0.08))
                                .clipShape(Capsule())
                            }
                        }
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // ── Bottom: original image panel ─────────────────────────────
            if !appState.capturedImages.isEmpty {
                ZoomableImagePager(images: appState.capturedImages)
                    .frame(height: isKeyboardVisible ? 120 : 240)
                    .clipped()
            }

            // ── Sticky CTA ───────────────────────────────────────────────
            Divider()
            Button {
                navigateToSolving = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(selectedCount > 0
                         ? "发送 \(selectedCount) 道题给 AI 专家解答"
                         : "请选择至少一道题目")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedCount > 0 ? Color.blue : Color.gray.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selectedCount == 0)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
        .navigationTitle("确认题目")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .navigationDestination(isPresented: $navigateToSolving) {
            SolvingContainerView()
        }
    }

    private func mergeProblems(at index: Int) {
        guard index + 1 < appState.problems.count else { return }
        let upper = appState.problems[index]
        let lower = appState.problems[index + 1]
        upper.fullLatexText += "\n\n" + lower.fullLatexText
        if !lower.knownDataMarkdown.isEmpty {
            upper.knownDataMarkdown = upper.knownDataMarkdown.isEmpty
                ? lower.knownDataMarkdown
                : upper.knownDataMarkdown + "\n\n" + lower.knownDataMarkdown
        }
        appState.problems.remove(at: index + 1)
        for (i, p) in appState.problems.enumerated() { p.number = i + 1 }
    }
}

// MARK: - Problem Card
private struct ProblemCard: View {
    @Bindable var problem: Problem
    @State private var isEditing  = false
    @State private var editText   = ""
    @State private var isExpanded = true
    @State private var cursorOffset = 0  // persists insertion point across edit sessions

    @State private var cachedSegments: [ProblemSegment] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──────────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: problem.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(problem.isSelected ? .blue : .secondary)
                    .font(.title3)
                    .onTapGesture { problem.isSelected.toggle() }

                Text("题目 \(problem.number)")
                    .font(.headline)
                    .foregroundStyle(problem.isSelected ? .primary : .secondary)

                Spacer()

                // Edit / Save button
                Button {
                    if isEditing {
                        problem.fullLatexText = editText
                        isEditing = false
                    } else {
                        editText  = problem.fullLatexText
                        isEditing = true
                    }
                } label: {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                        .foregroundStyle(isEditing ? .green : .secondary)
                }

                // Expand / collapse
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if isExpanded {
                Divider().padding(.horizontal)

                if isEditing {
                    // ── Inline LaTeX / Markdown editor ──────────────────
                    PersistentCursorTextEditor(text: $editText, cursorOffset: $cursorOffset)
                        .frame(minHeight: 140)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                } else {
                    // ── Segment-based rendering ──────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(cachedSegments.indices, id: \.self) { i in
                            segmentView(for: cachedSegments[i])
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }

                // ── Known data ───────────────────────────────────────────
                if !problem.knownDataMarkdown.isEmpty {
                    Divider().padding(.horizontal).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已知条件")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                        DynamicKaTeXView(content: problem.knownDataMarkdown)
                            .padding(.horizontal, 8)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    problem.isSelected ? Color.blue.opacity(0.5) : Color(uiColor: .systemGray4),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .animation(.easeInOut(duration: 0.15), value: problem.isSelected)
        .onAppear { cachedSegments = ProblemSegment.parse(problem.fullLatexText) }
        .onChange(of: problem.fullLatexText) { _, newText in
            cachedSegments = ProblemSegment.parse(newText)
        }
    }

    @ViewBuilder
    private func segmentView(for seg: ProblemSegment) -> some View {
        switch seg {
        case .body(let text):
            DynamicKaTeXView(content: text)

        case .metaPost(let code):
            CollapsibleBlock(
                label: "MetaPost 图形代码",
                icon: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
            }

        case .figureDesc(let desc):
            CollapsibleBlock(
                label: "图形描述",
                icon: {
                    Image(systemName: "photo")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
            ) {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Cursor-preserving text editor
/// UITextView wrapper that persists the insertion-point position across editing sessions.
/// When `isEditing` toggles back to true the cursor returns to where the user left off,
/// instead of jumping to the beginning as SwiftUI's TextEditor would.
private struct PersistentCursorTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorOffset: Int

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
        tv.backgroundColor = UIColor.secondarySystemBackground
        tv.layer.cornerRadius = 8
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Guard prevents overwriting cursor mid-typing: textViewDidChange keeps
        // uiView.text == text, so this branch only runs when entering edit mode.
        guard uiView.text != text else { return }
        uiView.text = text
        let offset = min(cursorOffset, text.utf16.count)
        if let pos = uiView.position(from: uiView.beginningOfDocument, offset: offset) {
            uiView.selectedTextRange = uiView.textRange(from: pos, to: pos)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: PersistentCursorTextEditor
        init(_ parent: PersistentCursorTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let range = textView.selectedTextRange else { return }
            parent.cursorOffset = textView.offset(from: textView.beginningOfDocument, to: range.start)
        }
    }
}
