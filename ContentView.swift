import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: DreamStore
    @State private var showNewDream = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                if store.dreams.isEmpty {
                    Text("No dreams yet")
                        .foregroundColor(.secondary)
                }

                ForEach(store.dreams) { dream in
                    NavigationLink {
                        DreamDetailView(dream: dream)
                    } label: {
                        DreamRowView(dream: dream)
                    }
                }
                .onDelete(perform: deleteDreams)
            }
            .navigationTitle("Dreamcatcher")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewDream = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewDream) {
                NewDreamView()
            }
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    SettingsView()
                }
            }
        }
    }

    private func deleteDreams(at offsets: IndexSet) {
        for index in offsets {
            let dream = store.dreams[index]
            NotificationManager.shared.cancelDreamNotification(for: dream.id)
            store.deleteDream(dream)
        }
    }
}

struct DreamRowView: View {
    let dream: Dream

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dream.originalText)
                .lineLimit(2)

            HStack {
                Text(dream.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if dream.rewrittenText != nil {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DreamStore())
}
