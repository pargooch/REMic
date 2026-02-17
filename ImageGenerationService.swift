import Foundation
import SwiftUI
import Combine

// MARK: - Image Generation Error

enum ImageGenerationError: LocalizedError {
    case notSupported
    case unavailable
    case cancelled
    case modelNotLoaded
    case creationFailed(String)
    case noImagesGenerated

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Image generation requires Apple Silicon device."
        case .unavailable:
            return "MLX image generation is unavailable. Please ensure the model is downloaded."
        case .cancelled:
            return "Image generation was cancelled."
        case .modelNotLoaded:
            return "MLX model not loaded. Please wait for initialization."
        case .creationFailed(let message):
            return "Image creation failed: \(message)"
        case .noImagesGenerated:
            return "No images were generated. Please try again."
        }
    }
}

// MARK: - Image Style (Maps to MLX styles)

enum DreamImageStyle: String, CaseIterable, Identifiable {
    case comicBook = "Comic Book"
    case popArt = "Pop Art"
    case graphicNovel = "Graphic Novel"
    case lineArt = "Line Art"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .comicBook: return "book.pages"
        case .popArt: return "sparkles.rectangle.stack"
        case .graphicNovel: return "text.book.closed"
        case .lineArt: return "pencil.and.outline"
        }
    }

    var description: String {
        switch self {
        case .comicBook: return "Bold lines, halftone dots, action effects"
        case .popArt: return "Vibrant colors, high contrast, stylized"
        case .graphicNovel: return "Dramatic shadows, strong composition"
        case .lineArt: return "Clean outlines, minimal shading"
        }
    }

    /// Convert to MLX style
    var mlxStyle: MLXImageStyle {
        switch self {
        case .comicBook: return .comicBook
        case .popArt: return .popArt
        case .graphicNovel: return .graphicNovel
        case .lineArt: return .lineArt
        }
    }
}

// MARK: - Generated Image

struct GeneratedDreamImage: Identifiable, Codable, Equatable {
    let id: UUID
    let imageData: Data
    let prompt: String
    let style: String
    let sequenceIndex: Int
    let createdAt: Date

    init(imageData: Data, prompt: String, style: DreamImageStyle, sequenceIndex: Int) {
        self.id = UUID()
        self.imageData = imageData
        self.prompt = prompt
        self.style = style.rawValue
        self.sequenceIndex = sequenceIndex
        self.createdAt = Date()
    }

    /// Initialize from MLX generated image
    init(from mlxImage: GeneratedMLXImage) {
        self.id = mlxImage.id
        self.imageData = mlxImage.imageData
        self.prompt = mlxImage.prompt
        self.style = mlxImage.style
        self.sequenceIndex = mlxImage.sequenceIndex
        self.createdAt = mlxImage.createdAt
    }

    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}

// MARK: - Image Generation Service

@MainActor
class ImageGenerationService: ObservableObject {
    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var statusMessage: String = ""
    @Published var generatedImages: [GeneratedDreamImage] = []
    @Published var error: ImageGenerationError?
    @Published var isModelLoaded = false

    private var isCancelled = false
    private var currentTask: Task<Void, Never>?
    private let mlxService = MLXImageService.shared

    /// Check if image generation is available (backend when authenticated, MLX when not)
    static var isAvailable: Bool {
        return AuthManager.shared.isAuthenticated || MLXImageService.isAvailable
    }

    init() {
        // Observe MLX service state
        Task {
            await observeMLXService()
        }
    }

    private func observeMLXService() async {
        // Keep model loaded state in sync
        for await _ in mlxService.$isModelLoaded.values {
            self.isModelLoaded = mlxService.isModelLoaded
        }
    }

    /// Load the MLX model
    func loadModel() async throws {
        statusMessage = "Loading MLX model..."
        try await mlxService.loadModel()
        isModelLoaded = true
        statusMessage = ""
    }

