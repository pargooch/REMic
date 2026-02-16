import Foundation
import SwiftUI
import Combine
import CoreGraphics
import CoreImage

// MARK: - MLX Image Generation Service
// Uses FLUX.1-schnell via flux.swift for fast on-device image generation
// FLUX.1-schnell generates images in 1-4 steps (much faster than Stable Diffusion)

// NOTE: To enable actual image generation, add this Swift Package in Xcode:
// File → Add Package Dependencies → https://github.com/mzbac/flux.swift (from: "0.1.3")
//
// Then uncomment the import below and the actual implementation code marked with "FLUX IMPLEMENTATION"

// Uncomment when flux.swift package is added:
// import FluxSwift

// MARK: - MLX Image Style

enum MLXImageStyle: String, CaseIterable, Identifiable {
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
        case .comicBook: return "Flat vector, bold shapes, graphic design"
        case .popArt: return "High contrast, color blocks, poster style"
        case .graphicNovel: return "Silhouettes, minimal, dramatic"
        case .lineArt: return "Clean outlines, two-tone, simple"
        }
    }

    /// FLUX-optimized style prompt for flat vector graphic style
    var stylePrompt: String {
        let baseStyle = "flat vector comic panel, graphic design style, thick black vector outlines, simple geometric shapes, two-dimensional, no depth, no shading, solid flat colors only, high contrast color blocks, clean poster-like composition, bold centered subject, minimal background, symbolic silhouette characters, screen print look"

        switch self {
        case .comicBook:
            return "\(baseStyle), comic sound effect text, action pose"
        case .popArt:
            return "\(baseStyle), primary colors red yellow blue, bold color blocks"
        case .graphicNovel:
            return "\(baseStyle), noir silhouettes, black and white with color accent"
        case .lineArt:
            return "\(baseStyle), two-tone, minimal fills, strong black shapes"
        }
    }

    /// Negative prompt to avoid unwanted styles
    var negativePrompt: String {
        return "photorealistic, photograph, 3D render, CGI, anime, manga, watercolor, oil painting, realistic faces, detailed skin texture, gradients, lighting effects, texture, depth, shading, blurry, low quality"
    }
}

// MARK: - MLX Generation Error

enum MLXGenerationError: LocalizedError {
    case modelNotLoaded
    case modelNotFound
    case generationFailed(String)
    case insufficientMemory
    case cancelled
    case unsupportedDevice
    case downloadFailed(String)
    case fluxNotInstalled

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "FLUX model not loaded. Please wait for initialization."
        case .modelNotFound:
            return "FLUX.1-schnell model not found. Downloading..."
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .insufficientMemory:
            return "Insufficient memory. Close other apps and try again."
        case .cancelled:
            return "Generation was cancelled."
        case .unsupportedDevice:
            return "Requires Apple Silicon (M1+ Mac or A14+ iPhone/iPad)."
        case .downloadFailed(let message):
            return "Model download failed: \(message)"
        case .fluxNotInstalled:
            return "FLUX.swift package not installed. Add it in Xcode Package Dependencies."
        }
    }
}

// MARK: - FLUX Model Configuration

struct FLUXModelConfig {
    let name: String
    let variant: String
    let steps: Int
    let description: String

    /// FLUX.1-schnell - fastest model (1-4 steps)
    static let schnell = FLUXModelConfig(
        name: "FLUX.1-schnell",
        variant: "schnell",
        steps: 4,
        description: "Ultra-fast generation (4 steps)"
    )

    /// FLUX.1-dev - higher quality (20-50 steps)
    static let dev = FLUXModelConfig(
        name: "FLUX.1-dev",
        variant: "dev",
        steps: 20,
        description: "Higher quality (more steps)"
    )

    static let recommended = schnell
}

// MARK: - Generated MLX Image

struct GeneratedMLXImage: Identifiable, Codable, Equatable {
    let id: UUID
    let imageData: Data
    let prompt: String
    let style: String
    let sequenceIndex: Int
    let createdAt: Date
    let generationTime: TimeInterval

