import SwiftUI
import PhotosUI

/// Avatar selection flow: Photo Library, Camera, or Remove
struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var authManager = AuthManager.shared

    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                    // Current avatar
                    ComicPanelCard(titleBanner: L("Current Avatar"), bannerColor: ComicTheme.Colors.deepPurple) {
                        HStack {
                            Spacer()
                            ProfilePictureView(size: 120)
                            Spacer()
                        }
                    }

                    if let preview = previewImage {
                        // Preview selected image
                        ComicPanelCard(titleBanner: L("New Photo"), bannerColor: ComicTheme.Colors.emeraldGreen) {
                            VStack(spacing: 16) {
                                HStack {
                                    Spacer()
                                    Image(uiImage: preview)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    ComicTheme.panelBorderColor(colorScheme),
                                                    lineWidth: ComicTheme.Dimensions.panelBorderWidth
                                                )
                                        )
                                    Spacer()
                                }

                                if isUploading {
                                    ProgressView(L("Uploading..."))
                                        .tint(ComicTheme.Colors.boldBlue)
                                } else {
                                    Button {
                                        useSelectedImage()
                                    } label: {
                                        Label(L("Use This Photo"), systemImage: "checkmark.circle.fill")
                                    }
                                    .buttonStyle(.comicPrimary(color: ComicTheme.Colors.emeraldGreen))

                                    Button {
                                        previewImage = nil
                                        selectedPhotoItem = nil
                                    } label: {
                                        Label(L("Cancel"), systemImage: "xmark.circle")
                                    }
                                    .buttonStyle(.comicSecondary(color: ComicTheme.Colors.crimsonRed))
                                }
                            }
                        }
                    } else {
                        // Action buttons
                        ComicPanelCard(titleBanner: L("Choose Avatar"), bannerColor: ComicTheme.Colors.boldBlue) {
                            VStack(spacing: 12) {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Label(L("Choose Photo or Memoji"), systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.comicPrimary(color: ComicTheme.Colors.boldBlue))

                                Button {
                                    showCamera = true
                                } label: {
                                    Label(L("Take Photo"), systemImage: "camera")
                                }
                                .buttonStyle(.comicSecondary(color: ComicTheme.Colors.boldBlue))

                                if authManager.avatarImageData != nil {
                                    Button(role: .destructive) {
                                        removeAvatar()
                                    } label: {
                                        Label(L("Remove Avatar"), systemImage: "trash")
                                    }
                                    .buttonStyle(.comicDestructive)
                                }
                            }
                        }

                        // Memoji tip
                        ComicPanelCard(bannerColor: ComicTheme.Colors.deepPurple) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "face.smiling")
                                    .font(.body.weight(.bold))
                                    .foregroundColor(ComicTheme.Colors.deepPurple)
                                    .frame(width: 24)
                                Text(L("To use your Memoji, save it as a sticker image to your Photos first, then select it here."))
                                    .font(ComicTheme.Typography.speechBubble(12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Privacy notice
                    ComicPanelCard(titleBanner: L("Privacy"), bannerColor: ComicTheme.Colors.goldenYellow) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.shield")
                                .font(.body.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.goldenYellow)
                                .frame(width: 24)
                            Text(L("Your photo creates a text description of your appearance. The photo itself is not shared with AI services."))
                                .font(ComicTheme.Typography.speechBubble(12))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(ComicTheme.Typography.speechBubble(12))
                            .foregroundColor(ComicTheme.Colors.crimsonRed)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .halftoneBackground()
            .navigationTitle(L("Profile Picture"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    previewImage = image
                    showCamera = false
                }
            }
            .onChange(of: selectedPhotoItem) {
                loadSelectedPhoto()
            }
        }
    }

    private func loadSelectedPhoto() {
        guard let item = selectedPhotoItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    previewImage = image
                }
            }
        }
    }

    private func useSelectedImage() {
        guard let image = previewImage else { return }

        // Resize to 512x512 max
        let resized = resizeImage(image, maxSize: 512)
        guard let pngData = resized.pngData() else { return }

        isUploading = true
        errorMessage = nil

        Task {
            if AuthManager.shared.isAuthenticated {
                do {
                    let response = try await BackendService.shared.uploadAvatar(imageData: pngData)
                    await MainActor.run {
                        authManager.setAvatar(imageData: pngData, description: response.avatar_description)
                        isUploading = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        authManager.setAvatar(imageData: pngData, description: "User avatar")
                        isUploading = false
                        dismiss()
                    }
                }
            } else {
                await MainActor.run {
                    authManager.setAvatar(imageData: pngData, description: "User avatar")
                    isUploading = false
                    dismiss()
                }
            }
        }
    }

    private func removeAvatar() {
        Task {
            if AuthManager.shared.isAuthenticated {
                try? await BackendService.shared.deleteAvatar()
            }
            await MainActor.run {
                authManager.clearAvatar()
                dismiss()
            }
        }
    }

    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        if ratio >= 1 { return image }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImageCaptured: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