    func cancel() {
        isCancelled = true
        mlxService.cancel()
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    // MARK: - Comic Page Generation

    /// Generate comic page(s) from a rewritten dream
    /// Backend path: single-shot generate-comic-page endpoint
    /// Local path: local layout planning → MLX render → ComicPageCompositor
    func generateComicPage(
        from text: String,
        style: DreamImageStyle = .comicBook,
        dreamerProfile: DreamerProfile? = nil
    ) async throws -> [ComicPageImage] {
        currentTask?.cancel()
        currentTask = nil
        try await Task.sleep(nanoseconds: 500_000_000)

        isGenerating = true
        isCancelled = false
        progress = 0
        generatedImages = []

        defer {
            isGenerating = false
            statusMessage = ""
        }

        if AuthManager.shared.isAuthenticated {
            return try await generateComicPageWithBackend(text: text, dreamerProfile: dreamerProfile)
        } else {
            return try await generateComicPageLocally(text: text, style: style, dreamerProfile: dreamerProfile)
        }
    }

    // MARK: - Backend Comic Page

    private func generateComicPageWithBackend(
        text: String,
        dreamerProfile: DreamerProfile?
    ) async throws -> [ComicPageImage] {
        statusMessage = "Painting your dream..."
        progress = 0.1

        let response = try await BackendService.shared.generateComicPage(
            rewrittenText: text,
            dreamerProfile: dreamerProfile
        )

        if isCancelled { throw ImageGenerationError.cancelled }

        progress = 0.9
        statusMessage = "Almost there..."

        var comicPages: [ComicPageImage] = []
        for page in response.pages {
            guard let imageData = decodeBase64Image(page.image_url) else {
                print("Failed to decode comic page \(page.page_number)")
                continue
            }
            comicPages.append(ComicPageImage(imageData: imageData, pageNumber: page.page_number))
        }

        guard !comicPages.isEmpty else {
            throw ImageGenerationError.creationFailed("Failed to decode comic page images")
        }

        progress = 1.0
        return comicPages
    }

    // MARK: - Local Comic Page

    private func generateComicPageLocally(
        text: String,
        style: DreamImageStyle,
        dreamerProfile: DreamerProfile?
    ) async throws -> [ComicPageImage] {
        // Load MLX model if needed
        if !mlxService.isModelLoaded {
            statusMessage = "Loading MLX model..."
            try await mlxService.loadModel()
        }

        // Step 1: Plan layout locally
        statusMessage = "Planning comic layout..."
        progress = 0.05

        let aiService = AIService()
        let layoutPlan: ComicLayoutPlan

        do {
            layoutPlan = try await aiService.planComicLayoutLocally(
                from: text,
                dreamerProfile: dreamerProfile
            )
        } catch {
            print("Local layout planning failed: \(error), using default 2x2 layout")
            layoutPlan = createDefaultLayoutPlan(from: text)
        }

        if isCancelled { throw ImageGenerationError.cancelled }

        var comicPages: [ComicPageImage] = []
        let comicLayout = layoutPlan.layout

        for (pageIndex, pagePlan) in comicLayout.pages.enumerated() {
            // Step 2: Generate panel images with MLX
            var panelImages: [UIImage] = []

            for (panelIndex, panelPlan) in pagePlan.panels.enumerated() {
                if isCancelled { throw ImageGenerationError.cancelled }

                let totalPanels = pagePlan.panels.count
                statusMessage = "Rendering panel \(panelIndex + 1)/\(totalPanels)..."
                progress = 0.1 + 0.7 * Double(panelIndex + 1) / Double(totalPanels)

                let sanitizedPrompt = aiService.sanitizeScenePromptPublic(panelPlan.image_prompt)

                do {
                    let mlxImage = try await mlxService.generateImage(
                        prompt: sanitizedPrompt,
                        style: style.mlxStyle,
                        sequenceIndex: panelIndex
                    )
                    if let uiImage = UIImage(data: mlxImage.imageData) {
                        panelImages.append(uiImage)
                    }
                } catch {
                    print("Failed to render panel \(panelIndex): \(error)")
                }
            }

            if isCancelled { throw ImageGenerationError.cancelled }

            // Step 3: Composite
            statusMessage = "Compositing page..."
            progress = 0.85

            guard let composedImage = ComicPageCompositor.composePage(
                panelImages: panelImages,
                pagePlan: pagePlan,
                layoutType: comicLayout.layout_type,
                titleText: pageIndex == 0 ? comicLayout.title_text : nil
            ) else { continue }

            guard let pngData = composedImage.pngData() else { continue }

            comicPages.append(ComicPageImage(imageData: pngData, pageNumber: pageIndex))
        }

        progress = 1.0

        guard !comicPages.isEmpty else {
            throw ImageGenerationError.noImagesGenerated
        }

        return comicPages
    }

    // MARK: - Helpers

    /// Create a default 2x2 layout plan when local AI planning fails
    private func createDefaultLayoutPlan(from text: String) -> ComicLayoutPlan {
        let scenes = generateFallbackScenes(count: 4)
        return ComicLayoutPlan(
            model_used: "fallback",
            layout: ComicLayout(
                title_text: "DREAM",
                layout_type: "2x2_grid",
                pages: [
                    ComicPagePlan(
                        page_number: 1,
                        panels: scenes.enumerated().map { index, prompt in
                            ComicPanelPlan(
                                panel_number: index + 1,
                                position: PanelPosition(row: index / 2, col: index % 2),
                                size: "standard",
                                image_prompt: prompt,
                                speech_bubble: nil,
                                sound_effect: nil,
                                narrative_caption: "Scene \(index + 1)"
                            )
                        }
                    )
                ]
            )
        )
    }

    /// Decode a base64 image URL (supports "data:image/png;base64,..." and raw base64)
    private func decodeBase64Image(_ imageUrl: String) -> Data? {
        let cleanBase64 = imageUrl.contains(",")
            ? String(imageUrl.split(separator: ",").last ?? "")
            : imageUrl
        return Data(base64Encoded: cleanBase64, options: .ignoreUnknownCharacters)
    }

    /// Generate flat vector style fallback scenes
    private func generateFallbackScenes(count: Int) -> [String] {
        let vectorStyle = "flat vector comic panel, graphic design style, thick black vector outlines, simple geometric shapes, two-dimensional, no depth, no shading, solid flat colors only, high contrast color blocks, clean poster-like composition, bold centered subject, minimal background, symbolic silhouette characters, screen print look, no gradients, no lighting, no texture, no realism, no 3D"

        let fallbacks = [
            "Silhouette figure running through doorway, SMASH! text, yellow and orange background, \(vectorStyle)",
            "Dark shadow shape with lightning bolt, purple and blue color blocks, \(vectorStyle)",
            "Explosion circle with BOOM! text, red and orange shapes, centered composition, \(vectorStyle)",
            "Standing figure with cape, arms raised, POW! text, gold and blue background, \(vectorStyle)",
            "Monster silhouette roaring, CRASH! text, green and black shapes, \(vectorStyle)",
            "Figure landing pose, BAM! text, red and yellow color blocks, \(vectorStyle)"
        ]

        return (0..<count).map { fallbacks[$0 % fallbacks.count] }
    }

    /// Generate a single image from a prompt using MLX
    func generateSingleImage(
        prompt: String,
        style: DreamImageStyle
    ) async throws -> GeneratedDreamImage {
        // Cancel any existing task
        currentTask?.cancel()
        currentTask = nil

        // Small delay to ensure previous resources are released
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second

        isGenerating = true
        isCancelled = false
        defer { isGenerating = false }

        // Check if model is loaded
        if !mlxService.isModelLoaded {
            statusMessage = "Loading MLX model..."
            try await mlxService.loadModel()
        }

        let mlxImage = try await mlxService.generateImage(
            prompt: prompt,
            style: style.mlxStyle,
            sequenceIndex: 0
        )

        return GeneratedDreamImage(from: mlxImage)
    }

    // MARK: - Comic Page Layout

    /// Layout style for combining images into a comic page
    enum ComicLayoutStyle {
        case vertical       // Stacked vertically
        case grid           // Grid layout
        case dynamic        // Varied panel sizes for visual interest
        case widescreen     // Wide horizontal panels
    }

    /// Combine multiple images into a single comic page
    func createComicPage(
        from images: [GeneratedDreamImage],
        style: ComicLayoutStyle = .dynamic,
        pageSize: CGSize = CGSize(width: 1024, height: 1536)
    ) -> UIImage? {
        let uiImages = images.compactMap { $0.uiImage }
        guard !uiImages.isEmpty else { return nil }

        // Use MLX comic panel layout
        let mlxLayoutStyle: MLXComicPanelLayout.LayoutStyle
        switch style {
        case .vertical: mlxLayoutStyle = .vertical
        case .grid: mlxLayoutStyle = .grid
        case .dynamic: mlxLayoutStyle = .dynamic
        case .widescreen: mlxLayoutStyle = .widescreen
        }

        return MLXComicPanelLayout.createComicPage(
            images: uiImages,
            style: mlxLayoutStyle,
            pageSize: pageSize
        )
    }

    // MARK: - Backend Upload

    /// Upload generated images to the backend
    /// Called after images are generated, if user is signed in
    func uploadImagesToBackend(
        images: [GeneratedDreamImage],
        rewrittenDreamId: String,
        style: DreamImageStyle
    ) async throws -> APIVisualization {
        guard AuthManager.shared.isAuthenticated else {
            throw ImageGenerationError.notSupported
        }

        statusMessage = "Uploading to cloud..."

        // Convert images to base64 URLs
        var imageUrls: [String] = []
        for image in images {
            let url = try await BackendService.shared.uploadImage(
                data: image.imageData,
                filename: "panel_\(image.sequenceIndex).png"
            )
            imageUrls.append(url)
        }

        // Create visualization on backend
        let visualization = try await BackendService.shared.createVisualization(
            rewrittenDreamId: rewrittenDreamId,
            visualizationType: "comic_panels",
            imageAssets: imageUrls,
            status: "completed"
        )

        statusMessage = ""
        return visualization
    }

    /// Check if backend upload is available
    var canUploadToBackend: Bool {
        AuthManager.shared.isAuthenticated
    }
}