    init(imageData: Data, prompt: String, style: MLXImageStyle, sequenceIndex: Int, generationTime: TimeInterval) {
        self.id = UUID()
        self.imageData = imageData
        self.prompt = prompt
        self.style = style.rawValue
        self.sequenceIndex = sequenceIndex
        self.createdAt = Date()
        self.generationTime = generationTime
    }

    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}

// MARK: - MLX Image Service

@MainActor
class MLXImageService: ObservableObject {
    static let shared = MLXImageService()

    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var isDownloading = false
    @Published var progress: Double = 0
    @Published var statusMessage: String = ""
    @Published var generatedImages: [GeneratedMLXImage] = []
    @Published var downloadProgress: Double = 0
    @Published var currentModel: FLUXModelConfig = .schnell

    private var isCancelled = false
    private var currentTask: Task<Void, Never>?

    // FLUX generation parameters
    private let imageWidth: Int = 512
    private let imageHeight: Int = 512

    // FLUX IMPLEMENTATION: Uncomment when flux.swift is added
    // private var generator: (any TextToImageGenerator)?

    /// Check if MLX/FLUX is available (requires Apple Silicon)
    static var isAvailable: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Model Management

    /// Load the FLUX.1-schnell model
    func loadModel() async throws {
        guard Self.isAvailable else {
            throw MLXGenerationError.unsupportedDevice
        }

        statusMessage = "Loading FLUX.1-schnell model..."

        // FLUX IMPLEMENTATION: Uncomment when flux.swift is added
        /*
        do {
            let config = FluxConfiguration.flux1Schnell
            let loadConfig = LoadConfiguration(float16: true, quantize: true)  // Quantize for memory efficiency
            generator = try config.textToImageGenerator(configuration: loadConfig)
            isModelLoaded = true
            statusMessage = "Model ready"
        } catch {
            throw MLXGenerationError.generationFailed(error.localizedDescription)
        }
        */

        // Simulated loading (remove when FLUX is integrated)
        try await Task.sleep(nanoseconds: 500_000_000)
        isModelLoaded = true
        statusMessage = "Model ready"
    }

    /// Unload model to free memory
    func unloadModel() {
        // generator = nil
        isModelLoaded = false
        statusMessage = ""
    }

    // MARK: - Image Generation

    /// Generate a single image using FLUX.1-schnell
    func generateImage(
        prompt: String,
        style: MLXImageStyle,
        sequenceIndex: Int = 0
    ) async throws -> GeneratedMLXImage {
        let startTime = Date()

        guard Self.isAvailable else {
            throw MLXGenerationError.unsupportedDevice
        }

        isGenerating = true
        isCancelled = false
        progress = 0
        statusMessage = "Preparing..."

        defer {
            isGenerating = false
            statusMessage = ""
        }

        // Ensure model is loaded
        if !isModelLoaded {
            try await loadModel()
        }

        // Build the full prompt with comic book style
        let fullPrompt = buildFLUXPrompt(sceneDescription: prompt, style: style)
        print("FLUX generating: \(fullPrompt)")

        // FLUX IMPLEMENTATION: Uncomment when flux.swift is added
        /*
        guard let generator = generator else {
            throw MLXGenerationError.modelNotLoaded
        }

        var params = FluxConfiguration.flux1Schnell.defaultParameters()
        params.prompt = fullPrompt
        params.negativePrompt = style.negativePrompt
        params.width = imageWidth
        params.height = imageHeight
        params.numInferenceSteps = currentModel.steps

        var denoiser = generator.generateLatents(parameters: params)
        var lastXt: MLXArray!

        let totalSteps = params.numInferenceSteps
        while let xt = denoiser.next() {
            if isCancelled { throw MLXGenerationError.cancelled }

            let currentStep = denoiser.i
            progress = Double(currentStep) / Double(totalSteps)
            statusMessage = "Generating... \(currentStep)/\(totalSteps)"
            lastXt = xt
        }

        // Decode latents to image
        let decoded = generator.decode(xt: lastXt)
        let cgImage = decoded.toCGImage()

        guard let cgImage = cgImage else {
            throw MLXGenerationError.generationFailed("Failed to create image")
        }

        let uiImage = UIImage(cgImage: cgImage)
        guard let imageData = uiImage.pngData() else {
            throw MLXGenerationError.generationFailed("Failed to encode image")
        }
        */

        // Simulated generation with placeholder (remove when FLUX is integrated)
        let steps = currentModel.steps
        for step in 1...steps {
            if isCancelled { throw MLXGenerationError.cancelled }
            progress = Double(step) / Double(steps)
            statusMessage = "Generating... \(step)/\(steps)"
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2s per step
        }

        let imageData = try generateStoryBasedPlaceholder(prompt: prompt, fullPrompt: fullPrompt, style: style)
        let generationTime = Date().timeIntervalSince(startTime)

        return GeneratedMLXImage(
            imageData: imageData,
            prompt: fullPrompt,
            style: style,
            sequenceIndex: sequenceIndex,
            generationTime: generationTime
        )
    }

