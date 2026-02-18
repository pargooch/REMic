import Foundation
import UIKit

struct Dream: Identifiable, Codable {
    let id: UUID
    var originalText: String
    var rewrittenText: String?
    var tone: String?
    var date: Date
    var generatedImages: [GeneratedDreamImage]?
    var imageStyle: String?
    var comicPages: [ComicPageImage]?
    var comicLayoutPlan: ComicLayoutPlan?
    var includeAvatarInComic: Bool?
    var analysis: DreamAnalysisResponse?

    init(originalText: String, date: Date = Date()) {
        self.id = UUID()
        self.originalText = originalText
        self.rewrittenText = nil
        self.tone = nil
        self.date = date
        self.generatedImages = nil
        self.imageStyle = nil
        self.comicPages = nil
        self.comicLayoutPlan = nil
        self.includeAvatarInComic = nil
        self.analysis = nil
    }

    var hasImages: Bool {
        guard let images = generatedImages else { return false }
        return !images.isEmpty
    }

    var hasComicPages: Bool {
        guard let pages = comicPages else { return false }
        return !pages.isEmpty
    }

    var sortedImages: [GeneratedDreamImage] {
        (generatedImages ?? []).sorted { $0.sequenceIndex < $1.sequenceIndex }
    }

    var sortedComicPages: [ComicPageImage] {
        (comicPages ?? []).sorted { $0.pageNumber < $1.pageNumber }
    }
}

// MARK: - Comic Page Image

struct ComicPageImage: Identifiable, Codable, Equatable {
    let id: UUID
    let imageData: Data
    let pageNumber: Int
    let createdAt: Date

    init(imageData: Data, pageNumber: Int) {
        self.id = UUID()
        self.imageData = imageData
        self.pageNumber = pageNumber
        self.createdAt = Date()
    }

    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}
