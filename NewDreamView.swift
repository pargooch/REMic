import SwiftUI

struct NewDreamView: View {
    @EnvironmentObject var store: DreamStore
    @Environment(\.dismiss) var dismiss
    
    @State private var dreamText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Write your dream or nightmare")
                    .font(.headline)
                    .padding(.top)
                
                TextEditor(text: $dreamText)
                    .padding()
                    .frame(height: 250)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                
                Button("Save") {
                    let dream = Dream(originalText: dreamText)
                    store.addDream(dream)
                    dismiss()
                }
                .padding()
            }
            .navigationTitle("New Dream")
        }
    }
}