    /// Generate a sequence of comic panels from scene descriptions
    func generateComicSequence(
        scenes: [String],
        style: MLXImageStyle
    ) async throws -> [GeneratedMLXImage] {
        var images: [GeneratedMLXImage] = []

        for (index, scene) in scenes.enumerated() {
            if isCancelled { throw MLXGenerationError.cancelled }

            statusMessage = "Panel \(index + 1)/\(scenes.count): Generating..."

            let image = try await generateImage(
                prompt: scene,
                style: style,
                sequenceIndex: index
            )
            images.append(image)
        }

        generatedImages = images
        return images
    }

    // MARK: - Prompt Building

    /// Build a FLUX-optimized prompt from the scene description
    private func buildFLUXPrompt(sceneDescription: String, style: MLXImageStyle) -> String {
        // The scene description comes from AIService which generates story-specific prompts
        // We add the comic book style elements

        var prompt = sceneDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure comic book style is included if not already
        if !prompt.lowercased().contains("comic") && !prompt.lowercased().contains("pop art") {
            prompt = "\(prompt), \(style.stylePrompt)"
        }

        // Add quality boosters for FLUX
        prompt = "\(prompt), high quality, detailed, professional illustration"

        return prompt
    }

    // MARK: - Placeholder (Story-Based)

    /// Generate a placeholder that reflects the actual scene description
    private func generateStoryBasedPlaceholder(prompt: String, fullPrompt: String, style: MLXImageStyle) throws -> Data {
        let size = CGSize(width: CGFloat(imageWidth), height: CGFloat(imageHeight))
        let renderer = UIGraphicsImageRenderer(size: size)

        // Extract key elements from the prompt for visual representation
        let promptLower = prompt.lowercased()

        // Determine scene type from prompt
        let sceneType: PlaceholderSceneType
        if promptLower.contains("monster") || promptLower.contains("beast") || promptLower.contains("creature") {
            sceneType = .monster
        } else if promptLower.contains("hero") || promptLower.contains("triumph") || promptLower.contains("victory") {
            sceneType = .hero
        } else if promptLower.contains("shadow") || promptLower.contains("dark") || promptLower.contains("villain") {
            sceneType = .shadow
        } else if promptLower.contains("door") || promptLower.contains("burst") || promptLower.contains("break") {
            sceneType = .action
        } else if promptLower.contains("fly") || promptLower.contains("soar") || promptLower.contains("sky") {
            sceneType = .flying
        } else if promptLower.contains("escape") || promptLower.contains("run") || promptLower.contains("chase") {
            sceneType = .chase
        } else {
            sceneType = .generic
        }

        // Extract sound effect from prompt or pick based on scene
        let soundEffect = extractSoundEffect(from: prompt) ?? sceneType.defaultSoundEffect

        // Get colors based on scene type and style
        let colors = sceneType.colors(for: style)

        let image = renderer.image { context in
            let ctx = context.cgContext
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Draw gradient background
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: [colors.primary.cgColor, colors.secondary.cgColor] as CFArray,
                                          locations: [0, 1]) {
                ctx.drawRadialGradient(gradient,
                                        startCenter: CGPoint(x: centerX, y: centerY * 0.7),
                                        startRadius: 0,
                                        endCenter: CGPoint(x: centerX, y: centerY),
                                        endRadius: size.width * 0.8,
                                        options: [])
            }

            // Draw halftone dots
            drawHalftonePattern(ctx: ctx, size: size, centerX: centerX, centerY: centerY)

            // Draw action lines
            drawActionLines(ctx: ctx, size: size, centerX: centerX, centerY: centerY, type: sceneType)

            // Draw scene-specific elements
            drawSceneElements(ctx: ctx, size: size, centerX: centerX, centerY: centerY, type: sceneType, colors: colors)

            // Draw sound effect burst and text
            drawSoundEffectBurst(ctx: ctx, centerX: centerX, centerY: centerY - 80, soundEffect: soundEffect)

            // Draw comic panel border
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(8)
            ctx.stroke(CGRect(x: 4, y: 4, width: size.width - 8, height: size.height - 8))

            // Draw scene description text at bottom (truncated)
            drawSceneLabel(ctx: ctx, size: size, text: prompt)
        }

