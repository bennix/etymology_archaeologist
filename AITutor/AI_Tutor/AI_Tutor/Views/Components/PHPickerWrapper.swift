import SwiftUI
import PhotosUI

struct PHPickerWrapper: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    var onDismiss: () -> Void = {}

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 10
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerWrapper

        init(_ parent: PHPickerWrapper) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true) { self.parent.onDismiss() }
            guard !results.isEmpty else { return }
            var loaded: [UIImage] = []
            let group = DispatchGroup()
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let img = object as? UIImage { loaded.append(img) }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self.parent.images = loaded
            }
        }
    }
}
