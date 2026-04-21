import SwiftUI

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    let sourceType: UIImagePickerController.SourceType
    var onFilePicked: (URL) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {

            // 📸 Photo Library
            if let imageURL = info[.imageURL] as? URL {
                parent.onFilePicked(imageURL)
                parent.presentationMode.wrappedValue.dismiss()
                return
            }

            // 📷 Camera
            if let image = info[.originalImage] as? UIImage,
               let url = saveImageToTemp(image) {
                parent.onFilePicked(url)
            }

            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        private func saveImageToTemp(_ image: UIImage) -> URL? {
            let fileName = UUID().uuidString + ".jpg"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)

            guard let data = image.jpegData(compressionQuality: 0.9) else {
                return nil
            }

            do {
                try data.write(to: url)
                return url
            } catch {
                print("Failed to save camera image:", error)
                return nil
            }
        }

    }
}
