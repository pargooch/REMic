import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: DreamStore
    @State private var showNewDream = false
    @State private var showSettings = false
    @State private var showAnalysis = false
    @State private var searchText = ""

    private var filteredDreams: [Dream] {
        guard !searchText.isEmpty else { return store.dreams }
        let query = searchText.lowercased()
        return store.dreams.filter {
            $0.originalText.lowercased().contains(query) ||
            ($0.rewrittenText?.lowercased().contains(query) ?? false) ||
            ($0.tone?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                    if store.dreams.isEmpty {
                        emptyState
                    } else if filteredDreams.isEmpty {
                        Text("No dreams match your search")
                            .font(ComicTheme.Typography.speechBubble(13))
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(filteredDreams) { dream in
                            SwipeToDeleteWrapper {
                                NavigationLink {
                                    DreamDetailView(dream: dream)
                                } label: {
                                    DreamRowView(dream: dream)
                                }
                                .buttonStyle(.plain)
                            } onDelete: {
                                NotificationManager.shared.cancelDreamNotification(for: dream.id)
                                withAnimation(.spring(response: 0.3)) {
                                    store.deleteDream(dream)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .halftoneBackground()
            .navigationTitle("Dreams")
            .searchable(text: $searchText, prompt: "Search dreams...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(ComicTheme.Colors.deepPurple)
                        }

                        if AuthManager.shared.isAuthenticated {
                            Button {
                                showAnalysis = true
                            } label: {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(ComicTheme.Colors.hotPink)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewDream = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(ComicTheme.Colors.boldBlue)
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
            .sheet(isPresented: $showAnalysis) {
                NavigationView {
                    DreamAnalysisView()
                }
            }
        }
    }

    private var emptyState: some View {
        ComicPanelCard(titleBanner: "Welcome, Dreamer!", bannerColor: ComicTheme.Colors.deepPurple) {
            VStack(spacing: 16) {
                SoundEffectText(text: "DREAM ON!", fillColor: ComicTheme.Colors.goldenYellow, fontSize: 42)

                Text("Record your first dream to begin your comic journey!")
                    .font(ComicTheme.Typography.speechBubble())
                    .multilineTextAlignment(.center)
                    .speechBubble()

                Button {
                    showNewDream = true
                } label: {
                    Label("Capture a Dream", systemImage: "moon.stars.fill")
                }
                .buttonStyle(.comicPrimary(color: ComicTheme.Colors.deepPurple))
            }
        }
        .padding(.top, 40)
    }
}

struct DreamRowView: View {
    let dream: Dream
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    private var accentColor: Color {
        if dream.hasComicPages { return ComicTheme.Colors.boldBlue }
        if dream.rewrittenText != nil { return ComicTheme.Colors.goldenYellow }
        return ComicTheme.Colors.deepPurple
    }

    var body: some View {
        ComicPanelCard {
            HStack(spacing: 12) {
                // Thumbnail if comic pages or images exist
                if let firstPage = dream.sortedComicPages.first, let uiImage = firstPage.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ComicTheme.panelBorderColor(colorScheme), lineWidth: 1.5)
                        )
                } else if let firstImage = dream.sortedImages.first, let uiImage = firstImage.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ComicTheme.panelBorderColor(colorScheme), lineWidth: 1.5)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(dream.originalText)
                        .lineLimit(2)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        // Date badge
                        Text(dream.date, style: .date)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.15))
                            .foregroundColor(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Spacer()

                        if dream.rewrittenText != nil {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.goldenYellow)
                        }

                        if dream.hasComicPages || dream.hasImages {
                            Image(systemName: "book.pages.fill")
                                .font(.caption.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.boldBlue)
                        }
                    }
                }
            }
        }
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// MARK: - Swipe to Delete

struct SwipeToDeleteWrapper<Content: View>: View {
    let content: Content
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showConfirm = false
    @Environment(\.colorScheme) private var colorScheme

    private let deleteThreshold: CGFloat = -80
    private let snapThreshold: CGFloat = -40

    init(@ViewBuilder content: () -> Content, onDelete: @escaping () -> Void) {
        self.content = content()
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            HStack(spacing: 0) {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        onDelete()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text("DELETE")
                            .font(.system(size: 10, weight: .black))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80)
                    .frame(maxHeight: .infinity)
                    .background(ComicTheme.Colors.crimsonRed)
                    .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.panelCornerRadius))
                }
                .buttonStyle(.plain)
            }
            .opacity(offset < 0 ? 1 : 0)

            // Main content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            // Only allow swiping left
                            if translation < 0 {
                                offset = translation * 0.8
                            } else if offset < 0 {
                                offset = min(0, offset + translation * 0.3)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if offset < deleteThreshold {
                                    // Snap open to show delete button
                                    offset = deleteThreshold
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if offset < 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    offset = 0
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DreamStore())
}
