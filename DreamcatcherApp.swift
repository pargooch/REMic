import SwiftUI

@main
struct DreamCatcherApp: App {
    @StateObject var store = DreamStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
