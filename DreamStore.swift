import Foundation
import Combine     // ← THIS fixes all errors

class DreamStore: ObservableObject {
    @Published var dreams: [Dream] = []
    
    func addDream(_ dream: Dream) {
        dreams.insert(dream, at: 0)
    }
    
    func updateDream(_ dream: Dream) {
        if let index = dreams.firstIndex(where: { $0.id == dream.id }) {
            dreams[index] = dream
        }
    }
}
