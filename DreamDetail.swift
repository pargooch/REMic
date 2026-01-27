import SwiftUI

struct DreamDetailView: View {
    @EnvironmentObject var store: DreamStore
    let dream: Dream
    
    @State private var selectedTone = "happy"
    
    let tones = ["happy", "funny", "hopeful", "calm", "positive"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                Text("Original Dream")
                    .font(.headline)
                Text(dream.originalText)
                
                Divider()
                
                if let rewritten = dream.rewrittenText {
                    Text("Rewritten Dream (\(dream.tone ?? ""))")
                        .font(.headline)
                    Text(rewritten)
                } else {
                    Text("Choose how you want this dream to become:")
                    
                    Picker("Tone", selection: $selectedTone) {
                        ForEach(tones, id: \.self) { t in
                            Text(t.capitalized)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Button("Rewrite with AI") {
                        rewriteDream()
                    }
                    .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle("Dream")
    }
    
    func rewriteDream() {
        // This will call AI next (we’ll implement it)
    }
}
