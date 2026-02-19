import SwiftUI
import PhotosUI
import Combine

/// Avatar selection flow: Memoji sticker, Photo Library, Camera, or Remove
struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var authManager = AuthManager.shared

    @State private var showMemojiBridge = false
    @State private var showPhotoPicker = false
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
                                Button {
                                    showMemojiBridge = true
                                } label: {
                                    Label(L("Use Memoji"), systemImage: "face.smiling")
                                }
                                .buttonStyle(.comicPrimary(color: ComicTheme.Colors.boldBlue))

                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Label(L("Choose Photo"), systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity)
                                        .font(ComicTheme.Typography.comicButton(16))
                                        .padding(.vertical, 12)
                                        .background(ComicTheme.Semantic.cardSurface(colorScheme))
                                        .foregroundColor(ComicTheme.Colors.boldBlue)
                                        .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                                                .stroke(ComicTheme.Colors.boldBlue, lineWidth: 2.5)
                                        )
                                }

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
            .sheet(isPresented: $showMemojiBridge) {
                MemojiCaptureView(onSave: { image in
                    previewImage = image
                    showMemojiBridge = false
                }, onCancel: {
                    showMemojiBridge = false
                })
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
                        // Store locally even if upload fails
                        authManager.setAvatar(imageData: pngData, description: "User avatar")
                        isUploading = false
                        dismiss()
                    }
                }
            } else {
                // Store locally only
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

// MARK: - Sticker Text View (intercepts paste for Memoji stickers)

class StickerTextView: UITextView {
    var onStickerImage: ((UIImage) -> Void)?

    override func paste(_ sender: Any?) {
        // Intercept: grab the sticker image directly from clipboard before UITextView processes it
        if let image = UIPasteboard.general.image {
            onStickerImage?(image)
        }
        super.paste(sender)
    }
}

// MARK: - Memoji Input State (bridges UITextView ↔ SwiftUI)

class MemojiInputState: ObservableObject {
    @Published var hasContent = false
    weak var textView: UITextView?

    /// Try every possible way to extract a sticker image
    func captureImage() -> UIImage? {
        if let image = extractFromAttachments() { return image }
        if let image = UIPasteboard.general.image { return image }
        return nil
    }

    private func extractFromAttachments() -> UIImage? {
        guard let textView = textView else { return nil }
        let attrText = textView.attributedText ?? NSAttributedString()
        guard attrText.length > 0 else { return nil }

        var found: UIImage?
        attrText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrText.length)) { value, _, stop in
            guard let attachment = value as? NSTextAttachment else { return }
            if let img = attachment.image {
                found = img; stop.pointee = true; return
            }
            if let data = attachment.fileWrapper?.regularFileContents, let img = UIImage(data: data) {
                found = img; stop.pointee = true; return
            }
            if let data = attachment.contents, let img = UIImage(data: data) {
                found = img; stop.pointee = true; return
            }
            if let img = attachment.image(forBounds: attachment.bounds, textContainer: nil, characterIndex: 0) {
                found = img; stop.pointee = true; return
            }
        }
        return found
    }
}

// MARK: - Memoji Capture View (Comic-themed)

struct MemojiCaptureView: View {
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var capturedImage: UIImage?
    @StateObject private var inputState = MemojiInputState()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                    // Instructions
                    ComicPanelCard(titleBanner: L("How To"), bannerColor: ComicTheme.Colors.boldBlue) {
                        VStack(alignment: .leading, spacing: 10) {
                            instructionRow(number: 1, text: L("Tap the area below to open the keyboard"))
                            instructionRow(number: 2, text: L("Tap") + " 🌐 " + L("to switch to emoji keyboard"))
                            instructionRow(number: 3, text: L("Swipe to find Memoji stickers and tap one"))
                        }
                    }

