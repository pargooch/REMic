import Foundation

struct Dream: Identifiable, Codable {
    let id: UUID
    var originalText: String
    var rewrittenText: String?
    var tone: String?
    var date: Date
    
    init(originalText: String) {
        self.id = UUID()
        self.originalText = originalText
        self.rewrittenText = nil
        self.tone = nil
        self.date = Date()
    }
}
