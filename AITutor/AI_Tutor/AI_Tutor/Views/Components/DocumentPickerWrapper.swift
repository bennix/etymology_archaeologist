// AI_Tutor/Views/Components/DocumentPickerWrapper.swift
import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerWrapper: UIViewControllerRepresentable {
    @Binding var images: [UIImage]

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.image, .jpeg, .png, .heic, .gif, .bmp, .tiff]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerWrapper

        init(_ parent: DocumentPickerWrapper) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            let loaded = urls.compactMap { url -> UIImage? in
                guard url.startAccessingSecurityScopedResource() else { return nil }
                defer { url.stopAccessingSecurityScopedResource() }
                guard let data = try? Data(contentsOf: url) else { return nil }
                return UIImage(data: data)
            }
            parent.images.append(contentsOf: loaded)
        }
    }
}