                    // Input area
                    ComicPanelCard(titleBanner: L("Enter Memoji"), bannerColor: ComicTheme.Colors.deepPurple) {
                        MemojiInputField(onImageCaptured: { image in
                            capturedImage = image
                        }, inputState: inputState)
                        .frame(height: 120)
                        .background(ComicTheme.Semantic.cardSurface(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                                .stroke(ComicTheme.Semantic.panelBorder(colorScheme).opacity(0.3), lineWidth: 2.0)
                        )
                    }

                    if let image = capturedImage {
                        // Preview + Use button
                        ComicPanelCard(titleBanner: L("Preview"), bannerColor: ComicTheme.Colors.emeraldGreen) {
                            VStack(spacing: 16) {
                                HStack {
                                    Spacer()
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
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

                                Button {
                                    onSave(image)
                                } label: {
                                    Label(L("Use This Memoji"), systemImage: "checkmark.circle.fill")
                                }
                                .buttonStyle(.comicPrimary(color: ComicTheme.Colors.emeraldGreen))
                            }
                        }
                    }

                    // Paste fallback
                    Button {
                        if let image = UIPasteboard.general.image {
                            capturedImage = image
                        }
                    } label: {
                        Label(L("Paste from Clipboard"), systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.comicSecondary(color: ComicTheme.Colors.boldBlue))
                }
                .padding()
            }
            .halftoneBackground()
            .navigationTitle(L("Memoji"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done")) {
                        if let image = capturedImage {
                            onSave(image)
                        } else if let image = inputState.captureImage() {
                            onSave(image)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(ComicTheme.Typography.comicButton(12))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(ComicTheme.Colors.boldBlue)
                .clipShape(Circle())
            Text(text)
                .font(ComicTheme.Typography.speechBubble(14))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Memoji Input Field (StickerTextView wrapper)

struct MemojiInputField: UIViewRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let inputState: MemojiInputState

    func makeUIView(context: Context) -> StickerTextView {
        let textView = StickerTextView()
        textView.font = .systemFont(ofSize: 48)
        textView.textAlignment = .center
        textView.backgroundColor = .clear
        textView.allowsEditingTextAttributes = true
        textView.delegate = context.coordinator
        textView.onStickerImage = { image in
            context.coordinator.onImageCaptured(image)
        }
        inputState.textView = textView
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            textView.becomeFirstResponder()
        }
        return textView
    }

    func updateUIView(_ uiView: StickerTextView, context: Context) {
        context.coordinator.onImageCaptured = onImageCaptured
        uiView.onStickerImage = { image in
            context.coordinator.onImageCaptured(image)
        }
        inputState.textView = uiView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, inputState: inputState)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var onImageCaptured: (UIImage) -> Void
        let inputState: MemojiInputState
        private var clipboardTimer: Timer?
        private var lastPasteboardChangeCount: Int

        init(onImageCaptured: @escaping (UIImage) -> Void, inputState: MemojiInputState) {
            self.onImageCaptured = onImageCaptured
            self.inputState = inputState
            self.lastPasteboardChangeCount = UIPasteboard.general.changeCount
            super.init()
            // Must use .common mode so the timer fires while the keyboard is active (.tracking mode)
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkClipboard()
            }
            RunLoop.main.add(timer, forMode: .common)
            clipboardTimer = timer
        }

        deinit {
            clipboardTimer?.invalidate()
        }

        func textViewDidChange(_ textView: UITextView) {
            let attrText = textView.attributedText ?? NSAttributedString()

            DispatchQueue.main.async {
                self.inputState.hasContent = attrText.length > 0
            }

            // Robust NSTextAttachment image extraction
            attrText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrText.length)) { value, _, stop in
                guard let attachment = value as? NSTextAttachment else { return }
                var image: UIImage?
                if let img = attachment.image {
                    image = img
                } else if let data = attachment.fileWrapper?.regularFileContents, let img = UIImage(data: data) {
                    image = img
                } else if let data = attachment.contents, let img = UIImage(data: data) {
                    image = img
                } else if let img = attachment.image(forBounds: attachment.bounds, textContainer: nil, characterIndex: 0) {
                    image = img
                }
                if let image = image {
                    DispatchQueue.main.async { self.onImageCaptured(image) }
                    stop.pointee = true
                }
            }
        }

        private func checkClipboard() {
            let currentCount = UIPasteboard.general.changeCount
            guard currentCount != lastPasteboardChangeCount else { return }
            lastPasteboardChangeCount = currentCount
            if let image = UIPasteboard.general.image {
                DispatchQueue.main.async {
                    self.onImageCaptured(image)
                }
            }
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