        guard let data = image.pngData() else {
            throw MLXGenerationError.generationFailed("Failed to encode image")
        }

        return data
    }

    private func extractSoundEffect(from prompt: String) -> String? {
        let effects = ["BOOM!", "BAM!", "SMASH!", "POW!", "CRASH!", "ZWIFF!", "BANG!", "KRAKOOM!", "WHOOSH!", "SLAM!"]
        let upper = prompt.uppercased()
        return effects.first { upper.contains($0.replacingOccurrences(of: "!", with: "")) }
    }

    private func drawHalftonePattern(ctx: CGContext, size: CGSize, centerX: CGFloat, centerY: CGFloat) {
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.12).cgColor)
        let spacing: CGFloat = 12
        for x in stride(from: 0, to: size.width, by: spacing) {
            for y in stride(from: 0, to: size.height, by: spacing) {
                let distance = sqrt(pow(x - centerX, 2) + pow(y - centerY, 2))
                let dotSize = max(1.5, 5 * (1 - distance / size.width))
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
            }
        }
    }

    private func drawActionLines(ctx: CGContext, size: CGSize, centerX: CGFloat, centerY: CGFloat, type: PlaceholderSceneType) {
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(2.5)

        let lineCount = type == .action ? 32 : 20
        for i in 0..<lineCount {
            let angle = CGFloat(i) * (2 * .pi) / CGFloat(lineCount)
            let inner: CGFloat = type == .action ? 60 : 90
            let outer: CGFloat = size.width * 0.65
            ctx.move(to: CGPoint(x: centerX + cos(angle) * inner, y: centerY + sin(angle) * inner))
            ctx.addLine(to: CGPoint(x: centerX + cos(angle) * outer, y: centerY + sin(angle) * outer))
            ctx.strokePath()
        }
    }

    private func drawSceneElements(ctx: CGContext, size: CGSize, centerX: CGFloat, centerY: CGFloat, type: PlaceholderSceneType, colors: SceneColors) {
        switch type {
        case .monster:
            // Draw monster silhouette
            ctx.setFillColor(UIColor.black.cgColor)
            let monsterPath = UIBezierPath()
            monsterPath.move(to: CGPoint(x: centerX, y: centerY + 120))
            monsterPath.addLine(to: CGPoint(x: centerX - 80, y: centerY + 200))
            monsterPath.addLine(to: CGPoint(x: centerX - 60, y: centerY + 140))
            monsterPath.addLine(to: CGPoint(x: centerX - 100, y: centerY + 100))
            monsterPath.addLine(to: CGPoint(x: centerX - 50, y: centerY + 80))
            monsterPath.addLine(to: CGPoint(x: centerX - 30, y: centerY + 40))
            monsterPath.addLine(to: CGPoint(x: centerX, y: centerY + 60))
            monsterPath.addLine(to: CGPoint(x: centerX + 30, y: centerY + 40))
            monsterPath.addLine(to: CGPoint(x: centerX + 50, y: centerY + 80))
            monsterPath.addLine(to: CGPoint(x: centerX + 100, y: centerY + 100))
            monsterPath.addLine(to: CGPoint(x: centerX + 60, y: centerY + 140))
            monsterPath.addLine(to: CGPoint(x: centerX + 80, y: centerY + 200))
            monsterPath.close()
            monsterPath.fill()

            // Eyes
            ctx.setFillColor(colors.accent.cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 25, y: centerY + 70, width: 15, height: 20))
            ctx.fillEllipse(in: CGRect(x: centerX + 10, y: centerY + 70, width: 15, height: 20))

        case .hero:
            // Draw heroic figure with cape
            ctx.setFillColor(colors.accent.cgColor)
            // Cape
            let capePath = UIBezierPath()
            capePath.move(to: CGPoint(x: centerX - 30, y: centerY + 60))
            capePath.addLine(to: CGPoint(x: centerX - 80, y: centerY + 200))
            capePath.addLine(to: CGPoint(x: centerX + 80, y: centerY + 200))
            capePath.addLine(to: CGPoint(x: centerX + 30, y: centerY + 60))
            capePath.close()
            capePath.fill()

            // Body silhouette
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 25, y: centerY + 30, width: 50, height: 50)) // head
            ctx.fill(CGRect(x: centerX - 30, y: centerY + 80, width: 60, height: 100)) // body

            // Arms raised
            ctx.setLineWidth(12)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: centerX - 25, y: centerY + 100))
            ctx.addLine(to: CGPoint(x: centerX - 70, y: centerY + 40))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: centerX + 25, y: centerY + 100))
            ctx.addLine(to: CGPoint(x: centerX + 70, y: centerY + 40))
            ctx.strokePath()

        case .shadow:
            // Dark menacing shadow figure
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.85).cgColor)
            let shadowPath = UIBezierPath()
            shadowPath.move(to: CGPoint(x: centerX, y: centerY + 20))
            shadowPath.addCurve(to: CGPoint(x: centerX - 100, y: centerY + 200),
                                 controlPoint1: CGPoint(x: centerX - 40, y: centerY + 60),
                                 controlPoint2: CGPoint(x: centerX - 120, y: centerY + 140))
            shadowPath.addLine(to: CGPoint(x: centerX + 100, y: centerY + 200))
            shadowPath.addCurve(to: CGPoint(x: centerX, y: centerY + 20),
                                 controlPoint1: CGPoint(x: centerX + 120, y: centerY + 140),
                                 controlPoint2: CGPoint(x: centerX + 40, y: centerY + 60))
            shadowPath.close()
            shadowPath.fill()

            // Glowing eyes
            ctx.setFillColor(colors.accent.cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 20, y: centerY + 50, width: 12, height: 8))
            ctx.fillEllipse(in: CGRect(x: centerX + 8, y: centerY + 50, width: 12, height: 8))

        case .action:
            // Door breaking / burst through
            ctx.setFillColor(UIColor.black.cgColor)
            // Debris pieces
            for _ in 0..<8 {
                let x = centerX + CGFloat.random(in: -100...100)
                let y = centerY + CGFloat.random(in: -50...150)
                let w = CGFloat.random(in: 15...40)
                let h = CGFloat.random(in: 10...30)
                let angle = CGFloat.random(in: 0...(2 * .pi))
                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: angle)
                ctx.fill(CGRect(x: -w/2, y: -h/2, width: w, height: h))
                ctx.restoreGState()
            }

            // Figure silhouette
            ctx.fillEllipse(in: CGRect(x: centerX - 20, y: centerY + 80, width: 40, height: 40))
            ctx.fill(CGRect(x: centerX - 25, y: centerY + 120, width: 50, height: 70))

        case .flying:
            // Figure soaring
            ctx.setFillColor(UIColor.black.cgColor)
            let flyPath = UIBezierPath()
            // Horizontal flying pose
            flyPath.move(to: CGPoint(x: centerX - 80, y: centerY + 80))
            flyPath.addLine(to: CGPoint(x: centerX + 80, y: centerY + 80))
            flyPath.addLine(to: CGPoint(x: centerX + 60, y: centerY + 100))
            flyPath.addLine(to: CGPoint(x: centerX - 60, y: centerY + 100))
            flyPath.close()
            flyPath.fill()

            // Head
            ctx.fillEllipse(in: CGRect(x: centerX + 50, y: centerY + 60, width: 35, height: 35))

            // Cape flowing back
            ctx.setFillColor(colors.accent.cgColor)
            let capePath = UIBezierPath()
            capePath.move(to: CGPoint(x: centerX - 60, y: centerY + 85))
            capePath.addCurve(to: CGPoint(x: centerX - 140, y: centerY + 140),
                               controlPoint1: CGPoint(x: centerX - 90, y: centerY + 100),
                               controlPoint2: CGPoint(x: centerX - 120, y: centerY + 120))
            capePath.addLine(to: CGPoint(x: centerX - 60, y: centerY + 100))
            capePath.close()
            capePath.fill()

        case .chase:
            // Running figure with motion blur
            ctx.setFillColor(UIColor.black.cgColor)

            // Multiple ghost images for motion
            for i in 0..<3 {
                let offsetX = CGFloat(i) * -25
                let alpha = 1.0 - (CGFloat(i) * 0.3)
                ctx.setFillColor(UIColor.black.withAlphaComponent(alpha).cgColor)

                let baseX = centerX + offsetX
                ctx.fillEllipse(in: CGRect(x: baseX - 15, y: centerY + 60, width: 30, height: 30))
                ctx.fill(CGRect(x: baseX - 18, y: centerY + 90, width: 36, height: 50))

                // Running legs
                ctx.setLineWidth(8)
                ctx.move(to: CGPoint(x: baseX - 10, y: centerY + 140))
                ctx.addLine(to: CGPoint(x: baseX - 30, y: centerY + 180))
                ctx.strokePath()
                ctx.move(to: CGPoint(x: baseX + 10, y: centerY + 140))
                ctx.addLine(to: CGPoint(x: baseX + 40, y: centerY + 160))
                ctx.strokePath()
            }

        case .generic:
            // Generic comic scene
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 25, y: centerY + 60, width: 50, height: 50))
            ctx.fill(CGRect(x: centerX - 30, y: centerY + 110, width: 60, height: 80))
        }
    }

    private func drawSoundEffectBurst(ctx: CGContext, centerX: CGFloat, centerY: CGFloat, soundEffect: String) {
        // Draw explosion burst shape
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(4)

        let burstPath = UIBezierPath()
        let points = 14
        let outerR: CGFloat = 90
        let innerR: CGFloat = 55
        for i in 0..<points * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let x = centerX + cos(angle) * r
            let y = centerY + sin(angle) * r
            if i == 0 {
                burstPath.move(to: CGPoint(x: x, y: y))
            } else {
                burstPath.addLine(to: CGPoint(x: x, y: y))
            }
        }
        burstPath.close()
        burstPath.fill()
        burstPath.stroke()

        // Draw sound effect text
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Impact", size: 42) ?? UIFont.boldSystemFont(ofSize: 42),
            .foregroundColor: UIColor.red,
            .strokeColor: UIColor.black,
            .strokeWidth: -3
        ]
        let textSize = soundEffect.size(withAttributes: textAttrs)
        soundEffect.draw(at: CGPoint(x: centerX - textSize.width / 2,
                                      y: centerY - textSize.height / 2),
                         withAttributes: textAttrs)
    }

    private func drawSceneLabel(ctx: CGContext, size: CGSize, text: String) {
        // Draw a small label at the bottom showing scene summary
        let truncated = text.count > 60 ? String(text.prefix(57)) + "..." : text

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]

        // Background box
        let labelSize = truncated.size(withAttributes: labelAttrs)
        let labelRect = CGRect(x: 12, y: size.height - labelSize.height - 16,
                               width: labelSize.width + 12, height: labelSize.height + 6)

        ctx.setFillColor(UIColor.white.withAlphaComponent(0.85).cgColor)
        let path = UIBezierPath(roundedRect: labelRect, cornerRadius: 4)
        path.fill()

        truncated.draw(at: CGPoint(x: 18, y: size.height - labelSize.height - 13), withAttributes: labelAttrs)
    }

    // MARK: - Control

    func cancel() {
        isCancelled = true
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
        isDownloading = false
    }
}

