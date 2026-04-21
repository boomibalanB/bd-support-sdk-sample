import SwiftUI
import UIKit

struct AttachmentPickerView<Label: View>: View {

    // MARK: - External controls
    let isEnabled: Bool
    let onFilesPicked: ([URL]) -> Void
    let onImagePicked: ([URL]) -> Void
    let label: () -> Label

    // MARK: - Internal state
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary

    init(
        isEnabled: Bool,
        onFilesPicked: @escaping ([URL]) -> Void,
        onImagePicked: @escaping ([URL]) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isEnabled = isEnabled
        self.onFilesPicked = onFilesPicked
        self.onImagePicked = onImagePicked
        self.label = label
    }

    var body: some View {
        Menu {
            Button("Choose File") {
                showDocumentPicker = true
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") {
                    imagePickerSource = .camera
                    showCameraPicker = true
                }
            }

            Button("Photo Library") {
                imagePickerSource = .photoLibrary
                showImagePicker = true
            }

        } label: {
            label()
                .disabled(!isEnabled)
        }
        .disabled(!isEnabled)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker {
                onFilesPicked($0)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imagePickerSource) {
                onImagePicked([$0])
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera) {
                onImagePicked([$0])
            }
        }
    }
}
