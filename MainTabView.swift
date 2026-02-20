import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: DreamStore
    @State private var selectedTab = 0
    @State private var dreamsPath = NavigationPath()
    @State private var pendingDreamID: UUID?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                NewDreamView(isTab: true) { savedDreamID in
                    pendingDreamID = savedDreamID
                    selectedTab = 1
                }
            }
            .tabItem {
                Label(L("New Dream"), systemImage: "pencil.and.scribble")
            }
            .tag(0)

            NavigationStack(path: $dreamsPath) {
                DreamsListView()
                    .navigationDestination(for: UUID.self) { dreamID in
                        if let dream = store.dreams.first(where: { $0.id == dreamID }) {
                            DreamDetailView(dream: dream)
                        }
                    }
            }
            .tabItem {
                Label(L("Dreams"), systemImage: "moon.stars.fill")
            }
            .tag(1)

            NavigationStack {
                DreamAnalysisView()
            }
            .tabItem {
                Label(L("Analysis"), systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(L("Settings"), systemImage: "gearshape.fill")
            }
            .tag(3)
        }
        .tint(ComicTheme.Colors.deepPurple)
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 1, let dreamID = pendingDreamID {
                pendingDreamID = nil
                // Small delay to let the tab switch complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dreamsPath.append(dreamID)
                }
            }
        }
    }
}