// MARK: - Placeholder Scene Types

private enum PlaceholderSceneType {
    case monster
    case hero
    case shadow
    case action
    case flying
    case chase
    case generic

    var defaultSoundEffect: String {
        switch self {
        case .monster: return "ROAR!"
        case .hero: return "POW!"
        case .shadow: return "DOOM!"
        case .action: return "SMASH!"
        case .flying: return "WHOOSH!"
        case .chase: return "ZOOM!"
        case .generic: return "BAM!"
        }
    }

    func colors(for style: MLXImageStyle) -> SceneColors {
        switch self {
        case .monster:
            return SceneColors(primary: .systemGreen, secondary: .black, accent: .systemRed)
        case .hero:
            return SceneColors(primary: .systemYellow, secondary: .systemOrange, accent: .systemBlue)
        case .shadow:
            return SceneColors(primary: .systemIndigo, secondary: .black, accent: .systemPurple)
        case .action:
            return SceneColors(primary: .systemOrange, secondary: .systemYellow, accent: .systemRed)
        case .flying:
            return SceneColors(primary: .systemCyan, secondary: .systemBlue, accent: .systemRed)
        case .chase:
            return SceneColors(primary: .systemRed, secondary: .systemOrange, accent: .black)
        case .generic:
            switch style {
            case .comicBook: return SceneColors(primary: .systemYellow, secondary: .systemOrange, accent: .systemRed)
            case .popArt: return SceneColors(primary: .systemRed, secondary: .systemPink, accent: .systemYellow)
            case .graphicNovel: return SceneColors(primary: .systemBlue, secondary: .systemIndigo, accent: .white)
            case .lineArt: return SceneColors(primary: .white, secondary: .systemGray5, accent: .black)
            }
        }
    }
}

