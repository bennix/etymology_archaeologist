import SwiftUI
import PhotosUI

struct ImageInputView: View {
    @Environment(AppState.self) private var appState
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showFilePicker = false
    @State private var navigateToExtraction = false

    private let maxImages = 5

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Subject picker
                subjectPicker

                // Action buttons
                buttonRow

                // Image grid or empty state
                if appState.capturedImages.isEmpty {
                    emptyStateView
                } else {
                    imageGrid
                    analyzeButton
                }
            }
            .padding()
        }
        .navigationTitle("AI \(appState.settings.selectedSubject.rawValue)导师")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !appState.capturedImages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        appState.capturedImages = []
                    } label: {
                        Label("清除全部", systemImage: "trash")
                    }
                }
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PHPickerWrapper(
                images: Binding(
                    get: { appState.capturedImages },
                    set: { appState.capturedImages = $0 }
                ),
                selectionLimit: max(1, maxImages - appState.capturedImages.count)
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { img in
                appState.capturedImages.append(img)
                showCamera = false
            }
        }
        .navigationDestination(isPresented: $navigateToExtraction) {
            ExtractionLoadingView()
        }
        .onChange(of: appState.navigationResetTrigger) { _, _ in
            navigateToExtraction = false
        }
    }

    // MARK: - Subject picker

    private var subjectPicker: some View {
        @Bindable var settings = appState.settings
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Subject.allCases) { subject in
                    Button {
                        settings.selectedSubject = subject
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: subject.icon)
                                .font(.caption)
                            Text(subject.rawValue)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            settings.selectedSubject == subject
                            ? Color.blue
                            : Color.blue.opacity(0.1)
                        )
                        .foregroundStyle(
                            settings.selectedSubject == subject
                            ? AnyShapeStyle(Color.white)
                            : AnyShapeStyle(Color.blue)
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Subviews

    private var atMax: Bool { appState.capturedImages.count >= maxImages }

    private var buttonRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(atMax ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(atMax)

                Button {
                    showPhotoPicker = true
                } label: {
                    Label("相册", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(atMax ? Color.gray.opacity(0.1) : Color.blue.opacity(0.12))
                        .foregroundStyle(atMax ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.blue))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(atMax)

                Button {
                    showFilePicker = true
                } label: {
                    Label("文件", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(atMax ? Color.gray.opacity(0.1) : Color.blue.opacity(0.08))
                        .foregroundStyle(atMax ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.blue))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(atMax)
                .sheet(isPresented: $showFilePicker) {
                    DocumentPickerWrapper(
                        images: Binding(
                            get: { appState.capturedImages },
                            set: { appState.capturedImages = $0 }
                        )
                    )
                }
            }

            if !appState.capturedImages.isEmpty {
                Text("\(appState.capturedImages.count) / \(maxImages) 张（每张独立提取）")
                    .font(.caption)
                    .foregroundStyle(atMax ? .orange : .secondary)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: appState.settings.selectedSubject.icon)
                .font(.system(size: 72))
                .foregroundStyle(.blue.opacity(0.35))
                .padding(.top, 60)
            Text("拍摄或选择\(appState.settings.selectedSubject.rawValue)题目图片")
                .font(.title3.bold())
                .foregroundStyle(.secondary)
            Text("支持多种题型\n可一次选择多张图片")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 40)
    }

    private var imageGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
            ForEach(Array(appState.capturedImages.enumerated()), id: \.offset) { index, image in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        appState.capturedImages.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .font(.title3)
                    }
                    .padding(4)
                }
            }
        }
    }

    private var analyzeButton: some View {
        Button {
            appState.reset()
            navigateToExtraction = true
        } label: {
            Label("开始 AI 分析 (\(appState.capturedImages.count) 张)", systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 4)
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let img = info[.originalImage] as? UIImage {
                parent.onCapture(img)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
