import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: DreamStore
    @State private var showNewDream = false
    
    var body: some View {
        NavigationView {
            List {
                if store.dreams.isEmpty {
                    Text("No dreams yet. Tap + to add one 🌙")
                        .foregroundColor(.secondary)
                }
                
                ForEach(store.dreams) { dream in
                    NavigationLink(destination: DreamDetailView(dream: dream)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dream.originalText)
                                .lineLimit(2)
                                .font(.body)
                            
                            if let tone = dream.tone {
                                Text("Rewritten: \(tone.capitalized)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Not rewritten yet")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("DreamCatcher")
            .toolbar {
                Button {
                    showNewDream = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showNewDream) {
                NewDreamView()
            }
        }
    }
}