private struct SceneColors {
    let primary: UIColor
    let secondary: UIColor
    let accent: UIColor
}

// MARK: - Comic Panel Layout Generator

struct MLXComicPanelLayout {

    enum LayoutStyle {
        case vertical
        case grid
        case dynamic
        case widescreen
    }

    static func createComicPage(
        images: [UIImage],
        style: LayoutStyle = .dynamic,
        pageSize: CGSize = CGSize(width: 1024, height: 1536)
    ) -> UIImage? {
        guard !images.isEmpty else { return nil }

        let renderer = UIGraphicsImageRenderer(size: pageSize)

        return renderer.image { context in
            let ctx = context.cgContext
            let margin: CGFloat = 20
            let gutter: CGFloat = 12
            let borderWidth: CGFloat = 4

            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: pageSize))

            let frames = calculatePanelFrames(
                count: images.count, style: style, pageSize: pageSize,
                margin: margin, gutter: gutter
            )

            for (index, image) in images.enumerated() {
                guard index < frames.count else { break }
                let frame = frames[index]

                ctx.setShadow(offset: CGSize(width: 3, height: 3), blur: 5,
                              color: UIColor.black.withAlphaComponent(0.3).cgColor)
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(frame)
                ctx.setShadow(offset: .zero, blur: 0)

                let imageFrame = frame.insetBy(dx: borderWidth, dy: borderWidth)
                drawImageAspectFill(image: image, in: imageFrame, context: ctx)

                ctx.setStrokeColor(UIColor.black.cgColor)
                ctx.setLineWidth(borderWidth)
                ctx.stroke(frame.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
            }
        }
    }

    private static func drawImageAspectFill(image: UIImage, in rect: CGRect, context: CGContext) {
        let imageAspect = image.size.width / image.size.height
        let rectAspect = rect.width / rect.height

        var drawRect: CGRect
        if imageAspect > rectAspect {
            let scaledWidth = rect.height * imageAspect
            drawRect = CGRect(x: rect.minX - (scaledWidth - rect.width) / 2,
                              y: rect.minY, width: scaledWidth, height: rect.height)
        } else {
            let scaledHeight = rect.width / imageAspect
            drawRect = CGRect(x: rect.minX, y: rect.minY - (scaledHeight - rect.height) / 2,
                              width: rect.width, height: scaledHeight)
        }

        context.saveGState()
        context.clip(to: rect)
        image.draw(in: drawRect)
        context.restoreGState()
    }

    private static func calculatePanelFrames(
        count: Int, style: LayoutStyle, pageSize: CGSize,
        margin: CGFloat, gutter: CGFloat
    ) -> [CGRect] {
        let w = pageSize.width - margin * 2
        let h = pageSize.height - margin * 2

        switch style {
        case .vertical:
            let ph = (h - gutter * CGFloat(count - 1)) / CGFloat(count)
            return (0..<count).map {
                CGRect(x: margin, y: margin + (ph + gutter) * CGFloat($0), width: w, height: ph)
            }

        case .grid:
            let cols = count <= 2 ? 1 : 2
            let rows = Int(ceil(Double(count) / Double(cols)))
            let pw = (w - gutter * CGFloat(cols - 1)) / CGFloat(cols)
            let ph = (h - gutter * CGFloat(rows - 1)) / CGFloat(rows)
            return (0..<count).map {
                CGRect(x: margin + (pw + gutter) * CGFloat($0 % cols),
                       y: margin + (ph + gutter) * CGFloat($0 / cols),
                       width: pw, height: ph)
            }

        case .dynamic:
            return createDynamicLayout(count: count, w: w, h: h, margin: margin, gutter: gutter)

        case .widescreen:
            let ph = w * 9 / 16
            let totalH = ph * CGFloat(count) + gutter * CGFloat(count - 1)
            let startY = margin + (h - totalH) / 2
            return (0..<count).map {
                CGRect(x: margin, y: startY + (ph + gutter) * CGFloat($0), width: w, height: ph)
            }
        }
    }

    private static func createDynamicLayout(
        count: Int, w: CGFloat, h: CGFloat, margin: CGFloat, gutter: CGFloat
    ) -> [CGRect] {
        switch count {
        case 2:
            return [
                CGRect(x: margin, y: margin, width: w, height: h * 0.58),
                CGRect(x: margin, y: margin + h * 0.58 + gutter, width: w, height: h * 0.42 - gutter)
            ]
        case 3:
            let topH = h * 0.55
            let botH = h - topH - gutter
            let halfW = (w - gutter) / 2
            return [
                CGRect(x: margin, y: margin, width: w, height: topH),
                CGRect(x: margin, y: margin + topH + gutter, width: halfW, height: botH),
                CGRect(x: margin + halfW + gutter, y: margin + topH + gutter, width: halfW, height: botH)
            ]
        case 4:
            let halfW = (w - gutter) / 2
            let topH = h * 0.48
            let botH = h - topH - gutter
            return [
                CGRect(x: margin, y: margin, width: halfW * 0.85, height: topH),
                CGRect(x: margin + halfW * 0.85 + gutter, y: margin, width: halfW * 1.15, height: topH),
                CGRect(x: margin, y: margin + topH + gutter, width: halfW * 1.15, height: botH),
                CGRect(x: margin + halfW * 1.15 + gutter, y: margin + topH + gutter, width: halfW * 0.85, height: botH)
            ]
        default:
            let ph = (h - gutter * CGFloat(count - 1)) / CGFloat(count)
            return (0..<count).map {
                CGRect(x: margin, y: margin + (ph + gutter) * CGFloat($0), width: w, height: ph)
            }
        }
    }
}
